package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.BooleanSupplier;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class FlutterSecureStoragePlugin implements MethodCallHandler, FlutterPlugin {

    private static final String TAG = "FlutterSecureStoragePlugin";
    private MethodChannel channel;
    private Context applicationContext;
    private final Map<String, FlutterSecureStorage> storagesBySharedPreferencesName = new HashMap<>();
    private static final HandlerThread workerThread;
    private static final CompletionSerialQueue operations;
    static {
        workerThread = new HandlerThread("com.it_nomads.fluttersecurestorage.shared");
        workerThread.start();
        final Handler handler = new Handler(workerThread.getLooper());
        operations = new CompletionSerialQueue(command -> handler.post(command));
    }
    private volatile boolean attached;
    private volatile BooleanSupplier ownerCurrentGuard = () -> true;

    /** Bind a background engine to its existing task-revision/visibility guard. */
    public void setOwnerCurrentGuard(BooleanSupplier guard) {
        if (guard == null) throw new IllegalArgumentException("guard is required");
        ownerCurrentGuard = guard;
    }

    private boolean ownerCurrent() {
        if (!attached) return false;
        try { return ownerCurrentGuard.getAsBoolean(); }
        catch (RuntimeException ignored) { return false; }
    }

    public void initInstance(BinaryMessenger messenger, Context context) {
        try {
            applicationContext = context.getApplicationContext();

            attached = true;

            channel = new MethodChannel(messenger, "plugins.it_nomads.com/flutter_secure_storage");
            channel.setMethodCallHandler(this);
        } catch (Exception e) {
            Log.e(TAG, "Registration failed", e);
        }
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        initInstance(binding.getBinaryMessenger(), binding.getApplicationContext());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        attached = false;
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        // An active initialize/encrypt operation retains its context and cache.
        // Never stop the shared worker or release its FIFO slot on detach.
        // This instance is collectible after its queued/active callbacks finish.
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result rawResult) {
        operations.submit(completed -> {
            MethodResultWrapper result = new MethodResultWrapper(rawResult, completed);
            new MethodRunner(call, result).run();
        });
    }

    @SuppressWarnings("unchecked")
    private static String getKeyFromCall(FlutterSecureStorage storage, MethodCall call) {
        Map<String, Object> arguments = (Map<String, Object>) call.arguments;
        String key = (String) arguments.get("key");
        return storage.addPrefixToKey(key);
    }

    @SuppressWarnings("unchecked")
    private static String getValueFromCall(MethodCall call) {
        Map<String, Object> arguments = (Map<String, Object>) call.arguments;
        return (String) arguments.get("value");
    }

    private FlutterSecureStorage getOrCreateStorage(FlutterSecureStorageConfig config) {
        // Use "ns:" prefix for storageNamespace to avoid collisions with legacy
        // sharedPreferencesName keys in the map. The key prefix is included so two
        // configs sharing a namespace/name but using different key prefixes don't
        // reuse (and go stale on) the same FlutterSecureStorage instance.
        final String namespace = config.hasStorageNamespace()
                ? "ns:" + config.getStorageNamespace()
                : config.getSharedPreferencesName();
        final String name = namespace + "|" + config.getSharedPreferencesKeyPrefix();
        synchronized (storagesBySharedPreferencesName) {
            FlutterSecureStorage existing = storagesBySharedPreferencesName.get(name);
            if (existing != null) {
                return existing;
            }
            FlutterSecureStorage created = new FlutterSecureStorage(applicationContext);
            storagesBySharedPreferencesName.put(name, created);
            return created;
        }
    }

    /**
     * MethodChannel.Result wrapper that responds on the platform thread.
     */
    static class MethodResultWrapper implements Result {

        private final Result methodResult;
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final Runnable completed;
        private final AtomicBoolean terminal = new AtomicBoolean();

        MethodResultWrapper(Result methodResult, Runnable completed) {
            this.methodResult = methodResult;
            this.completed = completed;
        }

        private void finish(Runnable response) {
            if (!terminal.compareAndSet(false, true)) return;
            try {
                handler.post(() -> {
                    try { response.run(); }
                    catch (RuntimeException ignored) {
                        // The owning engine may have detached while storage ran.
                    }
                });
            } finally { completed.run(); }
        }

        @Override
        public void success(final Object result) {
            finish(() -> methodResult.success(result));
        }

        @Override
        public void error(@NonNull final String errorCode, final String errorMessage, final Object errorDetails) {
            finish(() -> methodResult.error(errorCode, errorMessage, errorDetails));
        }

        @Override
        public void notImplemented() {
            finish(methodResult::notImplemented);
        }
    }

    /**
     * Wraps the functionality of onMethodCall() in a Runnable for execution in the worker thread.
     */
    class MethodRunner implements Runnable {
        private final MethodCall call;
        private final Result result;

        MethodRunner(MethodCall call, Result result) {
            this.call = call;
            this.result = result;
        }

        @SuppressWarnings("unchecked")
        @Override
        public void run() {
            // Guard MethodChannel payload before initialize(); funnel unexpected exceptions to result.error.
            try {
                if (!ownerCurrent()) {
                    result.error("owner_expired", "Storage owner is no longer active", null);
                    return;
                }
                if (call == null || call.arguments == null) {
                    handleException(new IllegalArgumentException("Method call arguments are null"));
                    return;
                }
                if (!(call.arguments instanceof Map)) {
                    handleException(new IllegalArgumentException("Method call arguments must be a Map"));
                    return;
                }
                Map<String, Object> args = (Map<String, Object>) call.arguments;
                Object rawOptions = args.get("options");
                Map<String, Object> options;
                if (rawOptions instanceof Map) {
                    options = (Map<String, Object>) rawOptions;
                } else {
                    options = new HashMap<>();
                }
                FlutterSecureStorageConfig config = new FlutterSecureStorageConfig(options);

                if ("checkUpgradeStatus".equals(call.method)) {
                    // Runs before initialize(), which is what would migrate or wipe.
                    result.success(UpgradeInspector.inspect(applicationContext, config));
                    return;
                }

                FlutterSecureStorage secureStorage = getOrCreateStorage(config);

                secureStorage.initialize(config, new SecurePreferencesCallback<>() {
                @Override
                public void onSuccess(Void unused) {
                    try {
                        if (!ownerCurrent()) {
                            result.error("owner_expired", "Storage owner is no longer active", null);
                            return;
                        }
                        switch (call.method) {
                            case "write": {
                                String key = getKeyFromCall(secureStorage, call);
                                String value = getValueFromCall(call);

                                if (value != null) {
                                    secureStorage.write(key, value, new SecurePreferencesCallback<>() {
                                        @Override
                                        public void onSuccess(Void unused) {
                                            result.success(null);
                                        }

                                        @Override
                                        public void onError(Exception e) {
                                            handleException(e);
                                        }
                                    });
                                } else {
                                    result.error("null", null, null);
                                }
                                break;
                            }
                            case "read": {
                                String key = getKeyFromCall(secureStorage, call);

                                if (secureStorage.containsKey(key)) {
                                    secureStorage.read(key, new SecurePreferencesCallback<>() {
                                        @Override
                                        public void onSuccess(String value) {
                                            result.success(value);
                                        }

                                        @Override
                                        public void onError(Exception e) {
                                            handleException(e);
                                        }
                                    });
                                } else {
                                    result.success(null);
                                }
                                break;
                            }
                            case "readAll": {
                                secureStorage.readAll(new SecurePreferencesCallback<>() {
                                    @Override
                                    public void onSuccess(Map<String, String> value) {
                                        result.success(value);
                                    }

                                    @Override
                                    public void onError(Exception e) {
                                        handleException(e);
                                    }
                                });
                                break;
                            }
                            case "containsKey": {
                                String key = getKeyFromCall(secureStorage, call);

                                boolean containsKey = secureStorage.containsKey(key);
                                result.success(containsKey);
                                break;
                            }
                            case "delete": {
                                String key = getKeyFromCall(secureStorage, call);

                                secureStorage.delete(key);
                                result.success(null);
                                break;
                            }
                            case "deleteAll": {
                                secureStorage.deleteAll();
                                result.success(null);
                                break;
                            }
                            case "isBiometricAvailable": {
                                boolean available = secureStorage.isBiometricAvailable();
                                result.success(available);
                                break;
                            }
                            case "isDeviceSecure": {
                                boolean secure = secureStorage.isDeviceSecure();
                                result.success(secure);
                                break;
                            }
                            default:
                                result.notImplemented();
                                break;
                        }
                    } catch (Throwable e) {
                        if (e instanceof VirtualMachineError) {
                            throw (VirtualMachineError) e;
                        }
                        if (config.shouldDeleteOnFailure()) {
                            try {
                                secureStorage.deleteAll();
                                result.success("Data has been reset");
                            } catch (Throwable ex) {
                                handleException(ex);
                            }
                        } else {
                            handleException(e);
                        }
                    }
                }

                @Override
                public void onError(Exception e) {
                    handleException(e);
                }
            });
            } catch (Throwable e) {
                // Catch Throwable, not just Exception: some OEM builds throw
                // java.lang.Error subclasses (e.g. NoSuchFieldError) from Android
                // Keystore framework code, and an uncaught Error on this
                // HandlerThread would crash the entire app process. Genuine VM
                // errors (OOM, StackOverflow) are rethrown instead of being
                // funneled through handleException/deleteAll, which would
                // allocate memory the JVM may no longer have.
                if (e instanceof VirtualMachineError) {
                    throw (VirtualMachineError) e;
                }
                handleException(e);
            }
        }


        private void handleException(Throwable e) {
            StringWriter stringWriter = new StringWriter();
            e.printStackTrace(new PrintWriter(stringWriter));
            // Send exception message as the message field so Flutter can parse it
            String errorMessage = e.getMessage() != null ? e.getMessage() : "Unknown error";
            result.error("Exception encountered", errorMessage, stringWriter.toString());
        }
    }
}
