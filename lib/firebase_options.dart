import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCZxxcSOSHFMD4sxlf-X1I4wx9rZQleEo4',
    appId: '1:702698165636:web:5d0ed175063e9e5d1fb9d1',
    messagingSenderId: '702698165636',
    projectId: 'carpoolingapp2025',
    authDomain: 'carpoolingapp2025.firebaseapp.com',
    storageBucket: 'carpoolingapp2025.firebasestorage.app',
    measurementId: 'G-LW5SWWP6NX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDS8tmdKRGpZxsed9HTwO64QtXYMZm0fmw',
    appId: '1:702698165636:android:7826342124af4b261fb9d1',
    messagingSenderId: '702698165636',
    projectId: 'carpoolingapp2025',
    storageBucket: 'carpoolingapp2025.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDQHw5JnlKYkp1hilmFlb3d0dg3qbqa8rs',
    appId: '1:702698165636:ios:7882f206a3ac18f51fb9d1',
    messagingSenderId: '702698165636',
    projectId: 'carpoolingapp2025',
    storageBucket: 'carpoolingapp2025.firebasestorage.app',
    iosClientId: '702698165636-bblf47v6qu1u7pimchlq00vgfj22ivuk.apps.googleusercontent.com',
    iosBundleId: 'com.example.carPoolingApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDQHw5JnlKYkp1hilmFlb3d0dg3qbqa8rs',
    appId: '1:702698165636:ios:7882f206a3ac18f51fb9d1',
    messagingSenderId: '702698165636',
    projectId: 'carpoolingapp2025',
    storageBucket: 'carpoolingapp2025.firebasestorage.app',
    iosClientId: '702698165636-bblf47v6qu1u7pimchlq00vgfj22ivuk.apps.googleusercontent.com',
    iosBundleId: 'com.example.carPoolingApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCZxxcSOSHFMD4sxlf-X1I4wx9rZQleEo4',
    appId: '1:702698165636:web:3e4aa883b715b0a01fb9d1',
    messagingSenderId: '702698165636',
    projectId: 'carpoolingapp2025',
    authDomain: 'carpoolingapp2025.firebaseapp.com',
    storageBucket: 'carpoolingapp2025.firebasestorage.app',
  );
}