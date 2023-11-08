import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ble_scanner.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    Key? key,
  }) : super(key: key);

  static const String routeName = '/settings-screen';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double sliderValue = 1;

  void setDistanceLimit(double value) {
    Provider.of<BleScanner>(context, listen: false).setDistanceLimit(value);
  }

  void getDistanceLimit() {
    setState(() {
      sliderValue =
          Provider.of<BleScanner>(context, listen: false).getDistanceLimit();
    });
  }

  void clearDevices() {
    Provider.of<BleScanner>(context, listen: false).clearDevices();
    Provider.of<BleScanner>(context, listen: false).clearDevicesRssi();
  }

  @override
  void initState() {
    getDistanceLimit();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Image.asset('assets/icons/app_icon.png'),
            onPressed: () {
              Navigator.of(context).pushNamed(AboutScreen.routeName);
            },
          ),
          title: const Text('         People Counter BLE'),
          backgroundColor: Colors.teal,
          actions: <Widget>[
            IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                })
          ],
        ),
        body: Column(
          children: <Widget>[
            const SizedBox(
              height: 100,
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Application settings',
                textScaleFactor: 1.6,
                style: TextStyle(
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: <Widget>[
                const Text('Adjust distance for nearby devices discovery:'),
                const SizedBox(
                  height: 10,
                ),
                Slider(
                  value: sliderValue,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${sliderValue.toString()} m',
                  onChanged: (double value) {
                    setState(() {
                      sliderValue = value;
                      setDistanceLimit(sliderValue);
                      clearDevices();
                    });
                  },
                ),
              ],
            )
          ],
        ),
      );
}
