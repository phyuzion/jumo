# 통화중 오는 전화 처리 기능 분석

## 1. 현재 구현 상태 분석

### 1.1. 구현된 기능
- `call_waiting_dialog.dart`: 통화 중 새로운 전화 수신 시 표시되는 팝업 UI 구현 완료
  - 대기 후 수신, 통화끊고 받기, 거절 등 3가지 액션 버튼 구현
  - 발신자 정보 표시 기능 포함
- `CallStateProvider`: 통화 상태 관리를 위한 Provider 구현
  - 단일 통화에 대한 상태 관리 기능 구현 (음소거, 스피커, 대기 등)
- `PhoneInCallService.kt`: 안드로이드의 통화 상태 감지 및 제어 기능 구현
  - 전화 수신/발신/종료 등의 상태 변화 감지
  - 통화 제어(홀드, 뮤트, 스피커 등) 기능 구현

### 1.2. 미구현/문제점
- 통화 중 새로운 전화가 오는 경우에 대한 상태 관리 미구현
- 통화 대기 및 대기 중인 통화 전환 기능 미구현
- `PhoneInCallService.kt`에는 `getCurrentCallDetails()` 메서드가 있으나, 현재 활성 통화에 대한 정보만 제공
- 대기 중인 통화와 활성 통화를 모두 관리하는 로직 부재
- `on_call_contents.dart`에 대기 중인 통화 정보 표시 및 전환 UI 부재

## 2. 코드 분석

### 2.1. NativeBridge.kt
- 기본적인 통화 제어 함수들은 이미 구현되어 있음
- `getCurrentCallState` 메서드는 `PhoneInCallService.getCurrentCallDetails()` 호출하여 정보를 가져옴
- 다음 함수들이 이미 구현되어 있음:
  - `acceptCall()`, `rejectCall()`, `hangUpCall()`
  - `toggleMute()`, `toggleHold()`, `toggleSpeaker()`

### 2.2. PhoneInCallService.kt
- `activeCalls`라는 리스트로 여러 통화를 관리할 준비는 되어 있음
- `getCurrentCallDetails()`는 현재 `activeCalls.lastOrNull()`만 반환하고 있어 대기 중인 통화 정보는 제공하지 않음
- 홀드 기능(`toggleHoldTopCall()`)은 구현되어 있으나, 대기 중인 통화와 활성 통화 전환 기능은 없음

### 2.3. CallStateProvider
- `_waitingCallNumber` 같은 변수가 없어 대기 중인 통화 정보를 관리하지 못함
- `acceptWaitingCall()`, `rejectWaitingCall()`, `endAndAcceptWaitingCall()` 함수가 부재

### 2.4. call_waiting_dialog.dart
- UI는 잘 구현되어 있지만, 실제 동작을 위한 로직 연결이 미비
- 버튼 액션 핸들러는 있지만 `CallStateProvider`에 구현된 함수가 없어 작동하지 않음
- 대기 중인 통화 상태를 감지하는 리스너가 구현은 되어 있으나 실제로 동작하지 않음

### 2.5. on_call_contents.dart
- 단일 통화에 대한 UI만 구현되어 있음
- 대기 중인 통화 정보 표시 및 통화 전환 버튼 UI 없음
- 홀드 버튼은 있으나, 대기 중인 통화와 활성 통화를 전환하는 기능은 없음

## 3. 해결 방안

### 3.1. PhoneInCallService.kt 수정
- `getCurrentCallDetails()` 메서드를 확장하여 활성 통화 및 대기 중인 통화 정보를 모두 반환하도록 수정
  ```kotlin
  fun getCurrentCallDetails(): Map<String, Any?> {
      val callMap = mutableMapOf<String, Any?>()
      
      // 활성 통화 정보
      val activeCall = activeCalls.find { it.state == Call.STATE_ACTIVE }
      if (activeCall != null) {
          callMap["active_number"] = activeCall.details.handle?.schemeSpecificPart
          callMap["active_state"] = "ACTIVE"
      }
      
      // 대기 중인 통화 정보
      val holdingCall = activeCalls.find { it.state == Call.STATE_HOLDING }
      if (holdingCall != null) {
          callMap["holding_number"] = holdingCall.details.handle?.schemeSpecificPart
          callMap["holding_state"] = "HOLDING"
      }
      
      // 수신 중인 통화 정보
      val ringingCall = activeCalls.find { it.state == Call.STATE_RINGING }
      if (ringingCall != null) {
          callMap["ringing_number"] = ringingCall.details.handle?.schemeSpecificPart
          callMap["ringing_state"] = "RINGING"
      }
      
      return callMap
  }
  ```

