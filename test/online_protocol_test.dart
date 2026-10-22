import 'dart:convert';
import 'dart:io';

import 'package:castle_heroes/online_match.dart';
import 'package:castle_heroes/race_game.dart';
import 'package:castle_heroes/server_clock.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

void main() {
  test(
    'Server clock advances monotonically without reading the device wall clock',
    () {
      var elapsed = Duration.zero;
      final clock = ServerClock(readElapsed: () => elapsed);
      expect(() => clock.now, throwsStateError);
      final server = DateTime.utc(2026, 10, 21, 12);
      clock.synchronize(server, roundTrip: const Duration(seconds: 2));
      elapsed = const Duration(seconds: 14);
      expect(clock.now, server.add(const Duration(seconds: 15)));
      clock.synchronize(server.add(const Duration(minutes: 1)));
      elapsed = const Duration(seconds: 19);
      expect(clock.now, server.add(const Duration(minutes: 1, seconds: 5)));
    },
  );

  test('Validated snapshots and command fixtures cover all online transitions', () {
    var hash = 0x811c9dc5;
    final banks = <List<RaceQuestion>>[];
    for (final name in ['children_questions', 'adults_questions']) {
      final content = File('data/$name.json').readAsStringSync();
      for (final byte in utf8.encode(content)) {
        hash = (hash * 31 + byte) % 2147483647;
      }
      banks.add(
        (jsonDecode(content) as List)
            .map(
              (item) => RaceQuestion.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
    }
    final version = '${OnlineMatch.version}-${hash.toRadixString(16)}';
    Map<String, dynamic> fresh() => {
      'protocol': OnlineMatch.version,
      'version': version,
      'seed': 7,
      'events': <String, dynamic>{},
      'revision': 0,
      'players': [
        {'uid': 'host', 'name': 'فحص المضيف', 'age': 0, 'character': 0},
        {'uid': 'guest', 'name': 'فحص الضيف', 'age': 1, 'character': 1},
      ],
      'phase': 'choose',
      'status': 'playing',
      'turnUid': 'host',
      'phaseSeconds': 60,
    };
    final fixtures = <Map<String, dynamic>>[];
    var data = fresh();
    data['state'] = OnlineMatch(data, banks).snapshot();
    final initial = copy(data);
    Map<String, dynamic> step(String kind, [int? value, String? label]) {
      final before = copy(data);
      final match = OnlineMatch(before, banks);
      final wasLoot = match.game.lootPending;
      final actor = ['next', 'timeout', 'forfeit'].contains(kind)
          ? 1 - match.game.team
          : match.game.answeringTeam;
      final event = <String, dynamic>{
        'kind': kind,
        'value': value,
        'actor': actor,
      };
      OnlineMatch.apply(match.game, event);
      if (kind == 'choose') {
        event['question'] =
            '${(before['players'] as List)[match.game.team]['age']}_${match.game.current!.id}';
      }
      final phase = OnlineMatch.phase(match.game);
      final revision = before['revision'] as int;
      data = copy({
        ...before,
        'events': {...before['events'] as Map, '$revision': event},
        'revision': revision + 1,
        'state': match.snapshot(),
        'phase': phase,
        'status': phase == 'finished' ? 'finished' : 'playing',
        'turnUid': (before['players'] as List)[match.game.answeringTeam]['uid'],
        'phaseSeconds': phase == 'choose'
            ? 60
            : ['answer', 'loot'].contains(phase)
            ? RaceMatch.questionSeconds
            : phase == 'result'
            ? (wasLoot && kind == 'answer' ? 6 : 3)
            : 0,
      });
      // Replay must reproduce every independently serialized state, not just the final score.
      expect(OnlineMatch(data, banks).snapshot(), data['state']);
      if (label != null) {
        fixtures.add({'label': label, 'before': before, 'after': copy(data)});
      }
      return data;
    }

    void reset() {
      data = copy(initial);
    }

    step('choose', 2, 'choose easy question');
    step(
      'answer',
      OnlineMatch(data, banks).game.current!.answer,
      'correct normal answer',
    );
    step('next', null, 'advance result');
    step('choose', 2);
    step(
      'answer',
      (OnlineMatch(data, banks).game.current!.answer + 1) % 3,
      'wrong answer without loot',
    );
    step('next');
    step('choose', 2);
    step('timeout', null, 'question timeout');
    reset();
    for (var i = 0; i < 10; i++) {
      step('choose', 2);
      step('answer', OnlineMatch(data, banks).game.current!.answer);
      step('next');
    }
    final lootReady = copy(data);
    for (final mode in ['correct', 'wrong', 'decline', 'timeout']) {
      data = copy(lootReady);
      step('choose', 2);
      final answer = OnlineMatch(data, banks).game.current!.answer;
      step('answer', (answer + 1) % 3, mode == 'correct' ? 'grant loot' : null);
      expect(data['phase'], 'loot');
      if (mode == 'correct') {
        step('answer', answer, 'correct loot');
      }
      if (mode == 'wrong') {
        step('answer', (answer + 2) % 3, 'wrong loot');
      }
      if (mode == 'decline') {
        step('decline', null, 'decline loot');
      }
      if (mode == 'timeout') {
        step('timeout', null, 'loot timeout');
      }
    }
    reset();
    for (var i = 0; i < 30; i++) {
      step('choose', 2);
      step('answer', OnlineMatch(data, banks).game.current!.answer);
      step('next');
    }
    final cannonReady = copy(data);
    for (final correct in [true, false]) {
      data = copy(cannonReady);
      step('cannon', null, correct ? 'activate cannon' : null);
      step('choose', 2);
      final answer = OnlineMatch(data, banks).game.current!.answer;
      step(
        'answer',
        correct ? answer : (answer + 1) % 3,
        correct ? 'cannon double reward' : 'cannon penalty',
      );
    }
    reset();
    step('forfeit', null, 'selection deadline forfeit');
    expect(OnlineMatch(data, banks).game.resultWinner, 1);
    reset();
    for (var i = 0; i < 54; i++) {
      step('choose', 2);
      step('answer', OnlineMatch(data, banks).game.current!.answer);
      step('next');
    }
    step('choose', 2);
    step(
      'answer',
      OnlineMatch(data, banks).game.current!.answer,
      'winning answer',
    );
    step('next', null, 'finish match');
    expect(data['phase'], 'finished');
    reset();
    while (OnlineMatch(data, banks).game.hasPlayableQuestion) {
      step('choose', 2);
      step('timeout');
      step('next');
    }
    step('skip', null, 'skip exhausted open levels');
    final tampered = copy(initial);
    (tampered['state'] as Map)['scores'] = [200, 0];
    expect(() => OnlineMatch(tampered, banks), throwsStateError);
    if (const bool.fromEnvironment('EXPORT_RULE_FIXTURES')) {
      Directory('.dart_tool').createSync();
      File('.dart_tool/online-rule-fixtures.json').writeAsStringSync(
        jsonEncode({'version': version, 'initial': initial, 'cases': fixtures}),
      );
    }
    expect(fixtures.length, greaterThanOrEqualTo(16));
  });
}
