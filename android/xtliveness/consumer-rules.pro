# keep the JavaScript bridge method the check page calls
-keepclassmembers class com.xtremebit.xtliveness.XtlCheckView$Bridge { @android.webkit.JavascriptInterface <methods>; }