- 통화 전환 메서드 추가
  ```kotlin
  fun switchActiveAndHoldingCalls() {
      val activeCall = activeCalls.find { it.state == Call.STATE_ACTIVE }
      val holdingCall = activeCalls.find { it.state == Call.STATE_HOLDING }
      
      if (activeCall != null && holdingCall != null) {
          activeCall.hold()
          holdingCall.unhold()
      }
  }
  ```

### 3.2. NativeBridge.kt 수정
- `switchCalls` 메서드 추가
  ```kotlin
  "switchCalls" -> { PhoneInCallService.switchActiveAndHoldingCalls(); result.success(true) }
  ```

### 3.3. CallStateProvider 수정
- 대기 중인 통화 정보를 관리하는 변수 추가
  ```dart
  String? _waitingCallNumber;
  String? _waitingCallerName;
  String? _holdingCallNumber;
  String? _holdingCallerName;
  
  // Getters
  String? get waitingCallNumber => _waitingCallNumber;
  String? get holdingCallNumber => _holdingCallNumber;
  ```

- 대기 중인 통화와 활성 통화 전환 함수 추가
  ```dart
  Future<void> switchCalls() async {
    try {
      await NativeMethods.invokeMethod('switchCalls');
      // 상태는 PhoneInCallService에서 변경 알림이 오면 업데이트됨
    } catch (e) {
      log('[CallStateProvider] Error switching calls: $e');
    }
  }
  ```

- 통화 중 수신 전화 처리 함수 추가
  ```dart
  Future<void> acceptWaitingCall() async {
    try {
      // 현재 통화를 대기 상태로 전환하고 대기 중인 전화 받기
      await NativeMethods.toggleHold(true);
      await NativeMethods.acceptCall();
    } catch (e) {
      log('[CallStateProvider] Error accepting waiting call: $e');
    }
  }
  
  Future<void> rejectWaitingCall() async {
    try {
      await NativeMethods.rejectCall();
      _waitingCallNumber = null;
      _waitingCallerName = null;
      notifyListeners();
    } catch (e) {
      log('[CallStateProvider] Error rejecting waiting call: $e');
    }
  }
  
  Future<void> endAndAcceptWaitingCall() async {
    try {
      await NativeMethods.hangUpCall();
      await Future.delayed(const Duration(milliseconds: 500));
      await NativeMethods.acceptCall();
    } catch (e) {
      log('[CallStateProvider] Error ending call and accepting waiting call: $e');
    }
  }
  ```

### 3.4. on_call_contents.dart 수정
- 대기 중인 통화 정보 표시 UI 추가
  ```dart
  // 대기 중인 통화가 있는 경우에만 표시
  if (callStateProvider.holdingCallNumber != null) {
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.pause, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    callStateProvider.holdingCallerName ?? '알 수 없음',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(callStateProvider.holdingCallNumber ?? ''),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.swap_calls),
              onPressed: () => callStateProvider.switchCalls(),
            ),
          ],
        ),
      ),
    ),
  }
  ```

## 4. 구현 계획

### 4.1. 파일별 수정 사항 상세

#### PhoneInCallService.kt

