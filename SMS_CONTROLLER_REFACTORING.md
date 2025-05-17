# SMS/MMS 컨트롤러 리팩토링 계획

## 현재 코드 분석

### 구조적 특징
1. **Android 플러그인**
   - `SmsDetector.kt`: SMS/MMS 변경 감지하는 별도 클래스 (로그만 출력)
   - `SmsPlugin.kt`: Flutter 연동을 위한 메인 플러그인 구현
     - MethodChannel: `getSmsSince`, `getMessagesSince` 등 쿼리 기능
     - EventChannel: 메시지 변경 이벤트 발생
     - MMS 메시지를 SMS 형식으로 변환 로직

2. **Flutter 컨트롤러**
   - `sms_controller.dart`: Native 플러그인과 통신 관리
     - 메시지 변경 이벤트 수신 처리
     - 수신된 메시지 가공 및 저장
     - 서버 업로드 로직

### 기본 흐름
1. Native에서 SMS/MMS 변경 감지 → EventChannel을 통해 이벤트 발생
2. Flutter가 이벤트 수신 → MethodChannel을 통해 최신 메시지 요청
3. Native가 메시지 쿼리 후 반환 → Flutter에서 가공 처리
4. Flutter에서 로컬 저장소에 저장 및 서버 업로드

### 현재 문제점
1. **중복 코드**: `SmsDetector`와 `SmsPlugin`이 유사 기능 수행
2. **불필요한 복잡성**: MMS 처리 로직이 복잡하고 가독성 낮음
3. **불일치 데이터 모델**: Android와 Flutter 간 데이터 변환 과정 복잡
4. **오류 처리 미흡**: 예외 상황에 대한 강건한 처리 부족
5. **성능 문제**: 불필요한 변환 및 처리 작업 존재

## 리팩토링 목표

### 기본 요구사항 재확인
1. Android에서 SMS와 MMS를 모두 동일하게 취급 (모두 "SMS"로 간주)
2. 수신/발신 메시지의 주소(전화번호)를 일관되게 처리
3. 메시지 내용을 정리해서 Flutter로 전달
4. Flutter에서 메시지를 로컬 저장소에 업데이트하고 서버에 업로드

### 구체적 목표
1. **코드 단순화**: 중복 코드 제거 및 로직 통합
2. **일관된 데이터 모델**: SMS/MMS 통합 모델 구현
3. **오류 처리 강화**: 모든 예외 상황 대응
4. **성능 최적화**: 최소한의 데이터 처리 및 효율적 쿼리

## 리팩토링 구현 결과

### 1단계: Android 코드 정리
✅ **완료**
1. `SmsDetector.kt` 제거 후 `SmsPlugin.kt`로 기능 통합
   - 중복 코드 제거 및 책임 단일화
   - 관찰자 패턴 로직 정리
   
2. MMS 메시지 타입 처리 로직 단순화
   ```kotlin
   private fun getMmsDirection(mmsType: Int): String {
       return when (mmsType) {
           MmsMessageType.NOTIFICATION_IND, MmsMessageType.RETRIEVE_CONF, 
           MmsMessageType.READ_ORIG_IND -> "INBOX"
           else -> "SENT"
       }
   }
   ```
   
3. MMS 메시지 주소/내용 추출 로직 개선
   ```kotlin
   private fun standardizeMessageAddress(address: String?): String {
       return address?.replace(" ", "")?.replace("-", "") ?: ""
   }
   ```

### 2단계: 데이터 모델 통합
✅ **완료**
1. 통합 메시지 모델 정의
   ```kotlin
   data class UnifiedMessage(
       val id: Long,
       val address: String,
       val body: String,
       val date: Long,
       val type: Int,
       val typeStr: String,
       val read: Int,
       val threadId: Long,
       val subject: String?,
       val messageClass: String
   )
   ```
   
2. 변환 함수 구현
   ```kotlin
   private fun convertToUnifiedMessage(cursor: Cursor, messageClass: String): UnifiedMessage {
       // 변환 로직
   }
   ```
   
3. SMS와 MMS 통합 쿼리 메서드 구현
   ```kotlin
   private fun getUnifiedMessages(fromTimestamp: Long, toTimestamp: Long?): List<Map<String, Any?>> {
       // SMS 및 MMS 통합 쿼리 로직
   }
   ```

### 3단계: Flutter 코드 개선
✅ **완료**
1. 메시지 동기화 로직 정리
   ```dart
   Future<bool> syncMessages() async {
     // 최적화된 동기화 로직
   }
   ```
   
2. 오류 처리 강화
   ```dart
   Future<void> _uploadMessagesToServer(List<Map<String, dynamic>> messages) async {
     try {
       // 업로드 로직
     } catch (e) {
       // 오류 처리
     }
   }
   ```
   
