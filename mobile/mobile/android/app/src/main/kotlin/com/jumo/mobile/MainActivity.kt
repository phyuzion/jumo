package com.jumo.mobile

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.TelecomManager
import android.util.Log
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {

    private val TAG = "Jumo Activity"

    private val ACTIVITY_CHANNEL_NAME = "com.jumo.mobile/nativeDefaultDialer"
    private var methodResultForDialer: MethodChannel.Result? = null

    private var flutterAppInitialized = false
    private var pendingIncomingNumber: String? = null
    
    private val REQUEST_CODE_SET_DEFAULT_DIALER = 1001

    private val callPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (!granted) {
            Toast.makeText(this, "CALL_PHONE 권한이 필요합니다.", Toast.LENGTH_SHORT).show()
            methodResultForDialer?.success(false)
            methodResultForDialer = null
        } else {
            requestSetDefaultDialer()
        }
    }

    private val roleRequestLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK) {
            Log.d(TAG, "기본 전화앱 설정 완료")
            // 기본 전화앱으로 설정된 후 통화 상태 초기화
            NativeBridge.resetCallState()
            // 화면 잠금 플래그 비활성화
            disableLockScreenFlags()
            // 인코밍 콜 관련 변수 초기화
            pendingIncomingNumber = null
            methodResultForDialer?.success(true)
        } else {
            Log.d(TAG, "기본 전화앱 설정 거부")
            methodResultForDialer?.success(false)
        }
        methodResultForDialer = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 시작 시 기본적으로 화면 잠금 플래그 비활성화
        disableLockScreenFlags()
        
        // 인텐트 확인 및 처리
        checkIntentForCall(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        checkIntentForCall(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SET_DEFAULT_DIALER) {
            if (isDefaultDialer()) {
                Log.d(TAG, "기본 전화앱 설정 완료 (하위 버전)")
                NativeBridge.resetCallState()
                methodResultForDialer?.success(true)
            } else {
                Log.d(TAG, "기본 전화앱 설정 거부 (하위 버전)")
                methodResultForDialer?.success(false)
            }
            methodResultForDialer = null
        }
    }

    override fun onResume() {
        super.onResume()
        
        // 앱이 다시 활성화될 때 통화 상태 확인
        try {
            val callDetails = PhoneInCallService.getCurrentCallDetails()
            val state = callDetails["state"] as String? ?: "IDLE"
            
            // 수신 전화 또는 통화 중인 경우 화면 잠금 플래그 활성화
            if (state == "RINGING" || state == "ACTIVE" || state == "DIALING" || state == "HOLDING") {
                Log.d(TAG, "onResume: 통화 관련 상태 감지($state), 화면 잠금 플래그 활성화")
                enableLockScreenFlags()
            } else {
                Log.d(TAG, "onResume: 통화 중이 아님($state), 화면 잠금 플래그 비활성화")
                disableLockScreenFlags()
            }
        } catch (e: Exception) {
            Log.e(TAG, "onResume: 통화 상태 확인 중 오류", e)
            disableLockScreenFlags()
        }
    }

    private fun checkIntentForCall(intent: Intent?){
        if (intent == null) return

        // 노티피케이션에서 전화 수락/거절 액션 처리
        if (intent.action == "ACCEPT_CALL") {
            Log.d(TAG, "Accept call action from notification")
            val number = intent.getStringExtra("incoming_number") ?: ""
            PhoneInCallService.acceptCall()
            // 수락 후 앱을 전면에 표시
            enableLockScreenFlags()
            return
        } else if (intent.action == "REJECT_CALL") {
            Log.d(TAG, "Reject call action from notification")
            PhoneInCallService.rejectCall()
            disableLockScreenFlags()
            return
        }

        if (intent.getBooleanExtra("incoming_call", false)) {
            Log.d(TAG, "Incoming call intent received")
            // 수신 전화일 때 화면 잠금 플래그 활성화
            enableLockScreenFlags()
            val number = intent.getStringExtra("incoming_number") ?: ""
            if (!flutterAppInitialized) {
                Log.d(TAG, "Flutter not init => pendingIncomingNumber=$number")
                pendingIncomingNumber = number
            } else {
                Log.d(TAG, "Flutter init => notifyIncomingNumber($number)")
                NativeBridge.notifyIncomingNumber(number)
            }
        } else if (intent.getBooleanExtra("waiting_call", false)) {
            Log.d(TAG, "Waiting call intent received")
            // 대기 통화에도 화면 잠금 플래그 활성화
            enableLockScreenFlags()
            val activeNumber = intent.getStringExtra("active_number") ?: ""
            val waitingNumber = intent.getStringExtra("waiting_number") ?: ""
            Log.d(TAG, "Waiting call data: active=$activeNumber, waiting=$waitingNumber")
            
            // 여기서는 NativeBridge.notifyWaitingCall을 직접 호출하지 않음
            // PhoneInCallService에서 이미 호출했기 때문
            
        } else if (intent.getBooleanExtra("on_call", false)) {
            Log.d(TAG, "On Call intent received")
            // 통화 중에도 화면 잠금 플래그 활성화
            enableLockScreenFlags()
            val onCallNumber = intent.getStringExtra("on_call_number") ?: ""
            val onCallConnected = intent.getBooleanExtra("on_call_connected", false)
            NativeBridge.notifyOnCall(onCallNumber, onCallConnected) 
        } else if (intent.getBooleanExtra("call_ended", false)) {
            Log.d(TAG, "Call ended intent received")
            // 통화 종료 시 화면 잠금 플래그 비활성화
            disableLockScreenFlags()
            val endedNumber = intent.getStringExtra("call_ended_number") ?: ""
            val reason = intent.getStringExtra("call_ended_reason") ?: ""
            NativeBridge.notifyCallEnded(endedNumber, reason) 
        } else {
            // 통화 관련 인텐트가 아닌 경우 화면 잠금 플래그 비활성화
            disableLockScreenFlags()
        }
        handleDialIntent(intent)
    }

    private fun enableLockScreenFlags() {
        Log.d(TAG, "Enabling lock screen flags for incoming call")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
    }

    private fun disableLockScreenFlags() {
        Log.d(TAG, "Disabling lock screen flags")
        window.clearFlags(
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
    }

    private fun requestSetDefaultDialer() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                roleRequestLauncher.launch(intent)
            } else {
                methodResultForDialer?.success(true)
                methodResultForDialer = null
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Android 8.0 (Oreo) 이상, Android 10 미만
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val changeDialerIntent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
                .putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
            
            try {
                startActivityForResult(changeDialerIntent, REQUEST_CODE_SET_DEFAULT_DIALER)
            } catch (e: Exception) {
                Log.e(TAG, "기본 전화앱 설정 인텐트 실행 실패", e)
                methodResultForDialer?.success(false)
                methodResultForDialer = null
            }
        } else {
            // Android 8.0 미만
            methodResultForDialer?.success(false)
            methodResultForDialer = null
        }
    }

    private fun isDefaultDialer(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            return roleManager.isRoleHeld(RoleManager.ROLE_DIALER)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Android 8.0 (Oreo) 이상, Android 10 미만
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            return packageName == telecomManager.defaultDialerPackage
        }
        return false
    }

    private fun handleDialIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action == Intent.ACTION_DIAL || action == Intent.ACTION_VIEW) {
            val data: Uri? = intent.data
            if (data != null && data.scheme == "tel") {
                val phoneNumber = data.schemeSpecificPart
                Log.d(TAG, "Dial intent with number: $phoneNumber")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        NativeBridge.setupChannel(flutterEngine)
        try {
            flutterEngine.plugins.add(SmsPlugin()) 
        } catch (e: Exception) {
            Log.e(TAG, "SmsPlugin 등록 중 오류 발생.", e)
        }
        
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACTIVITY_CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestDefaultDialerManually" -> {
                    methodResultForDialer = result
                    requestSetDefaultDialer()
                    
                }
                "isDefaultDialer" -> {
                    result.success(isDefaultDialer())
                }
                "setAppInitialized" -> {
                    flutterAppInitialized = true
                    pendingIncomingNumber?.let { number ->
                        Log.d(TAG, "Flushing pending incoming call to Flutter: $number")
                        NativeBridge.notifyIncomingNumber(number)
                        pendingIncomingNumber = null
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
