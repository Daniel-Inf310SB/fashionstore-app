import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hand_landmarker/hand_landmarker.dart';


/// Gestos que entiende FashionStore.
enum HandGestureType {
  none,
  openPalm,
}


/// Servicio dedicado a MediaPipe Hand Landmarker.
///
/// IMPORTANTE PARA DEPURACIÓN:
/// En consola verás:
///
///   🖐️ [HAND] MANO DETECTADA
///   ✋ [HAND] PALMA ABIERTA
///
/// Si nunca aparece "MANO DETECTADA", el problema está antes
/// de nuestra lógica de gesto (plugin / frames / dispositivo).
///
/// Si aparece "MANO DETECTADA" pero nunca "PALMA ABIERTA",
/// entonces MediaPipe funciona y solo debemos ajustar la regla
/// que clasifica la palma.
class HandGestureService {
  HandGestureService({
    this.holdDuration =
        const Duration(
      milliseconds:
          650,
    ),

    this.cooldown =
        const Duration(
      seconds:
          5,
    ),
  });


  final Duration holdDuration;

  final Duration cooldown;


  HandLandmarkerPlugin? _plugin;

  StreamSubscription<List<Hand>>?
      _landmarkSubscription;


  final StreamController<HandGestureType>
      _gestureController =
      StreamController<HandGestureType>.broadcast();


  bool _initialized =
      false;


  DateTime? _openPalmStartedAt;

  DateTime? _lastTriggerAt;


  HandGestureType _lastGesture =
      HandGestureType.none;


  // Evita llenar Logcat con 30-60 mensajes por segundo.
  DateTime? _lastHandConsoleLog;

  DateTime? _lastPalmConsoleLog;


  bool get isInitialized =>
      _initialized;


  HandGestureType get lastGesture =>
      _lastGesture;


  Stream<HandGestureType> get gestureStream =>
      _gestureController.stream;


  // =========================================================
  // INICIALIZAR
  // =========================================================

  void initialize() {

    if (_initialized) {
      return;
    }


    debugPrint(
      '🤖 [HAND] Inicializando Hand Landmarker...',
    );


    _plugin =
        HandLandmarkerPlugin.create(
      numHands:
          1,

      // Un poco más permisivo para la prueba.
      // Cuando funcione bien podemos volver a 0.70.
      minHandDetectionConfidence:
          0.55,

      delegate:
          HandLandmarkerDelegate.gpu,
    );


    _landmarkSubscription =
        _plugin!
            .landmarkStream
            .listen(

      _handleHands,

      onError:
          (
            Object error,
            StackTrace stackTrace,
          ) {

        debugPrint(
          '❌ [HAND] Error en landmarkStream: $error',
        );


        _resetOpenPalmProgress();

      },

    );


    _initialized =
        true;


    debugPrint(
      '✅ [HAND] Hand Landmarker inicializado.',
    );

  }


  // =========================================================
  // RECIBIR FRAME
  // =========================================================

  void processFrame(
    CameraImage image,
    int sensorOrientation,
  ) {

    if (
        !_initialized
        || _plugin == null
    ) {
      return;
    }


    try {

      // API 3.x: fire-and-forget.
      // El resultado llega por landmarkStream.
      _plugin!.processFrame(
        image,
        sensorOrientation,
      );

    } catch (error) {

      debugPrint(
        '❌ [HAND] Error enviando frame: $error',
      );

    }

  }


  // =========================================================
  // RESULTADOS DE MEDIAPIPE
  // =========================================================

  void _handleHands(
    List<Hand> hands,
  ) {

    if (hands.isEmpty) {

      _setGesture(
        HandGestureType.none,
      );


      _resetOpenPalmProgress();


      return;

    }


    // Si llegamos aquí, MediaPipe SÍ encontró una mano.
    _logHandDetected();


    final hand =
        hands.first;


    final isOpenPalm =
        _isOpenPalm(
      hand,
    );


    if (!isOpenPalm) {

      _setGesture(
        HandGestureType.none,
      );


      _resetOpenPalmProgress();


      return;

    }


    _logPalmDetected();


    final now =
        DateTime.now();


    _openPalmStartedAt ??=
        now;


    final elapsed =
        now.difference(
      _openPalmStartedAt!,
    );


    if (
        elapsed
        < holdDuration
    ) {
      return;
    }


    if (_lastTriggerAt != null) {

      final sinceLast =
          now.difference(
        _lastTriggerAt!,
      );


      if (
          sinceLast
          < cooldown
      ) {
        return;
      }

    }


    _lastTriggerAt =
        now;


    _openPalmStartedAt =
        null;


    debugPrint(
      '📸 [HAND] PALMA MANTENIDA -> CAPTURA',
    );


    _setGesture(
      HandGestureType.openPalm,
      forceEmit:
          true,
    );

  }


