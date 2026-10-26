package com.leanbitlab.ltvL;

import android.content.Context;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;

/**
 * The home's one Flutter engine, kept for the life of the process: when Android destroys the home's screen while an
 * app is open (the TCL's developer option "Don't keep activities" did it every time), the screen it creates again
 * attaches this same engine, so the home comes back as it was instead of starting over
 * (docs/devbertini/PERFORMANCE.md). MainActivity runs its Dart entrypoint the first time it starts it.
 */
final class HomeEngine {
    static final String ID = "home";

    private HomeEngine() {}

    /** The cached engine, made on first use with the application's context (never an activity's). */
    @NonNull
    static FlutterEngine obtain(@NonNull Context context) {
        FlutterEngineCache cache = FlutterEngineCache.getInstance();
        FlutterEngine engine = cache.get(ID);
        if (engine == null) {
            engine = new FlutterEngine(context.getApplicationContext());
            cache.put(ID, engine);
        }
        return engine;
    }
}
