import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('All sixty reviewed additions match their bank and religious levels stay medium/hard', () {
    for (final age in ['children', 'adults']) {
      final batch = jsonDecode(
        File('data/imports/verified_60_2026-10-22_$age.json')
            .readAsStringSync(),
      ) as Map;
      final bank = jsonDecode(
        File('data/${age}_questions.json').readAsStringSync(),
      ) as List;
      final byText = {for (final row in bank) row['question']: row};
      final additions = batch['questions'] as List;
      expect(additions.length, 30);
      expect(additions.where((row) => row['quranEvidence'] != null).length, 15);
      for (final row in additions) {
        final saved = byText[row['question']];
        expect(saved, isNotNull);
        expect(saved['options'], row['options']);
        expect(saved['correctOptionIndex'], row['correctOptionIndex']);
        expect(saved['level'], row['level']);
        if (row['quranEvidence'] != null) {
          expect(saved['level'], isIn([2, 3]));
          expect(
            (row['sources'] as List).every(
              (url) => (url as String).startsWith('https://quran.com/'),
            ),
            isTrue,
          );
        }
      }
    }
  });
}
