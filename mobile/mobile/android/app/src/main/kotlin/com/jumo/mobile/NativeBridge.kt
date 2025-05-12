package com.jumo.mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                    
                    try {
                        val context = JumoApp.context
                        val callIntent = Intent(Intent.ACTION_CALL).apply {
                            data = Uri.parse("tel:$number")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        // AndroidManifest.xml 에서 android.permission.CALL_PHONE 권한 필요
                        context.startActivity(callIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("NativeBridge", "makeCall error: $e")
                        result.error("CALL_ERROR", "Failed to start call", "$e")
                    }

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
                "toggleSpeaker" -> {
                    val speaker = call.argument<Boolean>("speakerOn") ?: false
                    PhoneInCallService.toggleSpeaker(speaker)
                    result.success(true)
                }
                "getMyPhoneNumber" -> {
                    val number = getMyPhoneNumberFromTelephony()
                    result.success(number) 
                }
                "openSmsApp" -> {
                    val number = call.argument<String>("phoneNumber") ?: ""
                    Log.d("NativeBridge", "openSmsApp($number)")
                    
                    try {
                        val context = JumoApp.context
                        val smsIntent = Intent(Intent.ACTION_SENDTO).apply {
                            data = Uri.parse("smsto:$number")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(smsIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("NativeBridge", "openSmsApp error: $e")
                        result.error("SMS_ERROR", "Failed to open SMS app", "$e")
                    }
                }
                "getCurrentCallState" -> {
                    try {
                        val callDetails = PhoneInCallService.getCurrentCallDetails()
                        result.success(callDetails)
                    } catch (e: Exception) {
                        Log.e("NativeBridge", "getCurrentCallState error: $e")
                        result.error("STATE_ERROR", "Failed to get current call state", "$e")
                    }
                }
                "getContacts" -> {
                    try {
                        val contacts = ContactManager.getContacts(JumoApp.context)
                        result.success(contacts)
                    } catch (e: Exception) {
                        Log.e("NativeBridge", "getContacts error: $e")
                        result.error("CONTACT_ERROR", e.message, null)
                    }
                }
                "upsertContact" -> {
                    try {
                        val rawContactId = call.argument<String>("rawContactId")
                        val displayName = call.argument<String>("displayName") ?: ""
                        val firstName = call.argument<String>("firstName") ?: ""
                        val middleName = call.argument<String>("middleName") ?: ""
                        val lastName = call.argument<String>("lastName") ?: ""
                        val phoneNumber = call.argument<String>("phoneNumber") ?: ""

                        val contactId = ContactManager.upsertContact(
                            JumoApp.context,
                            rawContactId,
                            displayName,
                            firstName,
                            middleName,
                            lastName,
                            phoneNumber
                        )
                        result.success(contactId)
                    } catch (e: Exception) {
                        Log.e("NativeBridge", "upsertContact error: $e")
                        result.error("CONTACT_ERROR", e.message, null)
                    }
                }
                "deleteContact" -> {
                    try {
                        val id = call.argument<String>("id") ?: ""
                        val success = ContactManager.deleteContact(JumoApp.context, id)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e("NativeBridge", "deleteContact error: $e")
                        result.error("CONTACT_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
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
        methodChannel?.invokeMethod("onIncomingNumber", number)
    }


    fun notifyOnCall(number: String, connected: Boolean) {
        val args = mapOf(
            "number" to number,
            "connected" to connected
        )
        methodChannel?.invokeMethod("onCall", args)
    }

    fun notifyCallEnded(endedNumber: String, reason: String) {
        val args = mapOf(
        "number" to endedNumber,
        "reason" to reason,
        )
        methodChannel?.invokeMethod("onCallEnded", args)
    }
}
