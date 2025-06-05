# 통화 상태 관리 개선 계획

## 현재 아키텍처 분석

### 통화 상태 관리 컴포넌트
현재 앱에서 통화 상태는 여러 컴포넌트에서 분산 관리되고 있습니다:

1. **PhoneInCallService.kt**
   - 실제 통화 상태를 안드로이드 시스템으로부터 직접 수신하는 유일한 컴포넌트
   - 통화 시작, 연결, 종료 등의 실제 상태 변화를 감지

2. **PhoneStateController**
   - 네이티브 이벤트를 Flutter로 전달하고 관리하는 중앙 컨트롤러
   - 통화 상태 변경을 감지하고 앱 내 다른 컴포넌트에 전파

3. **CallStateProvider**
   - UI에 표시될 통화 상태 관리
   - 사용자 인터페이스 업데이트 처리

4. **백그라운드 서비스**
   - 앱이 종료되어도 백그라운드에서 계속 실행
   - 통화 타이머 관리 (핵심 역할)
   - 통화 상태 캐싱 (앱 재시작 시 복원용)
   - BroadcastReceiver를 통한 PHONE_STATE 인텐트 수신

   백그라운드 서비스는 다음과 같이 구성되어 있습니다:
   - **background_service_manager.dart** - 백그라운드 서비스 초기화 및 설정 담당
   - **background_service_handler.dart** - 백그라운드 서비스 실행 로직
   - **call_state_manager.dart** - 통화 상태 관리 및 모니터링
   - **call_timer.dart** - 통화 타이머 기능 관리
   - **notification_manager.dart** - 알림 처리
   - **blocked_list_manager.dart** - 차단 목록 동기화
   - **service_constants.dart** - 서비스 관련 상수 정의

### 현재 데이터 흐름

1. 통화 상태 감지:
   - PhoneInCallService.kt → PhoneStateController → CallStateProvider → UI
   - BroadcastReceiver → background_service_handler.dart (별도 경로)

2. 앱 재시작 시:
   - call_state_manager.dart의 캐시 → UI 복원

3. 통화 타이머:
   - call_timer.dart에서 관리

## 발견된 문제점

### 1. 상태 관리 중복 및 불일치

여러 컴포넌트가 독립적으로 통화 상태를 관리하여 불일치 발생:
- PhoneStateController에서 관리하는 상태
- call_state_manager.dart에서 관리하는 캐시 상태
- 두 시스템이 동기화되지 않아 충돌 가능성

### 2. 인코밍 콜 처리 문제

전화가 오는 동안 앱이 시작될 때 여러 문제 발생:
- 앱 초기화 중 타임아웃으로 통화 상태 확인 실패
- 이전 캐시된 상태와 새 인코밍 콜 상태 간 충돌
- 잘못된 상태가 표시될 가능성 (예: 인코밍 콜이 통화 중으로 표시)

### 3. 앱 재시작 시 경쟁 상태(Race Condition)

앱이 시작되는 초기 단계에서 여러 시스템이 동시에 초기화되며 경쟁 상태 발생:
- 백그라운드 서비스의 캐시 상태
- PhoneInCallService의 실시간 상태
- BroadcastReceiver를 통한 시스템 이벤트
- 이로 인해 예측 불가능한 동작 발생

### 4. 코드 복잡성 증가

백그라운드 서비스에 너무 많은 책임이 집중:
- 통화 상태 캐싱
- 타이머 관리
- 상태 검증
- UI 업데이트 요청
- 이벤트 처리
- 이로 인해 유지보수 어려움 및 잠재적 버그 가능성 증가

## 단기 해결책 (현재 구현)

지금까지 구현한 방식으로 임시 해결:

1. **통화 상태 캐싱 메커니즘 개선**
   - 백그라운드 서비스에서 통화 상태를 명시적으로 캐싱
   - 앱 재시작 시 캐시된 상태 복원

