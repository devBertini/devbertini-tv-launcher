package com.leanbitlab.ltvL;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.util.List;

/**
 * Watches only the TCL's input screen (com.tcl.tv; no key passes through here): when a console's input has
 * shown "no signal" for a few seconds, the console went to rest, so its card's light goes out and the TV
 * comes back to the home instead of staying on the black input.
 */
public class LauncherAccessibilityService extends AccessibilityService {
    private static final String TAG = "DevBertiniConsole";
    private static final String TV = "com.tcl.tv";
    private static final String TIP = TV + ":id/rl_tip";
    private static final String INPUT_NAME = TV + ":id/tvInputName";
    private static final long REST_AFTER_MS = 4000;

    /** The connected service, for the sleep timer's standby request; null while it is off. */
    static volatile LauncherAccessibilityService instance;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable check = this::check;
    private long tipSince = 0;
    private String tipLabel = null;

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        CharSequence source = event.getPackageName();
        if (source == null || !TV.contentEquals(source)) return;
        handler.removeCallbacks(check);
        handler.postDelayed(check, 600);
    }

    @Override
    protected void onServiceConnected() {
        instance = this;
    }

    @Override
    public void onDestroy() {
        instance = null;
        super.onDestroy();
    }

    @Override
    public void onInterrupt() {
        handler.removeCallbacks(check);
    }

    private void check() {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null || root.getPackageName() == null || !TV.contentEquals(root.getPackageName())) {
            tipSince = 0;
            return;
        }
        String label = text(root, INPUT_NAME);
        if (label == null || !ConsoleRest.isConsole(this, label)) {
            tipSince = 0;
            return;
        }
        if (!visible(root, TIP)) {
            ConsoleRest.setResting(this, label, false);
            tipSince = 0;
            return;
        }
        long now = SystemClock.elapsedRealtime();
        if (tipSince == 0 || !label.equals(tipLabel)) {
            tipSince = now;
            tipLabel = label;
            handler.postDelayed(check, REST_AFTER_MS + 200);
            return;
        }
        if (now - tipSince < REST_AFTER_MS) {
            handler.postDelayed(check, REST_AFTER_MS - (now - tipSince) + 200);
            return;
        }
        tipSince = 0;
        ConsoleRest.setResting(this, label, true);
        Log.i(TAG, label + " shows no signal: resting, back to the home");
        Intent home = new Intent(this, MainActivity.class);
        home.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        startActivity(home);
    }

    private static String text(AccessibilityNodeInfo root, String id) {
        List<AccessibilityNodeInfo> nodes = root.findAccessibilityNodeInfosByViewId(id);
        for (AccessibilityNodeInfo node : nodes) {
            if (node.getText() != null && node.isVisibleToUser()) return node.getText().toString();
        }
        return null;
    }

    private static boolean visible(AccessibilityNodeInfo root, String id) {
        for (AccessibilityNodeInfo node : root.findAccessibilityNodeInfosByViewId(id)) {
            if (node.isVisibleToUser()) return true;
        }
        return false;
    }
}
