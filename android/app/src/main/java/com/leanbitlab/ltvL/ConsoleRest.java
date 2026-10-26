package com.leanbitlab.ltvL;

import android.content.Context;
import android.content.SharedPreferences;
import android.media.tv.TvInputInfo;
import android.media.tv.TvInputManager;

import java.util.HashSet;
import java.util.Set;

/**
 * Which consoles are resting. The TCL reports a console in rest mode as on (its input state and its
 * HDMI-CEC power status stay "on"), so the launcher learns it from the TV's own screen instead: the
 * accessibility service sees "no signal" on the console's input (LauncherAccessibilityService).
 */
final class ConsoleRest {
    private static final String FILE = "devbertini_console";
    private static final String RESTING = "resting";

    private ConsoleRest() {}

    /** Whether [label] names a device found over HDMI-CEC (a console), as getTvInputs lists them. */
    static boolean isConsole(Context context, String label) {
        TvInputManager manager = (TvInputManager) context.getSystemService(Context.TV_INPUT_SERVICE);
        if (manager == null || label == null) return false;
        for (TvInputInfo input : manager.getTvInputList()) {
            if (input.isPassthroughInput() && input.getParentId() != null) {
                CharSequence name = input.loadLabel(context);
                if (name != null && label.contentEquals(name)) return true;
            }
        }
        return false;
    }

    static boolean isResting(Context context, String label) {
        return prefs(context).getStringSet(RESTING, new HashSet<>()).contains(label);
    }

    static void setResting(Context context, String label, boolean resting) {
        Set<String> now = new HashSet<>(prefs(context).getStringSet(RESTING, new HashSet<>()));
        boolean changed = resting ? now.add(label) : now.remove(label);
        if (changed) prefs(context).edit().putStringSet(RESTING, now).apply();
    }

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(FILE, Context.MODE_PRIVATE);
    }
}
