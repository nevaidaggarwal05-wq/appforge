// TODO: flutterfire configure
// This file is a compile-only placeholder so `flutter analyze` passes
// before Firebase has been configured. To fill it in, run:
//
//   flutterfire configure --project=<your-shared-firebase-project>
//
// That will overwrite this file with real values for every platform.
// Until then the app will crash at FirebaseApp.configure() — which is
// expected; we only run that after Phase 5 deployment is complete.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS:     return ios;
      case TargetPlatform.macOS:   return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported on this platform. '
          'Run `flutterfire configure`.',
        );
    }
  }

  // REPLACE — flutterfire configure fills these in
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            '', // REPLACE
    appId:             '', // REPLACE
    messagingSenderId: '', // REPLACE
    projectId:         '', // REPLACE
    storageBucket:     '', // REPLACE
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            '', // REPLACE
    appId:             '', // REPLACE
    messagingSenderId: '', // REPLACE
    projectId:         '', // REPLACE
    storageBucket:     '', // REPLACE
    iosBundleId:       '', // REPLACE
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey:            '', // REPLACE
    appId:             '', // REPLACE
    messagingSenderId: '', // REPLACE
    projectId:         '', // REPLACE
    storageBucket:     '', // REPLACE
    iosBundleId:       '', // REPLACE
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            '', // REPLACE
    appId:             '', // REPLACE
    messagingSenderId: '', // REPLACE
    projectId:         '', // REPLACE
    authDomain:        '', // REPLACE
    storageBucket:     '', // REPLACE
  );
}
