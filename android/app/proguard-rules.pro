# Fix TypeToken issue with flutter_local_notifications and Gson
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep flutter_local_notifications classes
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }

# Keep Gson TypeToken generic signatures
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
