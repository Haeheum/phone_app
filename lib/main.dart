//geolocator 버전

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ===== 위치 관련 필드 ===================
  // 위치 권한 상태
  late LocationPermission _locationPermission;

  // 위치 정보 스트림 구독
  StreamSubscription<Position>? _positionSubscription;

  Position? _currentPosition;

  // 위치 정보 구독중
  bool _locationListening = false;

  // // ===== 블루투스 관련 필드 ===============
  // // Central 매니저
  // final CentralManager _centralManager = CentralManager();
  //
  // // 목표 서비스 UUID
  // final UUID targetServiceUUID = UUID.fromString(
  //   "4fafc201-1fb5-459e-8fcc-c5c9c331914b",
  // );
  //
  // // 찾은 장치 목록
  // final List<DiscoveredEventArgs> _discoveries = [];
  //
  // // BLE 검색중
  // bool _discovering = false;
  //
  // // BLE 연결됨
  // bool _connected = false;

  // 위치 권한 요청
  Future<void> _handleLocationPermission() async {
    // 위치 서비스(GPS) 활성화 확인 및 요청
    bool serviceEnabled;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    log(name: "디버그", "위치 권한 서비스 활성화: $serviceEnabled");
    if (!serviceEnabled) {
      return;
    }



    // 위치 권한 확인 및 요청
    _locationPermission = await Geolocator.requestPermission();
    log(name: "디버그", "위치 권한 상태: $_locationPermission");

    if (_locationPermission == LocationPermission.denied) {
      _locationPermission = await Geolocator.requestPermission();
      if (_locationPermission == LocationPermission.denied) {
        log(name: "디버그", "위치 권한 거부");
        return;
      }
    }

    if (_locationPermission == LocationPermission.deniedForever) {
      log(name: "디버그", "위치 권한 영구 거부");
      return;
    }
  }

  // 위치 정보 수신 시작/중지 토글
  Future<void> _toggleLocationListening() async {
    if (_positionSubscription == null) {
      log(name: "디버그", "위치 정보 수신 시작");
      // 위치 변경 감지 스트림 구독 시작
      _positionSubscription = Geolocator.getPositionStream().listen(
            (Position? position) {
          setState(() {
            _locationListening = true;
            _currentPosition = position;
          });
        },
        onError: (e) {
          log(name: "디버그", "위치 정보 수신 실패");
          setState(() {
            _locationListening = false;
          });
        },
        cancelOnError: true,
      );
    } else {
      log(name: "디버그", "위치 정보 수신 중지");
      _positionSubscription!.cancel(); // 구독 취소
      _positionSubscription = null;
      setState(() {
        _locationListening = false;
      });
    }
  }

  // // BLE 권한 요청
  // Future<void> _handleBLEPermission() async {
  //   _centralManager.authorize();
  // }
  //
  // // BLE 기기 검색 시작
  // Future<void> _startDiscovery({List<UUID>? serviceUUIDs}) async {
  //   if (_discovering) {
  //     return;
  //   }
  //   _discoveries.clear();
  //   await _centralManager.startDiscovery(serviceUUIDs: serviceUUIDs);
  //   _discovering = true;
  // }
  //
  // // BLE 기기 검색 중지
  // Future<void> _stopDiscovery() async {
  //   if (!_discovering) {
  //     return;
  //   }
  //   await _centralManager.stopDiscovery();
  //   _discovering = false;
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("위치 정보 예제")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _handleLocationPermission,
              child: const Text("1. 권한 요청"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _toggleLocationListening,
              child: Text("2. 위치 정보 수신 ${_locationListening ? "중지" : "시작"}"),
            ),
            const SizedBox(height: 16),
            Text(
              "3. 위치 데이터: "
                  "${_currentPosition != null ? "${_currentPosition!.latitude}, ${_currentPosition!.longitude}" : "없음"}",
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel(); // 위젯 종료 시 위치 정보 구독 취소
    super.dispose();
  }
}
