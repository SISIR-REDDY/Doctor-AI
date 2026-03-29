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
    // Initialize Firebase
    #if canImport(FirebaseCore)
    FirebaseApp.configure()
    #else
    print("ℹ️ FirebaseCore not available at build time — skipping Firebase configuration")
    #endif
    
    // Register for remote notifications (iOS Push / FCM)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()
    
    // Get Flutter binary messenger
    let controller = window?.rootViewController as! FlutterViewController
    let messenger = controller.binaryMessenger
    
    let firestoreReadyChannel = FlutterMethodChannel(name: "firestore_ready", binaryMessenger: messenger)
    firestoreReadyChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "markReady" {
        self?.isFirestoreReady = true
        print("✅ Native: Firestore marked ready by Flutter — native writes enabled")
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    let healthKitChannel = FlutterMethodChannel(name: "health_connect", binaryMessenger: messenger)
    healthKitChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleHealthKitCall(call, result: result)
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Instagram Stories Sharing Channel
    // ─────────────────────────────────────────────
    let instagramChannel = FlutterMethodChannel(name: "instagram_stories_share", binaryMessenger: messenger)
    instagramChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleInstagramCall(call, result: result)
    }
    
    // ─────────────────────────────────────────────
    // MARK: - Native Water Reminder Channel
    // ─────────────────────────────────────────────
    let waterReminderChannel = FlutterMethodChannel(name: "native_water_reminder", binaryMessenger: messenger)
    waterReminderChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "cancelNativeReminder":
        self.cancelWaterReminderNotifications {
          result(true)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Water reminders are disabled for this release.
    cancelWaterReminderNotifications()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Push Notification Handlers

  private func cancelWaterReminderNotifications(completion: (() -> Void)? = nil) {
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let waterIds = requests
        .map { $0.identifier }
        .filter { self.isWaterReminderIdentifier($0) }

      if !waterIds.isEmpty {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: waterIds)
      }

      UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
        let deliveredWaterIds = delivered
          .map { $0.request.identifier }
          .filter { self.isWaterReminderIdentifier($0) }
        if !deliveredWaterIds.isEmpty {
          UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: deliveredWaterIds)
        }

        DispatchQueue.main.async {
          completion?()
        }
      }
    }
  }

  private func isWaterReminderIdentifier(_ identifier: String) -> Bool {
    if identifier.hasPrefix("water_reminder_") {
      return true
    }

    if let numericId = Int(identifier),
       (10000...10199).contains(numericId) || (1000...1099).contains(numericId) {
      return true
    }

    return false
  }
  
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Pass device token to Firebase for FCM
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
  }
  
  // MARK: - Handle URL schemes (Google Sign-In callback)
  
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return super.application(app, open: url, options: options)
  }
  
  // MARK: - Instagram Stories Sharing
  
  private func handleInstagramCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isInstagramInstalled":
      if let instagramUrl = URL(string: "instagram-stories://share") {
        let isInstalled = UIApplication.shared.canOpenURL(instagramUrl)
        result(isInstalled)
      } else {
        result(false)
      }
      
    case "shareToInstagramStories":
      guard let args = call.arguments as? [String: Any],
            let imagePath = args["imagePath"] as? String else {
        result(false)
        return
      }
      
      guard let instagramUrl = URL(string: "instagram-stories://share"),
            UIApplication.shared.canOpenURL(instagramUrl) else {
        result(false)
        return
      }
      
      guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)) else {
        result(false)
        return
      }
      
      let pasteboardItems: [[String: Any]] = [[
        "com.instagram.sharedSticker.backgroundImage": imageData,
        "com.instagram.sharedSticker.contentURL": args["contentUrl"] as? String ?? ""
      ]]
      
      let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
        .expirationDate: Date().addingTimeInterval(60 * 5)
      ]
      
      UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
      
      UIApplication.shared.open(instagramUrl, options: [:]) { success in
        result(success)
      }
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // MARK: - HealthKit Method Channel Handler

  // Keep channel responses for backward compatibility while HealthKit is removed.
  private func handleHealthKitCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkAvailability":
      result(false)
    case "checkPermissions":
      result(false)
    case "requestPermissions":
      result(false)
    case "getTodayData":
      result([
        "steps": 0,
        "caloriesBurned": 0,
        "workoutSessions": 0,
        "workoutDuration": 0,
      ])
    case "getWeeklyData":
      result([])
    case "getTodayExerciseSessions":
      result([])
    case "enableBackgroundDelivery":
      result(false)
    case "openHealthConnectSettings":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

