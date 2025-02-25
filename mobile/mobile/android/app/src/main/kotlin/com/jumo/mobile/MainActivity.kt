package com.jumo.mobile

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.telecom.TelecomManager
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    // 이미 존재하는: 기본 전화앱 채널
    private val CHANNEL_DIALER = "custom.dialer.channel"

    // 추가: 전화번호 관련 채널
    private val CHANNEL_PHONE = "com.jumo.mobile/phone"

    private lateinit var telephonyManager: TelephonyManager

    // PhoneStateListener: 전화가 울릴 때(CALL_STATE_RINGING) phoneNumber를 받을 수 있음
    private val phoneStateListener = object : PhoneStateListener() {
        override fun onCallStateChanged(state: Int, phoneNumber: String?) {
            super.onCallStateChanged(state, phoneNumber)
            if (state == TelephonyManager.CALL_STATE_RINGING) {
                // 전화가 울리는 중
                val incomingNum = phoneNumber ?: ""
                sendIncomingNumberToFlutter(incomingNum)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 잠금화면 위 표시 (화면 켜기, 키가드 해제 등)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        // TelephonyManager 초기화
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ===== 1) 기존 "기본 전화앱" 채널 설정 =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_DIALER)
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

        // ===== 2) 새로 추가: 전화번호 관련 채널 설정 =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_PHONE)
            .setMethodCallHandler { call, result ->
                when(call.method) {
                    "startPhoneStateListener" -> {
                        startPhoneStateListener()
                        result.success(null)
                    }
                    "stopPhoneStateListener" -> {
                        stopPhoneStateListener()
                        result.success(null)
                    }
                    "getMyPhoneNumber" -> {
                        val myNum = getMyPhoneNumber()
                        result.success(myNum)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    // ------------------------------//
    //   "기본 전화앱" 로직
    // ------------------------------//
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
        return (telecomManager.defaultDialerPackage == applicationContext.packageName)
    }

    // ------------------------------//
    //   전화번호 / PhoneState 로직
    // ------------------------------//
    private fun startPhoneStateListener() {
        val permissionCheck = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
        if (permissionCheck != PackageManager.PERMISSION_GRANTED) {
            // 권한이 없다면 요청
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_PHONE_STATE),
                999
            )
        } else {
            telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
        }
    }

    private fun stopPhoneStateListener() {
        telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
    }

    private fun getMyPhoneNumber(): String? {
        // 권한이 있어야만 line1Number를 가져올 수 있음
        val permissionCheck = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
        return if (permissionCheck == PackageManager.PERMISSION_GRANTED) {
            telephonyManager.line1Number // 통신사/기기 따라 null or empty
        } else {
            null
        }
    }

    private fun sendIncomingNumberToFlutter(phoneNumber: String) {
        // 전화가 울릴 때(CALL_STATE_RINGING) -> 이 메서드 호출 -> Dart 측에 알림
        val dataMap = mapOf(
            "event" to "onIncomingNumber",
            "number" to phoneNumber
        )
        // 동일한 CHANNEL_PHONE 사용
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL_PHONE)
            .invokeMethod("onIncomingNumber", dataMap)
    }
}
