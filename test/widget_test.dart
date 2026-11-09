
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FashionStore - Pruebas iniciales', () {
    test('Nombre de la aplicacion', () {
      const appName = 'FashionStore';
      expect(appName, equals('FashionStore'));
    });

    test('Estados de sincronizacion offline', () {
      const states = {
        'LOCAL_PENDING',
        'SYNCED',
        'CONFLICT',
        'REJECTED',
      };

      expect(states.length, equals(4));
    });
  });
}
