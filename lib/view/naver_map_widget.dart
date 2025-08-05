import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class NaverMapWidget extends StatelessWidget {
  const NaverMapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final safeAreaPadding = MediaQuery.paddingOf(context);

    return NaverMap(
      options: NaverMapViewOptions(
        contentPadding: safeAreaPadding,
        initialCameraPosition: NCameraPosition(target: NLatLng(0, 0), zoom: 14),
        locationButtonEnable: true,
      ),
      onMapReady: (controller) async {
        NLatLng? myLocation = await controller.myLocationTracker
            .startLocationService();
        controller.updateCamera(NCameraUpdate.withParams(target: myLocation));
        final marker = NMarker(
          id: "my_location", // Required
          position: myLocation ?? NLatLng(0, 0), // Required
          caption: NOverlayCaption(text: "현재 위치"), // Optional
        );
        controller.addOverlay(marker);
      },
      onMapTapped: (nPoint, nLatLng) {
        _showAlertDialog(
          context: context,
          title: "목적지 설정",
          content: "(${nLatLng.latitude}, ${nLatLng.longitude})",
          onPressed: (){
            // todo : 블루투스로 목적지 좌표 전송
          }
        );
      },
    );
  }

  Future<void> _showAlertDialog({
    required BuildContext context,
    required String title,
    required String content,
    VoidCallback? onPressed,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
                onPressed?.call();
              },
            ),
          ],
        );
      },
    );
  }
}
