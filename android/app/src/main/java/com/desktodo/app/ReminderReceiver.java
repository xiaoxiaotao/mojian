package com.desktodo.app;
import android.content.*;
public class ReminderReceiver extends BroadcastReceiver {
 @Override public void onReceive(Context c,Intent i){if("com.desktodo.app.REMIND".equals(i.getAction()))ReminderScheduler.fire(c,i.getStringExtra("key"));else if("com.desktodo.app.FOCUS".equals(i.getAction()))FocusAlarm.fire(c);else {ReminderScheduler.reconcile(c,true);FocusAlarm.reconcile(c,true);}}
}
