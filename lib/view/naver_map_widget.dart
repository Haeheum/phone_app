import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:phone_app/constants.dart';
import 'package:phone_app/manager/bluetooth_manager.dart';
import 'package:phone_app/manager/location_manager.dart';
import 'package:google_places_autocomplete/google_places_autocomplete.dart';

class NaverMapWidget extends StatefulWidget {
  const NaverMapWidget({super.key});

  @override
  State<NaverMapWidget> createState() => _NaverMapWidgetState();
}

class _NaverMapWidgetState extends State<NaverMapWidget> {
  final TextEditingController _searchController = TextEditingController();
  late GooglePlacesAutocomplete _placesService;

  // 검색 결과 상태 관리 변수
  List<Prediction> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _placesService = GooglePlacesAutocomplete(
      apiKey: googleApiKey,
      predictionsListner: (predictions) {
        setState(() {
          _searchResults = predictions;
          _isLoading = false;
        });
      },
      loadingListner: (isLoading) {
        setState(() {
          _isLoading = isLoading;
        });
      },
    );
    _placesService.initialize();
  }

  void _searchAndMoveMap(String query) async {
    if (query.isEmpty) {
      _clearSearchResults();
      return;
    }
    _placesService.getPredictions(query);
  }

  void _onResultTapped(Prediction result) async {
    _searchController.clear();
    _clearSearchResults();

    final details = await _placesService.getPredictionDetail(result.placeId ?? '');

    if (details != null && details.geometry != null) {
      final lat = details.geometry!.location?.lat;
      final lng = details.geometry!.location?.lng;

      if (lat != null && lng != null) {
        // 지도 이동 및 마커 추가
        LocationManager.instance.mapController?.updateCamera(
          NCameraUpdate.withParams(target: NLatLng(lat, lng)),
        );
        _addDestinationMarker(NLatLng(lat, lng));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소 정보를 불러오는 데 실패했습니다.')),
      );
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
    final bool showSearchResults = _searchController.text.isNotEmpty && _searchResults.isNotEmpty;
    // 검색 후 결과가 없을 경우를 판단합니다.
    final bool noResults = _searchController.text.isNotEmpty && _searchResults.isEmpty && !_isLoading;

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
        if (showSearchResults)
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  title: Text(result.description ?? ''),
                  onTap: () => _onResultTapped(result),
                );
              },
            ),
          )
        else if (noResults)
          const Expanded(
            child: Center(
              child: Text("검색 결과가 없습니다."),
            ),
          )
        else
          Expanded(
            child: NaverMap(
              options: NaverMapViewOptions(
                contentPadding: safeAreaPadding,
                initialCameraPosition:
                const NCameraPosition(target: NLatLng(0, 0), zoom: 14),
                locationButtonEnable: true,
              ),
              onMapReady: (controller) async {
                locationManager.mapController = controller;
                NLatLng? myLocation =
                await controller.myLocationTracker.startLocationService();
                controller
                    .updateCamera(NCameraUpdate.withParams(target: myLocation));
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
                          BluetoothManager.instance
                              .sendCurrentLocation(lastKnownLocation);
                        }
                        BluetoothManager.instance.sendDestination(nLatLng);
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