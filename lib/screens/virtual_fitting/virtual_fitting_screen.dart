import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import '../../core/constants/app_colors.dart';


enum FittingGarment {
  shirt,
  dress,
}


class VirtualFittingScreen extends StatefulWidget {
  const VirtualFittingScreen({
    super.key,
  });

  @override
  State<VirtualFittingScreen> createState() =>
      _VirtualFittingScreenState();
}


class _VirtualFittingScreenState
    extends State<VirtualFittingScreen> {

  // =========================================================
  // CÁMARA
  // =========================================================

  CameraController? _cameraController;

  CameraDescription? _cameraDescription;

  bool _isLoading = true;

  String? _errorMessage;


  // =========================================================
  // POSE DETECTION
  // =========================================================

  late final PoseDetector _poseDetector;

  bool _isProcessingPose = false;

  int _frameCounter = 0;

  // Procesamos Pose cada 3 frames para no pelear con Hand Landmarker.
  static const int _poseEveryNFrames = 3;

  Size _inputImageSize = Size.zero;

  Offset? _smoothLeftShoulder;
  Offset? _smoothRightShoulder;
  Offset? _smoothLeftHip;
  Offset? _smoothRightHip;

  static const double _smoothingFactor = 0.30;


  // =========================================================
  // HAND LANDMARKER
  // =========================================================

  HandLandmarkerPlugin? _handPlugin;

  StreamSubscription<List<Hand>>? _handSubscription;

  List<Hand> _hands = const [];

  DateTime? _lastHandDetectedAt;

  // La captura se dispara cuando una mano se mantiene visible.
  DateTime? _handVisibleSince;

  bool _handCaptureLocked = false;

  static const Duration _handHoldDuration =
      Duration(milliseconds: 850);

  static const Duration _handLostResetDelay =
      Duration(milliseconds: 700);


  // =========================================================
  // CAPTURA / PREVIEW
  // =========================================================

  bool _isCountingDown = false;

  bool _isCapturing = false;

  bool _isPreviewMode = false;

  int _countdown = 0;

  String? _capturedPhotoPath;


  // =========================================================
  // VESTIDOR
  // =========================================================

  FittingGarment _selectedGarment =
      FittingGarment.shirt;

  bool _automaticTracking = true;

  bool _showMeasurements = true;

  bool _showBottomControls = true;

  double _manualScale = 1.0;

  double _manualOffsetX = 0.0;

  double _manualOffsetY = 0.0;


  // =========================================================
  // INICIALIZAR
  // =========================================================

  @override
  void initState() {
    super.initState();

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );

    _initializeCameraAndHand();
  }


  // =========================================================
  // INICIALIZAR CÁMARA + MANO
  // =========================================================

  Future<void> _initializeCameraAndHand() async {
    try {
      await SystemChrome.setPreferredOrientations(
        const [
          DeviceOrientation.portraitUp,
        ],
      );

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw StateError(
          'No se encontró ninguna cámara.',
        );
      }

      CameraDescription selectedCamera =
          cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraDescription = selectedCamera;

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      _handPlugin =
          HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.55,
        delegate: HandLandmarkerDelegate.gpu,
      );

      _handSubscription =
          _handPlugin!.landmarkStream.listen(
        _onHandsDetected,
        onError: (
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint(
            '❌ [HAND] landmarkStream error: $error',
          );
        },
      );

      await controller.initialize();

      _cameraController = controller;

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _isLoading = false;
      });

      await controller.startImageStream(
        _processCameraImage,
      );

      debugPrint(
        '✅ [VESTIDOR] cámara + Pose + Hand iniciados',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '❌ [VESTIDOR] error inicializando: $error',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'No se pudo iniciar el vestidor.\n$error';
      });
    }
  }


  // =========================================================
  // UN SOLO STREAM DE CÁMARA
  // =========================================================

  Future<void> _processCameraImage(
    CameraImage image,
  ) async {
    final controller = _cameraController;
    final camera = _cameraDescription;
    final handPlugin = _handPlugin;

    if (
        controller == null ||
        camera == null ||
        handPlugin == null ||
        !controller.value.isInitialized ||
        _isPreviewMode ||
        _isCapturing
    ) {
      return;
    }

    _frameCounter++;


    if (_frameCounter % 60 == 1) {
      debugPrint(
        '🎥 [STREAM] '
        'format=${image.format.group} '
        'planes=${image.planes.length} '
        'size=${image.width}x${image.height}',
      );
    }


    // -------------------------------------------------------
    // 1. MANO
    // -------------------------------------------------------

    try {
      handPlugin.processFrame(
        image,
        camera.sensorOrientation,
      );
    } catch (error) {
      debugPrint(
        '❌ [HAND] processFrame: $error',
      );
    }

    // -------------------------------------------------------
    // 2. CUERPO
    // -------------------------------------------------------
    //
    // Hand Landmarker trabaja async en nativo.
    // Pose lo limitamos para no procesar todos los frames.
    // -------------------------------------------------------

    if (!_automaticTracking) {
      return;
    }

    if (
        _isProcessingPose ||
        _frameCounter % _poseEveryNFrames != 0
    ) {
      return;
    }

    _isProcessingPose = true;

    try {
      final inputImage =
          _inputImageFromCameraImage(
        image,
      );

      if (inputImage == null) {
        return;
      }

      final poses =
          await _poseDetector.processImage(
        inputImage,
      );

      if (!mounted) {
        return;
      }

      if (poses.isEmpty) {
        return;
      }

      _updateSmoothedLandmarks(
        poses.first,
      );


      if (_frameCounter % 30 == 0) {
        debugPrint(
          '🧍 [POSE] CUERPO DETECTADO '
          'landmarks=${poses.first.landmarks.length}',
        );
      }


      setState(() {});
    } catch (error) {
      debugPrint(
        '⚠️ [POSE] frame ignorado: $error',
      );
    } finally {
      _isProcessingPose = false;
    }
  }


  // =========================================================
  // MANO DETECTADA
  // =========================================================

  void _onHandsDetected(
    List<Hand> hands,
  ) {
    if (!mounted) {
      return;
    }

    final now = DateTime.now();

    if (hands.isNotEmpty) {
      _lastHandDetectedAt = now;

      debugPrint(
        '🖐️ [HAND] MANO DETECTADA '
        'landmarks=${hands.first.landmarks.length}',
      );

      _handVisibleSince ??= now;

      final visibleFor =
          now.difference(
        _handVisibleSince!,
      );

      if (
          visibleFor >= _handHoldDuration &&
          !_handCaptureLocked &&
          !_isCountingDown &&
          !_isCapturing &&
          !_isPreviewMode
      ) {
        _handCaptureLocked = true;

        debugPrint(
          '📸 [HAND] mano mantenida -> CAPTURA AUTOMÁTICA',
        );

        _startAutoCapture();
      }
    } else {
      final lastSeen =
          _lastHandDetectedAt;

      if (
          lastSeen == null ||
          now.difference(lastSeen) >
              _handLostResetDelay
      ) {
        _handVisibleSince = null;
      }
    }

    setState(() {
      _hands = hands;
    });
  }


  // =========================================================
  // CAPTURA AUTOMÁTICA
  // =========================================================

  Future<void> _startAutoCapture() async {
    if (
        _isCountingDown ||
        _isCapturing ||
        _isPreviewMode
    ) {
      return;
    }

    setState(() {
      _isCountingDown = true;
    });

    for (int value = 3; value >= 1; value--) {
      if (!mounted) {
        return;
      }

      setState(() {
        _countdown = value;
      });

      await Future<void>.delayed(
        const Duration(
          seconds: 1,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _countdown = 0;
      _isCountingDown = false;
    });

    await _takePictureAndShowPreview();
  }


  Future<void> _takePictureAndShowPreview() async {
    final controller = _cameraController;

    if (
        controller == null ||
        !controller.value.isInitialized ||
        _isCapturing
    ) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      final photo =
          await controller.takePicture();

      if (!mounted) {
        return;
      }

      setState(() {
        _capturedPhotoPath = photo.path;
        _isPreviewMode = true;
        _isCapturing = false;
      });

      debugPrint(
        '✅ [CAPTURE] ${photo.path}',
      );
    } catch (error) {
      debugPrint(
        '❌ [CAPTURE] $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isCapturing = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo tomar la foto: $error',
          ),
        ),
      );

      await _restartStream();
    }
  }


  Future<void> _retake() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isPreviewMode = false;
      _capturedPhotoPath = null;
      _hands = const [];
      _handVisibleSince = null;
      _lastHandDetectedAt = null;
      _handCaptureLocked = false;
    });

    await _restartStream();
  }


  Future<void> _restartStream() async {
    final controller = _cameraController;

    if (
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages
    ) {
      return;
    }

    await controller.startImageStream(
      _processCameraImage,
    );
  }


  // =========================================================
  // CAMERA IMAGE -> INPUT IMAGE PARA ML KIT
  // =========================================================

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
  ) {
    final camera =
        _cameraDescription;

    if (camera == null) {
      return null;
    }

    final rotation =
        _rotationFromCamera(
      camera,
    );

    if (rotation == null) {
      return null;
    }

    _inputImageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    // =======================================================
    // ANDROID
    // =======================================================
    //
    // hand_landmarker trabaja feliz con YUV_420_888.
    //
    // ML Kit Flutter, en cambio, espera NV21 cuando construimos
    // InputImage desde bytes en Android.
    //
    // Por eso mantenemos la cámara en YUV420 para la mano
    // y convertimos SOLO los frames que van a Pose a NV21.
    // =======================================================

    if (Platform.isAndroid) {
      try {
        final Uint8List nv21Bytes =
            _convertYuv420ToNv21(
          image,
        );

        return InputImage.fromBytes(
          bytes:
              nv21Bytes,

          metadata:
              InputImageMetadata(
            size:
                _inputImageSize,

            rotation:
                rotation,

            format:
                InputImageFormat.nv21,

            // En Android no es relevante para NV21,
            // pero dejamos un valor coherente.
            bytesPerRow:
                image.width,
          ),
        );
      } catch (error) {
        debugPrint(
          '❌ [POSE] Error convirtiendo YUV420 -> NV21: $error',
        );

        return null;
      }
    }

    // =======================================================
    // IOS
    // =======================================================

    if (Platform.isIOS) {
      if (image.planes.length != 1) {
        return null;
      }

      final plane =
          image.planes.first;

      final format =
          InputImageFormatValue.fromRawValue(
        image.format.raw,
      );

      if (
          format == null
          || format != InputImageFormat.bgra8888
      ) {
        return null;
      }

      return InputImage.fromBytes(
        bytes:
            plane.bytes,

        metadata:
            InputImageMetadata(
          size:
              _inputImageSize,

          rotation:
              rotation,

          format:
              format,

          bytesPerRow:
              plane.bytesPerRow,
        ),
      );
    }

    return null;
  }


  // =========================================================
  // YUV_420_888 -> NV21
  // =========================================================
  //
  // CameraX normalmente entrega 3 planos:
  // Y, U, V.
  //
  // NV21 necesita:
  // YYYYYYYY... + VUVUVU...
  //
  // Respetamos bytesPerRow y bytesPerPixel para funcionar
  // correctamente aunque el dispositivo use padding.
  // =========================================================

  Uint8List _convertYuv420ToNv21(
    CameraImage image,
  ) {
    final width =
        image.width;

    final height =
        image.height;


    // Algunos backends pueden entregar ya un único plano.
    // En ese caso usamos directamente los bytes.
    if (image.planes.length == 1) {
      return Uint8List.fromList(
        image.planes.first.bytes,
      );
    }


    if (image.planes.length < 3) {
      throw StateError(
        'Formato YUV inesperado: ${image.planes.length} planos.',
      );
    }


    final yPlane =
        image.planes[0];

    final uPlane =
        image.planes[1];

    final vPlane =
        image.planes[2];


    final int ySize =
        width * height;

    final int uvSize =
        width * height ~/ 2;


    final nv21 =
        Uint8List(
      ySize + uvSize,
    );


    // -------------------------------------------------------
    // COPIAR Y
    // -------------------------------------------------------

    int outputIndex =
        0;

    final int yRowStride =
        yPlane.bytesPerRow;

    final int yPixelStride =
        yPlane.bytesPerPixel ?? 1;


    for (
      int row = 0;
      row < height;
      row++
    ) {
      final int rowStart =
          row * yRowStride;

      for (
        int col = 0;
        col < width;
        col++
      ) {
        final int sourceIndex =
            rowStart
            + col * yPixelStride;

        if (
            sourceIndex
            < yPlane.bytes.length
        ) {
          nv21[outputIndex++] =
              yPlane.bytes[
                sourceIndex
              ];
        } else {
          nv21[outputIndex++] =
              0;
        }
      }
    }


    // -------------------------------------------------------
    // COPIAR VU INTERCALADO
    // -------------------------------------------------------

    final int uvWidth =
        width ~/ 2;

    final int uvHeight =
        height ~/ 2;

    final int uRowStride =
        uPlane.bytesPerRow;

    final int vRowStride =
        vPlane.bytesPerRow;

    final int uPixelStride =
        uPlane.bytesPerPixel ?? 1;

    final int vPixelStride =
        vPlane.bytesPerPixel ?? 1;


    for (
      int row = 0;
      row < uvHeight;
      row++
    ) {
      for (
        int col = 0;
        col < uvWidth;
        col++
      ) {
        final int uIndex =
            row * uRowStride
            + col * uPixelStride;

        final int vIndex =
            row * vRowStride
            + col * vPixelStride;


        final int vValue =
            vIndex < vPlane.bytes.length
                ? vPlane.bytes[vIndex]
                : 128;

        final int uValue =
            uIndex < uPlane.bytes.length
                ? uPlane.bytes[uIndex]
                : 128;


        nv21[outputIndex++] =
            vValue;

        nv21[outputIndex++] =
            uValue;
      }
    }


    return nv21;
  }


  InputImageRotation? _rotationFromCamera(
    CameraDescription camera,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(
        camera.sensorOrientation,
      );
    }

    final controller =
        _cameraController;

    if (controller == null) {
      return null;
    }

    const orientations =
        <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    final deviceRotation =
        orientations[
          controller.value.deviceOrientation
        ];

    if (deviceRotation == null) {
      return null;
    }

    int rotationCompensation;

    if (
        camera.lensDirection ==
        CameraLensDirection.front
    ) {
      rotationCompensation =
          (
            camera.sensorOrientation +
            deviceRotation
          ) % 360;
    } else {
      rotationCompensation =
          (
            camera.sensorOrientation -
            deviceRotation +
            360
          ) % 360;
    }

    return InputImageRotationValue.fromRawValue(
      rotationCompensation,
    );
  }


  // =========================================================
  // LANDMARKS DEL CUERPO
  // =========================================================

  void _updateSmoothedLandmarks(
    Pose pose,
  ) {
    final leftShoulder =
        pose.landmarks[
          PoseLandmarkType.leftShoulder
        ];

    final rightShoulder =
        pose.landmarks[
          PoseLandmarkType.rightShoulder
        ];

    final leftHip =
        pose.landmarks[
          PoseLandmarkType.leftHip
        ];

    final rightHip =
        pose.landmarks[
          PoseLandmarkType.rightHip
        ];

    if (
        leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null
    ) {
      return;
    }

    _smoothLeftShoulder =
        _smoothOffset(
      _smoothLeftShoulder,
      Offset(
        leftShoulder.x,
        leftShoulder.y,
      ),
    );

    _smoothRightShoulder =
        _smoothOffset(
      _smoothRightShoulder,
      Offset(
        rightShoulder.x,
        rightShoulder.y,
      ),
    );

    _smoothLeftHip =
        _smoothOffset(
      _smoothLeftHip,
      Offset(
        leftHip.x,
        leftHip.y,
      ),
    );

    _smoothRightHip =
        _smoothOffset(
      _smoothRightHip,
      Offset(
        rightHip.x,
        rightHip.y,
      ),
    );
  }


  Offset _smoothOffset(
    Offset? oldValue,
    Offset newValue,
  ) {
    if (oldValue == null) {
      return newValue;
    }

    return Offset(
      _lerpDouble(
        oldValue.dx,
        newValue.dx,
        _smoothingFactor,
      ),
      _lerpDouble(
        oldValue.dy,
        newValue.dy,
        _smoothingFactor,
      ),
    );
  }


  double _lerpDouble(
    double a,
    double b,
    double t,
  ) {
    return a + (b - a) * t;
  }


  // =========================================================
  // AJUSTES
  // =========================================================

  void _resetAdjustments() {
    setState(() {
      _manualScale = 1.0;
      _manualOffsetX = 0.0;
      _manualOffsetY = 0.0;
    });
  }


  void _selectGarment(
    FittingGarment garment,
  ) {
    setState(() {
      _selectedGarment = garment;
      _manualScale = 1.0;
      _manualOffsetX = 0.0;
      _manualOffsetY = 0.0;
    });
  }


  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _handSubscription?.cancel();

    final controller =
        _cameraController;

    if (
        controller != null &&
        controller.value.isStreamingImages
    ) {
      controller.stopImageStream();
    }

    controller?.dispose();

    _handPlugin?.dispose();

    _poseDetector.close();

    super.dispose();
  }


  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final viewportSize =
                Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            if (_isPreviewMode) {
              return _buildPreview(
                viewportSize,
              );
            }

            return _buildLiveView(
              viewportSize,
            );
          },
        ),
      ),
    );
  }


  // =========================================================
  // LIVE VIEW
  // =========================================================

  Widget _buildLiveView(
    Size viewportSize,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCamera(),

        if (
            !_isLoading &&
            _errorMessage == null
        )
          _buildTrackingLayer(
            viewportSize,
          ),

        _buildTopBar(
          isPreview: false,
        ),

        if (
            !_isLoading &&
            _errorMessage == null
        )
          _buildGarmentSelector(),

        if (
            !_isLoading &&
            _errorMessage == null
        )
          _buildTechPanel(
            viewportSize,
          ),

        if (
            !_isLoading &&
            _errorMessage == null &&
            _showBottomControls
        )
          _buildBottomControls(),

        if (
            !_isLoading &&
            _errorMessage == null
        )
          _buildBottomControlsToggle(),

        if (_isCountingDown)
          _buildCountdownOverlay(),

        if (_isCapturing)
          _buildCapturingOverlay(),
      ],
    );
  }


  // =========================================================
  // PREVIEW
  // =========================================================

  Widget _buildPreview(
    Size viewportSize,
  ) {
    final pose =
        _mapSmoothedPoseToViewport(
      viewportSize,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_capturedPhotoPath != null)
          Image.file(
            File(
              _capturedPhotoPath!,
            ),
            fit: BoxFit.cover,
          )
        else
          const ColoredBox(
            color: Colors.black,
          ),

        if (pose != null) ...[
          if (_showMeasurements)
            IgnorePointer(
              child: CustomPaint(
                painter:
                    _PoseTechPainter(
                  pose: pose,
                ),
              ),
            ),

          _buildGarmentOverlay(
            pose,
            allowDrag: false,
          ),
        ],

        _buildTopBar(
          isPreview: true,
        ),

        Positioned(
          top: 72,
          left: 16,
          right: 16,
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration:
                _glassDecoration(),
            child:
                const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color:
                      Colors.greenAccent,
                ),
                SizedBox(
                  width: 8,
                ),
                Text(
                  'CAPTURA AUTOMÁTICA LISTA',
                  style:
                      TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: Row(
            children: [
              Expanded(
                child:
                    FilledButton.icon(
                  onPressed: _retake,
                  icon: const Icon(
                    Icons.replay,
                  ),
                  label: const Text(
                    'REPETIR',
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child:
                    FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger
                        .of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Captura aceptada.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.check,
                  ),
                  label: const Text(
                    'LISTO',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  // =========================================================
  // CÁMARA
  // =========================================================

  Widget _buildCamera() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final controller =
        _cameraController;

    if (
        controller == null ||
        !controller.value.isInitialized
    ) {
      return const Center(
        child: Text(
          'Cámara no disponible',
          style: TextStyle(
            color:
                AppColors.textPrimary,
          ),
        ),
      );
    }

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller
                .value
                .previewSize!
                .height,
            height: controller
                .value
                .previewSize!
                .width,
            child:
                CameraPreview(
              controller,
            ),
          ),
        ),
      ),
    );
  }


  // =========================================================
  // TRACKING
  // =========================================================

  Widget _buildTrackingLayer(
    Size viewportSize,
  ) {
    final pose =
        _mapSmoothedPoseToViewport(
      viewportSize,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (pose != null) ...[
          if (_showMeasurements)
            IgnorePointer(
              child: CustomPaint(
                painter:
                    _PoseTechPainter(
                  pose: pose,
                ),
              ),
            ),

          _buildGarmentOverlay(
            pose,
          ),
        ],

        // Mostramos los puntos de la mano para confirmar que
        // el detector que ya te funcionó sigue activo.
        if (_hands.isNotEmpty &&
            _cameraController != null)
          IgnorePointer(
            child: CustomPaint(
              painter:
                  _HandDebugPainter(
                hands: _hands,
                previewSize:
                    _cameraController!
                        .value
                        .previewSize!,
                lensDirection:
                    _cameraController!
                        .description
                        .lensDirection,
                sensorOrientation:
                    _cameraController!
                        .description
                        .sensorOrientation,
              ),
            ),
          ),
      ],
    );
  }


  _MappedPose? _mapSmoothedPoseToViewport(
    Size viewportSize,
  ) {
    final leftShoulder =
        _smoothLeftShoulder;

    final rightShoulder =
        _smoothRightShoulder;

    final leftHip =
        _smoothLeftHip;

    final rightHip =
        _smoothRightHip;

    if (
        leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        _inputImageSize.width <= 0 ||
        _inputImageSize.height <= 0
    ) {
      return null;
    }

    Offset mapPoint(
      Offset point,
    ) {
      double x =
          point.dx /
          _inputImageSize.width;

      double y =
          point.dy /
          _inputImageSize.height;

      if (
          _cameraDescription
                  ?.lensDirection ==
              CameraLensDirection.front
      ) {
        x = 1.0 - x;
      }

      x = x.clamp(
        0.0,
        1.0,
      );

      y = y.clamp(
        0.0,
        1.0,
      );

      return Offset(
        x * viewportSize.width,
        y * viewportSize.height,
      );
    }

    final ls =
        mapPoint(leftShoulder);

    final rs =
        mapPoint(rightShoulder);

    final lh =
        mapPoint(leftHip);

    final rh =
        mapPoint(rightHip);

    final shoulderCenter =
        Offset(
      (ls.dx + rs.dx) / 2,
      (ls.dy + rs.dy) / 2,
    );

    final hipCenter =
        Offset(
      (lh.dx + rh.dx) / 2,
      (lh.dy + rh.dy) / 2,
    );

    final shoulderWidth =
        _distanceBetween(
      ls,
      rs,
    );

    final hipWidth =
        _distanceBetween(
      lh,
      rh,
    );

    final torsoHeight =
        _distanceBetween(
      shoulderCenter,
      hipCenter,
    );

    final rotation =
        math.atan2(
      rs.dy - ls.dy,
      rs.dx - ls.dx,
    );

    return _MappedPose(
      leftShoulder: ls,
      rightShoulder: rs,
      leftHip: lh,
      rightHip: rh,
      shoulderCenter:
          shoulderCenter,
      hipCenter: hipCenter,
      shoulderWidth:
          shoulderWidth,
      hipWidth: hipWidth,
      torsoHeight: torsoHeight,
      rotation: rotation,
    );
  }


  double _distanceBetween(
    Offset a,
    Offset b,
  ) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;

    return math.sqrt(
      dx * dx + dy * dy,
    );
  }


  // =========================================================
  // PRENDA
  // =========================================================

  Widget _buildGarmentOverlay(
    _MappedPose pose, {
    bool allowDrag = true,
  }) {
    final isShirt =
        _selectedGarment ==
        FittingGarment.shirt;

    final assetPath =
        isShirt
            ? 'assets/images/polera.png'
            : 'assets/images/vestido.png';

    final widthFactor =
        isShirt ? 1.75 : 1.58;

    final garmentWidth =
        pose.shoulderWidth *
        widthFactor *
        _manualScale;

    final garmentCenterX =
        pose.shoulderCenter.dx +
        _manualOffsetX;

    final topOffsetFactor =
        isShirt ? 0.15 : 0.10;

    final garmentTop =
        pose.shoulderCenter.dy -
        garmentWidth *
            topOffsetFactor +
        _manualOffsetY;

    final image =
        Image.asset(
      assetPath,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );

    return Positioned(
      left:
          garmentCenterX -
          garmentWidth / 2,
      top: garmentTop,
      width: garmentWidth,
      child: Transform.rotate(
        angle: pose.rotation,
        alignment:
            Alignment.topCenter,
        child: allowDrag
            ? GestureDetector(
                onPanUpdate:
                    (details) {
                  setState(() {
                    _manualOffsetX +=
                        details.delta.dx;
                    _manualOffsetY +=
                        details.delta.dy;
                  });
                },
                child: image,
              )
            : image,
      ),
    );
  }


  // =========================================================
  // TOP BAR
  // =========================================================

  Widget _buildTopBar({
    required bool isPreview,
  }) {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Row(
        children: [
          _glassCircleButton(
            icon: isPreview
                ? Icons.close
                : Icons.arrow_back,
            onPressed: () {
              if (isPreview) {
                _retake();
              } else {
                Navigator.of(context)
                    .maybePop();
              }
            },
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration:
                  _glassDecoration(),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    isPreview
                        ? Icons.photo_camera_back_outlined
                        : Icons.center_focus_strong,
                    color:
                        Colors.cyanAccent,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Flexible(
                    child: Text(
                      isPreview
                          ? 'PREVIEW DE CAPTURA'
                          : 'FASHIONSTORE • BODY + HAND AI',
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        letterSpacing:
                            0.8,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          _glassCircleButton(
            icon: Icons.refresh,
            onPressed:
                _resetAdjustments,
          ),
        ],
      ),
    );
  }


  // =========================================================
  // SELECTOR PRENDA
  // =========================================================

  Widget _buildGarmentSelector() {
    return Positioned(
      top: 66,
      left: 16,
      right: 16,
      child: Container(
        padding:
            const EdgeInsets.all(6),
        decoration:
            _glassDecoration(),
        child: Row(
          children: [
            Expanded(
              child:
                  _garmentButton(
                label: 'POLERA',
                icon:
                    Icons.checkroom_outlined,
                garment:
                    FittingGarment.shirt,
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child:
                  _garmentButton(
                label: 'VESTIDO',
                icon:
                    Icons.woman_2_outlined,
                garment:
                    FittingGarment.dress,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _garmentButton({
    required String label,
    required IconData icon,
    required FittingGarment garment,
  }) {
    final selected =
        _selectedGarment == garment;

    return InkWell(
      borderRadius:
          BorderRadius.circular(14),
      onTap: () {
        _selectGarment(
          garment,
        );
      },
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        padding:
            const EdgeInsets.symmetric(
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.cyanAccent
                  .withValues(
                    alpha: 0.18,
                  )
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.cyanAccent
                : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? Colors.cyanAccent
                  : Colors.white70,
              size: 20,
            ),
            const SizedBox(
              width: 8,
            ),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.cyanAccent
                    : Colors.white,
                fontWeight:
                    FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // =========================================================
  // PANEL TECNOLÓGICO
  // =========================================================

  Widget _buildTechPanel(
    Size viewportSize,
  ) {
    final pose =
        _mapSmoothedPoseToViewport(
      viewportSize,
    );

    return Positioned(
      top: 126,
      right: 16,
      child: Container(
        width: 178,
        padding:
            const EdgeInsets.all(12),
        decoration:
            _glassDecoration(),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.memory,
                  color:
                      Colors.cyanAccent,
                  size: 16,
                ),
                SizedBox(
                  width: 7,
                ),
                Text(
                  'BODY + HAND AI',
                  style: TextStyle(
                    color:
                        Colors.cyanAccent,
                    fontWeight:
                        FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            _techRow(
              'CUERPO',
              pose == null
                  ? 'BUSCANDO'
                  : 'TRACKING',
            ),
            _techRow(
              'MANO',
              _hands.isEmpty
                  ? 'BUSCANDO'
                  : 'DETECTADA',
            ),
            _techRow(
              'HOMBROS',
              pose == null
                  ? '--'
                  : '${pose.shoulderWidth.toStringAsFixed(0)} px',
            ),
            _techRow(
              'TORSO',
              pose == null
                  ? '--'
                  : '${pose.torsoHeight.toStringAsFixed(0)} px',
            ),
          ],
        ),
      ),
    );
  }


  Widget _techRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 5,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
                const TextStyle(
              color: Colors.white54,
              fontSize: 9,
            ),
          ),
          Text(
            value,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  // =========================================================
  // CONTROLES INFERIORES
  // =========================================================

  Widget _buildBottomControls() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 54,
      child: Container(
        padding:
            const EdgeInsets.all(14),
        decoration:
            _glassDecoration(
          strong: true,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      _toggleButton(
                    icon:
                        Icons.auto_awesome_motion,
                    label: 'AUTO',
                    value:
                        _automaticTracking,
                    onChanged:
                        (value) {
                      setState(() {
                        _automaticTracking =
                            value;
                      });
                    },
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child:
                      _toggleButton(
                    icon:
                        Icons.analytics_outlined,
                    label:
                        'MEDICIÓN',
                    value:
                        _showMeasurements,
                    onChanged:
                        (value) {
                      setState(() {
                        _showMeasurements =
                            value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                const Text(
                  'ESCALA',
                  style: TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value:
                        _manualScale,
                    min: 0.65,
                    max: 1.45,
                    onChanged:
                        (value) {
                      setState(() {
                        _manualScale =
                            value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(_manualScale * 100).round()}%',
                    textAlign:
                        TextAlign.right,
                    style:
                        const TextStyle(
                      color:
                          Colors.cyanAccent,
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              '🖐️ Muestra la mano ~1 segundo → 3, 2, 1 → captura automática.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // =========================================================
  // MINI BOTÓN MOSTRAR / OCULTAR
  // =========================================================

  Widget _buildBottomControlsToggle() {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Center(
        child: InkWell(
          borderRadius:
              BorderRadius.circular(20),
          onTap: () {
            setState(() {
              _showBottomControls =
                  !_showBottomControls;
            });
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 7,
            ),
            decoration:
                _glassDecoration(),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  _showBottomControls
                      ? Icons
                          .keyboard_arrow_down
                      : Icons
                          .keyboard_arrow_up,
                  color:
                      Colors.cyanAccent,
                  size: 18,
                ),
                const SizedBox(
                  width: 5,
                ),
                Text(
                  _showBottomControls
                      ? 'MINIMIZAR'
                      : 'MOSTRAR',
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _toggleButton({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(12),
      onTap: () {
        onChanged(!value);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? Colors.cyanAccent
                : Colors.white24,
          ),
          color: value
              ? Colors.cyanAccent
                  .withValues(
                    alpha: 0.12,
                  )
              : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: value
                  ? Colors.cyanAccent
                  : Colors.white60,
            ),
            const SizedBox(
              width: 7,
            ),
            Text(
              label,
              style: TextStyle(
                color: value
                    ? Colors.cyanAccent
                    : Colors.white70,
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // =========================================================
  // COUNTDOWN / CAPTURANDO
  // =========================================================

  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black
            .withValues(
          alpha: 0.30,
        ),
        child: Center(
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black
                  .withValues(
                alpha: 0.72,
              ),
              border: Border.all(
                color:
                    Colors.cyanAccent,
                width: 2,
              ),
            ),
            alignment:
                Alignment.center,
            child: Text(
              '$_countdown',
              style:
                  const TextStyle(
                color:
                    Colors.cyanAccent,
                fontSize: 64,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildCapturingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black
            .withValues(
          alpha: 0.40,
        ),
        child:
            const Center(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(
                height: 14,
              ),
              Text(
                'Tomando captura...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // =========================================================
  // COMPONENTES
  // =========================================================

  Widget _glassCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration:
          _glassDecoration(
        circle: true,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
        ),
      ),
    );
  }


  BoxDecoration _glassDecoration({
    bool strong = false,
    bool circle = false,
  }) {
    return BoxDecoration(
      color: Colors.black
          .withValues(
        alpha:
            strong ? 0.78 : 0.58,
      ),
      borderRadius: circle
          ? null
          : BorderRadius.circular(18),
      shape: circle
          ? BoxShape.circle
          : BoxShape.rectangle,
      border: Border.all(
        color:
            Colors.cyanAccent.withValues(
          alpha: 0.28,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black
              .withValues(
            alpha: 0.25,
          ),
          blurRadius: 18,
          offset:
              const Offset(0, 6),
        ),
      ],
    );
  }
}


// ===========================================================
// DATOS DEL CUERPO
// ===========================================================

class _MappedPose {
  const _MappedPose({
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftHip,
    required this.rightHip,
    required this.shoulderCenter,
    required this.hipCenter,
    required this.shoulderWidth,
    required this.hipWidth,
    required this.torsoHeight,
    required this.rotation,
  });

  final Offset leftShoulder;
  final Offset rightShoulder;
  final Offset leftHip;
  final Offset rightHip;
  final Offset shoulderCenter;
  final Offset hipCenter;
  final double shoulderWidth;
  final double hipWidth;
  final double torsoHeight;
  final double rotation;
}


// ===========================================================
// PAINTER DEL CUERPO
// ===========================================================

class _PoseTechPainter
    extends CustomPainter {
  const _PoseTechPainter({
    required this.pose,
  });

  final _MappedPose pose;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final linePaint =
        Paint()
          ..color =
              Colors.cyanAccent
                  .withValues(
                alpha: 0.85,
              )
          ..strokeWidth = 1.5
          ..style =
              PaintingStyle.stroke;

    final softPaint =
        Paint()
          ..color =
              Colors.cyanAccent
                  .withValues(
                alpha: 0.25,
              )
          ..strokeWidth = 1.0
          ..style =
              PaintingStyle.stroke;

    final pointPaint =
        Paint()
          ..color =
              Colors.cyanAccent
          ..style =
              PaintingStyle.fill;

    canvas.drawLine(
      pose.leftShoulder,
      pose.rightShoulder,
      linePaint,
    );

    canvas.drawLine(
      pose.leftShoulder,
      pose.leftHip,
      softPaint,
    );

    canvas.drawLine(
      pose.rightShoulder,
      pose.rightHip,
      softPaint,
    );

    canvas.drawLine(
      pose.leftHip,
      pose.rightHip,
      linePaint,
    );

    canvas.drawLine(
      pose.shoulderCenter,
      pose.hipCenter,
      softPaint,
    );

    _drawPoint(
      canvas,
      pose.leftShoulder,
      'LS',
      pointPaint,
    );

    _drawPoint(
      canvas,
      pose.rightShoulder,
      'RS',
      pointPaint,
    );

    _drawPoint(
      canvas,
      pose.leftHip,
      'LH',
      pointPaint,
    );

    _drawPoint(
      canvas,
      pose.rightHip,
      'RH',
      pointPaint,
    );

    final shoulderMid =
        Offset(
      (
        pose.leftShoulder.dx +
        pose.rightShoulder.dx
      ) / 2,
      (
        pose.leftShoulder.dy +
        pose.rightShoulder.dy
      ) / 2 - 18,
    );

    _drawLabel(
      canvas,
      shoulderMid,
      'SHOULDER ${pose.shoulderWidth.toStringAsFixed(0)} px',
    );

    final torsoMid =
        Offset(
      pose.hipCenter.dx + 20,
      (
        pose.shoulderCenter.dy +
        pose.hipCenter.dy
      ) / 2,
    );

    _drawLabel(
      canvas,
      torsoMid,
      'TORSO ${pose.torsoHeight.toStringAsFixed(0)} px',
    );
  }

  void _drawPoint(
    Canvas canvas,
    Offset point,
    String label,
    Paint paint,
  ) {
    canvas.drawCircle(
      point,
      5,
      paint,
    );

    canvas.drawCircle(
      point,
      10,
      Paint()
        ..color =
            Colors.cyanAccent
                .withValues(
              alpha: 0.22,
            )
        ..style =
            PaintingStyle.fill,
    );

    _drawLabel(
      canvas,
      Offset(
        point.dx + 8,
        point.dy - 18,
      ),
      label,
    );
  }

  void _drawLabel(
    Canvas canvas,
    Offset position,
    String text,
  ) {
    final textPainter =
        TextPainter(
      text: TextSpan(
        text: text,
        style:
            const TextStyle(
          color:
              Colors.cyanAccent,
          fontSize: 9,
          fontWeight:
              FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      textDirection:
          TextDirection.ltr,
    );

    textPainter.layout();

    final background =
        Rect.fromLTWH(
      position.dx - 4,
      position.dy - 3,
      textPainter.width + 8,
      textPainter.height + 6,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        background,
        const Radius.circular(5),
      ),
      Paint()
        ..color =
            Colors.black.withValues(
          alpha: 0.68,
        ),
    );

    textPainter.paint(
      canvas,
      position,
    );
  }

  @override
  bool shouldRepaint(
    covariant _PoseTechPainter oldDelegate,
  ) {
    return true;
  }
}


// ===========================================================
// PAINTER DE MANO
// ===========================================================

class _HandDebugPainter
    extends CustomPainter {
  const _HandDebugPainter({
    required this.hands,
    required this.previewSize,
    required this.lensDirection,
    required this.sensorOrientation,
  });

  final List<Hand> hands;
  final Size previewSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  static const List<List<int>>
      _connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [0, 17],
    [17, 18],
    [18, 19],
    [19, 20],
  ];

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (hands.isEmpty) {
      return;
    }

    final scale =
        size.width /
        previewSize.height;

    final pointPaint =
        Paint()
          ..color =
              Colors.orangeAccent
          ..strokeWidth =
              7 / scale
          ..strokeCap =
              StrokeCap.round;

    final linePaint =
        Paint()
          ..color =
              Colors.greenAccent
          ..strokeWidth =
              3 / scale;

    canvas.save();

    final center =
        Offset(
      size.width / 2,
      size.height / 2,
    );

    canvas.translate(
      center.dx,
      center.dy,
    );

    canvas.rotate(
      sensorOrientation *
          math.pi /
          180,
    );

    if (
        lensDirection ==
        CameraLensDirection.front
    ) {
      canvas.scale(
        -1,
        1,
      );

      canvas.rotate(
        math.pi,
      );
    }

    canvas.scale(scale);

    final logicalWidth =
        previewSize.width;

    final logicalHeight =
        previewSize.height;

    for (final hand in hands) {
      for (
        final landmark
        in hand.landmarks
      ) {
        final dx =
            (landmark.x - 0.5) *
            logicalWidth;

        final dy =
            (landmark.y - 0.5) *
            logicalHeight;

        canvas.drawCircle(
          Offset(dx, dy),
          7 / scale,
          pointPaint,
        );
      }

      for (
        final connection
        in _connections
      ) {
        final start =
            hand.landmarks[
              connection[0]
            ];

        final end =
            hand.landmarks[
              connection[1]
            ];

        final startDx =
            (start.x - 0.5) *
            logicalWidth;

        final startDy =
            (start.y - 0.5) *
            logicalHeight;

        final endDx =
            (end.x - 0.5) *
            logicalWidth;

        final endDy =
            (end.y - 0.5) *
            logicalHeight;

        canvas.drawLine(
          Offset(
            startDx,
            startDy,
          ),
          Offset(
            endDx,
            endDy,
          ),
          linePaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(
    covariant _HandDebugPainter oldDelegate,
  ) {
    return true;
  }
}
