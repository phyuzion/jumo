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