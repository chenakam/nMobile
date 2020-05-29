import 'package:common_utils/common_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nmobile/helpers/settings.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/screens/news.dart';

import 'global.dart';

Future _onDidReceiveLocalNotification(int id, String title, String body, String payload) async {
// display a dialog with the notification details, tap ok to go to another page
  showDialog(
    context: Global.appContext,
    builder: (BuildContext context) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: Text('Ok'),
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NewsScreen(),
              ),
            );
          },
        )
      ],
    ),
  );
}

Future _onSelectNotification(String payload) async {

}

class LocalNotification {
  static FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static int _notificationId = 0;
  static init() async {
    var initializationSettingsAndroid = new AndroidInitializationSettings('@drawable/icon_logo');

    var initializationSettingsIOS = IOSInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );
    var initializationSettings = InitializationSettings(initializationSettingsAndroid, initializationSettingsIOS);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: _onSelectNotification);
  }

  static notification(String title, String content, {int badgeNumber}) async {
    var iOSPlatformChannelSpecifics = IOSNotificationDetails(badgeNumber: badgeNumber);

    var platformChannelSpecifics = NotificationDetails(null, iOSPlatformChannelSpecifics);
    try {
      await _flutterLocalNotificationsPlugin.show(_notificationId++, title, content, platformChannelSpecifics);
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  static debugNotification(String title, String content, {int badgeNumber}) async {
    if (!Settings.debug) return;
    var iOSPlatformChannelSpecifics = IOSNotificationDetails(badgeNumber: badgeNumber);

    var platformChannelSpecifics = NotificationDetails(null, iOSPlatformChannelSpecifics);
    try {
      await _flutterLocalNotificationsPlugin.show(_notificationId++, title, content, platformChannelSpecifics);
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  static messageNotification(String title, String content, {int badgeNumber}) async {
    LogUtil.v(title);
    LogUtil.v(content);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails(badgeNumber: badgeNumber);
    var androidNotificationDetails = AndroidNotificationDetails('channel_ID', 'channel name', 'channel description');

    var platformChannelSpecifics = NotificationDetails(androidNotificationDetails, iOSPlatformChannelSpecifics);
    try {
      switch (Settings.localNotificationType) {
        case LocalNotificationType.only_name:
          await _flutterLocalNotificationsPlugin.show(_notificationId++, title, NMobileLocalizations.of(Global.appContext).you_have_new_message, platformChannelSpecifics);
          break;
        case LocalNotificationType.name_and_message:
          await _flutterLocalNotificationsPlugin.show(_notificationId++, title, content, platformChannelSpecifics);
          break;
        case LocalNotificationType.none:
          await _flutterLocalNotificationsPlugin.show(_notificationId++, NMobileLocalizations.of(Global.appContext).new_message, NMobileLocalizations.of(Global.appContext).you_have_new_message, platformChannelSpecifics);
          break;
      }
    } catch (e) {
      debugPrint(e);
      debugPrintStack();
    }
  }

  static Future cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}