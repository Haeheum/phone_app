import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:phone_app/view/naver_map_widget.dart';
import 'package:phone_app/view/show_current_warning_widget.dart';

import 'manager/bluetooth_manager.dart';
import 'manager/location_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterNaverMap().init(
    clientId: 'g34s5gobge',
    onAuthFailed: (ex) {
      switch (ex) {
        case NQuotaExceededException(:final message):
          log(name: "디버그", "사용량 초과 : $message");
          break;
        case NUnauthorizedClientException() ||
            NClientUnspecifiedException() ||
            NAnotherAuthFailedException():
          log(name: "디버그", "인증 실패 : $ex");
          break;
      }
    },
  );
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final LocationManager _locationManager = LocationManager();
  final BluetoothManager _bluetoothManager = BluetoothManager();

  @override
  void initState() {
    super.initState();
    _bluetoothManager.initialize();
    _locationManager.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                  _bluetoothManager.startScan();
                },
                icon: const Icon(Icons.search),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ValueListenableBuilder<List<ScanResult>>(
          valueListenable: _bluetoothManager.scanResults,
          builder: (_, results, _) {
            return RefreshIndicator(
              onRefresh: () => _bluetoothManager.startScan(),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const DrawerHeader(
                    decoration: BoxDecoration(color: Colors.blue),
                    child: Center(
                      child: Text(
                        '블루투스 기기',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ),
                  ),
                  if (results.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          '검색된 기기가 없습니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ...results.map((result) {
                    return ListTile(
                      title: Text(result.device.platformName),
                      subtitle: Text(result.device.remoteId.str),
                      trailing: ElevatedButton(
                        onPressed: () {
                          _bluetoothManager.tryConnect(result.device);
                          Navigator.of(context).pop();
                        },
                        child: const Text('연결'),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
      onDrawerChanged: (isOpened) {
        if (!isOpened) {
          _bluetoothManager.stopScan();
        }
      },
      body: ValueListenableBuilder<bool>(
        valueListenable: _locationManager.hasLocationPermission,
        builder: (_, hasLocationPermission, __) {
          if (!hasLocationPermission) {
            return ShowCurrentWarning(
              message: '위치 권한 확인',
              onPressed: _locationManager.requestPermission,
            );
          }

          return ValueListenableBuilder<bool>(
            valueListenable: _bluetoothManager.isBleOn,
            builder: (_, isBleOn, __) {
              if (!isBleOn) {
                return ShowCurrentWarning(
                  message: '블루투스 확인',
                  onPressed: _bluetoothManager.turnOn,
                );
              }

              return NaverMapWidget();
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _locationManager.dispose();
    _bluetoothManager.dispose();
    super.dispose();
  }
}
