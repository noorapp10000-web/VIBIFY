-keep class io.flutter.** { *; }
-keep class com.ryanheise.** { *; }
-keep class com.tekartik.** { *; }
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

-dontwarn io.flutter.**
-dontwarn com.ryanheise.**

# Hive
-keep class ** implements com.hivedb.hive.HiveObject { *; }

# Keep enums
-keepclassmembers enum * { *; }

# Keep serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
