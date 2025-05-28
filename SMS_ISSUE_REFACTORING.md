SMS 관련 리펙토링 및 이슈 체크

1. 이슈 사항 : 갑자기 SMS가 도중에 안들어오거나, 어떤 특정 이슈로 인해 ( 확인 불가 ) 긁어오지 않는 경우가 있음.
2. ContentObserver 가 죽을수도 있는건가? 그렇다면 리프레시나 가져오기 전에 얘가 죽어있다면 어떻게든 다시 실려야 하고, 데이터가 중간에 뒤집어 오는 경우 때문에 앱이 죽을수도 있나? 확인 필요.
3. 가장 최근 리프레시 해서 가져온 날짜로 하지 말고, 가장 마지막에 가져온 문자 시간 ~ 현재 시간 기준으로 가져오는 로직으로 변경 + 하루치 가져오는 로직으로 변경


관련 코드
:안드로이드
- SmsPlugin.kt
- MainActivity.kt
- JumoApp.kt

:플러터
- sms_log_repository.dart
- sms_controller.dart
- recent_history_provider.dart
- recent_calls_screen.dart


## 문제 분석 및 해결 방안

### 식별된 문제점
1. **ContentObserver 동작 불안정**: ContentObserver가 비활성화되거나 죽을 수 있음
2. **메시지 조회 로직 문제**: 리프레시 날짜 기준으로 메시지를 가져오는 방식이 신뢰성 낮음
3. **데이터 중복/누락 위험**: 메시지 동기화 과정에서 데이터 처리 오류 가능성

### 리팩토링 계획

#### 1. ContentObserver 안정성 강화
- SmsPlugin.kt에서 ContentObserver 상태 확인하는 메소드 추가
- 앱 포그라운드 복귀시 ContentObserver 재등록 로직 구현
- observer 등록 실패시 자동 재시도 메커니즘 구현
- 로깅 강화로 ContentObserver 생명주기 모니터링

#### 2. 메시지 조회 로직 개선
- 기존: 리프레시 시간 기준으로 메시지 조회
- 개선: 마지막으로 가져온 메시지 시간 ~ 현재 시간 범위로 조회
- 구현 방법:
  - SmsController에서 마지막 메시지 시간 추적 변수 추가
  - 저장된 메시지 목록에서 최신 시간 계산 로직 개선
  - 네이티브 호출 시 fromTimestamp와 toTimestamp 명확히 전달

#### 3. 오류 복원력 강화
- 메시지 동기화 실패 시 단계별 폴백 메커니즘 구현
- 데이터 일관성 검증 로직 추가
- 예외 상황 발생 시 자동 복구 로직 구현
- 중복 메시지 필터링 로직 강화

#### 4. 성능 최적화
- 안드로이드 측에서 쿼리 최적화 (인덱스 활용)
- SMS와 MMS 데이터 효율적 병합 처리
- 데이터 캐싱 개선으로 반복 요청 최소화

### 구현 단계
1. ContentObserver 안정성 개선 (SmsPlugin.kt)
2. 메시지 조회 로직 변경 (SmsController.dart)
3. 데이터 모델 및 저장소 개선 (sms_log_repository.dart)
4. UI 업데이트 로직 최적화 (recent_history_provider.dart)
5. 테스트 및 모니터링 강화

### 테스트 계획
- 다양한 시나리오에서 SMS 수신/조회 테스트
- ContentObserver 강제 종료 후 복구 테스트
- 배터리 최적화 모드에서의 동작 테스트
- 오래된 메시지 및 대량 메시지 처리 성능 테스트


## SmsController 등록 및 초기화 흐름 분석

### SmsController 등록 시점
1. **main.dart에서 초기화**:
   - 앱 시작시 SmsController 인스턴스가 생성됨 (`final smsController = SmsController(smsLogRepository, appController)`)
   - AppController에 SmsController 등록 (`appController.setSmsController(smsController)`)
   - Provider 시스템에 SmsController 등록하여 앱 전체에서 접근 가능

2. **실제 SMS 기능 초기화 시점**:
   - AppController.triggerContactsLoadIfReady() 메소드 내에서 SMS 기능 초기화
   - 이 메소드는 다음 시점에 호출됨:
     - 로그인 성공 후 (LoginScreen에서)
     - 이미 로그인된 상태로 앱 실행 시 (DeciderScreen에서)
     - 앱 재개(resume) 시 (RecentHistoryProvider에서)

3. **초기화 조건**:
   - SMS 권한이 허용되어 있어야 함 (`smsPermissionStatus.isGranted`)
   - SmsController가 null이 아니어야 함
   - 로그인이 완료된 상태여야 함

