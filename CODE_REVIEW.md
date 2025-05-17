# 주모(JUMO) 모바일 앱 코드 리뷰

## 1. 현재 코드의 트리 (Kotlin & Dart)

### Kotlin 코드 (Android 네이티브)
```
com.jumo.mobile/
  ├─ MainActivity.kt          # 앱의 메인 액티비티
  ├─ JumoApp.kt               # 애플리케이션 클래스
  ├─ PhoneInCallService.kt    # 전화 통화 서비스
  ├─ NativeBridge.kt          # Flutter-네이티브 통신 브릿지
  ├─ SmsPlugin.kt             # SMS 관련 기능 제공 플러그인
  └─ ContactManager.kt        # 연락처 관리 기능
```

### Dart 코드 (Flutter)
```
lib/
  ├─ main.dart                # 앱의 진입점
  ├─ hive_registrar.g.dart    # Hive 데이터베이스 어댑터
  ├─ controllers/             # 앱 로직 컨트롤러
  │   ├─ app_controller.dart
  │   ├─ blocked_numbers_controller.dart
  │   ├─ call_log_controller.dart
  │   ├─ contacts_controller.dart
  │   ├─ navigation_controller.dart
  │   ├─ phone_state_controller.dart
  │   └─ sms_controller.dart
  ├─ repositories/            # 데이터 저장소
  │   ├─ auth_repository.dart
  │   ├─ blocked_history_repository.dart
  │   ├─ blocked_number_repository.dart
  │   ├─ call_log_repository.dart
  │   ├─ contact_repository.dart
  │   ├─ notification_repository.dart
  │   ├─ settings_repository.dart
  │   └─ sms_log_repository.dart
  ├─ models/                  # 데이터 모델
  │   ├─ blocked_history.dart
  │   └─ 기타 모델 클래스들
  ├─ providers/               # 상태 제공자
  │   ├─ call_state_provider.dart
  │   └─ recent_history_provider.dart
  ├─ screens/                 # UI 화면
  │   ├─ board_screen.dart
  │   ├─ content_detail_screen.dart
  │   ├─ content_edit_screen.dart
  │   ├─ decider_screen.dart
  │   ├─ home_screen.dart
  │   ├─ login_screen.dart
  │   ├─ search_screen.dart
  │   └─ settings_screen.dart
  ├─ services/                # 백그라운드 서비스
  ├─ utils/                   # 유틸리티 함수
  │   └─ constants.dart
  ├─ widgets/                 # 재사용 가능한 위젯
  ├─ graphql/                 # GraphQL 쿼리 및 뮤테이션
  └─ overlay/                 # 오버레이 UI 컴포넌트
```

## 2. 각 코드의 역할 + 연결 + 사용 중인 플러그인

### 네이티브 코드 (Kotlin)

#### MainActivity.kt [O]
- **설명**: 앱의 메인 액티비티, 플러터 엔진 초기화 및 전화 관련 이벤트 처리
- **연결 코드**: NativeBridge.kt, PhoneInCallService.kt, SmsPlugin.kt
- **플러그인**: 안드로이드 기본 API (RoleManager, ActivityResultContracts)

#### JumoApp.kt [O]
- **설명**: 애플리케이션 클래스, 앱 컨텍스트 제공
- **연결 코드**: MainActivity.kt, PhoneInCallService.kt
- **플러그인**: 없음

#### PhoneInCallService.kt [O]
- **설명**: 전화 통화 감지 및 처리 서비스, 통화 상태 관리
- **연결 코드**: MainActivity.kt, NativeBridge.kt
- **플러그인**: Android InCallService API

#### NativeBridge.kt [O]
- **설명**: Flutter와 네이티브 코드 간의 통신 관리
- **연결 코드**: MainActivity.kt, PhoneInCallService.kt, ContactManager.kt
- **플러그인**: Flutter MethodChannel, EventChannel

#### SmsPlugin.kt [O]
- **설명**: SMS 메시지 관리 및 모니터링
- **연결 코드**: MainActivity.kt
- **플러그인**: Android BroadcastReceiver, ContentResolver

#### ContactManager.kt [O]
- **설명**: 연락처 접근 및 관리
- **연결 코드**: NativeBridge.kt
- **플러그인**: Android ContentResolver, ContactsContract

### Dart 코드 (Flutter)

