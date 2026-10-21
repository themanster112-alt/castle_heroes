import 'dart:math';

import 'package:castle_heroes/online_match.dart';
import 'package:castle_heroes/race_game.dart';
import 'package:flutter_test/flutter_test.dart';

List<RaceQuestion> questions(String prefix, {int count = 60}) => List.generate(
  count,
  (i) => RaceQuestion(
    id: '$i',
    number: i,
    level: 1,
    text: '$prefix سؤال $i',
    options: ['صح', 'خطأ', 'بديل'],
    answer: 0,
  ),
);

void main() {
  test(
    'Same numeric IDs in different banks do not hide different questions',
    () {
      final game = RaceMatch([
        questions('طفل', count: 1),
        questions('كبير', count: 1),
      ], random: Random(1));
      game.chooseStone(1);
      game.submit(0);
      game.nextTurn();
      expect(game.available(1), hasLength(1));
      expect(game.chooseStone(1), isTrue);
      expect(game.current!.text, startsWith('كبير'));
    },
  );

  test('Exhaustion finishes with a winner or a draw, including timeouts', () {
    for (final correct in [false, true]) {
      final game = RaceMatch([
        questions('نفسه', count: 1),
        questions('نفسه', count: 1),
      ]);
      game.chooseStone(1);
      expect(game.finished, isFalse);
      if (correct) {
        game.submit(0);
      } else {
        game.timeOut();
      }
      expect(game.finished, isTrue);
      expect(game.resultWinner, correct ? 0 : null);
    }
  });

  test(
    'Two clients replay identical questions, loot, scores and ordinary turns',
    () {
      final banks = [questions('طفل'), questions('كبير')];
      final data = <String, dynamic>{
        'seed': 1234,
        'players': [
          {'age': 0},
          {'age': 1},
        ],
        'events': <String, dynamic>{},
      };
      final events = data['events'] as Map<String, dynamic>;
      OnlineMatch add(String kind, [int? value]) {
        events['${events.length}'] = {'kind': kind, 'value': value};
        final first = OnlineMatch(data, banks),
            second = OnlineMatch(data, banks);
        expect(first.game.current?.text, second.game.current?.text);
        expect(first.game.scores, second.game.scores);
        expect(first.game.surpriseStones, second.game.surpriseStones);
        expect(first.game.team, second.game.team);
        expect(first.game.lootUsed, second.game.lootUsed);
        return first;
      }

      for (var i = 0; i < 10; i++) {
        add('choose', 1);
        add('answer', 0);
        add('next');
      }
      add('choose', 1);
      final loot = add('answer', 1);
      expect(OnlineMatch.phase(loot.game), 'loot');
      final result = add('answer', 0);
      expect(result.game.lootUsed[1], isTrue);
      expect(result.game.scores[1], loot.game.scores[1] + 10);
      final next = add('next');
      expect(next.game.team, 1);
      expect(OnlineMatch.phase(next.game), 'choose');
    },
  );

  test('Invalid online commands cannot alter an active question', () {
    final game = RaceMatch([questions('أ'), questions('ب')]);
    expect(() => OnlineMatch.apply(game, {'kind': 'next'}), throwsStateError);
    game.chooseStone(1);
    expect(
      () => OnlineMatch.apply(game, {'kind': 'answer', 'value': 9}),
      throwsStateError,
    );
    expect(
      () => OnlineMatch.apply(game, {'kind': 'choose', 'value': 2}),
      throwsStateError,
    );
    expect(game.answered, isFalse);
    expect(game.scores, [0, 0]);
  });
}
