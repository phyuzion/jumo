package com.jumo.mobile

import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object NativeBridge {
    private const val CHANNEL_NAME = "com.jumo.mobile/native"
    private var methodChannel: MethodChannel? = null

    fun setupChannel(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            when(call.method) {
                "makeCall" -> {
                    val number = call.argument<String>("phoneNumber") ?: ""
                    Log.d("NativeBridge", "makeCall($number)")
                    // 실제 발신: ACTION_CALL or TelecomManager
                    result.success(true)
                }
                "acceptCall" -> {
                    PhoneInCallService.acceptCall()
                    result.success(true)
                }
                "rejectCall" -> {
                    PhoneInCallService.rejectCall()
                    result.success(true)
                }
                "hangUpCall" -> {
                    PhoneInCallService.hangUpCall()
                    result.success(true)
                }
                "toggleMute" -> {
                    val mute = call.argument<Boolean>("muteOn") ?: false
                    PhoneInCallService.toggleMute(mute)
                    result.success(true)
                }
                "toggleHold" -> {
                    val hold = call.argument<Boolean>("holdOn") ?: false
                    PhoneInCallService.toggleHold(hold)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // 수신 시 잠금화면 플래그 설정 + Flutter에서 call_screen 띄우기
    fun showIncomingCall() {
        Log.d("NativeBridge", "showIncomingCall()")
        // MainActivity 를 통해 잠금화면 플래그 + Navigator.push(call_screen)
        // 간단히: MainActivity 띄우고 -> onCreate에서 enableLockScreenFlags
        val context = /* applicationContext or activity ref */ 
            com.jumo.mobile.MainActivity() // (예시로는 불가, 실제론 Activity를 얻어야 함)

        // 더 정확히는, 이미 MainActivity가 떠 있는 상태라면 `onNewIntent` 형태로 전달
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("incoming_call", true)
        }
        context.startActivity(intent)
    }
}
