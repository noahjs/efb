import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Top-level handler for background messages (must be a top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are automatically shown as system notifications on
  // both iOS and Android when they contain a notification payload.
  debugPrint('Background message: ${message.messageId}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Call once during app startup, after Firebase.initializeApp().
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Register the background handler
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);

    // Local notifications for foreground messages
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'efb_alerts',
      'EFB Alerts',
      description: 'TFR, weather, and flight category alerts',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
  }

  /// Whether Firebase was successfully initialized.
  static bool get isAvailable => _initialized;

  /// Request notification permission from the user.
  static Future<bool> requestPermission() async {
    if (!_initialized) return false;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Get the current FCM device token.
  static Future<String?> getToken() async {
    if (!_initialized) return null;
    return FirebaseMessaging.instance.getToken();
  }

  /// Register the device token with the backend.
  static Future<void> registerTokenWithBackend(
    String token,
    ApiClient apiClient,
  ) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    await apiClient.registerDeviceToken(token: token, platform: platform);
  }

  /// Remove the device token from the backend (e.g., on logout).
  static Future<void> unregisterToken(ApiClient apiClient) async {
    final token = await getToken();
    if (token != null) {
      await apiClient.deleteDeviceToken(token);
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'efb_alerts',
          'EFB Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['alert_type'],
    );
  }

  static void _handleMessageOpenedApp(RemoteMessage message) {
    // Navigate based on alert_type when the user taps a notification
    final alertType = message.data['alert_type'];
    debugPrint('Notification tap (background): alert_type=$alertType');
    // Navigation can be handled here via a global navigator key if needed
  }

  static void _onNotificationTap(NotificationResponse response) {
    final alertType = response.payload;
    debugPrint('Notification tap (foreground): alert_type=$alertType');
    // Navigation can be handled here via a global navigator key if needed
  }

  static void _onTokenRefresh(String token) {
    debugPrint('FCM token refreshed: $token');
    // Token re-registration happens on next app launch or can be handled
    // via a global ApiClient reference if needed
  }
}
