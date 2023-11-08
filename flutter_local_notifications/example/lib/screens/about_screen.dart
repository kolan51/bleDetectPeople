import 'package:flutter/material.dart';

import 'home_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({
    Key? key,
  }) : super(key: key);

  static const String routeName = '/about-screen';

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Image.asset('assets/icons/app_icon.png'),
            onPressed: () {},
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
                  Navigator.of(context).pushNamed(HomePage.routeName);
                })
          ],
        ),
        body: const Column(
          children: <Widget>[
            SizedBox(
              height: 100,
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'About the authors',
                  textScaleFactor: 1.6,
                  style: TextStyle(
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Column(
              children: <Widget>[
                Text('Developed by Astrum'),
                SizedBox(
                  height: 10,
                ),
                Text('ver 1.0'),
                SizedBox(
                  height: 10,
                ),
                Icon(Icons.face),
              ],
            )
          ],
        ),
      );
}
