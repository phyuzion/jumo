package com.jumo.mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

object NativeBridge {
    private const val METHOD_CHANNEL_NAME = "com.jumo.mobile/native"
    private const val EVENT_CHANNEL_CONTACTS_STREAM_NAME = "com.jumo.mobile/contactsStream"
    private var methodChannel: MethodChannel? = null
    private var contactsEventChannel: EventChannel? = null

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
                "isDeviceOpen" -> {
                    try {
                        val context = JumoApp.context
                        val isOpen = DeviceUtils.isDeviceOpen(context)
                        val hasExternalDisplay = DeviceUtils.hasExternalDisplay(context)
                        val currentDisplayId = try {
                            val wm = context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
                            wm.defaultDisplay.displayId
                        } catch (e: Exception) {
                            0
                        }
                        
                        result.success(mapOf(
                            "isOpen" to isOpen,
                            "hasExternalDisplay" to hasExternalDisplay,
                            "currentDisplayId" to currentDisplayId
                        ))
                    } catch (e: Exception) {
                        Log.e("NativeBridge", "isDeviceOpen error: $e")
                        result.error("DEVICE_STATE_ERROR", "Failed to get device state", "$e")
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

        contactsEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_CONTACTS_STREAM_NAME)
        contactsEventChannel?.setStreamHandler(ContactsStreamHandler(JumoApp.context, bridgeScope))
    }

    fun dispose() {
        bridgeScope.cancel("NativeBridge disposed")
        methodChannel?.setMethodCallHandler(null)
        contactsEventChannel?.setStreamHandler(null)
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
    
    // 통화 상태 초기화 (기본 전화앱 설정 후 호출)
    fun resetCallState() {
        Log.d("NativeBridge", "resetCallState: 통화 상태 명시적 초기화")
        // IDLE 상태로 명시적 초기화
        methodChannel?.invokeMethod("onCallEnded", mapOf("number" to "", "reason" to "default_dialer_change"))
    }
}

class ContactsStreamHandler(private val context: Context, private val scope: CoroutineScope) : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (events == null) {
            Log.w("ContactsStreamHandler", "EventSink is null onListen, cannot stream.")
            return
        }

        val lastSyncTimestampEpochMillis = arguments as? Long

        Log.d("ContactsStreamHandler", "onListen called. lastSyncTimestamp: $lastSyncTimestampEpochMillis. Starting to stream contacts.")
        scope.launch {
            try {
                ContactManager.processContactsStreamed(
                    context = context,
                    lastSyncTimestampEpochMillis = lastSyncTimestampEpochMillis,
                    chunkSize = 50,
                    onChunkProcessed = {
                        chunk -> 
                        launch(Dispatchers.Main) {
                           Log.d("ContactsStreamHandler", "Sending chunk of ${chunk.size} contacts")
                           events.success(chunk) 
                        }
                    },
                    onFinished = {
                        launch(Dispatchers.Main) {
                            Log.d("ContactsStreamHandler", "Finished streaming all contacts.")
                            events.endOfStream()
                        }
                    },
                    onError = { 
                        exception -> 
                        launch(Dispatchers.Main) {
                            Log.e("ContactsStreamHandler", "Error streaming contacts: ${exception.message}")
                            events.error("CONTACT_STREAM_ERROR", exception.message, exception.stackTraceToString())
                        }
                    }
                )
            } catch (e: Exception) {
                launch(Dispatchers.Main) {
                    Log.e("ContactsStreamHandler", "Outer catch in onListen: Error streaming contacts: ${e.message}")
                    events.error("CONTACT_STREAM_ERROR", "Unexpected error in onListen: ${e.message}", e.stackTraceToString())
                }
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        Log.d("ContactsStreamHandler", "onCancel called. Contact streaming cancelled by Flutter.")
    }
}
