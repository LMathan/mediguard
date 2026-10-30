# Flutter & Plugin preservation rules for R8 / Proguard

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# SharedPreferences & Pigeon generated APIs
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep interface io.flutter.plugins.sharedpreferences.** { *; }
-keep class * implements io.flutter.plugins.sharedpreferences.** { *; }

# OneSignal SDK
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