2. **인코밍 콜 상태 관리 개선**
   - 인코밍 콜 상태도 캐싱
   - 타임스탬프를 통한 유효성 확인
   - 만료된 인코밍 콜 자동 정리

3. **중복 정보 방지 기능 추가**
   - 새 상태 설정 전 기존 상태 초기화
   - 상태 변경 시 확실한 로그 기록

4. **백그라운드-UI 통신 개선**
   - 초기화 완료 이벤트 추가
   - 캐시된 상태 확인 요청 처리

## 장기 해결책 (개선 방향)

현재 코드를 더 안정적이고 유지보수 가능한 구조로 개선하기 위한 계획:

### 1. 책임 분리 명확화

**PhoneStateController 강화:**
- 모든 통화 상태 관리의 중앙 지점으로 설정
- 캐싱 책임도 PhoneStateController로 이동
- 백그라운드 서비스는 타이머 관리와 상태 보존만 담당

**백그라운드 서비스 역할 축소:**
- 타이머 관리
- 상태 캐싱 (앱 종료 시 보존용)
- UI가 시작되기 전까지만 임시로 상태 제공

### 2. 상태 우선순위 명확화

**명확한 우선순위 설정:**
1. BroadcastReceiver (시스템 수준 이벤트) - 최우선
2. PhoneInCallService 상태 - 다음 우선순위
3. 백그라운드 서비스 캐시 - 최하위 우선순위

**HomeScreen 로드 후 즉시 상태 검증:**
- 앱이 완전히 시작된 후 곧바로 통화 상태 강제 확인
- 실제 시스템 상태를 모든 캐시된 상태보다 우선 적용
- 이후 정기적인 상태 검증 수행

### 3. 단방향 데이터 흐름 구현

**명확한 데이터 흐름 설정:**
- 앱 실행 중: PhoneStateController → 백그라운드 서비스 (상태 복사)
- 앱 시작 시: 백그라운드 서비스 → PhoneStateController (임시 상태 제공)
- PhoneInCallService → PhoneStateController (최종 상태 확정)

**이벤트 버스 도입 고려:**
- 컴포넌트 간 느슨한 결합을 위한 이벤트 기반 통신
- 각 컴포넌트는 이벤트 발행 및 구독만 담당

### 4. 상태 검증 메커니즘 추가

**HomeScreen 초기화 후 즉시 상태 검증:**
```dart
@override
void initState() {
  super.initState();
  // 기존 초기화 코드
  
  // 화면이 완전히 로드된 후 실행
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // 기존 초기화 코드
    
    // 강제로 현재 통화 상태 확인 및 업데이트
    _forceRefreshCallState();
  });
}

// 현재 통화 상태 강제 확인 및 업데이트
Future<void> _forceRefreshCallState() async {
  final phoneStateController = context.read<PhoneStateController>();
  // 현재 시스템 통화 상태 요청 (우선순위 높음)
  await phoneStateController.forceSyncCallState();
  log('[HomeScreen] Force refreshed call state after screen initialization');
}
```

**PhoneStateController에 강제 동기화 메서드 추가:**
```dart
// 현재 시스템 통화 상태 강제 확인 및 업데이트
Future<void> forceSyncCallState() async {
  // 네이티브에서 현재 통화 상태 확인
  final currentState = await NativeMethods.getCurrentCallState();
  // 현재 상태로 강제 업데이트 (캐시 상태 무시)
  _updateCallStateFromNative(currentState);
  log('[PhoneStateController] Forced call state sync completed');
  
  // 백그라운드 서비스에도 현재 상태 전파
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke('syncCallStateFromController', currentState);
  }
}
```

## 장기 구조 개선 계획

### 1단계: PhoneStateController 강화 (근본적 개선)

