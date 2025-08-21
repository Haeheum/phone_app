import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:phone_app/constants.dart';
import 'package:phone_app/manager/bluetooth_manager.dart';
import 'package:phone_app/manager/location_manager.dart';
import 'package:http/http.dart' as http;

class NaverMapWidget extends StatefulWidget {
  const NaverMapWidget({super.key});

  @override
  State<NaverMapWidget> createState() => _NaverMapWidgetState();
}

class _NaverMapWidgetState extends State<NaverMapWidget> {
  final TextEditingController _searchController = TextEditingController();

  // 검색 결과 상태 관리 변수
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  NLatLng? nLatLng;

  @override
  void initState() {
    super.initState();
    nLatLng = LocationManager().lastKnownLocation;
  }

  // 장소 검색을 위한 HTTP 요청 함수
  void _searchAndMoveMap(String query) async {
    if (query.isEmpty) {
      _clearSearchResults();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'language': 'ko',
        'components': 'country:kr',
        'key': googleApiKey,
      },
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data['predictions'] ?? [];
          _isLoading = false;
        });
      } else {
        log(name: '장소 검색 오류', '응답 코드: ${response.statusCode}');
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      log(name: '장소 검색 오류', '오류: $e');
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  // 장소 상세 정보를 가져오는 HTTP 요청 함수
  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {'place_id': placeId, 'key': googleApiKey},
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'];
      } else {
        log(name: '장소 상세 정보 오류', '응답 코드: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log(name: '장소 상세 정보 오류', '오류: $e');
      return null;
    }
  }

  void _onResultTapped(Map<String, dynamic> result) async {
    final placeId = result['place_id'];
    if (placeId == null) return;

    _searchController.clear();
    _clearSearchResults();

    final details = await _getPlaceDetails(placeId);

    if (details != null) {
      final lat = details['geometry']['location']['lat'];
      final lng = details['geometry']['location']['lng'];

      if (lat != null && lng != null) {
        nLatLng = NLatLng(lat, lng);

        // 지도 이동 및 마커 추가
        LocationManager.instance.mapController?.updateCamera(
          NCameraUpdate.withParams(target: nLatLng),
        );
        _addDestinationMarker(nLatLng!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        BluetoothManager.instance.isBleConnected.value
            ? SnackBar(
                content: Text(
                  'Latitude: ${nLatLng!.latitude}\nLongitude: ${nLatLng!.longitude}',
                ),
                action: SnackBarAction(
                  label: "목적지 전송",
                  onPressed: () async {
                    final lastKnownLocation =
                        LocationManager.instance.lastKnownLocation;
                    if (lastKnownLocation != null) {
                      BluetoothManager.instance.sendCurrentLocation(
                        lastKnownLocation,
                      );
                    }
                    BluetoothManager.instance.sendDestination(nLatLng!);
                  },
                ),
              )
            : const SnackBar(
                content: Text("블루투스 기기를 연결해 주세요"),
                showCloseIcon: true,
              ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('장소 정보를 불러오는 데 실패했습니다.')));
    }
  }

  void _clearSearchResults() {
    setState(() {
      _searchResults = [];
    });
  }

  void _addDestinationMarker(NLatLng nLatLng) {
    final marker = NMarker(
      id: "destination",
      position: nLatLng,
      caption: const NOverlayCaption(text: "목적지"),
    );
    LocationManager.instance.mapController!.addOverlay(marker);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationManager = LocationManager.instance;
    final safeAreaPadding = MediaQuery.paddingOf(context);

    // 검색 결과 화면을 보여줄지 지도 화면을 보여줄지 결정합니다.
    final bool showSearchResults =
        _searchController.text.isNotEmpty && _searchResults.isNotEmpty;
    // 검색 후 결과가 없을 경우를 판단합니다.
    final bool noResults =
        _searchController.text.isNotEmpty &&
        _searchResults.isEmpty &&
        !_isLoading;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            onChanged: (text) {
              _searchAndMoveMap(text);
            },
            decoration: InputDecoration(
              hintText: '장소 검색',
              suffixIcon: IconButton(
                icon: (_searchController.text.isNotEmpty)
                    ? const Icon(Icons.close)
                    : const Icon(Icons.search),
                onPressed: () {
                  _searchController.clear();
                  _clearSearchResults();
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (showSearchResults)
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  title: Text(result['structured_formatting']['main_text']),
                  subtitle: Text(
                    result['structured_formatting']['secondary_text'] ?? '',
                  ),
                  onTap: () => _onResultTapped(result),
                );
              },
            ),
          )
        else if (noResults)
          const Expanded(child: Center(child: Text("검색 결과가 없습니다.")))
        else
          Expanded(
            child: NaverMap(
              options: NaverMapViewOptions(
                contentPadding: safeAreaPadding,
                initialCameraPosition: NCameraPosition(
                  target:
                      locationManager.lastKnownLocation ?? const NLatLng(0, 0),
                  zoom: 14,
                ),
                locationButtonEnable: true,
              ),
              onMapReady: (controller) async {
                locationManager.mapController = controller;
                NLatLng? myLocation = locationManager.lastKnownLocation;
                controller.updateCamera(
                  NCameraUpdate.withParams(target: myLocation),
                );
                final marker = NMarker(
                  id: "origin",
                  position: myLocation ?? const NLatLng(0, 0),
                  caption: const NOverlayCaption(text: "출발지"),
                );
                controller.addOverlay(marker);
              },
              onMapTapped: (nPoint, nLatLng) {
                _addDestinationMarker(nLatLng);
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  BluetoothManager.instance.isBleConnected.value
                      ? SnackBar(
                          content: Text(
                            'Latitude: ${nLatLng.latitude}\nLongitude: ${nLatLng.longitude}',
                          ),
                          action: SnackBarAction(
                            label: "목적지 전송",
                            onPressed: () async {
                              final lastKnownLocation =
                                  LocationManager.instance.lastKnownLocation;
                              if (lastKnownLocation != null) {
                                BluetoothManager.instance.sendCurrentLocation(
                                  lastKnownLocation,
                                );
                              }
                              BluetoothManager.instance.sendDestination(
                                nLatLng,
                              );
                            },
                          ),
                        )
                      : const SnackBar(
                          content: Text("블루투스 기기를 연결해 주세요"),
                          showCloseIcon: true,
                        ),
                );
              },
            ),
          ),
      ],
    );
  }
}
