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

    companion object {
        private const val REQUEST_CODE_SET_DEFAULT_DIALER = 1001
    }

    private val callPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            requestSetDefaultDialerIfNeeded()
        } else {
            Toast.makeText(this, "CALL_PHONE 권한이 필요합니다.", Toast.LENGTH_SHORT).show()
        }
    }

    private val roleDialerLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK) {
            Log.d("MainActivity", "기본 전화앱 설정 완료")
        } else {
            Log.d("MainActivity", "기본 전화앱 설정 거부됨")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 안드로이드 Q 이상 가정: RoleManager 사용
        checkCallPermissionAndSetDialer()
        handleDialIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDialIntent(intent)
    }

    /**
     * 잠금화면 플래그: 필요할 때만 추가
     * 예: 수신 전화 화면을 이 액티비티로 띄운다면?
     */
    fun enableLockScreenFlags() {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
    }

    private fun checkCallPermissionAndSetDialer() {
        val callPerm = android.Manifest.permission.CALL_PHONE
        if (ContextCompat.checkSelfPermission(this, callPerm) == PackageManager.PERMISSION_GRANTED) {
            requestSetDefaultDialerIfNeeded()
        } else {
            callPermissionLauncher.launch(callPerm)
        }
    }

    private fun requestSetDefaultDialerIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
            if (roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                if (!roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                    val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                    roleDialerLauncher.launch(intent)
                }
            }
        }
    }

    private fun handleDialIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action == Intent.ACTION_DIAL || action == Intent.ACTION_VIEW) {
            val data: Uri? = intent.data
            if (data != null && data.scheme == "tel") {
                val phoneNumber = data.schemeSpecificPart
                Log.d("MainActivity", "Dial intent with number: $phoneNumber")
                // TODO: Flutter 로 전달 → DialerScreen 에서 표시
                // NativeBridge.passDialNumber(phoneNumber) 등
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeBridge.setupChannel(flutterEngine)
    }
}