**1.1 상태 관리 중앙화:**
```dart
class PhoneStateController {
  // 현재 통화 상태 정보 (단일 소스)
  CallStateInfo _currentCallState = CallStateInfo.idle();
  
  // 상태 관리용 필드들
  
  // 백그라운드 서비스와의 통신
  final FlutterBackgroundService _service;
  
  // 상태 업데이트 메서드 (모든 업데이트는 이 메서드를 통해서만 이루어짐)
  void _updateCallState(CallStateInfo newState) {
    _currentCallState = newState;
    
               // 1. 백그라운드 서비스와 상태 동기화
       _syncStateWithBackgroundService(newState);
    
           // 2. 이벤트 발행 (UI 업데이트)
      appEventBus.fire(CallStateChangedEvent(newState));
    
           // 3. 로깅
      log('[PhoneStateController] Call state updated: ${newState.toDebugString()}');
    
    }
  }
```

**1.2 네이티브 이벤트 핸들러 개선:**
```dart
// 네이티브 이벤트 수신 처리
void handlePhoneStateEvent(String eventName, Map<String, dynamic> eventData, bool isDefaultDialer) {
  // 이벤트 유형에 따라 처리
  switch (eventName) {
    case 'onIncomingNumber':
      final CallStateInfo newState = CallStateInfo(
        state: CallState.incoming,
        number: eventData['number'],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      // 최우선 순위로 상태 업데이트
      _updateCallState(newState);
      break;
      
    case 'onCallStarted':
      // 처리 로직...
      break;
      
    // 기타 이벤트 처리...
  }
  
  // 백그라운드 서비스에도 직접 전달 (중요!)
  _notifyBackgroundServiceOfNativeEvent(eventName, eventData);
}
```

**1.3 상태 강제 동기화 메서드 추가:**
```dart
// 현재 시스템 통화 상태를 강제로 확인하고 업데이트
Future<void> forceSyncCallState() async {
  // 1. 네이티브에서 현재 통화 상태 직접 요청
  final Map<String, dynamic> nativeState = await NativeMethods.getCurrentCallState();
  
  // 2. 결과에 따라 CallStateInfo 객체 생성
  final CallStateInfo stateFromNative = _mapNativeStateToCallStateInfo(nativeState);
  
  // 3. 현재 상태와 비교하여 다른 경우에만 업데이트
  if (!_currentCallState.equals(stateFromNative)) {
    log('[PhoneStateController] Forced sync found different state, updating...');
    _updateCallState(stateFromNative);
  } else {
    log('[PhoneStateController] Forced sync verified current state is correct');
  }
}
```

### 2단계: 백그라운드 서비스 역할 재정의

**2.1 타이머 관리로 역할 축소:**
```dart
// app_background_service.dart

// 통화 상태 자체는 저장하지 않고, 타이머 관련 정보만 관리
String _timerPhoneNumber = '';
int _timerStartTime = 0;
Timer? _callTimer;

// 타이머 시작 (PhoneStateController에서 호출)
void startCallTimer(String phoneNumber) {
  _timerPhoneNumber = phoneNumber;
  _timerStartTime = DateTime.now().millisecondsSinceEpoch;
  
  // 타이머 로직...
}

// 타이머 중지
void stopCallTimer() {
  _callTimer?.cancel();
  _callTimer = null;
}

// PhoneStateController에서 전달받은 상태 업데이트 처리
service.on('updateCallStateFromController').listen((state) {
  if (state?['state'] == 'active') {
    // 타이머 관리만 담당
    startCallTimer(state?['number']);
  } else if (state?['state'] == 'ended') {
    stopCallTimer();
  }
  
  // 실제 상태는 저장하지 않음 (PhoneStateController가 담당)
});
```

**2.2 BroadcastReceiver는 이벤트 전달만:**
```dart
// BroadcastReceiver 설정
receiver.messages.listen((message) async {
  // 이벤트 로깅
  log('[BackgroundService][BroadcastReceiver] Received broadcast: ${message?.data}');
  
  // 이벤트를 메인 앱으로 전달
  service.invoke('broadcastReceiverEvent', message?.data);
  
  // 직접 처리하지 않고 전달만 함
});
```