```kotlin
// getCurrentCallDetails() 메서드 확장
fun getCurrentCallDetails(): Map<String, Any?> {
    val callMap = mutableMapOf<String, Any?>()
    
    // 기본 상태 정보 (마지막 전화 기준)
    val lastCall = activeCalls.lastOrNull()
    if (lastCall != null) {
        callMap["state"] = when (lastCall.state) {
            Call.STATE_RINGING -> "RINGING"
            Call.STATE_DIALING -> "DIALING"
            Call.STATE_ACTIVE -> "ACTIVE"
            Call.STATE_HOLDING -> "HOLDING"
            Call.STATE_DISCONNECTED -> "IDLE"
            Call.STATE_CONNECTING -> "CONNECTING"
            Call.STATE_DISCONNECTING -> "DISCONNECTING"
            else -> "UNKNOWN"
        }
        callMap["number"] = lastCall.details.handle?.schemeSpecificPart
    } else {
        callMap["state"] = "IDLE"
        callMap["number"] = null
    }
    
    // 활성 통화 정보
    val activeCall = activeCalls.find { it.state == Call.STATE_ACTIVE }
    if (activeCall != null) {
        callMap["active_number"] = activeCall.details.handle?.schemeSpecificPart
        callMap["active_state"] = "ACTIVE"
    }
    
    // 대기 중인 통화 정보
    val holdingCall = activeCalls.find { it.state == Call.STATE_HOLDING }
    if (holdingCall != null) {
        callMap["holding_number"] = holdingCall.details.handle?.schemeSpecificPart
        callMap["holding_state"] = "HOLDING"
    }
    
    // 수신 중인 통화 정보
    val ringingCall = activeCalls.find { it.state == Call.STATE_RINGING }
    if (ringingCall != null) {
        callMap["ringing_number"] = ringingCall.details.handle?.schemeSpecificPart
        callMap["ringing_state"] = "RINGING"
    }
    
    return callMap
}

// 통화 전환 메서드 추가
companion object {
    private var instance: PhoneInCallService? = null
    private val activeCalls = mutableListOf<Call>()
    private const val NOTIFICATION_ID = 1001
    private const val CHANNEL_ID = "incoming_call_channel_id"

    // 기존 메서드들...
    fun acceptCall() { instance?.acceptTopCall() }
    fun rejectCall() { instance?.rejectTopCall() }
    fun hangUpCall() { instance?.hangUpTopCall() }
    fun toggleMute(mute: Boolean) { instance?.toggleMuteCall(mute) }
    fun toggleHold(hold: Boolean) { instance?.toggleHoldTopCall(hold) }
    fun toggleSpeaker(speaker: Boolean) { instance?.toggleSpeakerCall(speaker) }
    
    // 새로 추가: 통화 전환 메서드
    fun switchActiveAndHoldingCalls() {
        val activeCall = activeCalls.find { it.state == Call.STATE_ACTIVE }
        val holdingCall = activeCalls.find { it.state == Call.STATE_HOLDING }
        
        if (activeCall != null && holdingCall != null) {
            activeCall.hold()
            holdingCall.unhold()
        }
    }
}
```

#### NativeBridge.kt

```kotlin
// methodChannel?.setMethodCallHandler에 다음 케이스 추가
"switchCalls" -> { 
    PhoneInCallService.switchActiveAndHoldingCalls()
    result.success(true) 
}
```

#### native_methods.dart

```dart
// NativeMethods 클래스에 새 메서드 추가
static Future<void> switchCalls() async {
  await _methodChannel.invokeMethod('switchCalls');
}

// 현재 통화 상태 정보를 가져오는 함수 확장
static Future<Map<String, dynamic>> getCurrentCallState() async {
  try {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'getCurrentCallState',
    );
    return result ?? {
      'state': 'IDLE', 
      'number': null, 
      'active_number': null,
      'holding_number': null,
      'ringing_number': null
    };
  } catch (e) {
    log('[NativeMethods] Error calling getCurrentCallState: $e');
    return {
      'state': 'IDLE', 
      'number': null, 
      'active_number': null,
      'holding_number': null,
      'ringing_number': null
    };
  }
}
```

#### call_state_provider.dart

