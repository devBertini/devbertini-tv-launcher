package com.leanbitlab.ltvL;

import android.app.Notification;
import android.content.pm.PackageManager;
import android.graphics.PixelFormat;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.WindowManager;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import java.util.ArrayList;
import java.util.List;

public class LauncherNotificationListenerService extends NotificationListenerService {
    public interface NotificationListener {
        void onNotificationChanged();
    }

    private static final List<NotificationListener> listeners = new ArrayList<>();
    private static LauncherNotificationListenerService instance = null;
    /** Notifications already shown as a popup, so updates of the same one stay quiet. */
    private static final java.util.Set<String> shownKeys = new java.util.HashSet<>();

    public static void registerListener(NotificationListener listener) {
        synchronized (listeners) {
            listeners.add(listener);
        }
    }

    public static void unregisterListener(NotificationListener listener) {
        synchronized (listeners) {
            listeners.remove(listener);
        }
    }

    public static LauncherNotificationListenerService getInstance() {
        return instance;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        TvSetupCheck.restoreWatcher(this);
        notifyListeners();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (instance == this) {
            instance = null;
        }
        notifyListeners();
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        // Runs often and outside the home too: the console watcher comes back soon after the TCL drops it.
        TvSetupCheck.restoreWatcher(this);
        notifyListeners();
        showNotificationPopup(sbn);
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        notifyListeners();
    }

    private void notifyListeners() {
        synchronized (listeners) {
            for (NotificationListener listener : listeners) {
                listener.onNotificationChanged();
            }
        }
    }

