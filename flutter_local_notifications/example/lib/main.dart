import 'dart:async';
import 'dart:convert';
import 'dart:io';
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:android_intent/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;
import 'package:location/location.dart' as loc;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'providers/ble_logger.dart';
import 'providers/ble_scanner.dart';
import 'providers/local_provider.dart';
import 'screens/about_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

int id = 0;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Streams are created so that app can respond to notification-related events
/// since the plugin is initialised in the `main` function
final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
    StreamController<ReceivedNotification>.broadcast();

final StreamController<String?> selectNotificationStream =
    StreamController<String?>.broadcast();

const MethodChannel platform =
    MethodChannel('dexterx.dev/flutter_local_notifications_example');

const String portName = 'notification_send_port';

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;

/// A notification action which triggers a url launch event
const String urlLaunchActionId = 'id_1';

/// A notification action which triggers a App navigation event
const String navigationActionId = 'id_3';

/// Defines a iOS/MacOS notification category for text input actions.
const String darwinNotificationCategoryText = 'textCategory';

/// Defines a iOS/MacOS notification category for plain actions.
const String darwinNotificationCategoryPlain = 'plainCategory';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // ignore: avoid_print
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    // ignore: avoid_print
    print(
        'notification action tapped with input: ${notificationResponse.input}');
  }
}

Future<void> openLocationSetting() async {
  final AndroidIntent intent = new AndroidIntent(
    action: 'android.settings.LOCATION_SOURCE_SETTINGS',
  );
  await intent.launch();
}

/// Using permission_handler for both
Future<String> getLocationPermissionStatus() async {
  print('\n\nTrackingRepository.getLocationPermissionStatus() started\n\n');
  late String permission;

  permission = await Permission.locationWhenInUse.status.then((value) {
    print(
        'TrackingRepository.getLocationPermissionStatus() Permission.locationAlways.status is: ${value.name}\n\n');
    switch (value) {
      case PermissionStatus.denied:
        return 'denied';
      case PermissionStatus.permanentlyDenied:
        return 'deniedForever';
      case PermissionStatus.limited:
        return 'limited';
      case PermissionStatus.granted:
        return 'granted';
      case PermissionStatus.restricted:
        return 'restricted';
    }
    return permission;
  });
  return permission;
}