### ContentObserver 등록 흐름
1. AppController.triggerContactsLoadIfReady() 호출
2. SMS 권한 확인 후 SmsController.startSmsObservation() 호출
3. SmsController.listenToSmsEvents() 호출로 이벤트 구독 시작
4. SmsController.refreshSms() 호출하여 메시지 동기화 시작
5. 네이티브 코드(SmsPlugin.kt)에서 ContentObserver 등록 및 활성화

### 문제 지점
1. **앱 전환 후 이벤트 미수신 가능성**:
   - 앱이 백그라운드로 갔다가 다시 포그라운드로 돌아올 때 ContentObserver 상태 확인 부재
   - MyAppStateful.didChangeAppLifecycleState()에서 contactsCtrl.syncContacts()는 호출하지만 SMS 관련 초기화 재확인 부재

2. **ContentObserver 상태 확인 부재**:
   - 현재 SmsPlugin.kt에는 ContentObserver가 활성 상태인지 확인하는 메소드 없음
   - 초기화 이후 ContentObserver 상태를 확인하는 로직이 없어 "죽은" 상태로 남을 수 있음

3. **메시지 누락 위험**:
   - 메시지 조회 시점과 마지막 메시지 시간 간의 불일치로 메시지 누락 가능성


## 단계별 구현 계획

### 1단계: ContentObserver 상태 관리 개선 (SmsPlugin.kt)
1. **상태 확인 메소드 추가**
   ```kotlin
   // 추가할 코드
   fun isObserverActive(): Boolean {
       return smsContentObserver != null && mmsContentObserver != null
   }
   ```

2. **메소드 채널에 상태 확인 기능 추가**
   ```kotlin
   // onMethodCall 함수 내 when 블록에 추가
   "checkObserverStatus" -> {
       val isActive = isObserverActive()
       result.success(isActive)
   }
   ```

3. **자동 재등록 메커니즘 구현**
   ```kotlin
   // 추가할 코드
   private fun ensureObserverRegistered() {
       if (smsContentObserver == null || mmsContentObserver == null) {
           startObservation()
           Log.d(TAG, "ContentObserver 재등록 시도 완료")
       }
   }
   ```

### 2단계: Flutter 측 ContentObserver 상태 확인 및 복구 (sms_controller.dart)
1. **ContentObserver 상태 확인 메소드 추가**
   ```dart
   Future<bool> isObserverActive() async {
     try {
       final bool? isActive = await _methodChannel.invokeMethod<bool>('checkObserverStatus');
       return isActive ?? false;
     } on PlatformException catch (e) {
       log('[SmsController.isObserverActive] Error: ${e.message}');
       return false;
     }
   }
   ```

2. **앱 재개시 ContentObserver 상태 확인 및 복구 메소드 추가**
   ```dart
   Future<void> ensureObserverActive() async {
     if (!await isObserverActive()) {
       log('[SmsController.ensureObserverActive] Observer is not active, restarting...');
       await startSmsObservation();
       listenToSmsEvents();
     }
   }
   ```

3. **AppController에 복구 로직 연결**
   ```dart
   // app_controller.dart 내 triggerContactsLoadIfReady() 메소드 수정
   if (_smsController != null) {
     final smsPermissionStatus = await Permission.sms.status;
     if (smsPermissionStatus.isGranted) {
       await _smsController!.ensureObserverActive(); // 변경된 부분
       _smsController!.refreshSms();
     }
   }
   ```

### 3단계: 메시지 조회 로직 개선 (SmsController.dart)
1. **마지막 메시지 시간 추적 변수 추가**
   ```dart
   class SmsController with ChangeNotifier {
     // 기존 변수들...
     int _lastMessageTimestamp = 0; // 추가: 마지막으로 가져온 메시지 시간 저장
   ```

2. **마지막 메시지 시간 계산 로직 추가**
   ```dart
   void _updateLastMessageTimestamp() {
     if (_smsLogs.isNotEmpty) {
       // 내림차순 정렬된 상태에서 첫 번째 항목이 가장 최근 메시지
       final int latestTimestamp = _smsLogs.first['date'] as int? ?? 0;
       if (latestTimestamp > _lastMessageTimestamp) {
         _lastMessageTimestamp = latestTimestamp;
         log('[SmsController._updateLastMessageTimestamp] Updated to: ${DateTime.fromMillisecondsSinceEpoch(_lastMessageTimestamp)}');
       }
     }
   }
   ```

