# WebView invokes these methods through JavaScript rather than Java call sites.
-keepattributes RuntimeVisibleAnnotations
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Room constructs the generated WorkManager database implementation by name.
# Keep its no-argument constructor; this is not a Java call R8 can discover.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
