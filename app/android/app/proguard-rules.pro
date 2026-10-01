# WebView invokes these methods through JavaScript rather than Java call sites.
-keepattributes RuntimeVisibleAnnotations
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