3. 로그 기록 개선
   ```dart
   log('[SmsController.syncMessages] Message sync completed with ${messages.length} messages.');
   ```

### 4단계: 필드 단순화 및 데이터 최소화
✅ **완료**
1. 필요한 필드만 사용하도록 데이터 모델 단순화
   ```kotlin
   // 단순화된 메시지 데이터 모델
   data class UnifiedMessage(
       val id: Long,               // 메시지 고유 ID (내부 식별용)
       val address: String,        // 발신/수신 전화번호
       val body: String,           // 메시지 내용 (제목 포함)
       val date: Long,             // 타임스탬프
       val type: Int,              // 메시지 타입 코드 (1=INBOX, 2=SENT)
       val typeStr: String         // 타입 문자열 ("INBOX" 또는 "SENT")
   )
   
   // Flutter에 전달하는 맵 간소화
   fun toMap(): Map<String, Any?> {
       return mapOf(
           "address" to address,
           "body" to body,
           "date" to date,
           "type" to typeStr
       )
   }
   ```

2. 제목과 본문 통합
   ```kotlin
   // 제목이 있으면 본문 앞에 추가
   val body = if (!subject.isNullOrEmpty()) {
       "$subject\n$bodyText"
   } else {
       bodyText
   }
   ```

3. SMS/MMS 구분 제거
   - `message_class` 필드 제거
   - 단일 메시지 타입으로 처리 (INBOX 또는 SENT만 구분)

4. Flutter 컨트롤러 단순화
   - 타입 변환 함수 제거
   - 메시지 식별자 단순화
   ```dart
   String _generateSmsKey(Map<String, dynamic> smsMap) {
     final date = smsMap['date'];
     final address = smsMap['address'];
     
     if (date != null && address != null) {
       return "msg_key_[${date}_${address.hashCode}]";
     }
     return "msg_fallback_[${DateTime.now().millisecondsSinceEpoch}_${smsMap.hashCode}]";
   }
   ```

## 다음 단계 (향후 개선)

### 5단계: 성능 최적화
🔄 **진행 중**
1. 메시지 쿼리 최적화
   - SMS와 MMS 쿼리 최적화 (중복 쿼리 제거)
   - 필요한 컬럼만 선택적으로 쿼리

2. 중복 처리 방지
   - 변경감지 로직 개선 (현재는 전체 비교)
   - 메시지 ID 기반 효율적 비교

### 6단계: 테스트 및 안정화
❌ **예정**
1. 단위 테스트 추가
   - 주요 함수에 대한 단위 테스트 작성
   - 메시지 변환 로직 검증

2. 통합 테스트
   - 전체 흐름 검증
   - 다양한 메시지 유형 처리 확인

3. 오류 시나리오 테스트
   - 네트워크 오류 처리
   - 권한 거부 상황 처리

## 리팩토링 효과

### 개선된 점
1. **코드 가독성**
   - 중복 코드 제거
   - 일관된 데이터 모델 사용
   - 명확한 책임 분리

2. **안정성**
   - 오류 처리 강화
   - 동시성 이슈 방지 (동기화 중복 실행 방지)
   - 로깅 개선으로 디버깅 용이

3. **유지보수성**
   - 간소화된 데이터 모델로 확장 용이
   - 명확한 함수 분리로 수정 용이
   - 잘 문서화된 코드

4. **성능**
   - 불필요한 변환 작업 감소
   - 메시지 처리 로직 개선
   - 중복 쿼리 제거

5. **데이터 일관성**
   - SMS/MMS 통합적 처리
   - 필수 필드만 사용 (address, body, date, type)
   - 일관된 메시지 포맷 제공

## 결론

이번 리팩토링을 통해 SMS와 MMS를 통합적으로 처리하는 간소화된 인터페이스를 제공할 수 있게 되었습니다. 특히 다음과 같은 개선점이 있습니다:

1. **메시지 필드 간소화**: 필요한 4개 필드(주소, 본문, 날짜, 타입)만 사용하여 데이터 처리 단순화
2. **SMS/MMS 구분 제거**: 모든 메시지를 동일하게 처리하여 코드 복잡성 감소
3. **제목과 본문 통합**: MMS 제목을 본문에 포함시켜 일관된 메시지 형식 제공
4. **타입 단순화**: 메시지 타입을 INBOX 또는 SENT로만 구분하여 처리 로직 간소화

안드로이드와 플러터 간의 데이터 교환이 크게 단순화되었고, 오류 처리도 강화되었습니다. 앞으로는 성능 최적화와 테스트 강화를 통해 코드의 안정성과 효율성을 더욱 향상시킬 예정입니다. 