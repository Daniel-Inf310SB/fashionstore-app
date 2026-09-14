import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hand_landmarker/hand_landmarker.dart';


class HandOnlyTestScreen extends StatefulWidget {
  const HandOnlyTestScreen({
    super.key,
  });

  @override
  State<HandOnlyTestScreen> createState() =>
      _HandOnlyTestScreenState();
}


class _HandOnlyTestScreenState
    extends State<HandOnlyTestScreen> {

  CameraController? _controller;

  HandLandmarkerPlugin? _plugin;

  StreamSubscription<List<Hand>>?
      _handSubscription;

  bool _isInitialized = false;

  bool _isStarting = true;

  String? _errorMessage;

  List<Hand> _hands = const [];

  int _frameCounter = 0;

  DateTime? _lastFrameLog;

  DateTime? _lastHandLog;


  @override
  void initState() {
    super.initState();

    _initialize();
  }


  // =========================================================
  // INICIALIZAR
  // =========================================================

  Future<void> _initialize() async {

    try {

      await SystemChrome
          .setPreferredOrientations(
        const [
          DeviceOrientation.portraitUp,
        ],
      );


      debugPrint(
        '🤖 [HAND TEST] buscando cámaras...',
      );


      final cameras =
          await availableCameras();


      if (cameras.isEmpty) {

        throw StateError(
          'No se encontraron cámaras.',
        );

      }


      final camera =
          cameras.firstWhere(
        (cam) =>
            cam.lensDirection
            == CameraLensDirection.front,

        orElse:
            () => cameras.first,
      );


      debugPrint(
        '📷 [HAND TEST] cámara seleccionada: '
        '${camera.lensDirection} '
        'orientation=${camera.sensorOrientation}',
      );


      _controller =
          CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );


      debugPrint(
        '🤖 [HAND TEST] creando HandLandmarker...',
      );


      _plugin =
          HandLandmarkerPlugin.create(
        numHands:
            2,

        minHandDetectionConfidence:
            0.55,

        delegate:
            HandLandmarkerDelegate.gpu,
      );


      _handSubscription =
          _plugin!
              .landmarkStream
              .listen(
        _onHandsDetected,

        onError:
            (
              Object error,
              StackTrace stackTrace,
            ) {

          debugPrint(
            '❌ [HAND TEST] landmarkStream error: $error',
          );

        },
      );


      await _controller!
          .initialize();


      if (!mounted) {
        return;
      }


      setState(() {

        _isInitialized =
            true;

        _isStarting =
            false;

      });


      debugPrint(
        '✅ [HAND TEST] cámara inicializada.',
      );


      await _controller!
          .startImageStream(
        _processCameraImage,
      );


      debugPrint(
        '✅ [HAND TEST] image stream iniciado.',
      );

    } catch (error, stackTrace) {

      debugPrint(
        '❌ [HAND TEST] ERROR: $error',
      );

      debugPrint(
        '$stackTrace',
      );


      if (!mounted) {
        return;
      }


      setState(() {

        _isStarting =
            false;

        _errorMessage =
            error.toString();

      });

    }

  }


  // =========================================================
  // PROCESAR FRAME
  // =========================================================

  Future<void> _processCameraImage(
    CameraImage image,
  ) async {

    final plugin =
        _plugin;

    final controller =
        _controller;


    if (
        !_isInitialized
        || plugin == null
        || controller == null
    ) {
      return;
    }


    _frameCounter++;


    final now =
        DateTime.now();


    if (
        _lastFrameLog == null
        || now.difference(
              _lastFrameLog!,
            )
            >=
            const Duration(
              seconds:
                  2,
            )
    ) {

      _lastFrameLog =
          now;


      debugPrint(
        '🎞️ [HAND TEST] enviando frames... '
        'count=$_frameCounter '
        'format=${image.format.group} '
        'planes=${image.planes.length} '
        'size=${image.width}x${image.height}',
      );

    }


    try {

      plugin.processFrame(
        image,
        controller
            .description
            .sensorOrientation,
      );

    } catch (error) {

      debugPrint(
        '❌ [HAND TEST] processFrame error: $error',
      );

    }

  }


  // =========================================================
  // MANOS DETECTADAS
  // =========================================================

  void _onHandsDetected(
    List<Hand> hands,
  ) {

    final now =
        DateTime.now();


    if (hands.isEmpty) {

      if (
          _lastHandLog == null
          || now.difference(
                _lastHandLog!,
              )
              >=
              const Duration(
                seconds:
                    1,
              )
      ) {

        _lastHandLog =
            now;


        debugPrint(
          '👀 [HAND TEST] resultado recibido: 0 manos',
        );

      }

    } else {

      _lastHandLog =
          now;


      debugPrint(
        '🖐️ [HAND TEST] MANO DETECTADA '
        'cantidad=${hands.length} '
        'landmarks=${hands.first.landmarks.length}',
      );

    }


    if (!mounted) {
      return;
    }


    setState(() {

      _hands =
          hands;

    });

  }


  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {

    _handSubscription
        ?.cancel();


    final controller =
        _controller;


    if (
        controller != null
        && controller.value.isStreamingImages
    ) {

      controller.stopImageStream();

    }


    controller?.dispose();


    _plugin?.dispose();


    super.dispose();

  }


  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    if (_isStarting) {

      return const Scaffold(
        backgroundColor:
            Colors.black,

        body:
            Center(
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [

              CircularProgressIndicator(),

              SizedBox(
                height:
                    16,
              ),

              Text(
                'Inicializando prueba de mano...',
                style:
                    TextStyle(
                  color:
                      Colors.white,
                ),
              ),

            ],
          ),
        ),
      );

    }


    if (_errorMessage != null) {

      return Scaffold(
        backgroundColor:
            Colors.black,

        body:
            SafeArea(
          child:
              Center(
            child:
                Padding(
              padding:
                  const EdgeInsets.all(
                24,
              ),

              child:
                  Text(
                'ERROR\n\n$_errorMessage',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.redAccent,
                  fontSize:
                      16,
                ),
              ),

            ),
          ),
        ),
      );

    }


    final controller =
        _controller;


    if (
        controller == null
        || !controller.value.isInitialized
    ) {

      return const Scaffold(
        backgroundColor:
            Colors.black,

        body:
            Center(
          child:
              Text(
            'Cámara no inicializada',
            style:
                TextStyle(
              color:
                  Colors.white,
            ),
          ),
        ),
      );

    }


    final previewSize =
        controller
            .value
            .previewSize!;


    final previewAspectRatio =
        previewSize.height
        / previewSize.width;


    return Scaffold(
      backgroundColor:
          Colors.black,

      body:
          SafeArea(
        child:
            Column(
          children: [

            // =================================================
            // ESTADO
            // =================================================

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    16,

                vertical:
                    14,
              ),

              color:
                  _hands.isEmpty
                      ? Colors.orange
                          .withValues(
                            alpha:
                                0.18,
                          )
                      : Colors.green
                          .withValues(
                            alpha:
                                0.20,
                          ),

              child:
                  Column(
                children: [

                  Text(
                    _hands.isEmpty
                        ? '👀 BUSCANDO MANO'
                        : '🖐️ MANO DETECTADA',

                    style:
                        TextStyle(
                      color:
                          _hands.isEmpty
                              ? Colors.orangeAccent
                              : Colors.greenAccent,

                      fontSize:
                          18,

                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),


                  const SizedBox(
                    height:
                        4,
                  ),


                  Text(
                    'manos=${_hands.length} • frames=$_frameCounter',

                    style:
                        const TextStyle(
                      color:
                          Colors.white70,
                      fontSize:
                          12,
                    ),
                  ),

                ],
              ),
            ),


            // =================================================
            // CÁMARA
            // =================================================

            Expanded(
              child:
                  Center(
                child:
                    AspectRatio(
                  aspectRatio:
                      previewAspectRatio,

                  child:
                      Stack(
                    fit:
                        StackFit.expand,

                    children: [

                      CameraPreview(
                        controller,
                      ),


                      StreamBuilder<List<Hand>>(
                        stream:
                            _plugin!
                                .landmarkStream,

                        initialData:
                            const [],

                        builder:
                            (
                              context,
                              snapshot,
                            ) {

                          final hands =
                              snapshot.data
                              ?? const <Hand>[];


                          return CustomPaint(
                            size:
                                Size.infinite,

                            painter:
                                HandTestPainter(
                              hands:
                                  hands,

                              previewSize:
                                  previewSize,

                              lensDirection:
                                  controller
                                      .description
                                      .lensDirection,

                              sensorOrientation:
                                  controller
                                      .description
                                      .sensorOrientation,
                            ),
                          );

                        },
                      ),

                    ],
                  ),
                ),
              ),
            ),


            // =================================================
            // INSTRUCCIÓN
            // =================================================

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                16,
              ),

              child:
                  const Text(
                'Pon una mano abierta frente a la cámara.\n'
                'Si funciona, aparecerán puntos y líneas sobre los dedos.',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      Colors.white70,
                  fontSize:
                      13,
                ),
              ),
            ),

          ],
        ),
      ),
    );

  }

}


