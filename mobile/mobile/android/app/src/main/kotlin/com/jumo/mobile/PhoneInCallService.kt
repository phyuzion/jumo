package com.jumo.mobile

import android.telecom.Call
import android.telecom.InCallService
import android.telecom.VideoProfile
import android.util.Log

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
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        activeCalls.add(call)

        Log.d("PhoneInCallService", "call are: $call")
        if(call.state == Call.STATE_RINGING) {
            Log.d("PhoneInCallService", "calllinging: $call");

            NativeBridge.showIncomingCall()
        }
        call.registerCallback(object : Call.Callback() {
            override fun onStateChanged(call: Call, newState: Int) {
                super.onStateChanged(call, newState)
                Log.d("PhoneInCallService", "stateChanged: $newState")
                if (newState == Call.STATE_RINGING) {
                    // 수신 → MainActivity로 잠금화면 플래그 + call_screen 이동

                Log.d("PhoneInCallService", "calllinging: $newState")
                    NativeBridge.showIncomingCall()
                }
            }
        })
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        activeCalls.remove(call)
    }

    // ====== 통화 제어 메서드 ======
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
}
