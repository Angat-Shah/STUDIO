// import Flutter
// import UIKit

// @main
// @objc class AppDelegate: FlutterAppDelegate {
//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     GeneratedPluginRegistrant.register(with: self)
    
//     // Set up method channel for screenshot detection
//     let controller = window?.rootViewController as? FlutterViewController
//     let screenshotChannel = FlutterMethodChannel(
//       name: "screenshot_detector",
//       binaryMessenger: controller!.binaryMessenger
//     )
    
//     // Handle method calls from Flutter
//     screenshotChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
//       switch call.method {
//       case "startDetection":
//         // Add observer for screenshot notification
//         NotificationCenter.default.addObserver(
//           forName: UIApplication.userDidTakeScreenshotNotification,
//           object: nil,
//           queue: .main
//         ) { _ in
//           screenshotChannel.invokeMethod("onScreenshotDetected", arguments: nil)
//         }
//         result(true)
//       case "stopDetection":
//         // Remove observer
//         NotificationCenter.default.removeObserver(
//           self,
//           name: UIApplication.userDidTakeScreenshotNotification,
//           object: nil
//         )
//         result(true)
//       case "checkScreenshot":
//         // Not needed for iOS as we use NotificationCenter
//         result(false)
//       default:
//         result(FlutterMethodNotImplemented)
//       }
//     }
    
//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }
// }

// import Flutter
// import UIKit

// @main
// @objc class AppDelegate: FlutterAppDelegate {
//   var field = UITextField()

//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     GeneratedPluginRegistrant.register(with: self)
    
//     #if !DEBUG
//     addSecuredView()
//     #endif

//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }

//   override func applicationWillResignActive(_ application: UIApplication) {
//     field.isSecureTextEntry = false
//   }

//   override func applicationDidBecomeActive( _ application: UIApplication) {
//     field.isSecureTextEntry = true
//   }

//   private func addSecuredView() {
//     if(!window.subviews.contains(field)) {
//       window.addSubview(field)
//       field.centerYAnchor.constraint(equalTo: window.centerYAnchor).isActive = true
//       field.centerXAnchor.constraint(equalTo: window.centerXAnchor).isActive = true
//       window.layer.superlayer?.addSublayer(field.layer)
//       if #available(iOS 17.0, *) {
//         field.layer.sublayers?.last?.addSublayer(window.layer)
//       } else {
//         field.layer.sublayers?.first?.addSublayer(window.layer)
//       }
//     }
//   }
// }

// import Flutter
// import UIKit

// @main
// @objc class AppDelegate: FlutterAppDelegate {
//   private var field = UITextField()
//   private var screenshotObserver: NSObjectProtocol?
//   private var isSecureOverlayEnabled = false

//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     GeneratedPluginRegistrant.register(with: self)
    
//     // Ensure the root view controller is a FlutterViewController
//     guard let controller = window?.rootViewController as? FlutterViewController else {
//       fatalError("Root view controller must be FlutterViewController")
//     }
    
//     // Set up method channel for screenshot detection
//     let screenshotChannel = FlutterMethodChannel(
//       name: "screenshot_detector",
//       binaryMessenger: controller.binaryMessenger
//     )
    
//     // Handle method calls from Flutter
//     screenshotChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
//       switch call.method {
//       case "startDetection":
//         // Remove any existing observer to prevent duplicates
//         if let observer = self.screenshotObserver {
//           NotificationCenter.default.removeObserver(observer)
//         }
        
//         // Add observer for screenshot notification
//         self.screenshotObserver = NotificationCenter.default.addObserver(
//           forName: UIApplication.userDidTakeScreenshotNotification,
//           object: nil,
//           queue: .main
//         ) { [weak self] notification in
//           // Debounce using a static timestamp check
//           guard let self = self else { return }
//           struct LastScreenshot {
//             static var lastTime: Date?
//           }
//           let now = Date()
//           if let lastTime = LastScreenshot.lastTime, now.timeIntervalSince(lastTime) < 0.5 {
//             return // Ignore if too close to the last event
//           }
//           LastScreenshot.lastTime = now
          