3. **메시지 동기화 메소드 수정**
   ```dart
   Future<void> _processSyncMessagesAsync() async {
     // 기존 코드...
     
     try {
       // 현재 저장된 로그 가져오기
       final List<Map<String, dynamic>> currentStoredLogs = await _smsLogRepository.getAllSmsLogs();
       
       // 마지막 메시지 시간 계산 (기존 로직을 대체)
       int fromTimestamp = 0;
       if (currentStoredLogs.isNotEmpty) {
         // 모든 메시지에서 최근 시간 찾기
         for (final msg in currentStoredLogs) {
           final int msgDate = msg['date'] as int? ?? 0;
           if (msgDate > fromTimestamp) {
             fromTimestamp = msgDate;
           }
         }
       }
       
       // 시간이 너무 오래된 경우 기본값으로 하루 전으로 설정
       final DateTime now = DateTime.now();
       final DateTime oneDayAgo = now.subtract(_messageLookbackPeriod);
       final int oneDayAgoTimestamp = oneDayAgo.millisecondsSinceEpoch;
       
       if (fromTimestamp < oneDayAgoTimestamp) {
         fromTimestamp = oneDayAgoTimestamp;
       }
       
       // 현재 시간까지 조회
       final int toTimestamp = now.millisecondsSinceEpoch;
       
       // 변경된 매개변수로 메시지 가져오기
       final List<Map<String, dynamic>> newMessages = await _fetchMessagesFromNative(
         DateTime.fromMillisecondsSinceEpoch(fromTimestamp),
         DateTime.fromMillisecondsSinceEpoch(toTimestamp),
       );
       
       // 기존 코드 계속...
     }
     // 나머지 코드...
   }
   ```

### 4단계: 앱 라이프사이클 관리 개선 (MyAppStateful)
1. **앱 재개시 SMS 상태 확인 로직 추가**
   ```dart
   // _MyAppStatefulState 클래스의 didChangeAppLifecycleState 메소드 수정
   @override
   void didChangeAppLifecycleState(AppLifecycleState state) {
     super.didChangeAppLifecycleState(state);
     if (state == AppLifecycleState.resumed) {
       log('[MyAppStateful] App resumed. Checking login state...');
       try {
         final authRepository = context.read<AuthRepository>();
         authRepository.getLoginStatus().then((isLoggedIn) {
           if (isLoggedIn) {
             log('[MyAppStateful] User is logged in. Refreshing contacts...');
             final contactsCtrl = context.read<ContactsController>();
             contactsCtrl.syncContacts(forceFullSync: false);
             
             // SMS Observer 상태 확인 및 복구 추가
             log('[MyAppStateful] Checking SMS observer status...');
             final smsController = context.read<SmsController>();
             smsController.ensureObserverActive();
             
             log('[MyAppStateful] Refreshing recent history...');
             context.read<RecentHistoryProvider>().refresh();
           } else {
             log('[MyAppStateful] User is not logged in. Skipping contacts refresh.');
           }
         });
       } catch (e) {
         log('[MyAppStateful] Error checking login state or refreshing: $e');
       }
     }
   }
   ```

### 5단계: 오류 처리 및 로그 강화
1. **SmsPlugin.kt에 디버그 플래그 추가**
   ```kotlin
   companion object {
       private const val TAG = "SmsPlugin"
       private const val DEBUG = true // 디버그 모드 활성화
       // 나머지 상수...
       
       private fun logDebug(message: String) {
           if (DEBUG) Log.d(TAG, message)
       }
   }
   ```

2. **ContentObserver 오류 복구 로직 강화**
   ```kotlin
   private fun startObservation() {
       try {
           // 기존 코드...
           logDebug("[Observer] SmsContentObserver 등록 시도")
           applicationContext.contentResolver.registerContentObserver(
               Telephony.Sms.CONTENT_URI, true, smsContentObserver!!
           )
           logDebug("[Observer] SmsContentObserver 등록 성공")
       } catch (e: Exception) {
           Log.e(TAG, "[Observer] SmsContentObserver 등록 실패: ${e.message}")
           // 자동 재시도 로직 (1초 후)
           handler.postDelayed({
               logDebug("[Observer] SmsContentObserver 재등록 시도")
               try {
                   if (smsContentObserver == null) {
                       smsContentObserver = createContentObserver("SMS")
                   }
                   applicationContext.contentResolver.registerContentObserver(
                       Telephony.Sms.CONTENT_URI, true, smsContentObserver!!
                   )
                   logDebug("[Observer] SmsContentObserver 재등록 성공")
               } catch (e: Exception) {
                   Log.e(TAG, "[Observer] SmsContentObserver 재등록 실패: ${e.message}")
               }
           }, 1000)
       }
       
       // MMS ContentObserver에도 유사한 로직 적용
   }
   ```

### 테스트 단계
1. **각 단계별 기능 확인**
   - ContentObserver 상태 확인 API 테스트
   - 앱 백그라운드/포그라운드 전환 시 정상 동작 확인
   - 메시지 누락 여부 테스트

2. **스트레스 테스트**
   - 배터리 최적화 모드에서 SMS 수신 테스트
   - 대량 메시지 동기화 성능 테스트
   - 메모리 누수 확인

