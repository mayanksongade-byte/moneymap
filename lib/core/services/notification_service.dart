// import 'dart:async';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter/foundation.dart';
//
// class NotificationService {
//   static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
//   FlutterLocalNotificationsPlugin();
//
//   static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
//
//   static Future<void> initialize() async {
//     try {
//       // ૧. નોટિફિકેશન માટેની પરવાનગી લેવી
//       await _messaging.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//       );
//
//       // ૨. લોકલ નોટિફિકેશન સેટઅપ
//       const AndroidInitializationSettings initializationSettingsAndroid =
//       AndroidInitializationSettings('@mipmap/ic_launcher');
//
//       const InitializationSettings initializationSettings = InitializationSettings(
//         android: initializationSettingsAndroid,
//         iOS: DarwinInitializationSettings(),
//       );
//
//       await _localNotificationsPlugin.initialize(
//         initializationSettings,
//         onDidReceiveNotificationResponse: (NotificationResponse details) {
//           // જ્યારે યુઝર નોટિફિકેશન પર ટેપ કરે ત્યારે
//           debugPrint("Notification tapped: ${details.payload}");
//         },
//       );
//
//       // ૩. એન્ડ્રોઇડ નોટિફિકેશન ચેનલ (હાઇ ઇમ્પોર્ટન્સ માટે)
//       const AndroidNotificationChannel channel = AndroidNotificationChannel(
//         'high_importance_channel',
//         'High Importance Notifications',
//         description: 'This channel is used for important notifications.',
//         importance: Importance.max,
//         playSound: true,
//       );
//
//       await _localNotificationsPlugin
//           .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin>()
//           ?.createNotificationChannel(channel);
//
//       // ૪. જ્યારે એપ ચાલુ હોય (Foreground) ત્યારે મેસેજ સાંભળવા
//       FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//         RemoteNotification? notification = message.notification;
//         if (notification != null) {
//           showLocalNotification(
//             title: notification.title ?? '',
//             body: notification.body ?? '',
//             payload: message.data.toString(),
//           );
//         }
//       });
//
//       // ૫. જ્યારે એપ બેકગ્રાઉન્ડમાં હોય અને નોટિફિકેશન પર ક્લિક કરો ત્યારે
//       FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//         debugPrint("App opened via notification: ${message.data}");
//       });
//
//       // ૬. FCM ટોકન મેળવવું
//       _messaging.getToken().then((token) {
//         if (kDebugMode) print("Firebase Messaging Token: $token");
//       });
//
//     } catch (e) {
//       debugPrint("Notification Service Init Error: $e");
//     }
//   }
//
//   static Future<void> showLocalNotification({
//     required String title,
//     required String body,
//     String? payload,
//   }) async {
//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//     AndroidNotificationDetails(
//       'high_importance_channel',
//       'High Importance Notifications',
//       importance: Importance.max,
//       priority: Priority.high,
//       icon: '@mipmap/ic_launcher',
//       playSound: true,
//     );
//
//     const NotificationDetails platformChannelSpecifics =
//     NotificationDetails(android: androidPlatformChannelSpecifics);
//
//     await _localNotificationsPlugin.show(
//       0,
//       title,
//       body,
//       platformChannelSpecifics,
//       payload: payload,
//     );
//   }
// }