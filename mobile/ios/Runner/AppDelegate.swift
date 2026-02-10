import Flutter
import UIKit
import MapboxMaps
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let info = Bundle.main.infoDictionary ?? [:]
    if let mapboxToken = info["MapboxToken"] as? String, !mapboxToken.isEmpty {
      MapboxOptions.accessToken = mapboxToken
    }
    if let googleKey = info["GoogleMapsKey"] as? String, !googleKey.isEmpty {
      GMSServices.provideAPIKey(googleKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