Future<String> requestLocationPermission() async {
  late String permission;
  var locationWhenInUseStatus =
      await Permission.locationWhenInUse.status.then((value) {
    print('\n\nTrackingRepository.requestLocationPermission() iOS\n'
        'Permission.locationWhenInUse.status is: ${value.name}');
    return value;
  });

  /// locationWhenInUseStatus NOT Granted
  if (!locationWhenInUseStatus.isGranted) {
    print('\n\nTrackingRepository.requestLocationPermission() iOS\n'
        'locationWhenInUseRequest NOT Granted, we now request it');

    /// Ask locationWhileInUse permission
    var locationWhenInUseRequest = await Permission.locationWhenInUse.request();
    print('\n\nTrackingRepository.requestLocationPermission() iOS\n'
        'Permission.locationWhenInUse.request() status is: $locationWhenInUseRequest');

    /// locationWhenInUseRequest granted
    if (locationWhenInUseRequest.isGranted) {
      /// When in use NOW Granted
      print('\n\nTrackingRepository.requestLocationPermission() ios\n'
          'When in use NOW Granted');
      permission = 'whileInUse';
      PermissionStatus status = await Permission.locationAlways.request();
      print(
          '\n\nTrackingRepository.requestLocationPermission() ios locationWhenInUse is Now Granted\n'
          'Permission.locationAlways.request() status is: $status');

      if (status.isGranted) {
        /// Always is NOW Granted
        print('\n\nTrackingRepository.requestLocationPermission() ios\n'
            'Always use NOW Granted');
        permission = 'granted';
        print(
            '\n\nTrackingRepository.requestLocationPermission() ios locationAlways is Now Granted\n'
            'Permission.locationAlways.request() status is: $status');
      } else {
        //Do another stuff
      }
    }

    /// locationWhenInUseRequest not granted
    else {
      //The user deny the permission
      permission = 'denied';
    }
    if (locationWhenInUseRequest.isPermanentlyDenied) {
      //When the user previously rejected the permission and select never ask again
      //Open the screen of settings
      print('\n\nTrackingRepository.requestLocationPermission() iOS\n'
          'Permission.locationWhenInUse.request is isPermanentlyDenied');
      permission = 'deniedForever';
      bool didOpen = await openAppSettings();
      print(
          '\n\nTrackingRepository.requestLocationPermission() ios isPermanentlyDenied\n'
          'openAppSettings() didOpen: $didOpen');

      // TODO: re-check for locationWhenInUse permission status?
    }
  }

  /// locationWhenInUseStatus is ALREADY Granted
  else {
    print('\n\nTrackingRepository.requestLocationPermission() iOS\n'
        'locationWhenInUse ALREADY Granted, we now check for locationAlways permission');
    permission = 'whenInUse';

    var locationAlwaysStatus =
        await Permission.locationAlways.status.then((value) {
      print(
          '\n\nTrackingRepository.requestLocationPermission() iOS\nlocationWhenInUse already granted\n'
          'Permission.locationAlways.status is: ${value.name}');
      return value;
    });

    /// locationAlways is NOT Already Granted
    if (!locationAlwaysStatus.isGranted) {
      print('\n\nTrackingRepository.requestLocationPermission() iOS\n'
          'locationAlways not granted, we now ask for permission');

      /// ask locationAlways permission
      var locationAlwaysStatus = await Permission.locationAlways.request();

      /// finally it opens the system popup
      print('\n\nTrackingRepository.requestLocationPermission() iOs\n'
          'Permission.locationAlways.request() status is: $locationAlwaysStatus');

      /// locationAlways is NOW Granted
      if (locationAlwaysStatus.isGranted) {
        print('\n\nTrackingRepository.requestLocationPermission() iOS\n'
            'locationAlways was Granted upon request');
        permission = 'granted';
      }

      /// locationAlways was NOT Granted
      else {
        print('\n\nTrackingRepository.requestLocationPermission() iOS\n'
            'Permission.locationAlways.request() status was NOT Granted upon request, we now open AppSettings');
        await openAppSettings().then((value) {
          print(
              '\n\nTrackingRepository.requestLocationPermission() ios locationAlways isPermanentlyDenied\n'
              'openAppSettings() didOpen: $value');
        });
        // TODO: re-check locationAlways permission status??
      }
    }

    /// locationAlways is ALREADY Granted
    else {
      permission = 'granted';
    }
  }
  return permission;
}

Future _initLocationService() async {
  loc.Location location = loc.Location();

  bool? _serviceEnabled;
  loc.PermissionStatus _permissionGranted = loc.PermissionStatus.denied;
  loc.LocationData? _locationData;

  if (!await location.serviceEnabled()) {
    if (!await location.requestService()) {
      return;
    }
  }

  var permission = await location.hasPermission();
  if (permission == PermissionStatus.denied) {
    permission = await location.requestPermission();
    if (permission != PermissionStatus.granted) {
      return;
    }
  }

  var loca = await location.getLocation();
  print("${loca.latitude} ${loca.longitude}");
}

Future<void> checkPerm() async {
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;

  //location
  if (await Permission.location.serviceStatus.isEnabled) {
    //permissionGranted
  } else {
    await Permission.locationWhenInUse.request();

    if (await Permission.locationWhenInUse.request().isGranted) {
      await Permission.locationAlways.request();

      print(await Permission.locationAlways.request());
    }
  }

  var statusLocation = await Permission.location.status;

  if (statusLocation.isGranted) {
    //isGranted
  } else if (statusLocation.isDenied) {
    Map<Permission, PermissionStatus> statusLocationMap = await [
      Permission.location,
    ].request();
  }

  if (await Permission.location.isPermanentlyDenied) {
    await openLocationSetting();
  }

  if (androidInfo.version.sdkInt <= 30) {
    switch (await Permission.location.request()) {
      case PermissionStatus.denied:
        // TODO: Handle this case.
        break;
      case PermissionStatus.granted:
        // TODO: Handle this case.
        break;
      case PermissionStatus.restricted:
        // TODO: Handle this case.
        break;
      case PermissionStatus.limited:
        // TODO: Handle this case.
        break;
      case PermissionStatus.permanentlyDenied:
        // TODO: Handle this case.
        break;
      case PermissionStatus.provisional:
        // TODO: Handle this case.
        break;
    }
    return;
  }

  if (30 < androidInfo.version.sdkInt) {
    Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.bluetoothScan,
    ].request();

    if (statuses[Permission.bluetoothScan] == PermissionStatus.granted) {
      // permission granted
    }
    return;
  } else {
    print('tu');
    final PermissionStatus status = await Permission.bluetooth.status;
    final PermissionStatus statusLoc = await Permission.location.status;

    if (status.isDenied) {
      await Permission.bluetooth.request();
    }

    if (statusLoc.isDenied) {
      await Permission.location.request();
    }

    if (await Permission.bluetooth.status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }
}

