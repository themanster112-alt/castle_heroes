import 'dart:math';

import 'package:castle_heroes/race_game.dart';
import 'package:flutter_test/flutter_test.dart';

RaceQuestion question(String id, String category, {int level = 1}) =>
    RaceQuestion(
      id: id,
      number: int.parse(id),
      text: 'سؤال $id',
      options: ['أ', 'ب', 'ج'],
      answer: 0,
      category: category,
      level: level,
    );

void main() {
  test(
    'Unequal topic pools rotate without consecutive repeats across players',
    () {
      final banks = List.generate(
        2,
        (lane) => [
          for (var i = 1; i <= 20; i++) question('${lane * 100 + i}', 'دين'),
          for (var i = 21; i <= 30; i++) question('${lane * 100 + i}', 'علوم'),
          for (var i = 31; i <= 40; i++) question('${lane * 100 + i}', 'لغة'),
        ],
      );
      final game = RaceMatch(banks, random: Random(4));
      for (var i = 0; i < 12; i++) {
        expect(game.chooseLevel(1), isTrue);
        if (i > 0) {
          expect(game.categoryHistory[i], isNot(game.categoryHistory[i - 1]));
        }
        game.submit(1);
        game.nextTurn();
      }
      expect(game.categoryCounts.values.toSet(), {4});
    },
  );
  test('Topic exhaustion falls back within the unlocked chosen difficulty', () {
    final game = RaceMatch([
      [
        question('1', 'دين'),
        question('2', 'دين'),
        question('3', 'علوم', level: 2),
      ],
    ]);
    expect(game.chooseLevel(2), isFalse);
    expect(game.chooseLevel(1), isTrue);
    game.submit(1);
    game.nextTurn();
    expect(game.chooseLevel(1), isTrue);
    expect(game.current!.category, 'دين');
    game.submit(1);
    game.nextTurn();
    expect(game.chooseLevel(1), isFalse);
    expect(game.current, isNull);
    expect(game.chooseLevel(2), isTrue);
  });
  test('Canonical replay records the delivered question category only', () {
    final first = question('1', 'دين'),
        second = question('2', 'دين'),
        other = question('3', 'علوم');
    final game = RaceMatch([
      [first, second, other],
    ], random: Random(2));
    expect(game.chooseStone(1, selectedQuestion: first), isTrue);
    game.submit(1);
    game.nextTurn();
    expect(game.selectionCandidates(1), [other]);
    expect(game.chooseStone(1, selectedQuestion: second), isTrue);
    expect(game.categoryHistory, ['دين', 'دين']);
    expect(game.categoryCounts, {'دين': 2});
  });
}