```dart
// 새로운 멤버 변수 추가
String? _waitingCallNumber;
String? _waitingCallerName;
String? _holdingCallNumber;
String? _holdingCallerName;

// Getter 추가
String? get waitingCallNumber => _waitingCallNumber;
String? get waitingCallerName => _waitingCallerName;
String? get holdingCallNumber => _holdingCallNumber;
String? get holdingCallerName => _holdingCallerName;

// 통화 상태 동기화 함수 추가
Future<void> syncCallState() async {
  try {
    final callDetails = await NativeMethods.getCurrentCallState();
    log('[CallStateProvider] Call state details: $callDetails');
    
    // 대기 중인 통화 정보 업데이트
    final holdingNumber = callDetails['holding_number'] as String?;
    if (holdingNumber != null && holdingNumber.isNotEmpty) {
      if (_holdingCallNumber != holdingNumber) {
        _holdingCallNumber = holdingNumber;
        _holdingCallerName = await contactsController.getContactName(holdingNumber);
        log('[CallStateProvider] 대기 중인 통화 정보 업데이트: $_holdingCallNumber, $_holdingCallerName');
      }
    } else {
      _holdingCallNumber = null;
      _holdingCallerName = null;
    }
    
    // 수신 중인 통화 정보 업데이트
    final ringingNumber = callDetails['ringing_number'] as String?;
    if (ringingNumber != null && ringingNumber.isNotEmpty) {
      if (_waitingCallNumber != ringingNumber) {
        _waitingCallNumber = ringingNumber;
        _waitingCallerName = await contactsController.getContactName(ringingNumber);
        log('[CallStateProvider] 수신 중인 통화 정보 업데이트: $_waitingCallNumber, $_waitingCallerName');
      }
    } else {
      _waitingCallNumber = null;
      _waitingCallerName = null;
    }
    
    // 통화 상태 및 활성 번호 업데이트
    final state = callDetails['state'] as String? ?? 'IDLE';
    final number = callDetails['active_number'] as String? ?? 
                  callDetails['number'] as String? ?? '';
    
    CallState callStateEnum = CallState.idle;
    switch (state) {
      case 'RINGING':
        callStateEnum = CallState.incoming;
        break;
      case 'ACTIVE':
      case 'DIALING':
        callStateEnum = CallState.active;
        break;
      case 'IDLE':
        callStateEnum = CallState.idle;
        break;
      default:
        if (_callState == CallState.active) {
          callStateEnum = CallState.active;
        } else {
          callStateEnum = CallState.idle;
        }
    }
    
    // 상태 업데이트 필요 시 적용
    if (callStateEnum != _callState || _number != number) {
      await updateCallState(
        state: callStateEnum,
        number: number,
        isConnected: state == 'ACTIVE',
      );
    }
    
    // 상태 변경이 없어도 UI 업데이트가 필요한 경우
    if (_holdingCallNumber != null || _waitingCallNumber != null) {
      notifyListeners();
    }
  } catch (e) {
    log('[CallStateProvider] Error syncing call state: $e');
  }
}

// 타이머 시작 로직 추가 (생성자 또는 적절한 초기화 지점에 호출)
void startCallStateTimer() {
  _callStateTimer?.cancel();
  _callStateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
    syncCallState();
  });
  log('[CallStateProvider] 통화 상태 동기화 타이머 시작');
}

// 통화 수락/거절 함수 구현
Future<void> acceptWaitingCall() async {
  try {
    log('[CallStateProvider] 대기 후 수신 시도');
    // 현재 통화를 대기 상태로 전환
    await NativeMethods.toggleHold(true);
    // 대기 상태 반영
    _isHold = true;
    
    // 잠시 대기 후 수신 통화 받기
    await Future.delayed(const Duration(milliseconds: 300));
    await NativeMethods.acceptCall();
    
    // 상태 즉시 동기화
    await syncCallState();
  } catch (e) {
    log('[CallStateProvider] Error accepting waiting call: $e');
  }
}

Future<void> rejectWaitingCall() async {
  try {
    log('[CallStateProvider] 대기 통화 거절');
    await NativeMethods.rejectCall();
    _waitingCallNumber = null;
    _waitingCallerName = null;
    notifyListeners();
  } catch (e) {
    log('[CallStateProvider] Error rejecting waiting call: $e');
  }
}

Future<void> endAndAcceptWaitingCall() async {
  try {
    log('[CallStateProvider] 현재 통화 종료 후 대기 통화 수락');
    // 현재 통화 종료
    await NativeMethods.hangUpCall();
    
    // 잠시 대기 후 수신 통화 받기
    await Future.delayed(const Duration(milliseconds: 500));
    await NativeMethods.acceptCall();
    
    // 상태 즉시 동기화
    await syncCallState();
  } catch (e) {
    log('[CallStateProvider] Error ending call and accepting waiting call: $e');
  }
}

Future<void> switchCalls() async {
  try {
    log('[CallStateProvider] 통화 전환 시도');
    await NativeMethods.switchCalls();
    
    // 상태 즉시 동기화
    await Future.delayed(const Duration(milliseconds: 300));
    await syncCallState();
  } catch (e) {
    log('[CallStateProvider] Error switching calls: $e');
  }
}
```

