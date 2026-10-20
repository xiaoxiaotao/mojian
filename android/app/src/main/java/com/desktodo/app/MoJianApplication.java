package com.desktodo.app;
public final class MoJianApplication extends android.app.Application {
 @Override public void onCreate(){super.onCreate();ScreenFonts.load(this);}
}
