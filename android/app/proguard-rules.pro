# ===== FINAL v9 SECURE - ProGuard Rules for Hack Protection =====

# Keep Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Firebase - CRITICAL (otherwise Firebase breaks with obfuscate)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firestore.** { *; }
-keepattributes Signature, *Annotation*

# Keep Agora - CRITICAL (voice chat breaks if obfuscated)
-keep class io.agora.** { *; }
-keep class com.agora.** { *; }

# Keep Image Picker, Cropper
-keep class com.yalantis.ucrop.** { *; }
-keep class androidx.** { *; }

# Keep Connectivity, Device Info
-keep class com.julien.wyart.** { *; }

# Obfuscate everything else
-obfuscationdictionary proguard-dictionary.txt
-classobfuscationdictionary proguard-dictionary.txt
-packageobfuscationdictionary proguard-dictionary.txt

# Security: Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom classes (our app)
-keep class com.ludo.premium.** { *; }
