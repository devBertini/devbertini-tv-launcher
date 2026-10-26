package com.leanbitlab.ltvL;

import android.app.AppOpsManager;
import android.app.NotificationManager;
import android.app.role.RoleManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Process;
import android.provider.Settings;

import java.util.ArrayList;
import java.util.List;

/**
 * What a TV update may have undone of the TV's setup (the checks deploy.ps1 -Setup applies), named for the home's notice;
 * deploy.ps1 -Setup puts it all back. The TCL-only items are checked only where com.tcl.tv exists.
 */
final class TvSetupCheck {
    private TvSetupCheck() {}

    /**
     * Turns the console watcher back on when the TCL turned it off, if adb granted WRITE_SECURE_SETTINGS;
     * returns whether it is on afterwards.
     */
    static boolean restoreWatcher(Context context) {
        if (!installed(context.getPackageManager(), "com.tcl.tv")) return true;
        String service = context.getPackageName() + "/" + LauncherAccessibilityService.class.getName();
        String services = Settings.Secure.getString(context.getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        if (services != null && services.contains(service)) return true;
        if (context.checkSelfPermission("android.permission.WRITE_SECURE_SETTINGS") != PackageManager.PERMISSION_GRANTED) return false;
        try {
            String next = services == null || services.isEmpty() ? service : services + ":" + service;
            Settings.Secure.putString(context.getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, next);
            Settings.Secure.putInt(context.getContentResolver(), Settings.Secure.ACCESSIBILITY_ENABLED, 1);
            return true;
        } catch (SecurityException e) {
            return false;
        }
    }

    static List<String> problems(Context context) {
        restoreWatcher(context);
        List<String> found = new ArrayList<>();
        PackageManager pm = context.getPackageManager();
        String pkg = context.getPackageName();
        RoleManager roles = context.getSystemService(RoleManager.class);
        if (roles != null && !roles.isRoleHeld(RoleManager.ROLE_HOME)) found.add("tela inicial padrão");
        if (enabled(pm, "com.google.android.apps.tv.launcherx")) found.add("Google TV ligado de novo");
        NotificationManager notifications = context.getSystemService(NotificationManager.class);
        if (notifications != null && !notifications.isNotificationListenerAccessGranted(
                new ComponentName(context, LauncherNotificationListenerService.class))) found.add("acesso às notificações");
        if (!Settings.canDrawOverlays(context)) found.add("avisos por cima dos apps");
        AppOpsManager ops = context.getSystemService(AppOpsManager.class);
        if (ops != null && ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), pkg)
                != AppOpsManager.MODE_ALLOWED) found.add("uso dos apps");
        if (context.checkSelfPermission("android.permission.READ_TV_LISTINGS") != PackageManager.PERMISSION_GRANTED) {
            found.add("programação da TV");
        }
        // Developer option "Don't keep activities": on, every app (the home included) comes back rebuilt.
        if (Settings.Global.getInt(context.getContentResolver(), Settings.Global.ALWAYS_FINISH_ACTIVITIES, 0) != 0) {
            found.add("manter as telas dos apps");
        }
        if (installed(pm, "com.tcl.tv")) {
            if (context.getResources().getDisplayMetrics().densityDpi != 320) found.add("densidade da tela");
            String services = Settings.Secure.getString(context.getContentResolver(),
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
            if (services == null || !services.contains(pkg + "/" + LauncherAccessibilityService.class.getName())) {
                found.add("leitura do console");
            }
        }
        return found;
    }

    private static boolean installed(PackageManager pm, String name) {
        try {
            pm.getApplicationInfo(name, 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    private static boolean enabled(PackageManager pm, String name) {
        try {
            int state = pm.getApplicationEnabledSetting(name);
            return state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT || state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }
}
