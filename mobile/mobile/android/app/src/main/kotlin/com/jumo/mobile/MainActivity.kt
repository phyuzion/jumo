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

class MainActivity : FlutterFragmentActivity() {

    private val TAG = "MainActivity"

    private val ACTIVITY_CHANNEL_NAME = "com.jumo.mobile/nativeDefaultDialer"
    private var methodResultForDialer: MethodChannel.Result? = null

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
        handleDialIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent: $intent")

        if (intent.getBooleanExtra("incoming_call", false)) {
            // 수신 전화
            Log.d(TAG, "Incoming call intent received")
            enableLockScreenFlags()
            val number = intent.getStringExtra("incoming_number") ?: ""
            NativeBridge.notifyIncomingNumber(number)

        } else if (intent.getBooleanExtra("on_call", false)) {
            // 통화시작
            Log.d(TAG, "On Call intent received")
            val onCallNumber = intent.getStringExtra("on_call_number") ?: ""
            val onCallConnected = intent.getBooleanExtra("on_call_connected", false)
            NativeBridge.notifyOnCall(onCallNumber, onCallConnected) 
            // 통화 종료 + 번호
        } else if (intent.getBooleanExtra("call_ended", false)) {
            // 통화 종료
            Log.d(TAG, "Call ended intent received")
            val endedNumber = intent.getStringExtra("call_ended_number") ?: ""
            val reason = intent.getStringExtra("call_ended_reason") ?: ""
            NativeBridge.notifyCallEnded(endedNumber, reason) 
            // 통화 종료 + 번호
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
            if (roleManager.isRoleAvailable(RoleManager.ROLE_DIALER) &&
                !roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
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
                // e.g. NativeBridge.notifyDialNumber(phoneNumber) or ignore
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeBridge.setupChannel(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACTIVITY_CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestDefaultDialerManually" -> {
                    methodResultForDialer = result
                    // Flutter에서 이미 권한을 받았다고 가정
                    requestSetDefaultDialer()
                }

                "isDefaultDialer" -> {
                    val isDef = isDefaultDialer()
                    result.success(isDef)
                }

                else -> result.notImplemented()
            }
        }
    }
}
