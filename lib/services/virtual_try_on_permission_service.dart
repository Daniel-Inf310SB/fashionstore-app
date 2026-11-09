import 'package:permission_handler/permission_handler.dart';

class VirtualTryOnPermissionService {
  VirtualTryOnPermissionService._();

  static Future<CameraPermissionResult>
      requestCamera() async {
    var status = await Permission.camera.status;

    if (status.isGranted) {
      return const CameraPermissionResult.granted();
    }

    status = await Permission.camera.request();

    if (status.isGranted) {
      return const CameraPermissionResult.granted();
    }

    if (status.isPermanentlyDenied) {
      return const CameraPermissionResult.permanentlyDenied();
    }

    return const CameraPermissionResult.denied();
  }

  static Future<bool> openSystemSettings() {
    return openAppSettings();
  }
}

enum CameraPermissionState {
  granted,
  denied,
  permanentlyDenied,
}

class CameraPermissionResult {
  const CameraPermissionResult._(
    this.state,
  );

  const CameraPermissionResult.granted()
      : this._(CameraPermissionState.granted);

  const CameraPermissionResult.denied()
      : this._(CameraPermissionState.denied);

  const CameraPermissionResult.permanentlyDenied()
      : this._(
          CameraPermissionState.permanentlyDenied,
        );

  final CameraPermissionState state;

  bool get isGranted =>
      state == CameraPermissionState.granted;

  bool get isPermanentlyDenied =>
      state ==
      CameraPermissionState.permanentlyDenied;
}
