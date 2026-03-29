// Firebase options for secondary app: stock-154a6
// Used exclusively for reading gold_transactions data
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class GoldFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyDJVTQkyTT9hqg9-Bum4MXh7nUHZswLk9c',
    appId:             '1:77598238528:android:6558e8ff19c7b6950f3ca5',
    messagingSenderId: '77598238528',
    projectId:         'stock-154a6',
    storageBucket:     'stock-154a6.firebasestorage.app',
    databaseURL:       'https://stock-154a6-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // iOS app registered on Firebase Console (stock-154a6) with Bundle ID: com.savemoney.savemoney
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyDaOh5LomXI7goZlP9H9jWJ_zYz1hRmJh0',
    appId:             '1:77598238528:ios:33183c3fa7eab5870f3ca5',
    messagingSenderId: '77598238528',
    projectId:         'stock-154a6',
    storageBucket:     'stock-154a6.firebasestorage.app',
    databaseURL:       'https://stock-154a6-default-rtdb.asia-southeast1.firebasedatabase.app',
    iosBundleId:       'com.savemoney.savemoney',
  );
}
