노티피케이션 관련 이슈

현재 상황 : 어드민과 서버, DB에는 노티피케이션이 정상적으로 저장이 되고 있는것으로 확인되나, Mobile 쪽에서 땡겨 갈때에 못가져가는 것으로 확인됨.

1. 관련 코드
서버
server/graphql/notification/notification.resolvers.js
server/graphql/notification/notification.typeDefs.js
어드민
admin/src/graphql 하위
admin/src/pages/Notifications.jsx
클라이언트
mobile/mobile/lib/graphql/notification_api.dart
mobile/mobile/lib/services/app_background_service.dart
mobile/mobile/lib/services/local_notification_service.dart


2. 의심상황
어드민에서는 잘 작성되고 가져오는데 왜 그럴까..
혹시, app_background_service 가, isolate 된 애라서 직접 API를 부르니까 토큰등이 없어서 오류가 나나?

3. 문제 상황
 1) 어드민에서 userId 를 넣는게 유저의 ObjectID를 넣어야만 제대로 세팅 되는것으로 확인. 말그대로 userId를 넣어야 하는데 오브젝트 아이디를 받게끔 되어있음.
 2) 서버쪽 코드를 수정할 순 없음. 그니까 어드민에서 수정을 진행해야하고, 클라이언트에서도 제대로 가져갈 수 있도록 수정해야함.