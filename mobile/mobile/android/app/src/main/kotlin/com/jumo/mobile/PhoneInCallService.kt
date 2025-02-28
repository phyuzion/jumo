package com.jumo.mobile

import android.os.Build
import android.telecom.Call
import android.telecom.InCallService
import android.telecom.VideoProfile
import android.util.Log
import android.content.Intent

class PhoneInCallService : InCallService() {

    companion object {
        private var instance: PhoneInCallService? = null
        private val activeCalls = mutableListOf<Call>()

        fun acceptCall() { instance?.acceptTopCall() }
        fun rejectCall() { instance?.rejectTopCall() }
        fun hangUpCall() { instance?.hangUpTopCall() }
        fun toggleMute(mute: Boolean) { instance?.setMuted(mute) }
        fun toggleHold(hold: Boolean) { instance?.toggleHoldTopCall(hold) }
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

        // 콜백 등록
        call.registerCallback(object : Call.Callback() {
            override fun onStateChanged(call: Call, newState: Int) {
                super.onStateChanged(call, newState)
                handleCallState(call, newState)
            }
        })

        // "처음 상태" 처리
        handleCallState(call, call.state)
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        activeCalls.remove(call)
    }

    private fun handleCallState(call: Call, newState: Int) {
        Log.d("PhoneInCallService", "handleCallState: $newState")

        if (newState == Call.STATE_RINGING) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                if (call.details.callDirection == Call.Details.DIRECTION_INCOMING) {
                    val number = call.details.handle?.schemeSpecificPart ?: ""
                    Log.d("PhoneInCallService", "Incoming call => $number")
                    showIncomingCall(number)
                } else {
                    // 발신 측에서 상대방이 울리는 중
                    // (Outgoing ring)
                }
            } else {
                val number = call.details.handle?.schemeSpecificPart ?: ""
                Log.d("PhoneInCallService", "Incoming call => $number")
                showIncomingCall(number)
            }
        }
        else if (newState == Call.STATE_DIALING) {
            Log.d("PhoneInCallService", "Outgoing Dialing ... ")
            // NativeBridge.showOutgoingCall() 등
        }
        else if (newState == Call.STATE_ACTIVE) {
            Log.d("PhoneInCallService", "Call active (connected)")
            // NativeBridge.showOnCallScreen() 등
        }
        else if (newState == Call.STATE_DISCONNECTED) {
            Log.d("PhoneInCallService", "Call disconnected => show Ended screen or close UI")
            showCallEnded()
        }
    }

    // ====== 통화 제어 ======
    private fun acceptTopCall() {
        val c = activeCalls.lastOrNull() ?: return
        c.answer(VideoProfile.STATE_AUDIO_ONLY)
    }

    private fun rejectTopCall() {
        val c = activeCalls.lastOrNull() ?: return
        c.reject(Call.REJECT_REASON_DECLINED)
    }

    private fun hangUpTopCall() {
        val c = activeCalls.lastOrNull() ?: return
        c.disconnect()
    }

    private fun toggleHoldTopCall(hold: Boolean) {
        val c = activeCalls.lastOrNull() ?: return
        if (hold) c.hold() else c.unhold()
    }


    private fun showIncomingCall(number: String) {
        val context = JumoApp.context
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("incoming_call", true)
            putExtra("incoming_number", number)
        }
        context.startActivity(intent)
    }
    // 통화 종료 => Flutter에서 CallEndedScreen 열게끔
    fun showCallEnded() {
        // Similar approach => onNewIntent or direct event
        Log.d("NativeBridge", "showCallEnded()")
        val context = JumoApp.context
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("call_ended", true)
        }
        context.startActivity(intent)
    }

}