/// IMPORTANT: running the following code on its own won't work as there is
/// setup required for each platform head project.
///
/// Please download the complete example app from the GitHub repository where
/// all the setup has been done
Future<void> main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  await checkPerm();
  String status = await getLocationPermissionStatus();
  if (status != 'granted') {
    await requestLocationPermission();
  }

  //await _initLocationService();

  //await requestLocationPermissionBacground();

  final FlutterReactiveBle ble = FlutterReactiveBle();
  final BleLogger bleLogger = BleLogger(ble: ble);

  final BleScanner scanner =
      BleScanner(ble: ble, logMessage: bleLogger.addToLog);

  await _configureLocalTimeZone();

  final NotificationAppLaunchDetails? notificationAppLaunchDetails = !kIsWeb &&
          Platform.isLinux
      ? null
      : await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  const String initialRoute = HomePage.routeName;
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    selectedNotificationPayload =
        notificationAppLaunchDetails!.notificationResponse?.payload;
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_launcher');

  final List<DarwinNotificationCategory> darwinNotificationCategories =
      <DarwinNotificationCategory>[
    DarwinNotificationCategory(
      darwinNotificationCategoryText,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.text(
          'text_1',
          'Action 1',
          buttonTitle: 'Send',
          placeholder: 'Placeholder',
        ),
      ],
    ),
    DarwinNotificationCategory(
      darwinNotificationCategoryPlain,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain('id_1', 'Action 1'),
        DarwinNotificationAction.plain(
          'id_2',
          'Action 2 (destructive)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
        DarwinNotificationAction.plain(
          navigationActionId,
          'Action 3 (foreground)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.foreground,
          },
        ),
        DarwinNotificationAction.plain(
          'id_4',
          'Action 4 (auth required)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.authenticationRequired,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    )
  ];

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {
      didReceiveLocalNotificationStream.add(
        ReceivedNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        ),
      );
    },
    notificationCategories: darwinNotificationCategories,
  );
  final LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(
    defaultActionName: 'Open notification',
    defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
    linux: initializationSettingsLinux,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) {
      switch (notificationResponse.notificationResponseType) {
        case NotificationResponseType.selectedNotification:
          selectNotificationStream.add(notificationResponse.payload);
          break;
        case NotificationResponseType.selectedNotificationAction:
          if (notificationResponse.actionId == navigationActionId) {
            selectNotificationStream.add(notificationResponse.payload);
          }
          break;
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
  runApp(MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<LocalProvider>(
        create: (_) => LocalProvider(),
      ),
      Provider<BleScanner>.value(value: scanner),
      Provider<BleLogger>.value(value: bleLogger),
      StreamProvider<BleScannerState?>(
        create: (_) => scanner.state,
        initialData: const BleScannerState(
          discoveredDevices: <DiscoveredDevice>[],
          scanIsInProgress: false,
        ),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      routes: <String, WidgetBuilder>{
        HomePage.routeName: (_) => HomePage(notificationAppLaunchDetails),
        SettingsScreen.routeName: (_) => const SettingsScreen(),
        AboutScreen.routeName: (_) => const AboutScreen(),
      },
    ),
  ));
}

Future<void> _configureLocalTimeZone() async {
  if (kIsWeb || Platform.isLinux) {
    return;
  }
  tz.initializeTimeZones();
  final String? timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName!));
}

class PaddedElevatedButton extends StatelessWidget {
  const PaddedElevatedButton({
    required this.buttonText,
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(buttonText),
        ),
      );
}