### 3단계: 일관된 데이터 모델 도입

**3.1 통화 상태를 위한 명확한 데이터 클래스:**
```dart
// 통화 상태를 나타내는 불변 클래스
class CallStateInfo {
  final CallState state;
  final String number;
  final String callerName;
  final int timestamp;
  final bool isConnected;
  final int duration;
  
  const CallStateInfo({
    required this.state,
    required this.number,
    this.callerName = '',
    required this.timestamp,
    this.isConnected = false,
    this.duration = 0,
  });
  
  // 기본 idle 상태 생성
  factory CallStateInfo.idle() {
    return CallStateInfo(
      state: CallState.idle,
      number: '',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
  
  // 직렬화/역직렬화 메서드 (간단한 JSON 변환)
  Map<String, dynamic> toJson() {
    return {
      'state': state.index,
      'number': number,
      'callerName': callerName,
      'timestamp': timestamp,
      'isConnected': isConnected,
      'duration': duration,
    };
  }
  
  factory CallStateInfo.fromJson(Map<String, dynamic> json) {
    return CallStateInfo(
      state: CallState.values[json['state'] as int],
      number: json['number'] as String,
      callerName: json['callerName'] as String? ?? '',
      timestamp: json['timestamp'] as int,
      isConnected: json['isConnected'] as bool? ?? false,
      duration: json['duration'] as int? ?? 0,
    );
  }
  
  // 디버깅용 문자열
  String toDebugString() {
    return 'CallStateInfo{state: $state, number: $number, name: $callerName, connected: $isConnected, duration: $duration}';
  }
  
  // 상태 비교 메서드
  bool equals(CallStateInfo other) {
    return state == other.state && 
           number == other.number && 
           isConnected == other.isConnected;
  }
}
```

### 4단계: 단방향 데이터 흐름 및 이벤트 버스 도입

**4.1 이벤트 버스 강화:**
```dart
// utils/app_event_bus.dart

// 통화 상태 변경 이벤트
class CallStateChangedEvent {
  final CallStateInfo state;
  CallStateChangedEvent(this.state);
}

// 홈 화면 초기화 완료 이벤트
class HomeScreenInitializedEvent {}

// 앱 초기화 완료 이벤트
class AppInitializedEvent {}
```

**4.2 HomeScreen에서 이벤트 발행 및 구독:**
```dart
@override
void initState() {
  super.initState();
  
  // 이벤트 구독
  _callStateSubscription = appEventBus.on<CallStateChangedEvent>().listen((event) {
    // UI 업데이트
    _updateUIWithCallState(event.state);
  });
  
  // 화면 초기화 완료 후
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // 초기화 완료 이벤트 발행
    appEventBus.fire(HomeScreenInitializedEvent());
    
    // 강제 상태 동기화 요청
    context.read<PhoneStateController>().forceSyncCallState();
  });
}
```

**4.3 PhoneStateController에서 이벤트 구독:**
```dart
PhoneStateController() {
  // 홈 화면 초기화 완료 이벤트 구독
  _homeScreenInitSub = appEventBus.on<HomeScreenInitializedEvent>().listen((_) {
    log('[PhoneStateController] HomeScreen initialized, performing forced sync');
    forceSyncCallState();
  });
  
  // 백그라운드 이벤트 구독
  _bgEventSub = appEventBus.on<BackgroundEventReceivedEvent>().listen((event) {
    // 백그라운드 서비스 이벤트 처리
    _handleBackgroundEvent(event.eventType, event.data);
  });
}
```

### 5단계: 효율적인 상태 전달 및 복원

