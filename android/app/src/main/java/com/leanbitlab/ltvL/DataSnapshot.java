package com.leanbitlab.ltvL;

import android.content.Context;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * A byte copy of everything the launcher keeps (every profile's database, the settings, the profiles file),
 * so tools/devbertini/deploy.ps1 can pull it to the PC before each install and push it back after a loss.
 * The snapshot lives in the app's external files folder, which adb can read; the art cache is left out
 * (the launcher fetches it again). An uninstall erases that folder too: the PC copy is the backup.
 */
final class DataSnapshot {
    private static final String TAG = "DevBertiniSnapshot";
    // app_flutter holds the databases, files the profiles file, shared_prefs the settings.
    private static final String[] PARTS = {"app_flutter", "files", "shared_prefs"};
    private static final String SKIPPED = "art";

    private DataSnapshot() {}

    /** Writes the snapshot; returns the number of files copied, or -1 when it failed. */
    static synchronized int save(Context context) {
        File external = context.getExternalFilesDir(null);
        if (external == null) return -1;
        File target = new File(external, "snapshot");
        try {
            deleteTree(target);
            int count = 0;
            for (String part : PARTS) {
                count += copyTree(new File(context.getDataDir(), part), new File(target, part), true);
            }
            write(new File(target, "snapshot.txt"), "files=" + count + "\ntime=" + System.currentTimeMillis() + "\n");
            Log.i(TAG, "snapshot saved: " + count + " files");
            return count;
        } catch (IOException e) {
            Log.e(TAG, "snapshot failed", e);
            return -1;
        }
    }

    /**
     * Before the launcher opens its databases: when deploy.ps1 pushed a snapshot as restore.zip into the
     * external files folder (adb's shell may create files there but not folders), the launcher's data is
     * replaced by it, once, and the zip is deleted.
     */
    static synchronized void restoreIfRequested(Context context) {
        File external = context.getExternalFilesDir(null);
        if (external == null) return;
        File zip = new File(external, "restore.zip");
        if (!zip.isFile()) return;
        File unpacked = new File(context.getCacheDir(), "restore");
        try {
            deleteTree(unpacked);
            unzip(zip, unpacked);
            if (!new File(unpacked, "snapshot.txt").isFile()) throw new IOException("restore.zip holds no snapshot.txt");
            int count = 0;
            for (String part : PARTS) {
                File from = new File(unpacked, part);
                if (!from.isDirectory()) continue;
                File to = new File(context.getDataDir(), part);
                deleteKept(to);
                count += copyTree(from, to, false);
            }
            Log.i(TAG, "snapshot restored: " + count + " files");
        } catch (IOException e) {
            Log.e(TAG, "restore failed", e);
        } finally {
            if (!zip.delete()) Log.e(TAG, "restore.zip could not be deleted");
            try {
                deleteTree(unpacked);
            } catch (IOException ignored) {
            }
        }
    }

    /** Unpacks [zip] into [to]; Windows' zip tools write backslashes, read here as folders. */
    private static void unzip(File zip, File to) throws IOException {
        String root = to.getCanonicalPath() + File.separator;
        try (java.util.zip.ZipInputStream in = new java.util.zip.ZipInputStream(new FileInputStream(zip))) {
            java.util.zip.ZipEntry entry;
            byte[] buffer = new byte[64 * 1024];
            while ((entry = in.getNextEntry()) != null) {
                String name = entry.getName().replace('\\', '/');
                File target = new File(to, name);
                if (!target.getCanonicalPath().startsWith(root)) throw new IOException("entry outside the folder: " + name);
                if (entry.isDirectory() || name.endsWith("/")) {
                    if (!target.isDirectory() && !target.mkdirs()) throw new IOException("mkdirs " + target);
                    continue;
                }
                File parent = target.getParentFile();
                if (parent != null && !parent.isDirectory() && !parent.mkdirs()) throw new IOException("mkdirs " + parent);
                try (OutputStream out = new FileOutputStream(target)) {
                    int read;
                    while ((read = in.read(buffer)) > 0) out.write(buffer, 0, read);
                }
            }
        }
    }

    /** Clears what a snapshot holds in [dir], keeping the art cache. */
    private static void deleteKept(File dir) throws IOException {
        File[] children = dir.listFiles();
        if (children == null) return;
        for (File child : children) {
            if (child.getName().equals(SKIPPED) && child.isDirectory()) continue;
            deleteTree(child);
        }
    }

    private static int copyTree(File from, File to, boolean skipArt) throws IOException {
        if (!from.exists()) return 0;
        if (from.isFile()) {
            File parent = to.getParentFile();
            if (parent != null && !parent.isDirectory() && !parent.mkdirs()) throw new IOException("mkdirs " + parent);
            try (InputStream in = new FileInputStream(from); OutputStream out = new FileOutputStream(to)) {
                byte[] buffer = new byte[64 * 1024];
                int read;
                while ((read = in.read(buffer)) > 0) out.write(buffer, 0, read);
            }
            return 1;
        }
        int count = 0;
        File[] children = from.listFiles();
        if (children == null) return 0;
        if (!to.isDirectory() && !to.mkdirs()) throw new IOException("mkdirs " + to);
        for (File child : children) {
            if (skipArt && child.isDirectory() && child.getName().equals(SKIPPED)) continue;
            count += copyTree(child, new File(to, child.getName()), skipArt);
        }
        return count;
    }

    private static void deleteTree(File file) throws IOException {
        if (!file.exists()) return;
        File[] children = file.listFiles();
        if (children != null) {
            for (File child : children) deleteTree(child);
        }
        if (!file.delete()) throw new IOException("delete " + file);
    }

    private static void write(File file, String text) throws IOException {
        try (OutputStream out = new FileOutputStream(file)) {
            out.write(text.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        }
    }
}
