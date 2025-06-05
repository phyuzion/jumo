search 할때,

isRegisteredUser 일경우 정보를 그냥 가리는데,

이제 이건 필요없어진거임.

그니까 그 기능을 뺴야함.

그런데 순서를, 고객이 많은 상태이고 서버 수정이 필요하니..

클라이언트 수정 + 서버에서는 해당 값을 null로만 반환
이후 모든 고객들이 업데이트를 하고나면 서버에서 해당 값을 삭제.

1. 클라이언트 쪽에서 부터...
 1) search_records_controller.dart
 2) search_api.dart 수정
 3) phone_number_model.dart 수정

2. 서버쪽에서..
 1) server/server/phone.resolver.js 에서 isRegisterdUser를 항시 널로 반환토록 진행

=========

여기까지 해두면 구버전, 신버전 모두 이상없이 사용 가능.

이후 신버전으로 사용자들이 모두 업데이트를 하면 서버에서 리턴해주던것도 삭제.