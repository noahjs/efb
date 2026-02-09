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
    MapboxOptions.accessToken = "pk.eyJ1Ijoibm9haGpzIiwiYSI6ImNtbGQzbzF5dTBmMWszZnB4aDgzbDZzczUifQ.yv1FBDKs9T1RllaF7h_WxA"
    GMSServices.provideAPIKey("AIzaSyBSU9AnFbDLJYWR_TOyM9t8VAsgsemH0s4")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