#### main.dart [O]
- **설명**: 앱의 진입점, 의존성 주입 설정 및 앱 초기화
- **연결 코드**: 모든 컨트롤러, 리포지토리, 프로바이더
- **플러그인**: provider, get_it, hive_flutter, path_provider, flutter_background_service

#### hive_registrar.g.dart [O]
- **설명**: Hive 데이터베이스 어댑터 자동 생성 코드
- **연결 코드**: models/ 디렉토리의 모델 클래스들
- **플러그인**: hive

### controllers/

#### app_controller.dart [O]
- **설명**: 앱 전체 상태 관리, 기능 초기화 및 조정
- **연결 코드**: contacts_controller.dart, call_log_controller.dart, sms_controller.dart, blocked_numbers_controller.dart
- **플러그인**: provider

#### blocked_numbers_controller.dart [O]
- **설명**: 차단된 전화번호 관리 및 처리
- **연결 코드**: contacts_controller.dart, repositories/blocked_number_repository.dart, repositories/blocked_history_repository.dart
- **플러그인**: provider, hive

#### call_log_controller.dart [O]
- **설명**: 통화 기록 관리 및 처리
- **연결 코드**: repositories/call_log_repository.dart
- **플러그인**: provider, platform_channel

#### contacts_controller.dart [O]
- **설명**: 연락처 관리 및 동기화
- **연결 코드**: repositories/contact_repository.dart, repositories/settings_repository.dart
- **플러그인**: platform_channel

#### navigation_controller.dart [O]
- **설명**: 앱 내 화면 이동 및 네비게이션 관리
- **연결 코드**: phone_state_controller.dart, contacts_controller.dart
- **플러그인**: flutter GlobalKey<NavigatorState>

#### phone_state_controller.dart [O]
- **설명**: 전화 상태 관리 및 처리
- **연결 코드**: call_log_controller.dart, contacts_controller.dart, blocked_numbers_controller.dart, app_controller.dart
- **플러그인**: platform_channel, flutter_background_service

#### sms_controller.dart [O]
- **설명**: SMS 메시지 관리 및 처리
- **연결 코드**: repositories/sms_log_repository.dart, app_controller.dart
- **플러그인**: platform_channel

### repositories/

#### auth_repository.dart [O]
- **설명**: 사용자 인증 관리
- **연결 코드**: 없음 (독립 기능)
- **플러그인**: hive

#### blocked_history_repository.dart [O]
- **설명**: 차단 기록 저장 및 관리
- **연결 코드**: models/blocked_history.dart
- **플러그인**: hive

#### blocked_number_repository.dart [O]
- **설명**: 차단된 번호 저장 및 관리
- **연결 코드**: blocked_numbers_controller.dart
- **플러그인**: hive

#### call_log_repository.dart [O]
- **설명**: 통화 기록 저장 및 관리
- **연결 코드**: call_log_controller.dart
- **플러그인**: hive

#### contact_repository.dart [O]
- **설명**: 연락처 저장 및 관리
- **연결 코드**: contacts_controller.dart
- **플러그인**: hive

#### notification_repository.dart [O]
- **설명**: 앱 내 알림 관리
- **연결 코드**: app_controller.dart
- **플러그인**: hive, flutter_local_notifications

#### settings_repository.dart [O]
- **설명**: 앱 설정 저장 및 관리
- **연결 코드**: contacts_controller.dart, blocked_numbers_controller.dart
- **플러그인**: hive

#### sms_log_repository.dart [O]
- **설명**: SMS 메시지 기록 저장 및 관리
- **연결 코드**: sms_controller.dart
- **플러그인**: hive

### models/

#### blocked_history.dart [O]
- **설명**: 차단 기록 데이터 모델
- **연결 코드**: blocked_history_repository.dart
- **플러그인**: hive

### providers/

#### call_state_provider.dart [O]
- **설명**: 통화 상태 관리 및 UI 업데이트
- **연결 코드**: phone_state_controller.dart, call_log_controller.dart, contacts_controller.dart
- **플러그인**: provider, flutter_background_service

#### recent_history_provider.dart [O]
- **설명**: 최근 통화 및 SMS 기록 상태 관리
- **연결 코드**: app_controller.dart, call_log_controller.dart, sms_controller.dart
- **플러그인**: provider

### screens/

#### board_screen.dart [O]
- **설명**: 게시판 화면 UI 구현
- **연결 코드**: navigation_controller.dart
- **플러그인**: provider

