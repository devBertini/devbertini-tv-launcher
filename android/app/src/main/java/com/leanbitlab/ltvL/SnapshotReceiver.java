package com.leanbitlab.ltvL;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * deploy.ps1 asks for a fresh snapshot before it installs (`am broadcast -n com.leanbitlab.ltvL/.SnapshotReceiver`).
 * The manifest guards it with the DUMP permission, which adb's shell holds and other apps do not.
 * The result code is the number of files copied, or -1.
 */
public class SnapshotReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        setResultCode(DataSnapshot.save(context));
    }
}