#### on_call_contents.dart 

```dart
@override
Widget build(BuildContext context) {
  // Provider에서 상태 읽기
  final callStateProvider = context.watch<CallStateProvider>();
  final isMuted = callStateProvider.isMuted;
  final isHold = callStateProvider.isHold;
  final isSpeakerOn = callStateProvider.isSpeakerOn;

  final displayName = callerName.isNotEmpty ? callerName : number;
  final callStateText = connected ? _formatDuration(duration) : '통화 연결중...';

  return Column(
    children: [
      // 상단 정보 (기존 코드)
      Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 2.0),
        child: Text(
          callStateText,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          displayName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          number,
          style: const TextStyle(color: Colors.black54, fontSize: 16),
        ),
      ),

      // 대기 중인 통화 정보 표시 (새로 추가)
      if (callStateProvider.holdingCallNumber != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                const Icon(Icons.pause, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '대기 중인 통화',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        callStateProvider.holdingCallerName ?? '알 수 없음',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        callStateProvider.holdingCallNumber ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_calls, color: Colors.blue),
                  onPressed: () => context.read<CallStateProvider>().switchCalls(),
                  tooltip: '통화 전환',
                ),
              ],
            ),
          ),
        ),

      const Spacer(),
      
      // 기존 버튼 영역 (음소거, 통화대기, 스피커)
      // ... 기존 코드 유지 ...
    ],
  );
}
```

### 4.2. 구현 순서 및 테스트 계획

1. **코드 수정 및 구현 순서**
   - PhoneInCallService.kt의 getCurrentCallDetails 메서드를 확장 구현
   - switchActiveAndHoldingCalls 메서드 추가
   - NativeBridge.kt에 switchCalls 메서드 추가
   - native_methods.dart에 switchCalls 함수 추가
   - CallStateProvider에 대기/활성 통화 관리 변수 및 함수 추가
   - 상태 동기화 타이머 및 syncCallState 함수 구현
   - on_call_contents.dart에 대기 중인 통화 정보 표시 UI 추가

2. **테스트 계획**
   - test_scenarios.md 파일에 정의된 5가지 시나리오별 테스트 수행
   - 각 시나리오마다 통화 상태 변화가 UI에 정확히 반영되는지 확인
   - getCurrentCallDetails 함수가 정확한 통화 정보를 반환하는지 로그로 확인
   - 통화 상태 전환 시 발생할 수 있는 버그나 지연 문제 해결

3. **예상 이슈 및 대응 방안**
   - 안드로이드 버전별 통화 관리 API 차이: API 버전 체크 로직 구현
   - 상태 업데이트 지연: 적절한 타이밍의 Future.delayed 추가
   - 통화 상태 감지 오류: 로깅 강화 및 방어적 코딩 적용
   - UI 업데이트 문제: setState 또는 notifyListeners 호출 시점 최적화

이 변경사항들은 기존 코드에 최소한의 수정을 가하면서 필요한 기능을 구현할 수 있도록 합니다. 