#if canImport(FirebaseCore)
import FirebaseCore
#endif
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var isFirestoreReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if canImport(FirebaseCore)
    FirebaseApp.configure()
    #endif

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)

    let registrar = self as! FlutterPluginRegistry
    let messenger = registrar.registrar(forPlugin: "AppChannels")!.messenger()

    let firestoreReadyChannel = FlutterMethodChannel(name: "firestore_ready", binaryMessenger: messenger)
    firestoreReadyChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "markReady" {
        self?.isFirestoreReady = true
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
  }

  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    return super.application(app, open: url, options: options)
  }
}
