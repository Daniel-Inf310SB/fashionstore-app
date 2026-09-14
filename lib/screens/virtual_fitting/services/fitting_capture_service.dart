import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';


/// Se encarga de convertir un RepaintBoundary en PNG.
///
/// En FashionStore lo usamos DESPUÉS de tomar la foto real
/// de la cámara y mostrarla como Image.file detrás de la prenda.
/// Así la captura final contiene:
///
/// - foto de la cámara
/// - polera / vestido
/// - líneas de medición
/// - overlay visual del vestidor
class FittingCaptureService {

  // =========================================================
  // CAPTURAR REPAINT BOUNDARY
  // =========================================================

  Future<String> captureBoundary(
    GlobalKey boundaryKey, {
    double pixelRatio = 2.0,
  }) async {

    // Aseguramos que Flutter haya terminado de pintar el preview.
    await WidgetsBinding.instance.endOfFrame;


    final context =
        boundaryKey.currentContext;


    if (context == null) {
      throw StateError(
        'No se encontró el RepaintBoundary del preview.',
      );
    }


    final renderObject =
        context.findRenderObject();


    if (renderObject
        is! RenderRepaintBoundary) {

      throw StateError(
        'El widget indicado no es un RenderRepaintBoundary.',
      );

    }


    final ui.Image image =
        await renderObject.toImage(
      pixelRatio:
          pixelRatio,
    );


    final byteData =
        await image.toByteData(
      format:
          ui.ImageByteFormat.png,
    );


    image.dispose();


    if (byteData == null) {
      throw StateError(
        'No se pudo convertir el preview a PNG.',
      );
    }


    final bytes =
        byteData.buffer.asUint8List();


    final directory =
        await getApplicationDocumentsDirectory();


    final capturesDirectory =
        Directory(
      '${directory.path}/FashionStoreCaptures',
    );


    if (!await capturesDirectory.exists()) {

      await capturesDirectory.create(
        recursive:
            true,
      );

    }


    final timestamp =
        DateTime.now()
            .millisecondsSinceEpoch;


    final file =
        File(
      '${capturesDirectory.path}/fitting_$timestamp.png',
    );


    await file.writeAsBytes(
      bytes,
      flush:
          true,
    );


    return file.path;

  }

}
