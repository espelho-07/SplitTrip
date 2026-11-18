# Flutter Wrapper ProGuard & R8 Optimization Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# SQLite3 & Drift C-bindings
-keep class org.sqlite.** { *; }
-keep class com.simonbinder.sqlite3.** { *; }
-dontwarn org.sqlite.**

# Supabase / GoTrue Models
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses
-dontwarn okio.**

# Native Kith Widgets & Notification Helpers
-keep class com.nirniq.kith.** { *; }
-keepclassmembers class com.nirniq.kith.** { *; }