**5.1 메모리 내 상태와 서비스 간 통신:**
```dart
// PhoneStateController에서 백그라운드 서비스와 직접 통신
class PhoneStateController {
  // 메모리 내 현재 상태
  CallStateInfo _currentCallState = CallStateInfo.idle();
  
  // 백그라운드 서비스 인스턴스
  final FlutterBackgroundService _service;
  
  // 백그라운드 서비스로 상태 전달
  Future<void> _syncStateWithBackgroundService(CallStateInfo state) async {
    if (await _service.isRunning()) {
      _service.invoke('updateCallStateFromController', state.toJson());
      log('[PhoneStateController] State synced to background service: ${state.toDebugString()}');
    }
  }
  
  // 백그라운드 서비스에서 상태 요청
  Future<CallStateInfo?> _requestStateFromBackgroundService() async {
    if (!(await _service.isRunning())) return null;
    
    // 백그라운드 서비스에 상태 요청
    final completer = Completer<CallStateInfo?>();
    StreamSubscription? subscription;
    
    subscription = _service.on('respondWithCachedState').listen((cachedState) {
      if (!completer.isCompleted && cachedState != null) {
        try {
          final state = CallStateInfo.fromJson(
            Map<String, dynamic>.from(cachedState as Map),
          );
          completer.complete(state);
        } catch (e) {
          log('[PhoneStateController] Error parsing cached state: $e');
          completer.complete(null);
        }
        subscription?.cancel();
      }
    });
    
    // 타임아웃 설정
    Future.delayed(const Duration(seconds: 1), () {
      if (!completer.isCompleted) {
        completer.complete(null);
        subscription?.cancel();
      }
    });
    
    // 요청 전송
    _service.invoke('requestCachedState');
    
    return completer.future;
  }
}
```

**5.2 백그라운드 서비스의 경량화된 상태 캐싱:**
```dart
// 백그라운드 서비스에서 메모리 내 캐싱
Map<String, dynamic>? _cachedCallState;
int _stateLastUpdated = 0;

// 컨트롤러에서 상태 업데이트 수신
service.on('updateCallStateFromController').listen((state) {
  if (state != null) {
    _cachedCallState = Map<String, dynamic>.from(state);
    _stateLastUpdated = DateTime.now().millisecondsSinceEpoch;
    log('[BackgroundService] Call state cached from controller');
  }
});

// 캐싱된 상태 요청 처리
service.on('requestCachedState').listen((_) {
  // 너무 오래된 상태는 무시 (1분 이상)
  final isTooOld = DateTime.now().millisecondsSinceEpoch - _stateLastUpdated > 60000;
  
  if (_cachedCallState != null && !isTooOld) {
    service.invoke('respondWithCachedState', _cachedCallState);
    log('[BackgroundService] Responded with cached call state');
  } else {
    service.invoke('respondWithCachedState', null);
    log('[BackgroundService] No valid cached state to respond with');
  }
});
```

이러한 장기적 구조 개선을 통해:
1. 명확한 책임 분리
2. 타입 안전한 데이터 모델
3. 일관된 데이터 흐름
4. 효율적인 서비스 간 통신
5. 즉발성 데이터에 적합한 경량 캐싱
6. 복잡한 영구 저장소 의존성 제거
7. 중복 코드 제거

등을 달성할 수 있습니다. 이 접근법은 통화 상태의 즉발성 특성에 더 적합하며, 불필요한 저장소 계층 없이 필요한 기능을 제공합니다.

## 결론

현재 통화 상태 관리는 여러 컴포넌트에 분산되어 복잡성이 증가하고 있습니다. 단기적으로는 기존 구현을 개선하여 안정성을 높이고, 장기적으로는 명확한 책임 분리와 데이터 흐름을 통해 유지보수 가능한 구조로 리팩토링해야 합니다.

핵심은 "앱이 시작되면 실제 통화 상태가 최우선"이라는 원칙을 지키는 것입니다. 이를 통해 사용자는 항상 정확한 통화 상태를 볼 수 있게 됩니다.

## 구현 체크리스트

아래 체크리스트를 통해 구현 진행 상황을 추적할 수 있습니다:

