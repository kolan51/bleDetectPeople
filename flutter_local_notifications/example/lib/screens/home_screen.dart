// Screen class for the first/main screen of this program, where the statuses are displayed and all the functions are initialized
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bluetooth_enable_fork/bluetooth_enable_fork.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../functions/rssi_distance.dart';
import '../main.dart';
import '../providers/ble_scanner.dart';
import '../providers/local_provider.dart';
import 'about_screen.dart';
import 'settings_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage(
    this.notificationAppLaunchDetails, {
    Key? key,
  }) : super(key: key);

  static const String routeName = '/';

  final NotificationAppLaunchDetails? notificationAppLaunchDetails;

  bool get didNotificationLaunchApp =>
      notificationAppLaunchDetails?.didNotificationLaunchApp ?? false;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _notificationsEnabled = false;
  bool _notificationShown = false;
  bool? _isFirstLoaded = false;
  Timer? timerDevices;
  Timer? timerCalculate;
  Timer? timerDistance;
  Timer? timerNotify;
  Timer? timerLog;
  Timer? timerLoaded;

  RssiDistance rssiDistance = RssiDistance();

  bool scanStarted = false;

  List<DiscoveredDevice> _devices = <DiscoveredDevice>[];
  Map<String, int> _devicesRssi = <String, int>{};
  List<String> alreadyCalculated = <String>[];
  Map<String, double> _devicesFoundInRange = <String, double>{};

  List<double> _devicesInRange = <double>[];
  final TextEditingController _logController = TextEditingController();

  double distanceValue = 1;

  Future<void> enableBT() async {
    await BluetoothEnable.enableBluetooth.then((String value) {});
  }

  Future<void> startScan() async {
    Provider.of<BleScanner>(context, listen: false).clearDevices();
    Provider.of<BleScanner>(context, listen: false).clearDevicesRssi();
    if (scanStarted) {
      await Provider.of<BleScanner>(context, listen: false).stopScan();
      setState(() {
        scanStarted = false;
        _devicesFoundInRange = <String, double>{};
        _logController.text = '';
      });
    }

    Provider.of<BleScanner>(context, listen: false).startScan();
    scanStarted = true;
    setState(() {
      _devicesInRange = <double>[];
      _devicesFoundInRange = <String, double>{};
      _devices = Provider.of<BleScanner>(context, listen: false).getDevices();
      _devicesRssi =
          Provider.of<BleScanner>(context, listen: false).getDevicesRssi();
    });
  }

  // Function to refresh logs on screen
  void _refreshLogs(BuildContext context) {
    final String text =
        Provider.of<BleScanner>(context, listen: false).getLog();
    print(text);
    setState(() {
      _logController.text = text;
    });
  }

  void getDistanceLimit() {
    setState(() {
      distanceValue =
          Provider.of<BleScanner>(context, listen: false).getDistanceLimit();
    });
  }

  void setIsLoaded(bool? isLoaded) {
    Provider.of<LocalProvider>(context, listen: false).isLoaded = isLoaded;
  }

  void getIsLoaded() {
    _isFirstLoaded =
        Provider.of<LocalProvider>(context, listen: false).isLoaded!;
  }

  Future<void> getDevices() async {
    setState(() {
      _devices = Provider.of<BleScanner>(context, listen: false).getDevices();
    });
  }

  Future<void> getDevicesRssi() async {
    setState(() {
      _devicesRssi =
          Provider.of<BleScanner>(context, listen: false).getDevicesRssi();
    });
  }

  void getDevicesInRange() {
    _devicesRssi.forEach((String key, int value) {
      final int rssi = rssiDistance
          .calculateFilter(
            value.toDouble(),
          )
          .toInt();

      final double distance = rssiDistance.calcDistbyRSSI(rssi);

      if (distance <= distanceValue) {
        if (!_devicesFoundInRange.containsKey(key)) {
          if (key == '') {
            key = 'Unknown Device';
          }
          _logController.text += '$key - ${distance.toStringAsFixed(1)} m\n\n';
        }
        _devicesFoundInRange.putIfAbsent(key, () => distance);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    enableBT();
    startScan();
    getDistanceLimit();
    _isAndroidPermissionGranted();
    _requestPermissions();
    getIsLoaded();

    timerDevices = Timer.periodic(
        const Duration(milliseconds: 5), (Timer t) => getDevicesRssi());
    timerDistance = Timer.periodic(
        const Duration(milliseconds: 5), (Timer t) => getDistanceLimit());
    timerCalculate = Timer.periodic(
        const Duration(milliseconds: 20), (Timer t) => getDevicesInRange());

    timerLoaded = Timer.periodic(
        const Duration(milliseconds: 20), (Timer t) => getIsLoaded());
    timerNotify = Timer.periodic(const Duration(minutes: 5),
        (Timer t) => _showNotification(_devicesFoundInRange.length.toString()));

    // timerLog = Timer.periodic(
    //     const Duration(milliseconds: 5), (Timer t) => _refreshLogs(context));
  }

  @override
  void dispose() {
    didReceiveLocalNotificationStream.close();
    selectNotificationStream.close();
    timerDevices!.cancel();
    timerCalculate!.cancel();
    timerDistance!.cancel();
    timerNotify!.cancel();
    timerLog!.cancel();
    timerLoaded!.cancel();
    _logController.dispose();
    super.dispose();
  }

  Future<void> _isAndroidPermissionGranted() async {
    if (Platform.isAndroid) {
      final bool granted = await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;

      setState(() {
        _notificationsEnabled = granted;
      });
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? grantedNotificationPermission =
          await androidImplementation?.requestNotificationsPermission();
      setState(() {
        _notificationsEnabled = grantedNotificationPermission ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: Image.asset('assets/icons/app_icon.png'),
            onPressed: () {
              Navigator.of(context).pushNamed(AboutScreen.routeName);
            }),
        title: const Text('         People Counter BLE'),
        backgroundColor: Colors.teal,
        actions: <Widget>[
          IconButton(
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pushNamed(SettingsScreen.routeName);
              })
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(
                  height: 100,
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Estimated people nearby',
                    textScaleFactor: 1.6,
                    style: TextStyle(
                      fontStyle: FontStyle.normal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Nearby people/devices: ${_devicesFoundInRange.length}'),
                const SizedBox(height: 20),
                OutlinedButton(
                  style: ButtonStyle(
                    backgroundColor: const MaterialStatePropertyAll<Color>(
                      Colors.teal,
                    ),
                    overlayColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.pressed)) {
                          return const Color(0xFF4e62e0).withOpacity(0.8);
                        }
                        return Colors.transparent;
                      },
                    ),
                  ),
                  onPressed: () async {
                    _isFirstLoaded!
                        ? await startScan()
                        : showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              // return object of type Dialog
                              return AlertDialog(
                                title: const Text('Enable Location'),
                                content: const Text(
                                    'This Application requires the location service to be enabled!'),
                                actions: <Widget>[
                                  // usually buttons at the bottom of the dialog

                                  Center(
                                    child: OutlinedButton(
                                      style: ButtonStyle(
                                        backgroundColor:
                                            const MaterialStatePropertyAll<
                                                Color>(
                                          Colors.teal,
                                        ),
                                        overlayColor: MaterialStateProperty
                                            .resolveWith<Color>(
                                          (Set<MaterialState> states) {
                                            if (states.contains(
                                                MaterialState.pressed)) {
                                              return const Color(0xFF4e62e0)
                                                  .withOpacity(0.8);
                                            }
                                            return Colors.transparent;
                                          },
                                        ),
                                      ),
                                      child: const Text(
                                        'OK I will turn on the location!',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      onPressed: () {
                                        // Close the dialog
                                        setIsLoaded(true);
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                  },
                  child: !_isFirstLoaded!
                      ? const Text(
                          'Press me to start Scanning',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Press me to re-start Scanning',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 60,
                      left: 10,
                      right: 10,
                      top: 10,
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: TextField(
                        minLines: 5,
                        style: const TextStyle(
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                        ),
                        enabled: false,
                        readOnly: true,
                        maxLines: null, //grow automatically
                        decoration: InputDecoration.collapsed(
                          border: OutlineInputBorder(
                            gapPadding: 5,
                            borderRadius: BorderRadius.circular(3),
                            borderSide: const BorderSide(
                              width: 10,
                              strokeAlign: BorderSide.strokeAlignCenter,
                            ),
                          ),
                          hintText: '',
                          hintStyle:
                              Theme.of(context).primaryTextTheme.titleSmall,
                        ),
                        controller: _logController,
                      ),
                    ),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Future<void> _showNotification(String value) async {
    await startScan();

    if (_notificationShown) {
      await cancelNotifications(0);
    }
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('Astrum', 'Astrum',
            channelDescription: 'People Counter update',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(0, 'People Counter update',
        'Current number of people/devices nearby $value', notificationDetails,
        payload: 'item x');
    _notificationShown = true;
  }

  Future<void> cancelNotifications(int notificationId) async {
    await flutterLocalNotificationsPlugin.cancel(notificationId);
  }

  Future<void> _repeatNotification() async {
    if (_notificationShown) {
      await cancelNotifications(0);
    }
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('Astrum', 'Astrum',
            channelDescription: 'People Counter update');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.periodicallyShow(
      0,
      'People Counter update',
      'Current number of people/devices nearby ${_devicesInRange.length}',
      RepeatInterval.everyMinute,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    _notificationShown = true;
  }
}
