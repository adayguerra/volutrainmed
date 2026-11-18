import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Comprueba si el dispositivo puede reconocer la voz íntegramente en local
    // (sin pedir permisos). La app nunca usa reconocimiento en la nube.
    let canal = FlutterMethodChannel(
      name: "volutrainmed/voz_local",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    canal.setMethodCallHandler { llamada, resultado in
      guard llamada.method == "soportaReconocimientoLocal" else {
        resultado(FlutterMethodNotImplemented)
        return
      }
      let args = llamada.arguments as? [String: Any]
      let locale = (args?["locale"] as? String) ?? "es-ES"
      let reconocedor = SFSpeechRecognizer(locale: Locale(identifier: locale))
      resultado(reconocedor?.supportsOnDeviceRecognition ?? false)
    }
  }
}