### 1. PhoneStateController 개선
- [ ] 1.1 중앙 상태 관리 구조 구현
- [ ] 1.2 _updateCallState 메서드 구현
- [ ] 1.3 네이티브 이벤트 핸들러 개선
- [ ] 1.4 상태 강제 동기화 메서드 추가
- [ ] 1.5 백그라운드 서비스 통신 메서드 추가

### 2. 데이터 모델 개선
- [ ] 2.1 CallStateInfo 클래스 구현
- [ ] 2.2 상태 직렬화/역직렬화 메서드 구현
- [ ] 2.3 상태 비교 메서드 구현
- [ ] 2.4 디버깅 메서드 구현

### 3. 백그라운드 서비스 역할 재정의
- [ ] 3.1 통화 상태 관리 책임 제거
- [ ] 3.2 타이머 관리 역할 집중화
- [ ] 3.3 BroadcastReceiver 이벤트 전달 구현
- [ ] 3.4 컨트롤러와의 통신 채널 구현
- [ ] 3.5 경량화된 상태 캐싱 구현

### 4. 이벤트 시스템 구현
- [ ] 4.1 이벤트 클래스 정의
- [ ] 4.2 앱 이벤트 버스 구현/확장
- [ ] 4.3 HomeScreen 이벤트 구독 구현
- [ ] 4.4 PhoneStateController 이벤트 구독 구현

### 5. UI 통합
- [ ] 5.1 HomeScreen 초기화 시 상태 강제 동기화 구현
- [ ] 5.2 통화 상태 UI 업데이트 메서드 개선
- [ ] 5.3 인코밍 콜 표시 개선
- [ ] 5.4 통화 타이머 UI 연동 개선

### 6. 테스트 및 검증
- [ ] 6.1 앱 시작 시 통화 상태 복원 테스트
- [ ] 6.2 인코밍 콜 처리 테스트
- [ ] 6.3 앱 종료 후 재시작 테스트
- [ ] 6.4 다양한 통화 상태 전환 테스트
- [ ] 6.5 오류 상황 복구 테스트 

## 현재 상황 정리 (2024-06-05)

### 해결된 문제
1. **통화 중 앱 종료/재시작 문제**
   - 백그라운드 서비스에서 통화 상태 캐싱 구현
   - 타이머 지속 및 상태 복원 가능
   - 재시작 시 통화 화면 복원 성공

2. **노티피케이션 동기화 문제**
   - 서버와 로컬 노티피케이션 동기화 구현
   - 만료된 노티피케이션 자동 정리
   - 삭제 기능 개선 및 UI 반영

3. **인코밍 콜 처리 개선**
   - 인코밍 콜 상태 캐싱 추가
   - 상태 초기화 로직 강화
   - 중복 상태 방지 메커니즘 추가

### 현재 문제점 및 한계
1. **아키텍처 분산 문제**
   - 통화 상태 관리가 여러 컴포넌트에 분산됨
   - 책임 소재가 불명확하여 유지보수 어려움
   - 백그라운드 서비스가 너무 많은 역할 담당

2. **코드 복잡성**
   - 백그라운드 서비스 코드가 점점 비대해짐
   - 통화 상태 처리를 위한 분기 로직 복잡
   - 디버깅 및 테스트 어려움

3. **잠재적 경쟁 상태**
   - 앱 시작 시 여러 소스에서 통화 상태 업데이트
   - 상태 우선순위 로직 부족
   - 전화 상태 변경 시 일관성 보장 어려움

### 다음 단계
1. **단기 조치 (완료)**
   - 현재 구현된 해결책으로 당장의 문제 해소
   - 백그라운드 서비스의 통화 상태 관리 개선
   - 인코밍 콜 및 통화 중 상태 처리 강화

2. **중기 계획 (진행 중)**
   - PhoneStateController 역할 강화
   - 백그라운드 서비스와의 통신 개선
   - 명확한 상태 우선순위 적용

3. **장기 계획 (예정)**
   - 체크리스트에 따른 아키텍처 전면 개선
   - 컴포넌트 간 책임 명확화
   - 단방향 데이터 흐름 및 이벤트 시스템 도입

