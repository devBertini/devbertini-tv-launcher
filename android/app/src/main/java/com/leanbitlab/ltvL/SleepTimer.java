package com.leanbitlab.ltvL;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

/**
 * "Desligar em": an exact alarm (USE_EXACT_ALARM, granted at install to a sideloaded app) that puts the TV
 * in standby after the chosen minutes, even with another app in front. Android stretches an inexact alarm
 * to a 10-minute window, too loose for a timer. A reboot clears it.
 */
final class SleepTimer {
    private static final String FILE = "devbertini_sleep";
    private static final String AT = "at";

    private SleepTimer() {}

    /** Sets the timer [minutes] from now, or clears it with 0; returns the standby time in epoch ms, or 0. */
    static long set(Context context, int minutes) {
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        PendingIntent intent = PendingIntent.getBroadcast(context, 0, new Intent(context, SleepReceiver.class),
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        alarms.cancel(intent);
        if (minutes <= 0) {
            prefs(context).edit().remove(AT).apply();
            return 0;
        }
        long at = System.currentTimeMillis() + minutes * 60_000L;
        if (alarms.canScheduleExactAlarms()) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent);
        } else {
            alarms.setWindow(AlarmManager.RTC_WAKEUP, at, 60_000L, intent);
        }
        prefs(context).edit().putLong(AT, at).apply();
        return at;
    }

    /** The standby time in epoch ms while a timer runs, or 0. */
    static long at(Context context) {
        long at = prefs(context).getLong(AT, 0);
        return at > System.currentTimeMillis() - 120_000L ? at : 0;
    }

    static void clear(Context context) {
        prefs(context).edit().remove(AT).apply();
    }

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(FILE, Context.MODE_PRIVATE);
    }
}
