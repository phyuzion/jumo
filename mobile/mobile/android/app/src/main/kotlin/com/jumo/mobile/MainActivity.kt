package com.jumo.mobile

import android.content.Intent
import android.os.Bundle
import android.telecom.TelecomManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "custom.dialer.channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 잠금화면 위 표시
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "기본 전화앱" 설정/확인용 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when(call.method) {
                    "setDefaultDialer" -> {
                        setDefaultDialer()
                        result.success(null)
                    }
                    "isDefaultDialer" -> {
                        result.success(isDefaultDialer())
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun setDefaultDialer() {
        val telecomManager = getSystemService(TELECOM_SERVICE) as TelecomManager
        val pkgName = applicationContext.packageName
        if (telecomManager.defaultDialerPackage != pkgName) {
            val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
            intent.putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, pkgName)
            startActivity(intent)
        }
    }

    private fun isDefaultDialer(): Boolean {
        val telecomManager = getSystemService(TELECOM_SERVICE) as TelecomManager
        return telecomManager.defaultDialerPackage == applicationContext.packageName
    }
}
