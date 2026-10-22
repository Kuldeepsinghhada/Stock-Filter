# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# SQLite
-keep class com.tekartik.sqflite.** { *; }

# Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Desugaring & Missing Optional Libraries
-dontwarn java.time.**
-dontwarn com.google.android.play.core.**

# Don't obfuscate model classes if serialized
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Strip debug log calls in release builds for extra size savings
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}