#### content_detail_screen.dart [O]
- **설명**: 콘텐츠 상세 화면 UI 구현
- **연결 코드**: navigation_controller.dart
- **플러그인**: provider, flutter_quill

#### content_edit_screen.dart [O]
- **설명**: 콘텐츠 편집 화면 UI 구현
- **연결 코드**: navigation_controller.dart
- **플러그인**: provider, flutter_quill

#### decider_screen.dart [O]
- **설명**: 로그인 상태에 따라 적절한 화면으로 라우팅
- **연결 코드**: navigation_controller.dart, auth_repository.dart
- **플러그인**: provider

#### home_screen.dart [O]
- **설명**: 앱 홈 화면 UI 구현
- **연결 코드**: navigation_controller.dart, recent_history_provider.dart
- **플러그인**: provider

#### login_screen.dart [O]
- **설명**: 로그인 화면 UI 구현
- **연결 코드**: navigation_controller.dart, auth_repository.dart
- **플러그인**: provider

#### search_screen.dart [O]
- **설명**: 검색 화면 UI 구현
- **연결 코드**: navigation_controller.dart, contacts_controller.dart
- **플러그인**: provider

#### settings_screen.dart [O]
- **설명**: 설정 화면 UI 구현
- **연결 코드**: navigation_controller.dart, settings_repository.dart
- **플러그인**: provider

### utils/

#### constants.dart [O]
- **설명**: 앱 전체에서 사용되는 상수 정의
- **연결 코드**: 모든 파일
- **플러그인**: 없음

### overlay/
- **설명**: 전화 통화 시 오버레이 UI 구현
- **연결 코드**: phone_state_controller.dart, call_state_provider.dart
- **플러그인**: flutter_overlay_window

## 3. 최초 이니셜라이즈 할때의 흐름

1. **Flutter 앱 초기화**:
   - `main()` 함수에서 시작
   - `WidgetsFlutterBinding.ensureInitialized()` 호출로 Flutter 엔진 초기화
   - `initializeDependencies()` 함수 호출로 Hive 데이터베이스 및 저장소 초기화
   - 각종 Repository 인스턴스 생성 및 GetIt에 등록
   - Controller 클래스들 초기화 및 Provider 등록

2. **네이티브 연결 설정**:
   - `MainActivity`의 `configureFlutterEngine()` 호출
   - `NativeBridge.setupChannel()` 호출로 Flutter와 네이티브 간 메서드 채널 설정
   - `SmsPlugin` 등록

3. **앱 상태 초기화**:
   - `MyAppStateful` 위젯의 `initState()`에서 실행
   - `_initializeAppController()`: 앱 컨트롤러 초기화
   - `_handleInitialPayload()`: 푸시 알림으로 앱이 시작된 경우 처리
   - `_listenToBackgroundService()`: 백그라운드 서비스 이벤트 구독
   - `_saveScreenSizeToHive()`: 화면 크기 저장
   - `_applySecureFlag()`: 보안 플래그 적용 (스크린샷 방지)

4. **사용자 인증 상태 확인**:
   - `DeciderScreen`에서 로그인 상태에 따라 적절한 화면으로 라우팅
   - 로그인된 경우 연락처 동기화, 전화 기록, SMS 기록 로드

5. **권한 요청**:
   - 필요한 권한 확인 및 없는 경우 사용자에게 요청 (전화, SMS, 연락처 등)
   - 기본 전화 앱 설정 요청 (선택적)

## 4. 백그라운드 서비스의 동작

1. **백그라운드 서비스 초기화**:
   - Flutter Background Service 플러그인 사용
   - 앱이 종료되어도 전화 및 SMS 모니터링 유지

2. **전화 상태 모니터링**:
   - `PhoneInCallService`가 InCallService를 확장하여 전화 상태 모니터링
   - 백그라운드에서 전화 상태 변경 감지 및 처리

3. **전화 이벤트 전달**:
   - 백그라운드 서비스에서 Flutter 앱으로 이벤트 전달
   - `updateUiCallState` 이벤트를 통해 UI 업데이트

4. **SMS 모니터링**:
   - `SmsPlugin`에서 BroadcastReceiver를 통해 SMS 수신 감지
   - 수신된 SMS 처리 및 필요시 차단

