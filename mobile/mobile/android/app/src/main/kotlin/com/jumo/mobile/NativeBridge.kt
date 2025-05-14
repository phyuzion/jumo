package com.jumo.mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

object NativeBridge {
    private const val METHOD_CHANNEL_NAME = "com.jumo.mobile/native"
    private var methodChannel: MethodChannel? = null

    private val bridgeScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun setupChannel(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME)
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
                        context.startActivity(callIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("NativeBridge", "makeCall error: $e")
                        result.error("CALL_ERROR", "Failed to start call", "$e")
                    }
                }
                "acceptCall" -> { PhoneInCallService.acceptCall(); result.success(true) }
                "rejectCall" -> { PhoneInCallService.rejectCall(); result.success(true) }
                "hangUpCall" -> { PhoneInCallService.hangUpCall(); result.success(true) }
                "toggleMute" -> { PhoneInCallService.toggleMute(call.argument<Boolean>("muteOn") ?: false); result.success(true) }
                "toggleHold" -> { PhoneInCallService.toggleHold(call.argument<Boolean>("holdOn") ?: false); result.success(true) }
                "toggleSpeaker" -> { PhoneInCallService.toggleSpeaker(call.argument<Boolean>("speakerOn") ?: false); result.success(true) }
                "getMyPhoneNumber" -> { result.success(getMyPhoneNumberFromTelephony()) }
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
                        result.success(PhoneInCallService.getCurrentCallDetails())
                    } catch (e: Exception) {
                        Log.e("NativeBridge", "getCurrentCallState error: $e")
                        result.error("STATE_ERROR", "Failed to get current call state", "$e")
                    }
                }
                "getContacts" -> {
                    bridgeScope.launch {
                        try {
                            val contacts = withContext(Dispatchers.IO) {
                                ContactManager.getContacts(JumoApp.context)
                            }
                            withContext(Dispatchers.Main) {
                                result.success(contacts)
                            }
                        } catch (e: Exception) {
                            Log.e("NativeBridge", "getContacts error: $e")
                            withContext(Dispatchers.Main) {
                                result.error("CONTACT_ERROR", e.message, e.stackTraceToString())
                            }
                        }
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
                        result.error("CONTACT_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "deleteContact" -> {
                    try {
                        val id = call.argument<String>("id") ?: ""
                        val success = ContactManager.deleteContact(JumoApp.context, id)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e("NativeBridge", "deleteContact error: $e")
                        result.error("CONTACT_ERROR", e.message, e.stackTraceToString())
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        bridgeScope.cancel("NativeBridge disposed")
        methodChannel?.setMethodCallHandler(null)
    }

    fun getMyPhoneNumberFromTelephony(): String { 
        return try {
            val telephony = JumoApp.context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            telephony.line1Number ?: ""
        } catch (e: Exception) {
            Log.e("NativeBridge", "Error getting phone number", e)
            ""
        }
    }
    fun notifyIncomingNumber(number: String) { methodChannel?.invokeMethod("onIncomingNumber", number) }
    fun notifyOnCall(number: String, connected: Boolean) { methodChannel?.invokeMethod("onCall", mapOf("number" to number, "connected" to connected)) }
    fun notifyCallEnded(endedNumber: String, reason: String) { methodChannel?.invokeMethod("onCallEnded", mapOf("number" to endedNumber, "reason" to reason)) }
}
