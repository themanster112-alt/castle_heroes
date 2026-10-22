import 'package:flutter/material.dart';

/// Stone centers in the supplied 1536 x 2752 solo artwork, from start to castle.
abstract final class SoloMap {
  static const asset = 'assets/backgrounds/solo_question_map.jpg';
  static const aspectRatio = 1536 / 2752;
  static const platforms = <Offset>[
    Offset(.804, .916),
    Offset(.530, .854),
    Offset(.300, .818),
    Offset(.179, .761),
    Offset(.302, .682),
    Offset(.402, .641),
    Offset(.387, .596),
    Offset(.246, .545),
    Offset(.201, .503),
    Offset(.590, .444),
    Offset(.696, .415),
    Offset(.718, .380),
    Offset(.563, .352),
    Offset(.425, .328),
  ];
}
