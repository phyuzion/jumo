# Flutter Local Notifications plugin rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# System Alert Window plugin rules (기존 + 보강)
-keep class in.jvapps.system_alert_window.** { *; }
-keepattributes *Annotation*
-keepclassmembers class in.jvapps.system_alert_window.** { *; }
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver

# 필요한 경우 다른 규칙 추가
# -keep class c2.a { *; }

# -------------------------------------------------------------------
# Jumo custom classes 및 Flutter background-service 가 reflection 으로
# 호출되므로 난독화 제외 (Issue #6)
# -------------------------------------------------------------------
-keep class com.jumo.mobile.** { *; }
-keep class id.flutter.flutter_background_service.** { *; }

# MethodChannel lookup 시 class 이름/field 유지
-keepattributes *Annotation*
-keep class ** {
    @io.flutter.embedding.engine.FlutterEngine *;
}

# Google Play Core 라이브러리 관련 클래스 유지 (릴리스 빌드 오류 수정)
-keep class com.google.android.play.core.** { *; }