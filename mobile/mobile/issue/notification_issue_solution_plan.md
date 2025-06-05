# 노티피케이션 이슈 해결 계획

## 문제 상황
1. 어드민과 서버, DB에는 노티피케이션이 정상적으로 저장되고 있음
2. 모바일 앱에서 노티피케이션을 가져오지 못함
3. 어드민에서 userId 입력 시 ObjectID 형태로 입력해야 하는데 UI/UX가 명확하지 않음

## 핵심 원인
1. **백그라운드 서비스(isolate) 문제**: 
   - 백그라운드 서비스에서 GraphQL API를 직접 호출하면 인증 토큰 문제 발생
   - Isolate가 분리되어 있어 메인 앱의 토큰을 공유하지 못함

2. **어드민 UI 문제**:
   - 유저 ID 입력 시 ObjectID 형식을 요구하지만 UI에 명확히 표시되지 않음

## 해결 방안

### 1. 모바일 앱 수정
1. **백그라운드 서비스 메시지 패싱 구현**:
   - 백그라운드 서비스에서 직접 API 호출하지 않고 메인 isolate에 요청
   - 메인 isolate에서 API 호출 후 결과 전달
   - `app_background_service.dart` 수정

```dart
// 백그라운드 서비스 수정 (app_background_service.dart)
// 직접 호출 제거:
// final notiList = await NotificationApi.getNotifications();

// 대신 메인 isolate에 요청:
service.invoke('requestNotifications');

// 응답 리스너 추가:
service.on('notificationsResponse').listen((event) {
  final notiList = event?['notifications'] as List<dynamic>?;
  if (notiList == null || notiList.isEmpty) return;
  
  // 기존 처리 로직
  for (final n in notiList) {
    final sid = (n['id'] ?? '').toString();
    if (sid.isEmpty) continue;
    service.invoke('saveNotification', {
      'id': sid,
      'title': n['title'] as String? ?? 'No Title',
      'message': n['message'] as String? ?? '...',
      'validUntil': n['validUntil'],
    });
  }
});
```

2. **메인 앱에 리스너 추가** (`main.dart`):
```dart
// main.dart에 리스너 추가
void _listenToBackgroundService() {
  // 기존 리스너들...
  
  // 노티피케이션 요청 리스너 추가
  FlutterBackgroundService().on('requestNotifications').listen((event) async {
    try {
      final notiList = await NotificationApi.getNotifications();
      FlutterBackgroundService().invoke('notificationsResponse', {'notifications': notiList});
    } catch (e) {
      FlutterBackgroundService().invoke('notificationsError', {'error': e.toString()});
    }
  });
}
```

### 2. 어드민 페이지 수정
1. **유저 ID 입력 부분 명확화**:
   - `Notifications.jsx` 파일의 알림 생성 모달 수정
   - 유저 검색 기능 추가

```jsx
// Notifications.jsx 수정 (알림 생성 모달 부분)
<label className="block mt-3 mb-1">특정 유저ID (선택)</label>
<div>
  <input
    className="border p-1 w-full mb-1"
    placeholder="ObjectID 형식으로 입력 (ex: 507f1f77bcf86cd799439011)"
    value={targetUserId}
    onChange={(e) => setTargetUserId(e.target.value)}
  />
  <small className="text-gray-500 block mb-2">
    비워두면 전역 알림 / 특정 유저에게만 보내려면 유저의 ObjectID를 입력
  </small>
  <button
    className="bg-gray-200 text-gray-700 px-2 py-1 rounded text-sm"
    onClick={() => setShowUserSearchModal(true)}
  >
    유저 검색
  </button>
</div>

{/* 유저 검색 모달 추가 */}
{showUserSearchModal && (
  <UserSearchModal 
    onSelect={(userId) => {
      setTargetUserId(userId);
      setShowUserSearchModal(false);
    }}
    onClose={() => setShowUserSearchModal(false)}
  />
)}
```

2. **유저 검색 모달 컴포넌트 구현**:
   - 유저 검색 및 선택 기능 구현
   - 선택된 유저의 ObjectID를 자동으로 설정

## 구현 순서
1. 모바일 앱 백그라운드 서비스 수정 (메시지 패싱 구현)
2. 모바일 앱 메인에 리스너 추가
3. 어드민 페이지 수정 (유저 ID 필드 명확화)
4. 어드민 페이지 유저 검색 기능 추가

## 테스트 방법
1. 어드민에서 특정 유저에게 알림 생성
2. 모바일 앱에서 로그를 확인하여 알림이 정상적으로 가져와지는지 확인
3. 알림 UI에 표시되는지 확인 