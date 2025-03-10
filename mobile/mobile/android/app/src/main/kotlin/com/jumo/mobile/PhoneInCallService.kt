package com.jumo.mobile

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.telecom.Call
import android.telecom.CallAudioState
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
                // 수신
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    if (call.details.callDirection == Call.Details.DIRECTION_INCOMING) {
                        val number = call.details.handle?.schemeSpecificPart ?: ""
                        showIncomingCall(number)
                    }
                } else {
                    val number = call.details.handle?.schemeSpecificPart ?: ""
                    showIncomingCall(number)
                }
            }
            Call.STATE_DIALING -> {
                // 발신
                Log.d("PhoneInCallService", "[handleCallState] Outgoing Dialing...")
            }
            Call.STATE_ACTIVE -> {
                // 통화 연결됨
                Log.d("PhoneInCallService", "[handleCallState] Call ACTIVE")
            }
            Call.STATE_DISCONNECTED -> {
                // 통화 종료
                val number = call.details.handle?.schemeSpecificPart ?: ""
                Log.d("PhoneInCallService", "[handleCallState] DISCONNECTED => $number")
                showCallEnded(number)
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

        when {
            // A) Android 13 (API 33 이상)
            
            // B) Android 12 (API 31~32)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                // setAudioRoute(CallAudioState.ROUTE_SPEAKER or ...)
                setAudioRoute(
                    if (enable) CallAudioState.ROUTE_SPEAKER
                    else CallAudioState.ROUTE_EARPIECE
                )
            }
            // C) 하위 버전
            else -> {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.mode = AudioManager.MODE_IN_CALL
                audioManager.isSpeakerphoneOn = enable
            }
        }
    }

    /** ===========================
     *  (2) 뮤트 On/Off
     * ========================== */
    private fun toggleMuteCall(muteOn: Boolean) {
        

        /*
        val call = activeCalls.lastOrNull() ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val current = callAudioState
            if (current != null) {
                // 기존 route, supportedRouteMask 유지
                val newState = CallAudioState(
                    muteOn,
                    current.route,
                    current.supportedRouteMask
                )
                updateCallAudioState(newState)
            } else {
                Log.w("PhoneInCallService", "toggleMuteCall() => callAudioState is null")
            }
        } else {
            // 하위 버전 => AudioManager
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.isMicrophoneMute = muteOn
        }
            */
    }

    /** ===========================
     *  showIncomingCall & showCallEnded
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

    private fun showCallEnded(number: String) {
        val context = JumoApp.context
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("call_ended", true)
            putExtra("call_ended_number", number)
        }
        context.startActivity(intent)
    }
}
