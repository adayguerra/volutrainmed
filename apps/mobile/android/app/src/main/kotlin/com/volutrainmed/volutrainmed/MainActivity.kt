package com.volutrainmed.volutrainmed

import android.content.Intent
import android.os.Build
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Comprueba si el dispositivo puede reconocer la voz íntegramente en
        // local. La app nunca usa reconocimiento en la nube: si esto devuelve
        // false, manos libres sigue con el teclado y los botones.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "volutrainmed/voz_local")
            .setMethodCallHandler { call, result ->
                if (call.method != "soportaReconocimientoLocal") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val locale = call.argument<String>("locale") ?: "es-ES"
                soportaReconocimientoLocal(locale) { ok -> runOnUiThread { result.success(ok) } }
            }
    }

    private fun soportaReconocimientoLocal(locale: String, responder: (Boolean) -> Unit) {
        // Antes de Android 12 no existe el reconocedor exclusivamente local.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return responder(false)
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) return responder(false)
        // Android 12: hay reconocedor local; el idioma no puede consultarse.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return responder(true)
        val respondido = AtomicBoolean(false)
        try {
            val reconocedor = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            reconocedor.checkRecognitionSupport(intent, Executors.newSingleThreadExecutor(), object : RecognitionSupportCallback {
                override fun onSupportResult(soporte: RecognitionSupport) {
                    val instalado = soporte.installedOnDeviceLanguages.any { it.equals(locale, ignoreCase = true) }
                    if (respondido.compareAndSet(false, true)) responder(instalado)
                    runOnUiThread { reconocedor.destroy() }
                }

                override fun onError(error: Int) {
                    if (respondido.compareAndSet(false, true)) responder(false)
                    runOnUiThread { reconocedor.destroy() }
                }
            })
        } catch (e: Exception) {
            if (respondido.compareAndSet(false, true)) responder(false)
        }
    }
}
