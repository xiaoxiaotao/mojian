package com.desktodo.app;

import android.app.Instrumentation;
import android.app.Activity;
import android.content.pm.ApplicationInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.AdaptiveIconDrawable;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import java.io.File;
import java.io.FileOutputStream;

/** Explicit offline resource preview. Does not launch the app or touch user state/devices. */
public final class IconPreview extends Instrumentation {
    @Override public void onCreate(Bundle args) { start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            ApplicationInfo info = getTargetContext().getApplicationInfo();
            Drawable icon = getTargetContext().getPackageManager().getApplicationIcon(info);
            if (info.icon == 0 || !(icon instanceof AdaptiveIconDrawable))
                throw new IllegalStateException("Missing adaptive application icon");
            Bitmap bitmap = Bitmap.createBitmap(512, 512, Bitmap.Config.ARGB_8888);
            icon.setBounds(0, 0, 512, 512);
            icon.draw(new Canvas(bitmap));
            File output = new File(getTargetContext().getFilesDir(), "launcher-icon-preview.png");
            try (FileOutputStream stream = new FileOutputStream(output)) {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
            }
            result.putString("result", "PASS: application icon resolves to adaptive artwork; offline preview exported");
            finish(Activity.RESULT_OK, result);
        } catch (Exception error) {
            result.putString("error", error.toString());
            finish(Activity.RESULT_CANCELED, result);
        }
    }
}
