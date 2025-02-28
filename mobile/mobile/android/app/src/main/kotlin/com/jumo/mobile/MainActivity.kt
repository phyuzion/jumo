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

class MainActivity : FlutterFragmentActivity() {

    private val TAG = "MainActivity"

    private val callPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (!granted) {
            Toast.makeText(this, "CALL_PHONE 권한이 필요합니다.", Toast.LENGTH_SHORT).show()
        } else {
            requestSetDefaultDialer()
        }
    }

    private val roleRequestLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK) {
            Log.d(TAG, "기본 전화앱 설정 완료")
        } else {
            Log.d(TAG, "기본 전화앱 설정 거부")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkCallPermission()
        handleDialIntent(intent)

        
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent: $intent")

        if (intent.getBooleanExtra("incoming_call", false)) {
            Log.d(TAG, "Incoming call intent received")
            enableLockScreenFlags()

            val number = intent.getStringExtra("incoming_number") ?: ""
            Log.d(TAG, "Incoming call number = $number")

            NativeBridge.notifyIncomingNumber(number)
        }
        else if (intent.getBooleanExtra("call_ended", false)) {
            Log.d(TAG, "Call ended intent received")
            // Flutter에 통화종료 알림
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

    private fun checkCallPermission() {
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
            if (roleManager.isRoleAvailable(RoleManager.ROLE_DIALER) &&
                !roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                roleRequestLauncher.launch(intent)
            }
        } else {
            // 구버전: TelecomManager.ACTION_CHANGE_DEFAULT_DIALER
        }
    }

    // ACTION_DIAL / ACTION_VIEW(tel:) 인텐트 => Flutter로 전달
    private fun handleDialIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action == Intent.ACTION_DIAL || action == Intent.ACTION_VIEW) {
            val data: Uri? = intent.data
            if (data != null && data.scheme == "tel") {
                val phoneNumber = data.schemeSpecificPart
                Log.d(TAG, "Dial intent with number: $phoneNumber")
                // Flutter 에 전달 => ex: NativeBridge.notifyDialNumber(phoneNumber)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeBridge.setupChannel(flutterEngine)
    }
}
