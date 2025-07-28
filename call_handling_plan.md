통화중 오는 전화 확인 및 oncall 상태에서 대기 - 통화 - 대기 상태 전화 구현, 기존 잘못된 구현으로 인해 재구현 진행중.

시나리오
1. 전화중
2. 전화중인데 통화가 새로 들어옴 ( 한개의 전화가 active 상태인데 ringing 으로 새로 들어오는 경우. )
3. 팝업으로 알림
4. 대기후 통화, 종료후 통화, 거절 을 통해 신규 들어온 전화 컨트롤.
 - 대기 후 통화 : 기존 통화 대기 후 신규 전화 받음
 - 종료 후 통화 : 기존 통화 종류 후 신규 전화 받음
 - 거절 : 신규로 들어오는 전화 거절
5. 4번에서 거절 외 모든 통화는 신규를 받는것으로써 on_call 상태로 변환됨.
6. on_call 상태에서 현재 "대기중 ( 받았으므로 기존통화가 될것.)" 인 전화가 있을 경우 on_call_contents 에 해당 내용을 표시
7. on_call_contents 에서 대기중인 전화를 눌러 서로 번갈아가며 대기할 수 있음.
8. 이때, 오직 대기는 1통화. 또 들어올경우 자동 거절. (부재중으로 남기게 됨)

현재 상황
1. 통화중 오는 전화에 대한 팝업 구현 ( call_wating_dialog.dart, call_waiting_dialog )
2. 이후 개발상황 모두 롤백함.
3. 수정할 때 필요한 코드.

MainActivity.kt
NativeBridge.kt
PhoneInCallService.kt
app_controller.dart
navigation_controller.dart
phone_state_controller.dart
main.dart
Call_state_provider.dart
home_screen.dart
call_timer.dart
native_method.dart
app_event_bus.dart
call_waiting_dialog.dart
on_call_contents.dart

지시사항
1. 상기시나리오를 기반으로 call_wating_dialog 및  코드들을 모두 체크
2. 현재 구현된 상황을 파악
3. 코드 수정을 하지말고 먼저 제안.
4. getCurrentCall Detail 이라는 함수가 있음. 얘는 2초마다 한번씩 땡겨오는 애임.
 -> 얘를 제대로 써서, 대기중인 전화와 통화중인 전화상태만 제대로 가져와서 온콜에 던져주기만 하면 됨.
4. call_handling_issue_status.md 파일을 생성, 1, 2, 3 번에 대한 내용을 기재.
5. 최소한의 수정으로 진행해야함. 기존의 로직에 최소한의 변경이 없도록
6. 지시자의 검수 후 개발 진행.
7. 이후 test_scenario 에 맞춰 테스트.