5. **데이터 동기화**:
   - 백그라운드에서 발생한 전화/SMS 이벤트를 로컬 데이터베이스에 저장
   - 앱이 다시 포그라운드로 돌아올 때 데이터 동기화

## 5. 전화가 왔을 때의 흐름

1. **전화 수신 감지**:
   - `PhoneInCallService`의 `onCallAdded()`에서 새 통화 감지
   - `Call.STATE_RINGING` 상태 확인
   - 수신자 전화번호 추출

2. **UI 알림**:
   - `showIncomingCall()` 메서드 호출
   - MainActivity로 인텐트 전송 (`incoming_call=true`)
   - MainActivity에서 `NativeBridge.notifyIncomingNumber()` 호출
   - Flutter의 `MethodChannel`을 통해 `onIncomingNumber` 이벤트 전달

3. **Flutter 측 처리**:
   - `PhoneStateController`에서 수신 전화 처리
   - `CallStateProvider`에서 상태 업데이트
   - 전화번호를 기반으로 연락처 정보 조회

4. **차단 검사**:
   - `BlockedNumbersController`를 통해 차단된 번호인지 확인
   - 차단된 번호인 경우 자동 거절 처리 및 기록 저장

5. **수신 화면 표시**:
   - 오버레이 UI 표시 (전화 수신 화면)
   - 사용자가 수락/거절 버튼 클릭 가능

## 6. 전화가 끊겼을 때의 흐름

1. **통화 종료 감지**:
   - `PhoneInCallService`에서 `Call.STATE_DISCONNECTED` 상태 감지
   - 종료 이유 확인 (`DisconnectCause.MISSED` 등)
   - 전화번호 및 종료 사유 추출

2. **UI 알림**:
   - `showCallEnded()` 메서드 호출
   - MainActivity로 인텐트 전송 (`call_ended=true`)
   - MainActivity에서 `NativeBridge.notifyCallEnded()` 호출
   - Flutter의 `MethodChannel`을 통해 `onCallEnded` 이벤트 전달

3. **Flutter 측 처리**:
   - `PhoneStateController`에서 종료된 통화 처리
   - `CallStateProvider`에서 상태 업데이트 (`CallState.ended`)
   - 통화 종료 UI 표시 (필요한 경우)

4. **통화 기록 저장**:
   - `CallLogController`를 통해 통화 기록 저장
   - `CallLogRepository`에서 Hive 데이터베이스에 저장
   - 부재중 전화인 경우 알림 표시

5. **데이터 동기화**:
   - 서버에 통화 기록 동기화 (로그인된 경우)
   - 최근 기록 목록 업데이트

## 7. 잠재적인 이슈

1. **권한 관련 이슈**:
   - Android 13 이상에서 알림 권한 별도 요청 필요
   - 기기마다 다른 권한 정책으로 인한 오작동 가능성

2. **백그라운드 제한**:
   - 최신 Android에서 백그라운드 서비스 제한 정책으로 인한 문제
   - 배터리 최적화 예외 처리 필요

3. **기본 전화 앱 설정 이슈**:
   - 사용자가 기본 전화 앱으로 설정하지 않으면 일부 기능 제한
   - 기기마다 다른 기본 앱 설정 UI로 인한 사용자 혼란 가능성

4. **메모리 관리**:
   - 대량의 전화/SMS 기록 및 연락처 처리 시 메모리 사용량 증가
   - Hive 데이터베이스 성능 이슈 가능성

5. **동기화 충돌**:
   - 서버 데이터와 로컬 데이터 간 동기화 충돌 가능성
   - 네트워크 문제로 인한 동기화 실패 처리 미흡

6. **UI 스레드 차단**:
   - 대량 데이터 처리 시 UI 스레드 차단 가능성
   - 일부 무거운 작업이 백그라운드 스레드로 충분히 분리되지 않음

7. **보안 관련 이슈**:
   - 민감한 통화 및 SMS 데이터 암호화 처리 미흡
   - 로그에 민감한 정보 노출 가능성

8. **통화 상태 불일치**:
   - 네이티브와 Flutter 간의 통화 상태 불일치 가능성
   - 예외 상황(통화 중 앱 강제 종료 등)에 대한 복구 메커니즘 미흡

9. **오래된 API 사용**:
   - 일부 구현이 최신 Android API 변경사항을 따라가지 못함
   - API 29(Android 10) 이전 버전과 이후 버전에서 다른 구현 방식 필요 