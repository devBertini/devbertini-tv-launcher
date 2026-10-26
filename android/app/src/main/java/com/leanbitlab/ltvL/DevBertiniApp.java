package com.leanbitlab.ltvL;

import android.app.Application;

/** Restores a pushed snapshot before any part of the launcher (activity, services) reads its data. */
public class DevBertiniApp extends Application {
    @Override
    public void onCreate() {
        DataSnapshot.restoreIfRequested(this);
        super.onCreate();
    }
}