//           DispatchQueue.main.async {
//             screenshotChannel.invokeMethod("onScreenshotDetected", arguments: nil)
//           }
//         }
//         result(true)
//       case "stopDetection":
//         // Remove observer
//         if let observer = self.screenshotObserver {
//           NotificationCenter.default.removeObserver(observer)
//           self.screenshotObserver = nil
//         }
//         result(true)
//       case "checkScreenshot":
//         // Not needed for iOS as we use NotificationCenter
//         result(false)
//       case "enableSecureOverlay":
//         #if !DEBUG
//         self.addSecuredView()
//         self.isSecureOverlayEnabled = true
//         self.field.isSecureTextEntry = true
//         #endif
//         result(true)
//       case "disableSecureOverlay":
//         #if !DEBUG
//         self.field.removeFromSuperview()
//         self.isSecureOverlayEnabled = false
//         #endif
//         result(true)
//       default:
//         result(FlutterMethodNotImplemented)
//       }
//     }
    
//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }

//   override func applicationWillResignActive(_ application: UIApplication) {
//     if isSecureOverlayEnabled {
//       field.isSecureTextEntry = false
//     }
//   }

//   override func applicationDidBecomeActive(_ application: UIApplication) {
//     if isSecureOverlayEnabled {
//       field.isSecureTextEntry = true
//     }
//   }

//   private func addSecuredView() {
//     if !window!.subviews.contains(field) {
//       window!.addSubview(field)
//       field.centerYAnchor.constraint(equalTo: window!.centerYAnchor).isActive = true
//       field.centerXAnchor.constraint(equalTo: window!.centerXAnchor).isActive = true
//       window!.layer.superlayer?.addSublayer(field.layer)
//       if #available(iOS 17.0, *) {
//         field.layer.sublayers?.last?.addSublayer(window!.layer)
//       } else {
//         field.layer.sublayers?.first?.addSublayer(window!.layer)
//       }
//     }
//   }
// }

import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var field = UITextField()
  private var screenshotObserver: NSObjectProtocol?
  private var isSecureOverlayEnabled = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("Root view controller must be FlutterViewController")
    }
    
    let screenshotChannel = FlutterMethodChannel(
      name: "screenshot_detector",
      binaryMessenger: controller.binaryMessenger
    )
    
    screenshotChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "startDetection":
        if self.screenshotObserver != nil {
          NotificationCenter.default.removeObserver(self.screenshotObserver!)
          self.screenshotObserver = nil
        }
        
        self.screenshotObserver = NotificationCenter.default.addObserver(
          forName: UIApplication.userDidTakeScreenshotNotification,
          object: nil,
          queue: .main
        ) { [weak self] notification in
          guard let self = self else { return }
          struct LastScreenshot {
            static var lastTime: Date?
          }
          let now = Date()
          if let lastTime = LastScreenshot.lastTime, now.timeIntervalSince(lastTime) < 0.5 {
            return
          }
          LastScreenshot.lastTime = now
          
          DispatchQueue.main.async {
            screenshotChannel.invokeMethod("onScreenshotDetected", arguments: nil)
          }
        }
        result(true)
      case "stopDetection":
        if let observer = self.screenshotObserver {
          NotificationCenter.default.removeObserver(observer)
          self.screenshotObserver = nil
        }
        result(true)
      case "checkScreenshot":
        result(false)
      case "enableSecureOverlay":
        #if !DEBUG
        self.addSecuredView()
        self.isSecureOverlayEnabled = true
        self.field.isSecureTextEntry = true
        #endif
        result(true)
      case "disableSecureOverlay":
        #if !DEBUG
        self.removeSecuredView()
        self.isSecureOverlayEnabled = false
        self.field.isSecureTextEntry = false
        #endif
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    if isSecureOverlayEnabled {
      field.isSecureTextEntry = false
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    if isSecureOverlayEnabled {
      field.isSecureTextEntry = true
    }
  }

  private func addSecuredView() {
    if !window!.subviews.contains(field) {
      field.translatesAutoresizingMaskIntoConstraints = false
      window!.addSubview(field)
      field.centerYAnchor.constraint(equalTo: window!.centerYAnchor).isActive = true
      field.centerXAnchor.constraint(equalTo: window!.centerXAnchor).isActive = true
      window!.layer.superlayer?.addSublayer(field.layer)
      if #available(iOS 17.0, *) {
        field.layer.sublayers?.last?.addSublayer(window!.layer)
      } else {
        field.layer.sublayers?.first?.addSublayer(window!.layer)
      }
    }
  }

  private func removeSecuredView() {
    if window!.subviews.contains(field) {
      field.isSecureTextEntry = false
      field.removeFromSuperview()
      field.layer.sublayers?.removeAll()
    }
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    if let observer = screenshotObserver {
      NotificationCenter.default.removeObserver(observer)
      screenshotObserver = nil
    }
    removeSecuredView()
  }
}