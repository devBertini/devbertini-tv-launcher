package com.leanbitlab.ltvL;

import android.accessibilityservice.AccessibilityService;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/** The sleep timer's alarm: the launcher's accessibility service locks the screen, which puts the TV in standby. */
public class SleepReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        SleepTimer.clear(context);
        LauncherAccessibilityService service = LauncherAccessibilityService.instance;
        boolean done = service != null && service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_LOCK_SCREEN);
        Log.i("DevBertiniSleep", done ? "standby requested" : "no accessibility service to request standby");
    }
}