### 요약
현재 앱은 통화 상태 관리와 관련된 주요 문제를 해결하여 기본 기능이 안정적으로 작동하고 있습니다. 그러나 코드 구조상 근본적인 개선이 필요하며, 이를 위해 체계적인 리팩토링 계획을 수립했습니다. 단계적 접근으로 기존 기능을 유지하면서 코드 품질과 유지보수성을 향상시킬 예정입니다. 

## 리팩토링 현황 (2024-06-06)

### 백그라운드 서비스 모듈화 완료
기존의 단일 파일 `app_background_service.dart`가 담당하던 모든 기능을 다음과 같이 여러 파일로 분리했습니다:

1. **background_service_manager.dart**
   - 백그라운드 서비스 초기화 및 설정 담당
   - 안드로이드/iOS 설정 관리
   - 서비스 라이프사이클 관리

2. **background_service_handler.dart**
   - 백그라운드 서비스 메인 진입점 (`onStart` 함수)
   - 서비스 컴포넌트 초기화 및 조정
   - 초기 백그라운드 작업 수행

3. **call_state_manager.dart**
   - 통화 상태 감지 및 관리
   - 통화 상태 캐싱
   - 상태 모니터링 타이머 관리
   - BroadcastReceiver 설정 및 이벤트 처리

4. **call_timer.dart**
   - 통화 타이머 관리
   - 타이머 UI 업데이트
   - 통화 시간 추적

5. **notification_manager.dart**
   - 알림 처리 로직
   - 알림 이벤트 처리

6. **blocked_list_manager.dart**
   - 차단 목록 동기화 관련 기능
   - Repository 연동

7. **service_constants.dart**
   - 서비스 관련 상수 정의

### 모듈화를 통한 개선 사항

1. **코드 가독성 향상**
   - 각 모듈은 단일 책임 원칙(SRP)에 따라 명확한 역할을 갖게 됨
   - 파일당 코드량 감소로 가독성 크게 향상
   - 관련 코드가 한 곳에 모여 있어 이해하기 쉬움

2. **유지보수성 개선**
   - 모듈별 독립적인 수정 가능
   - 버그 수정 시 관련 모듈만 수정하면 됨
   - 새로운 기능 추가가 용이해짐

3. **코드 재사용성 향상**
   - 모듈화된 컴포넌트는 다른 부분에서도 재사용 가능
   - 명확한 인터페이스를 통한 컴포넌트 통신

4. **의존성 명시화**
   - 각 클래스의 의존성이 생성자를 통해 명시적으로 주입됨
   - 모듈 간 의존 관계가 명확해짐

### 향후 과제

리팩토링의 첫 단계로 백그라운드 서비스를 모듈화했지만, 여전히 더 개선이 필요한 부분이 있습니다:

1. **PhoneStateController와의 통합**
   - 장기 계획에서 언급한 대로 PhoneStateController를 통화 상태 관리의 중앙 지점으로 강화
   - 백그라운드 서비스와 PhoneStateController 간의 명확한 책임 분리

2. **상태 관리 통합**
   - 여러 모듈에 분산된 상태 관리를 단일 소스로 통합
   - 상태 업데이트 순서와 우선순위 명확화

3. **데이터 모델 개선**
   - 장기 계획에서 언급한 CallStateInfo 클래스 구현
   - 타입 안전한 상태 관리

4. **이벤트 기반 아키텍처 도입**
   - 컴포넌트 간 통신을 위한 이벤트 시스템 확장
   - 느슨한 결합을 통한 유연성 향상

이번 리팩토링은 백그라운드 서비스의 복잡성을 줄이고 관리하기 쉬운 구조로 개선하는 첫 단계였습니다. 앞으로 계속해서 아키텍처를 개선하여 더 안정적이고 유지보수하기 쉬운 코드베이스를 구축해 나갈 예정입니다. 