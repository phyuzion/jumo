package com.jumo.mobile

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.DisconnectCause
import android.telecom.InCallService
import android.telecom.VideoProfile
import android.util.Log

class PhoneInCallService : InCallService() {

    companion object {
        private var instance: PhoneInCallService? = null
        private val activeCalls = mutableListOf<Call>()

        // 외부에서 불릴 공개 메서드
        fun acceptCall() { instance?.acceptTopCall() }
        fun rejectCall() { instance?.rejectTopCall() }
        fun hangUpCall() { instance?.hangUpTopCall() }
        fun toggleMute(mute: Boolean) { instance?.toggleMuteCall(mute) }
        fun toggleHold(hold: Boolean) { instance?.toggleHoldTopCall(hold) }
        fun toggleSpeaker(speaker: Boolean) { instance?.toggleSpeakerCall(speaker) }
    }

    // 스피커가 아닌 라우트를 저장하기 위한 변수 (초기값은 earpiece)
    private var lastNonSpeakerRoute: Int = CallAudioState.ROUTE_EARPIECE

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d("PhoneInCallService", "[onCreate] InCallService created.")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        activeCalls.clear()
        Log.d("PhoneInCallService", "[onDestroy] InCallService destroyed.")
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        activeCalls.add(call)
        Log.d("PhoneInCallService", "[onCallAdded] $call")

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
        Log.d("PhoneInCallService", "[handleCallState] newState=$newState")

        when (newState) {
            Call.STATE_RINGING -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    if (call.details.callDirection == Call.Details.DIRECTION_INCOMING) {
                        val number = call.details.handle?.schemeSpecificPart ?: ""
                        showIncomingCall(number)
                        Log.d("PhoneInCallService", "[handleCallState] incoming Dialing... => $number")
                    }
                } else {
                    val number = call.details.handle?.schemeSpecificPart ?: ""
                    showIncomingCall(number)
                    Log.d("PhoneInCallService", "[handleCallState] incoming Dialing... => $number")
                }

            }
            Call.STATE_DIALING -> {
                val number = call.details.handle?.schemeSpecificPart ?: ""
                Log.d("PhoneInCallService", "[handleCallState] Outgoing Dialing... => $number")
                showOnCall(number, false)
            }
            Call.STATE_ACTIVE -> {
                val number = call.details.handle?.schemeSpecificPart ?: ""
                Log.d("PhoneInCallService", "[handleCallState] Call ACTIVE => $number")
                showOnCall(number, true)
            }
            Call.STATE_DISCONNECTED -> {
                val number = call.details.handle?.schemeSpecificPart ?: ""
                var reason = "ended"

                val disconnectCause = call.details.disconnectCause
                val code = disconnectCause.code
                Log.d("PhoneInCallService", "[handleCallState] DISCONNECTED => $number")

                when (code) {
                    DisconnectCause.MISSED -> {
                        reason = "missed"
                    }
                }

                showCallEnded(number, reason)
            }
        }
    }

    /** 수신 */
    private fun acceptTopCall() {
        activeCalls.lastOrNull()?.answer(VideoProfile.STATE_AUDIO_ONLY)
    }

    /** 거절 */
    private fun rejectTopCall() {
        activeCalls.lastOrNull()?.reject(Call.REJECT_REASON_DECLINED)
    }

    /** 종료 */
    private fun hangUpTopCall() {
        activeCalls.lastOrNull()?.disconnect()
    }

    /** 홀드 on/off */
    private fun toggleHoldTopCall(hold: Boolean) {
        val c = activeCalls.lastOrNull() ?: return
        if (hold) c.hold() else c.unhold()
    }

    /** ===========================
     *  (1) 스피커 On/Off
     * ========================== */
    private fun toggleSpeakerCall(enable: Boolean) {
        val call = activeCalls.lastOrNull() ?: return
        val audioState = this.callAudioState

        if (enable) {
            // 스피커 켜기 전, 현재 라우트가 스피커가 아니면 저장
            if (audioState.route != CallAudioState.ROUTE_SPEAKER) {
                lastNonSpeakerRoute = audioState.route
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setAudioRoute(CallAudioState.ROUTE_SPEAKER)
            } else {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.mode = AudioManager.MODE_IN_CALL
                audioManager.isSpeakerphoneOn = true
            }
        } else {
            // 스피커 끌기 -> lastNonSpeakerRoute 로 복귀
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setAudioRoute(lastNonSpeakerRoute)
            } else {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.mode = AudioManager.MODE_IN_CALL

                // 하위 버전에서는 세분화가 힘들고,
                // 기본적으로 "스피커 off => earpiece" 되지만
                // lastNonSpeakerRoute가 earpiece가 아닐 수도 있으니
                // 실제로는 블루투스/유선 이어폰 등을 직접 켜줘야 함.
                // (외부 고려 안 한다고 했으니 여기선 단순화)
                audioManager.isSpeakerphoneOn = false
            }
        }
    }

    /** ===========================
     *  (2) 뮤트 On/Off
     * ========================== */
    private fun toggleMuteCall(muteOn: Boolean) {
        val call = activeCalls.lastOrNull() ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.isMicrophoneMute = muteOn
            Log.d("PhoneInCallService", "[toggleMuteCall] Mute set to: $muteOn (API >= 31)")
        } else {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.isMicrophoneMute = muteOn
            Log.d("PhoneInCallService", "[toggleMuteCall] Mute set to: $muteOn (API < 31)")
        }
    }

    /** ===========================
     *  showIncomingCall & showOnCall & showCallEnded
     * ========================== */
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

    private fun showOnCall(number: String, connected: Boolean) {
        val context = JumoApp.context
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("on_call", true)
            putExtra("on_call_number", number)
            putExtra("on_call_connected", connected)
        }
        context.startActivity(intent)
    }

    private fun showCallEnded(number: String, reason: String) {
        val context = JumoApp.context
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("call_ended", true)
            putExtra("call_ended_number", number)
            putExtra("call_ended_reason", reason)
        }
        context.startActivity(intent)
    }
}
