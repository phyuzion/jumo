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

    // 채널 이름: "com.jumo.mobile/nativeDefaultDialer"
    private val ACTIVITY_CHANNEL_NAME = "com.jumo.mobile/nativeDefaultDialer"

    // Flutter -> "requestDefaultDialerManually" 호출 시 결과 반환용
    private var methodResultForDialer: MethodChannel.Result? = null

    // ---- 기존: callPermissionLauncher (optional) ----
    // 만약 requestDefaultDialer() 과정에서 CALL_PHONE 권한이 필요하다면 사용.
    // 그러나 지금은 Flutter(permission_handler)에서 권한을 얻으므로 여기선 굳이 안써도 됨.
    private val callPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (!granted) {
            Toast.makeText(this, "CALL_PHONE 권한이 필요합니다.", Toast.LENGTH_SHORT).show()
            methodResultForDialer?.success(false)
            methodResultForDialer = null
        } else {
            requestSetDefaultDialer()  // 권한 OK 시도
        }
    }

    // ---- Role Dialer request launcher ----
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

        // **(변경)**: onCreate 시점에 "checkCallPermission()" 제거
        // handleDialIntent(intent) 는 그대로 (ACTION_DIAL / ACTION_VIEW 등)
        handleDialIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent: $intent")

        if (intent.getBooleanExtra("incoming_call", false)) {
            Log.d(TAG, "Incoming call intent received")
            enableLockScreenFlags()
            val number = intent.getStringExtra("incoming_number") ?: ""
            NativeBridge.notifyIncomingNumber(number)
        } else if (intent.getBooleanExtra("call_ended", false)) {
            Log.d(TAG, "Call ended intent received")
            NativeBridge.notifyCallEnded()
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

    /**
     * (Optional) CALL_PHONE 권한 체크 -> roleDialer
     *  Flutter(permission_handler) 에서 이미 권한을 받았다고 가정하면
     *  사실상 아래 코드는 "requestSetDefaultDialer()" 만 호출해도 됨.
     */
    private fun checkCallPermissionAndRequestDialer() {
        val callPerm = android.Manifest.permission.CALL_PHONE
        if (ContextCompat.checkSelfPermission(this, callPerm) != PackageManager.PERMISSION_GRANTED) {
            callPermissionLauncher.launch(callPerm)
        } else {
            requestSetDefaultDialer()
        }
    }

    private fun requestSetDefaultDialer() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)
                && !roleManager.isRoleHeld(RoleManager.ROLE_DIALER)
            ) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                roleRequestLauncher.launch(intent)
            } else {
                // 이미 기본 전화앱
                methodResultForDialer?.success(true)
                methodResultForDialer = null
            }
        } else {
            // 구버전: ...
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
                // e.g. NativeBridge.notifyDialNumber(phoneNumber)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeBridge.setupChannel(flutterEngine)

        // MethodChannel for "com.jumo.mobile/nativeDefaultDialer"
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACTIVITY_CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestDefaultDialerManually" -> {
                    Log.d(TAG, "[MethodChannel] requestDefaultDialerManually")
                    methodResultForDialer = result

                    // 여기서도 "Flutter에서 이미 권한 받았다" 가정 => 바로 requestSetDefaultDialer()
                    // 또는 "혹시 모르니 권한체크" => checkCallPermissionAndRequestDialer()

                    requestSetDefaultDialer()  
                    // or checkCallPermissionAndRequestDialer()
                }

                "isDefaultDialer" -> {
                    val isDef = isDefaultDialer()
                    result.success(isDef)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
