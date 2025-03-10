package com.jumo.mobile

import android.os.Build
import android.telecom.Call
import android.telecom.InCallService
import android.telecom.VideoProfile
import android.util.Log
import android.content.Intent
import android.media.AudioManager
import android.media.AudioDeviceInfo

import android.content.Context

class PhoneInCallService : InCallService() {
    companion object {
        private var instance: PhoneInCallService? = null
        private val activeCalls = mutableListOf<Call>()

        fun acceptCall() { instance?.acceptTopCall() }
        fun rejectCall() { instance?.rejectTopCall() }
        fun hangUpCall() { instance?.hangUpTopCall() }
        fun toggleMute(mute: Boolean) { instance?.setMuted(mute) }
        fun toggleHold(hold: Boolean) { instance?.toggleHoldTopCall(hold) }
        fun toggleSpeaker(speaker: Boolean) { instance?.toggleSpeaker(speaker) }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d("PhoneInCallService", "InCallService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        activeCalls.clear()
        Log.d("PhoneInCallService", "InCallService destroyed")
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        activeCalls.add(call)
        Log.d("PhoneInCallService", "onCallAdded: $call")

        call.registerCallback(object : Call.Callback() {
            override fun onStateChanged(call: Call, newState: Int) {
                super.onStateChanged(call, newState)
                handleCallState(call, newState)
            }
        })
        handleCallState(call, call.state)
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        activeCalls.remove(call)
    }

    private fun handleCallState(call: Call, newState: Int) {
        Log.d("PhoneInCallService", "handleCallState: $newState")

        when (newState) {
            Call.STATE_RINGING -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    if (call.details.callDirection == Call.Details.DIRECTION_INCOMING) {
                        val number = call.details.handle?.schemeSpecificPart ?: ""
                        Log.d("PhoneInCallService", "Incoming call => $number")
                        showIncomingCall(number)
                    }
                } else {
                    val number = call.details.handle?.schemeSpecificPart ?: ""
                    showIncomingCall(number)
                }
            }
            Call.STATE_DIALING -> {
                Log.d("PhoneInCallService", "Outgoing Dialing...")
            }
            Call.STATE_ACTIVE -> {
                Log.d("PhoneInCallService", "Call ACTIVE (connected)")
                // TODO: if you want to show OnCall screen here, do it
            }
            Call.STATE_DISCONNECTED -> {
                Log.d("PhoneInCallService", "Call DISCONNECTED => show ended")
                val number = call.details.handle?.schemeSpecificPart ?: ""
                showCallEnded(number)
            }
        }
    }

    private fun acceptTopCall() {
        activeCalls.lastOrNull()?.answer(VideoProfile.STATE_AUDIO_ONLY)
    }

    private fun rejectTopCall() {
        activeCalls.lastOrNull()?.reject(Call.REJECT_REASON_DECLINED)
    }

    private fun hangUpTopCall() {
        activeCalls.lastOrNull()?.disconnect()
    }

    private fun toggleHoldTopCall(hold: Boolean) {
        val c = activeCalls.lastOrNull() ?: return
        if (hold) c.hold() else c.unhold()
    }

        // PhoneInCallService.kt (예시)
    private fun toggleSpeaker(enable: Boolean) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager

        val manager = getSystemService(AudioManager::class.java)
        manager.mode = AudioManager.MODE_IN_CALL

        if (enable) {
            val devices = manager.availableCommunicationDevices
            val speaker = devices.firstOrNull {
                it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
            }
            if (speaker != null) {
                manager.setCommunicationDevice(speaker)
            }
        } else {
            manager.clearCommunicationDevice()
        }

        if(enable){
            Log.d("PhoneInCallService", "Call Speaker")
        }else{
            Log.d("PhoneInCallService", "Call Speaker off")
        }
    }

    private fun showIncomingCall(number: String) {
        val context = JumoApp.context
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                     Intent.FLAG_ACTIVITY_SINGLE_TOP or
                     Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra("incoming_call", true)
            putExtra("incoming_number", number)
        }
        context.startActivity(intent)
    }

    fun showCallEnded(number: String) {
        val context = JumoApp.context
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                     Intent.FLAG_ACTIVITY_SINGLE_TOP or
                     Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra("call_ended", true)
            putExtra("call_ended_number", number) // 넘겨줌
        }
        context.startActivity(intent)
    }
}