// ===========================================================
// PAINTER DE LANDMARKS
// Basado en el ejemplo oficial de hand_landmarker 3.0.1
// ===========================================================

class HandTestPainter
    extends CustomPainter {

  HandTestPainter({
    required this.hands,
    required this.previewSize,
    required this.lensDirection,
    required this.sensorOrientation,
  });


  final List<Hand> hands;

  final Size previewSize;

  final CameraLensDirection lensDirection;

  final int sensorOrientation;


  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {

    final scale =
        size.width
        / previewSize.height;


    final pointPaint =
        Paint()
          ..color =
              Colors.redAccent
          ..strokeWidth =
              8 / scale
          ..strokeCap =
              StrokeCap.round;


    final linePaint =
        Paint()
          ..color =
              Colors.cyanAccent
          ..strokeWidth =
              4 / scale;


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
      sensorOrientation
      * math.pi
      / 180,
    );


    if (
        lensDirection
        == CameraLensDirection.front
    ) {

      canvas.scale(
        -1,
        1,
      );


      canvas.rotate(
        math.pi,
      );

    }


    canvas.scale(
      scale,
    );


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
            (
              landmark.x
              - 0.5
            )
            * logicalWidth;

        final dy =
            (
              landmark.y
              - 0.5
            )
            * logicalHeight;


        canvas.drawCircle(
          Offset(
            dx,
            dy,
          ),
          8 / scale,
          pointPaint,
        );

      }


      for (
        final connection
        in HandLandmarkConnections
            .connections
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
            (
              start.x
              - 0.5
            )
            * logicalWidth;

        final startDy =
            (
              start.y
              - 0.5
            )
            * logicalHeight;

        final endDx =
            (
              end.x
              - 0.5
            )
            * logicalWidth;

        final endDy =
            (
              end.y
              - 0.5
            )
            * logicalHeight;


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
    covariant CustomPainter oldDelegate,
  ) {

    return true;

  }

}


// ===========================================================
// CONEXIONES DE LOS 21 PUNTOS DE LA MANO
// ===========================================================

class HandLandmarkConnections {

  static const List<List<int>>
      connections = [

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

}
