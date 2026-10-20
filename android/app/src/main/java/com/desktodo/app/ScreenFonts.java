package com.desktodo.app;
import android.content.Context;import android.graphics.Typeface;
/** Unmodified, bundled OFL screen fonts. Native UI retains platform font scaling. */
final class ScreenFonts {
 static Typeface chinese,verse,digits;
 static synchronized void load(Context context){if(chinese!=null)return;chinese=Typeface.createFromAsset(context.getAssets(),"fonts/SourceHanSansSC-Medium.otf");verse=Typeface.createFromAsset(context.getAssets(),"fonts/LXGWWenKaiGBScreen.ttf");digits=new Typeface.Builder(context.getAssets(),"fonts/Inter-Variable.ttf").setFontVariationSettings("'wght' 500").build();}
 static boolean isDigits(String value){if(value==null||value.isEmpty())return false;for(int i=0;i<value.length();i++){char ch=value.charAt(i);if(ch>=128&&"°▲▼—".indexOf(ch)<0)return false;}return true;}
 static boolean isVerse(String value){return "下班之后".equals(value)||"把时间，还给生活。".equals(value)||"今天的留白，也很珍贵。".equals(value);}
 static Typeface face(String value){if(chinese==null)throw new IllegalStateException("屏幕字体未加载");return isDigits(value)?digits:isVerse(value)?verse:chinese;}
}
