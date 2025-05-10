package com.jumo.mobile

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
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
            methodResultForDialer?.success(true)
        } else {
            Log.d(TAG, "기본 전화앱 설정 거부")
            methodResultForDialer?.success(false)
        }
        methodResultForDialer = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkIntentForCall(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        checkIntentForCall(intent)
    }

    private fun checkIntentForCall(intent: Intent?){
        if (intent == null) return

        if (intent.getBooleanExtra("incoming_call", false)) {
            Log.d(TAG, "Incoming call intent received")
            enableLockScreenFlags()
            val number = intent.getStringExtra("incoming_number") ?: ""
            if (!flutterAppInitialized) {
                Log.d(TAG, "Flutter not init => pendingIncomingNumber=$number")
                pendingIncomingNumber = number
            } else {
                Log.d(TAG, "Flutter init => notifyIncomingNumber($number)")
                NativeBridge.notifyIncomingNumber(number)
            }
        } else if (intent.getBooleanExtra("on_call", false)) {
            Log.d(TAG, "On Call intent received")
            val onCallNumber = intent.getStringExtra("on_call_number") ?: ""
            val onCallConnected = intent.getBooleanExtra("on_call_connected", false)
            NativeBridge.notifyOnCall(onCallNumber, onCallConnected) 
        } else if (intent.getBooleanExtra("call_ended", false)) {
            Log.d(TAG, "Call ended intent received")
            val endedNumber = intent.getStringExtra("call_ended_number") ?: ""
            val reason = intent.getStringExtra("call_ended_reason") ?: ""
            NativeBridge.notifyCallEnded(endedNumber, reason) 
        }
        handleDialIntent(intent)
    }

    private fun enableLockScreenFlags() {
        window.addFlags(
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
        } else {
            methodResultForDialer?.success(false)
            methodResultForDialer = null
        }
    }

    private fun isDefaultDialer(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            return roleManager.isRoleHeld(RoleManager.ROLE_DIALER)
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
        
        // 1. 자동 생성된 플러그인 등록 (외부 플러그인 용)
        // GeneratedPluginRegistrant.registerWith(flutterEngine)는 보통 자동으로 프로젝트에 포함되어 있거나,
        // FlutterActivity에서 내부적으로 처리될 수 있습니다. 만약 중복 호출 오류가 나면 이 줄을 주석처리하거나 삭제하세요.
        // 명시적으로 호출해야 한다면 아래와 같이 합니다.
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine)    
        } catch (e: Exception) {
            Log.e(TAG, "GeneratedPluginRegistrant 등록 중 오류: ", e)
        }

        // 2. NativeBridge 채널 설정 (기존 방식 유지)
        NativeBridge.setupChannel(flutterEngine)
        // 3. SmsPlugin 수동 등록
        try {
            flutterEngine.plugins.add(SmsPlugin()) 
        } catch (e: Exception) {
            Log.e(TAG, "SmsPlugin 등록 중 오류 발생.", e)
        }
        
        // 4. 기존 ACTIVITY_CHANNEL_NAME 채널 설정 (유지)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACTIVITY_CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestDefaultDialerManually" -> {
                    methodResultForDialer = result
                    // CALL_PHONE 권한 확인 및 요청은 여기서 하는 것이 적절
                    if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                        requestSetDefaultDialer()
                    } else {
                        callPermissionLauncher.launch(android.Manifest.permission.CALL_PHONE)
                    }
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
