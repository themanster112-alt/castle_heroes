import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class OnlineFirebaseOptions {
  static FirebaseOptions get current =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? android
      : web;
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAnmWUfm7m0ixkQxFQaxN9qNPr3BvxlqbY',
    appId: '1:1091533671519:android:c219a95908e989c9b89fea',
    messagingSenderId: '1091533671519',
    projectId: 'castle-heroes-online-20261021',
    storageBucket: 'castle-heroes-online-20261021.firebasestorage.app',
  );
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyBYSKPsrLoL7hoJeDQmq-111CZtB42C5zM',
    appId: '1:1091533671519:web:3b11ffc789db2abab89fea',
    messagingSenderId: '1091533671519',
    projectId: 'castle-heroes-online-20261021',
    authDomain: 'castle-heroes-online-20261021.firebaseapp.com',
    storageBucket: 'castle-heroes-online-20261021.firebasestorage.app',
  );
}