    private boolean canShowPopup() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return android.provider.Settings.canDrawOverlays(this);
        }
        return true;
    }

    private int dpToPx(int dp) {
        return (int) (dp * getResources().getDisplayMetrics().density);
    }

    private void showNotificationPopup(StatusBarNotification sbn) {
        if (sbn == null || sbn.isOngoing()) {
            return;
        }

        android.content.SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        boolean enabled = prefs.getBoolean("flutter.system_notifications_popup", true);
        if (!enabled) {
            return;
        }

        // Silent notifications (low importance) never interrupt what is on screen.
        try {
            Ranking ranking = new Ranking();
            if (getCurrentRanking().getRanking(sbn.getKey(), ranking)
                    && ranking.getImportance() < android.app.NotificationManager.IMPORTANCE_DEFAULT) {
                return;
            }
        } catch (Exception ignored) {
        }

        if (!canShowPopup()) {
            return;
        }

        android.app.Notification notification = sbn.getNotification();
        if (notification == null) return;

        // Filter out service and media transport notifications
        String category = notification.category;
        if (android.app.Notification.CATEGORY_SERVICE.equals(category) ||
            android.app.Notification.CATEGORY_TRANSPORT.equals(category)) {
            return;
        }

        Bundle extras = notification.extras;
        if (extras == null) return;

        // Filter out media sessions (playback)
        if (extras.containsKey(android.app.Notification.EXTRA_MEDIA_SESSION)) {
            return;
        }

        CharSequence titleChar = extras.getCharSequence(Notification.EXTRA_TITLE);
        CharSequence textChar = extras.getCharSequence(Notification.EXTRA_TEXT);

        final String title = titleChar != null ? titleChar.toString().trim() : "";
        final String text = textChar != null ? textChar.toString().trim() : "";

        if (title.isEmpty() && text.isEmpty()) {
            return;
        }

        final String packageName = sbn.getPackageName();
        final PackageManager pm = getPackageManager();
        String appLabel = packageName;
        Drawable appIcon = null;
        try {
            android.content.pm.ApplicationInfo appInfo = pm.getApplicationInfo(packageName, 0);
            appLabel = pm.getApplicationLabel(appInfo).toString().trim();
            appIcon = pm.getApplicationIcon(appInfo);
        } catch (Exception e) {
            e.printStackTrace();
        }

        // Filter out generic app running notifications where title/text are just the app label
        if (title.equalsIgnoreCase(appLabel) && (text.isEmpty() || text.equalsIgnoreCase(appLabel))) {
            return;
        }
        if (title.equalsIgnoreCase(packageName) && (text.isEmpty() || text.equalsIgnoreCase(packageName))) {
            return;
        }

        final String finalAppLabel = appLabel;
        final Drawable finalAppIcon = appIcon;
        // The same notification updated (a download's progress) shows once.
        final String showKey = sbn.getKey() + "|" + title + "|" + text;
        synchronized (shownKeys) {
            if (!shownKeys.add(showKey)) return;
            if (shownKeys.size() > 200) shownKeys.clear();
        }

        final WindowManager windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        if (windowManager == null) return;

        // DevBertini: a black pill that drops from the top centre for four seconds and goes back up,
        // like the music island of the home: the app's icon, its name and the title, then the text.
        new Handler(Looper.getMainLooper()).post(() -> {
            try {
                android.widget.LinearLayout pill = new android.widget.LinearLayout(this);
                pill.setOrientation(android.widget.LinearLayout.HORIZONTAL);
                pill.setGravity(Gravity.CENTER_VERTICAL);
                pill.setPadding(dpToPx(10), dpToPx(8), dpToPx(22), dpToPx(8));
                android.graphics.drawable.GradientDrawable background = new android.graphics.drawable.GradientDrawable();
                background.setColor(android.graphics.Color.BLACK);
                background.setCornerRadius(dpToPx(30));
                background.setStroke(dpToPx(1), android.graphics.Color.parseColor("#2EFFFFFF"));
                pill.setBackground(background);

                android.widget.ImageView iconView = new android.widget.ImageView(this);
                if (finalAppIcon != null) iconView.setImageDrawable(finalAppIcon);
                iconView.setClipToOutline(true);
                android.graphics.drawable.GradientDrawable round = new android.graphics.drawable.GradientDrawable();
                round.setShape(android.graphics.drawable.GradientDrawable.OVAL);
                iconView.setBackground(round);
                android.widget.LinearLayout.LayoutParams iconParams = new android.widget.LinearLayout.LayoutParams(dpToPx(30), dpToPx(30));
                iconParams.rightMargin = dpToPx(12);
                pill.addView(iconView, iconParams);

                android.widget.LinearLayout texts = new android.widget.LinearLayout(this);
                texts.setOrientation(android.widget.LinearLayout.VERTICAL);
                android.widget.TextView titleView = new android.widget.TextView(this);
                android.text.SpannableStringBuilder header = new android.text.SpannableStringBuilder(finalAppLabel);
                header.setSpan(new android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 0, header.length(), 0);
                if (!title.isEmpty() && !title.equalsIgnoreCase(finalAppLabel)) header.append("  ").append(title);
                titleView.setText(header);
                titleView.setTextColor(android.graphics.Color.parseColor("#F5F0E8"));
                titleView.setTextSize(13);
                titleView.setSingleLine(true);
                titleView.setEllipsize(android.text.TextUtils.TruncateAt.END);
                titleView.setMaxWidth(dpToPx(460));
                texts.addView(titleView);
                if (!text.isEmpty()) {
                    android.widget.TextView bodyView = new android.widget.TextView(this);
                    bodyView.setText(text);
                    bodyView.setTextColor(android.graphics.Color.parseColor("#99FFFFFF"));
                    bodyView.setTextSize(12);
                    bodyView.setSingleLine(true);
                    bodyView.setEllipsize(android.text.TextUtils.TruncateAt.END);
                    bodyView.setMaxWidth(dpToPx(460));
                    texts.addView(bodyView);
                }
                pill.addView(texts);

                int layoutFlag = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                        ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        : WindowManager.LayoutParams.TYPE_PHONE;
                WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                        WindowManager.LayoutParams.WRAP_CONTENT,
                        WindowManager.LayoutParams.WRAP_CONTENT,
                        layoutFlag,
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                        PixelFormat.TRANSLUCENT);
                params.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
                params.y = dpToPx(20);

                pill.setAlpha(0f);
                pill.setTranslationY(-dpToPx(28));
                windowManager.addView(pill, params);
                pill.animate().alpha(1f).translationY(0f).setDuration(340)
                        .setInterpolator(new android.view.animation.DecelerateInterpolator()).start();
                new Handler(Looper.getMainLooper()).postDelayed(() -> pill.animate().alpha(0f).translationY(-dpToPx(28))
                        .setDuration(260).setInterpolator(new android.view.animation.AccelerateInterpolator())
                        .withEndAction(() -> {
                            try {
                                windowManager.removeView(pill);
                            } catch (Exception ignored) {
                            }
                        }).start(), 4000);
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }
}
