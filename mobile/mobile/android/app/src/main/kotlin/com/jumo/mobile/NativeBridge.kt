package com.jumo.mobile

import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.telephony.TelephonyManager

object NativeBridge {
    private const val CHANNEL_NAME = "com.jumo.mobile/native"
    private var methodChannel: MethodChannel? = null

    fun setupChannel(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "makeCall" -> {
                    val number = call.argument<String>("phoneNumber") ?: ""
                    Log.d("NativeBridge", "makeCall($number)")
                    // ACTION_CALL or TelecomManager.placeCall
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
                "getMyPhoneNumber" -> {
                    val number = getMyPhoneNumberFromTelephony()
                    result.success(number) 
                }
                else -> result.notImplemented()
            }
        }
    }
    

    fun getMyPhoneNumberFromTelephony(): String {
        return try {
            val telephony = JumoApp.context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            telephony.line1Number ?: ""
        } catch (e: Exception) {
            "you can not brought your phone number"
        }
    }

    fun notifyIncomingNumber(number: String) {
        Log.d("NativeBridge", "notifyIncomingNumber($number)")
        methodChannel?.invokeMethod("onIncomingNumber", number)
    }

    fun notifyCallEnded() {
        Log.d("NativeBridge", "notifyCallEnded()")
        methodChannel?.invokeMethod("onCallEnded", null)
    }

}
