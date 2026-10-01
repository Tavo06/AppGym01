import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Configuración de Firebase generada por FlutterFire CLI.
///
/// Valores reales para Android, Web y Windows (proyecto `fitprogress-f232f`).
/// iOS y macOS siguen sin configurar: para habilitarlas, ejecuta de nuevo
/// `flutterfire configure` y selecciona esas plataformas.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDrv9PmHNODhChfpevwKitX5e1oQHA3fuE',
    appId: '1:996263447499:android:06af9603ab5419741d444e',
    messagingSenderId: '996263447499',
    projectId: 'fitprogress-f232f',
    storageBucket: 'fitprogress-f232f.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REEMPLAZAR_CON_FLUTTERFIRE',
    appId: 'REEMPLAZAR_CON_FLUTTERFIRE',
    messagingSenderId: 'REEMPLAZAR_CON_FLUTTERFIRE',
    projectId: 'REEMPLAZAR_CON_FLUTTERFIRE',
    storageBucket: 'REEMPLAZAR_CON_FLUTTERFIRE.appspot.com',
    iosBundleId: 'com.fitprogress.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBL3Js6PnxRdeRgrIlnG8ap1wyDtJbldes',
    appId: '1:996263447499:web:a1c9f259916c11111d444e',
    messagingSenderId: '996263447499',
    projectId: 'fitprogress-f232f',
    authDomain: 'fitprogress-f232f.firebaseapp.com',
    storageBucket: 'fitprogress-f232f.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBL3Js6PnxRdeRgrIlnG8ap1wyDtJbldes',
    appId: '1:996263447499:web:24acd261c5a0f5291d444e',
    messagingSenderId: '996263447499',
    projectId: 'fitprogress-f232f',
    authDomain: 'fitprogress-f232f.firebaseapp.com',
    storageBucket: 'fitprogress-f232f.firebasestorage.app',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REEMPLAZAR_CON_FLUTTERFIRE',
    appId: 'REEMPLAZAR_CON_FLUTTERFIRE',
    messagingSenderId: 'REEMPLAZAR_CON_FLUTTERFIRE',
    projectId: 'REEMPLAZAR_CON_FLUTTERFIRE',
    storageBucket: 'REEMPLAZAR_CON_FLUTTERFIRE.appspot.com',
  );
}