  // =========================================================
  // LOGS
  // =========================================================

  void _logHandDetected() {

    final now =
        DateTime.now();


    if (
        _lastHandConsoleLog == null
        || now.difference(
              _lastHandConsoleLog!,
            )
            >=
            const Duration(
              milliseconds:
                  700,
            )
    ) {

      _lastHandConsoleLog =
          now;


      debugPrint(
        '🖐️ [HAND] MANO DETECTADA',
      );

    }

  }


  void _logPalmDetected() {

    final now =
        DateTime.now();


    if (
        _lastPalmConsoleLog == null
        || now.difference(
              _lastPalmConsoleLog!,
            )
            >=
            const Duration(
              milliseconds:
                  500,
            )
    ) {

      _lastPalmConsoleLog =
          now;


      debugPrint(
        '✋ [HAND] PALMA ABIERTA',
      );

    }

  }


  // =========================================================
  // CLASIFICAR PALMA ABIERTA
  // =========================================================

  bool _isOpenPalm(
    Hand hand,
  ) {

    final landmarks =
        hand.landmarks;


    if (
        landmarks.length
        < 21
    ) {

      debugPrint(
        '⚠️ [HAND] Landmarks incompletos: ${landmarks.length}',
      );


      return false;

    }


    int extendedFingers =
        0;


    if (_fingerExtended(
      landmarks,
      wristIndex:
          0,
      mcpIndex:
          5,
      pipIndex:
          6,
      tipIndex:
          8,
    )) {
      extendedFingers++;
    }


    if (_fingerExtended(
      landmarks,
      wristIndex:
          0,
      mcpIndex:
          9,
      pipIndex:
          10,
      tipIndex:
          12,
    )) {
      extendedFingers++;
    }


    if (_fingerExtended(
      landmarks,
      wristIndex:
          0,
      mcpIndex:
          13,
      pipIndex:
          14,
      tipIndex:
          16,
    )) {
      extendedFingers++;
    }


    if (_fingerExtended(
      landmarks,
      wristIndex:
          0,
      mcpIndex:
          17,
      pipIndex:
          18,
      tipIndex:
          20,
    )) {
      extendedFingers++;
    }


    // Para la prueba hacemos la regla más tolerante:
    // 3 de los 4 dedos largos extendidos ya cuenta como palma.
    //
    // Así podremos confirmar primero que TODO el flujo funciona.
    // Luego la hacemos más estricta.
    return extendedFingers >= 3;

  }


  bool _fingerExtended(
    List<Landmark> landmarks, {
    required int wristIndex,
    required int mcpIndex,
    required int pipIndex,
    required int tipIndex,
  }) {

    final wrist =
        landmarks[wristIndex];

    final mcp =
        landmarks[mcpIndex];

    final pip =
        landmarks[pipIndex];

    final tip =
        landmarks[tipIndex];


    final wristToTip =
        _distance(
      wrist,
      tip,
    );


    final wristToPip =
        _distance(
      wrist,
      pip,
    );


    final mcpToTip =
        _distance(
      mcp,
      tip,
    );


    final mcpToPip =
        _distance(
      mcp,
      pip,
    );


    return wristToTip
            > wristToPip
                * 1.05
        && mcpToTip
            > mcpToPip
                * 1.20;

  }


  double _distance(
    Landmark a,
    Landmark b,
  ) {

    final dx =
        b.x - a.x;

    final dy =
        b.y - a.y;


    return math.sqrt(
      dx * dx
      + dy * dy,
    );

  }


  // =========================================================
  // ESTADO
  // =========================================================

  void _setGesture(
    HandGestureType gesture, {
    bool forceEmit = false,
  }) {

    if (
        !forceEmit
        && gesture
            == _lastGesture
    ) {
      return;
    }


    _lastGesture =
        gesture;


    if (
        !_gestureController.isClosed
    ) {

      _gestureController.add(
        gesture,
      );

    }

  }


  void _resetOpenPalmProgress() {

    _openPalmStartedAt =
        null;

  }


  void resetGestureLatch() {

    _openPalmStartedAt =
        null;


    _lastGesture =
        HandGestureType.none;

  }


  // =========================================================
  // CERRAR
  // =========================================================

  Future<void> dispose() async {

    await _landmarkSubscription
        ?.cancel();


    _plugin?.dispose();


    _plugin =
        null;


    _initialized =
        false;


    await _gestureController.close();

  }

}
