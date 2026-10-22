import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Production banks have explicit difficulties, unique IDs and valid answers',
    () {
      for (final name in ['children', 'adults']) {
        final rows = jsonDecode(
          File('data/${name}_questions.json').readAsStringSync(),
        ) as List;
        final ids = <String>{};
        final levels = <int>{};
        for (final row in rows) {
          expect(
            ids.add(row['id'] as String),
            isTrue,
            reason: '$name duplicate ${row['id']}',
          );
          expect(row['level'], isIn([1, 2, 3]), reason: '$name/${row['id']}');
          levels.add(row['level'] as int);
          expect(row['question'], isNotEmpty);
          final options = (row['options'] as List).cast<String>();
          expect(options.length, 3);
          expect(options.toSet().length, 3);
          expect(options.every((option) => option.trim().isNotEmpty), isTrue);
          expect(row['correctOptionIndex'], isIn([0, 1, 2]));
        }
        expect(levels, {1, 2, 3});
      }
    },
  );
  test(
    'Basic knowledge stays outside hard and imported questions remain hard',
    () {
      for (final name in ['children', 'adults']) {
        final rows = jsonDecode(
          File('data/${name}_questions.json').readAsStringSync(),
        ) as List;
        final byId = {for (final row in rows) row['id']: row};
        for (final id
            in name == 'children' ? ['135', '144'] : ['1', '194', '195']) {
          expect(byId[id]['level'], 1);
        }
        if (name == 'adults') {
          final batch = jsonDecode(
            File('data/imports/hard_questions_2026-10-22.json')
                .readAsStringSync(),
          ) as Map;
          final byText = {for (final row in rows) row['question']: row};
          for (final imported in batch['questions'] as List) {
            final saved = byText[imported['question']];
            expect(saved, isNotNull);
            expect(saved['level'], imported['level']);
            expect(saved['options'], imported['options']);
            expect(saved['correctOptionIndex'], imported['correctOptionIndex']);
          }
        }
      }
    },
  );
}
