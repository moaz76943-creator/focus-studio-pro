package com.moaz.focusstudiopro;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.speech.tts.TextToSpeech;
import android.speech.tts.Voice;
import android.view.Display;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL_SYSTEM = "com.moaz.focusstudiopro/system_insets";
    private static final String CHANNEL_TTS = "com.moaz.focusstudiopro/native_tts";

    private TextToSpeech tts;
    private boolean ttsReady = false;
    private String activeEnginePackage = null;
    private Insets lastSystemBarInsets = Insets.NONE;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        configureEdgeToEdgeSystemBars();
        enableHighRefreshRate120Hz();
        initDefaultTts(null);
    }

    private void configureEdgeToEdgeSystemBars() {
        Window window = getWindow();
        if (window == null) return;
        WindowCompat.setDecorFitsSystemWindows(window, false);
        View contentView = window.getDecorView().findViewById(android.R.id.content);
        if (contentView == null) return;

        ViewCompat.setOnApplyWindowInsetsListener(contentView, (v, windowInsets) -> {
            Insets sysBars = windowInsets.getInsets(
                    WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout()
            );
            Insets ime = windowInsets.getInsets(WindowInsetsCompat.Type.ime());
            lastSystemBarInsets = sysBars;
            int bottomPad = Math.max(sysBars.bottom, ime.bottom);
            v.setPadding(sysBars.left, sysBars.top, sysBars.right, bottomPad);
            return WindowInsetsCompat.CONSUMED;
        });
        ViewCompat.requestApplyInsets(contentView);
    }

    private void enableHighRefreshRate120Hz() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Window window = getWindow();
            if (window == null) return;
            Display display = getDisplayCompat();
            if (display == null) return;
            Display.Mode[] modes = display.getSupportedModes();
            Display.Mode bestMode = null;
            float maxRate = 60f;
            for (Display.Mode m : modes) {
                if (m.getRefreshRate() > maxRate) {
                    maxRate = m.getRefreshRate();
                    bestMode = m;
                }
            }
            if (bestMode != null) {
                WindowManager.LayoutParams params = window.getAttributes();
                params.preferredDisplayModeId = bestMode.getModeId();
                window.setAttributes(params);
            }
        }
    }

    private Display getDisplayCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return getDisplay();
        }
        WindowManager wm = (WindowManager) getSystemService(WINDOW_SERVICE);
        return wm != null ? wm.getDefaultDisplay() : null;
    }

    private synchronized void initDefaultTts(final String enginePkg) {
        if (tts != null) {
            tts.stop();
            tts.shutdown();
            tts = null;
            ttsReady = false;
        }
        TextToSpeech.OnInitListener listener = status -> {
            ttsReady = (status == TextToSpeech.SUCCESS);
        };
        if (enginePkg != null && !enginePkg.trim().isEmpty()) {
            activeEnginePackage = enginePkg.trim();
            tts = new TextToSpeech(getApplicationContext(), listener, activeEnginePackage);
        } else {
            activeEnginePackage = null;
            tts = new TextToSpeech(getApplicationContext(), listener);
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_SYSTEM)
                .setMethodCallHandler((call, result) -> {
                    if ("getSystemBarInsets".equals(call.method)) {
                        float density = getResources().getDisplayMetrics().density;
                        Map<String, Double> map = new HashMap<>();
                        map.put("top", (double) (lastSystemBarInsets.top / density));
                        map.put("bottom", (double) (lastSystemBarInsets.bottom / density));
                        map.put("left", (double) (lastSystemBarInsets.left / density));
                        map.put("right", (double) (lastSystemBarInsets.right / density));
                        result.success(map);
                    } else {
                        result.notImplemented();
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_TTS)
                .setMethodCallHandler(this::handleTtsCall);
    }

    private void handleTtsCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "discoverEngines": {
                List<Map<String, String>> engines = new ArrayList<>();
                if (tts != null) {
                    for (TextToSpeech.EngineInfo info : tts.getEngines()) {
                        Map<String, String> item = new HashMap<>();
                        item.put("name", info.name != null ? info.name : "");
                        item.put("label", info.label != null ? info.label : "");
                        engines.add(item);
                    }
                }
                result.success(engines);
                break;
            }
            case "selectEngine": {
                String pkg = call.argument("enginePackage");
                initDefaultTts(pkg);
                result.success(true);
                break;
            }
            case "discoverVoices": {
                List<Map<String, Object>> voicesOut = new ArrayList<>();
                if (tts != null && ttsReady && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    Set<Voice> voices = tts.getVoices();
                    if (voices != null) {
                        for (Voice v : voices) {
                            Locale loc = v.getLocale();
                            if (loc == null) continue;
                            Map<String, Object> vm = new HashMap<>();
                            vm.put("name", v.getName());
                            vm.put("locale", loc.toLanguageTag());
                            vm.put("languageCode", loc.getLanguage());
                            vm.put("countryCode", loc.getCountry());
                            vm.put("quality", v.getQuality());
                            vm.put("latency", v.getLatency());
                            vm.put("networkRequired", v.isNetworkConnectionRequired());
                            String lower = v.getName().toLowerCase(Locale.ROOT);
                            String gender = "neutral";
                            if (lower.contains("female") || lower.contains("#female") || lower.contains("-f-")) {
                                gender = "female";
                            } else if (lower.contains("male") || lower.contains("#male") || lower.contains("-m-")) {
                                gender = "male";
                            }
                            vm.put("gender", gender);
                            voicesOut.add(vm);
                        }
                    }
                }
                result.success(voicesOut);
                break;
            }
            case "speak": {
                if (tts == null || !ttsReady) {
                    result.error("TTS_NOT_READY", "Native Android TTS engine is not ready.", null);
                    return;
                }
                String text = call.argument("text");
                String voiceName = call.argument("voiceName");
                String languageTag = call.argument("languageTag");
                Double speedObj = call.argument("speed");
                Integer repeatObj = call.argument("repeatCount");

                if (text == null || text.trim().isEmpty()) {
                    result.success(false);
                    return;
                }
                float speed = speedObj != null ? speedObj.floatValue() : 1.0f;
                speed = Math.max(0.5f, Math.min(2.0f, speed));
                int repeatCount = repeatObj != null ? repeatObj : 1;
                repeatCount = Math.max(1, Math.min(9, repeatCount));

                tts.stop();
                tts.setSpeechRate(speed);

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    boolean voiceApplied = false;
                    if (voiceName != null && !voiceName.isEmpty() && tts.getVoices() != null) {
                        for (Voice v : tts.getVoices()) {
                            if (voiceName.equals(v.getName())) {
                                tts.setVoice(v);
                                voiceApplied = true;
                                break;
                            }
                        }
                    }
                    if (!voiceApplied && languageTag != null && !languageTag.isEmpty()) {
                        Locale loc = Locale.forLanguageTag(languageTag);
                        int avail = tts.isLanguageAvailable(loc);
                        if (avail < TextToSpeech.LANG_AVAILABLE) {
                            result.error("VOICE_UNAVAILABLE", "Language or voice not installed on device: " + languageTag, null);
                            return;
                        }
                        tts.setLanguage(loc);
                    }
                }

                for (int i = 0; i < repeatCount; i++) {
                    int queueMode = (i == 0) ? TextToSpeech.QUEUE_FLUSH : TextToSpeech.QUEUE_ADD;
                    String utteranceId = "utt_" + UUID.randomUUID().toString() + "_" + i;
                    tts.speak(text, queueMode, null, utteranceId);
                }
                result.success(true);
                break;
            }
            case "stop": {
                if (tts != null) {
                    tts.stop();
                }
                result.success(true);
                break;
            }
            case "installMissingTtsData": {
                try {
                    Intent installIntent = new Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA);
                    installIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(installIntent);
                    result.success(true);
                } catch (Exception e) {
                    result.error("TTS_INSTALL_UNSUPPORTED", e.getMessage(), null);
                }
                break;
            }
            default:
                result.notImplemented();
                break;
        }
    }

    @Override
    protected void onDestroy() {
        if (tts != null) {
            tts.stop();
            tts.shutdown();
            tts = null;
        }
        super.onDestroy();
    }
}
