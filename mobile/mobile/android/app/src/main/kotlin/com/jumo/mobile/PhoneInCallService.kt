package com.jumo.mobile

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
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
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "incoming_call_channel_id"

        // 외부에서 불릴 공개 메서드
        fun acceptCall() { instance?.acceptTopCall() }
        fun rejectCall() { instance?.rejectTopCall() }
        fun hangUpCall() { instance?.hangUpTopCall() }
        fun toggleMute(mute: Boolean) { instance?.toggleMuteCall(mute) }
        fun toggleHold(hold: Boolean) { instance?.toggleHoldTopCall(hold) }
        fun toggleSpeaker(speaker: Boolean) { instance?.toggleSpeakerCall(speaker) }
        
        // 통화 전환 메서드
        fun switchActiveAndHoldingCalls() {
            Log.d("PhoneInCallService", "[switchActiveAndHoldingCalls] 통화 전환 시도")
            val activeCall = activeCalls.find { it.state == Call.STATE_ACTIVE }
            val holdingCall = activeCalls.find { it.state == Call.STATE_HOLDING }
            
            if (activeCall != null && holdingCall != null) {
                Log.d("PhoneInCallService", "[switchActiveAndHoldingCalls] 활성 통화 대기로 전환, 대기 통화 활성화")
                activeCall.hold()
                holdingCall.unhold()
            } else {
                Log.d("PhoneInCallService", "[switchActiveAndHoldingCalls] 전환 가능한 통화 없음: 활성=$activeCall, 대기=$holdingCall")
            }
        }
        
        // 현재 통화 끊고 수신 통화 받기 메서드 추가
        fun endCurrentAndAcceptRinging() {
            Log.d("PhoneInCallService", "[endCurrentAndAcceptRinging] 현재 통화 종료 후 수신 통화 수락 시도")
            
            // 활성 통화와 수신 통화 찾기
            val activeCall = activeCalls.find { it.state == Call.STATE_ACTIVE }
            val ringingCall = activeCalls.find { it.state == Call.STATE_RINGING }
            
            if (activeCall != null && ringingCall != null) {
                try {
                    Log.d("PhoneInCallService", "[endCurrentAndAcceptRinging] 활성 통화 종료 시작: ${activeCall.details.handle?.schemeSpecificPart}")
                    
                    // 먼저 수신 통화 객체를 저장
                    val callToAccept = ringingCall
                    
                    // 활성 통화 종료
                    activeCall.disconnect()
                    
                    // 잠시 대기 후 수신 통화 수락
                    Thread.sleep(300)  // 300ms 대기
                    
                    if (callToAccept.state == Call.STATE_RINGING) {
                        Log.d("PhoneInCallService", "[endCurrentAndAcceptRinging] 수신 통화 응답: ${callToAccept.details.handle?.schemeSpecificPart}")
                        callToAccept.answer(VideoProfile.STATE_AUDIO_ONLY)
                    } else {
                        Log.d("PhoneInCallService", "[endCurrentAndAcceptRinging] 수신 통화가 더 이상 RINGING 상태가 아님: ${callToAccept.state}")
                    }
                } catch (e: Exception) {
                    Log.e("PhoneInCallService", "[endCurrentAndAcceptRinging] 오류 발생: ${e.message}")
                }
            } else {
                Log.d("PhoneInCallService", "[endCurrentAndAcceptRinging] 필요한 통화 없음: 활성=$activeCall, 수신=$ringingCall")
            }
        }

        // 현재 통화 정보 반환 메서드 (완전히 새로 구현)
        fun getCurrentCallDetails(): Map<String, Any?> {
            val callMap = mutableMapOf<String, Any?>()
            
            // 통화 상태 초기화 (IDLE)
            callMap["active_state"] = "IDLE"
            callMap["holding_state"] = "IDLE"
            callMap["ringing_state"] = "IDLE"
            
            // 활성 통화 검색 (DIALING 상태도 ACTIVE로 간주)
            val activeCall = activeCalls.find { it.state == Call.STATE_ACTIVE || it.state == Call.STATE_DIALING }
            if (activeCall != null) {
                callMap["active_number"] = activeCall.details.handle?.schemeSpecificPart
                callMap["active_state"] = if (activeCall.state == Call.STATE_DIALING) "DIALING" else "ACTIVE"
                Log.d("PhoneInCallService", "[getCurrentCallDetails] 활성 통화: ${callMap["active_number"]} (상태: ${callMap["active_state"]})")
            }
            
            // 대기 중인 통화 검색
            val holdingCall = activeCalls.find { it.state == Call.STATE_HOLDING }
            if (holdingCall != null) {
                callMap["holding_number"] = holdingCall.details.handle?.schemeSpecificPart
                callMap["holding_state"] = "HOLDING"
                Log.d("PhoneInCallService", "[getCurrentCallDetails] 대기 통화: ${callMap["holding_number"]}")
            }
            
            // 수신 중인 통화 검색
            val ringingCall = activeCalls.find { it.state == Call.STATE_RINGING }
            if (ringingCall != null) {
                callMap["ringing_number"] = ringingCall.details.handle?.schemeSpecificPart
                callMap["ringing_state"] = "RINGING"
                Log.d("PhoneInCallService", "[getCurrentCallDetails] 수신 통화: ${callMap["ringing_number"]}")
            }
            
            // 모든 통화 상태 로깅 (디버깅용)
            activeCalls.forEachIndexed { index, call ->
                val state = when(call.state) {
                    Call.STATE_ACTIVE -> "ACTIVE"
                    Call.STATE_HOLDING -> "HOLDING"
                    Call.STATE_RINGING -> "RINGING"
                    Call.STATE_DIALING -> "DIALING"
                    Call.STATE_DISCONNECTED -> "DISCONNECTED"
                    else -> "OTHER(${call.state})"
                }
                val number = call.details.handle?.schemeSpecificPart ?: "unknown"
                Log.d("PhoneInCallService", "[getCurrentCallDetails] 통화[$index]: 번호=$number, 상태=$state")
            }
            
            return callMap
        }
    }

    // 스피커가 아닌 라우트를 저장하기 위한 변수 (초기값은 earpiece)
    private var lastNonSpeakerRoute: Int = CallAudioState.ROUTE_EARPIECE
    
    // 오디오 포커스 요청 객체 (API 26+)
    private var audioFocusRequest: AudioFocusRequest? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d("PhoneInCallService", "[onCreate] InCallService created.")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        activeCalls.clear()
        
        // 오디오 포커스 해제
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioFocusRequest?.let {
                audioManager.abandonAudioFocusRequest(it)
                audioFocusRequest = null
            }
        }
        
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
                val isIncoming = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    call.details.callDirection == Call.Details.DIRECTION_INCOMING
                } else {
                    true // API 28 이하에서는 방향을 확인할 수 없으므로 항상 수신 전화로 간주
                }
                
                                    if (isIncoming) {
                    val number = call.details.handle?.schemeSpecificPart ?: ""
                    
                    // 이미 활성화된 통화가 있는지 체크
                    val activeCall = activeCalls.find { it != call && it.state == Call.STATE_ACTIVE }
                    val dialingCall = activeCalls.find { it != call && it.state == Call.STATE_DIALING }
                    
                    if (activeCall != null) {
                        // 활성 통화가 있는 상태에서 새로운 수신 = 대기 통화 상황
                        val activeNumber = activeCall.details.handle?.schemeSpecificPart ?: ""
                        Log.d("PhoneInCallService", "[handleCallState] 대기 통화 감지: 활성=$activeNumber, 수신=$number")
                        
                        // 대기 통화 상황만 알리고, 일반 수신 전화 알림은 보내지 않음
                        showWaitingCall(activeNumber, number)
                        // showIncomingCall은 호출하지 않음 - 이 부분이 중요!
                    } else if (dialingCall != null) {
                        // 발신 중인 통화가 있는 상태에서 새로운 수신 = 부재중으로 처리 (안드로이드 기본 동작)
                        Log.d("PhoneInCallService", "[handleCallState] 발신 중 수신 전화 감지: $number - 부재중으로 처리")
                        // 아무 작업 없이 시스템이 자동으로 부재중으로 처리하도록 함
                    } else {
                        // 일반 수신 전화
                        showIncomingCall(number)
                        Log.d("PhoneInCallService", "[handleCallState] incoming Dialing... => $number")
                    }
                }
            }
            Call.STATE_DIALING -> {
                val number = call.details.handle?.schemeSpecificPart ?: ""
                Log.d("PhoneInCallService", "[handleCallState] Outgoing Dialing... => $number")
                showOnCall(number, false)
                
                // 통화 시 오디오 포커스 요청 (API 버전별 분기)
                requestAudioFocus()
            }
            Call.STATE_ACTIVE -> {
                val number = call.details.handle?.schemeSpecificPart ?: ""
                Log.d("PhoneInCallService", "[handleCallState] Call ACTIVE => $number")
                showOnCall(number, true)
                
                // 통화 시 오디오 포커스 요청 (API 버전별 분기)
                requestAudioFocus()
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
                
                // 통화 종료 시 오디오 포커스 해제
                abandonAudioFocus()
                
                // 전화 알림 취소 호출 제거
            }
        }
    }

    /** 수신 */
    private fun acceptTopCall() {
        activeCalls.lastOrNull()?.answer(VideoProfile.STATE_AUDIO_ONLY)
    }

    /** 거절 */
    private fun rejectTopCall() {
        Log.d("PhoneInCallService", "[rejectTopCall] Attempting to reject/disconnect call...")
        val callToReject = activeCalls.lastOrNull()
        if (callToReject != null) {
            // reject() 대신 disconnect() 사용
            Log.d("PhoneInCallService", "[rejectTopCall] Using disconnect() for call: $callToReject, State: ${callToReject.state}")
            callToReject.disconnect()
        } else {
            Log.d("PhoneInCallService", "[rejectTopCall] No active call found to disconnect.")
        }
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

    /** 오디오 포커스 요청 */
    private fun requestAudioFocus() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Android 8.0 이상
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
                
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(audioAttributes)
                .setAcceptsDelayedFocusGain(false)
                .setOnAudioFocusChangeListener { }
                .build()
                
            audioManager.requestAudioFocus(audioFocusRequest!!)
        } else {
            // Android 8.0 미만
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, 
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
        }
    }
    
    /** 오디오 포커스 해제 */
    private fun abandonAudioFocus() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Android 8.0 이상
            audioFocusRequest?.let {
                audioManager.abandonAudioFocusRequest(it)
            }
        } else {
            // Android 8.0 미만
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    /** ===========================
     *  (1) 스피커 On/Off
     * ========================== */
    private fun toggleSpeakerCall(enable: Boolean) {
        val call = activeCalls.lastOrNull() ?: return
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        if (enable) {
            // 스피커 켜기 전, 현재 라우트가 스피커가 아니면 저장
            val audioState = this.callAudioState
            if (audioState.route != CallAudioState.ROUTE_SPEAKER) {
                lastNonSpeakerRoute = audioState.route
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12 이상
                setAudioRoute(CallAudioState.ROUTE_SPEAKER)
            } else {
                // Android 12 미만
                audioManager.mode = AudioManager.MODE_IN_CALL
                audioManager.isSpeakerphoneOn = true
            }
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12 이상
                setAudioRoute(lastNonSpeakerRoute)
            } else {
                // Android 12 미만
                audioManager.mode = AudioManager.MODE_IN_CALL
                audioManager.isSpeakerphoneOn = false
            }
        }
    }

    /** ===========================
     *  (2) 뮤트 On/Off
     * ========================== */
    private fun toggleMuteCall(muteOn: Boolean) {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.isMicrophoneMute = muteOn
        Log.d("PhoneInCallService", "[toggleMuteCall] Mute set to: $muteOn")
    }

    /** ===========================
     *  showIncomingCall & showOnCall & showCallEnded & showWaitingCall
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
    
    // 대기 통화 알림 메서드 추가
    private fun showWaitingCall(activeNumber: String, incomingNumber: String) {
        // 1. 먼저 NativeBridge를 통해 Flutter에 대기 통화 이벤트 전달
        val context = JumoApp.context
        Log.d("PhoneInCallService", "[showWaitingCall] 대기 통화 이벤트 전송: 활성=$activeNumber, 대기=$incomingNumber")
        NativeBridge.notifyWaitingCall(activeNumber, incomingNumber)
        
        // 2. 화면 전환도 함께 처리 (incoming_call은 포함하지 않음)
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            // 대기 통화임을 명확히 표시하고 일반 incoming_call 플래그는 설정하지 않음
            putExtra("waiting_call", true)
            putExtra("active_number", activeNumber)
            putExtra("waiting_number", incomingNumber)
            // 아래 플래그들은 포함하지 않음 - 중요!
            // putExtra("incoming_call", true) - 이 플래그가 있으면 인코밍콜 플로우가 트리거됨
            // putExtra("incoming_number", incomingNumber)
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
