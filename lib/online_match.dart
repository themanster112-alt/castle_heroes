import 'dart:math';
import 'dart:convert';

import 'race_game.dart';

/// Replaying the same ordered commands against the same banks synchronizes both devices.
class OnlineMatch {
  static const version = 2;
  final Map<String, dynamic> data;
  final RaceMatch game;
  OnlineMatch._(this.data, this.game);

  factory OnlineMatch(
    Map<String, dynamic> data,
    List<List<RaceQuestion>> banks,
  ) {
    final players = (data['players'] as List).cast<Map>();
    final game = RaceMatch(
      players
          .map((p) => List<RaceQuestion>.of(banks[p['age'] as int]))
          .toList(),
      random: Random(data['seed'] as int),
    );
    final seed = data['seed'] as int;
    for (var lane = 0; lane < game.banks.length; lane++) {
      game.surpriseStones[lane] = (lane == 0 ? seed : seed ~/ 14) % 14 + 1;
    }
    final events = Map<String, dynamic>.from(data['events'] as Map);
    for (var i = 0; i < events.length; i++) {
      final event = Map<String, dynamic>.from(events['$i'] as Map);
      if (event['kind'] == 'choose' && event['question'] != null) {
        final age = players[game.team]['age'];
        final candidates = game.available(
          RaceMatch.stoneLevel(event['value'] as int),
        );
        final question = candidates
            .where((q) => '${age}_${q.id}' == event['question'])
            .firstOrNull;
        if (question == null) throw StateError('السؤال غير متاح');
        event['selectedQuestion'] = question;
      }
      apply(game, event);
    }
    final match = OnlineMatch._(data, game);
    if (data['state'] != null) {
      final state = Map<String, dynamic>.from(data['state'] as Map);
      final expected = match.snapshot();
      if (state.length != expected.length ||
          !expected.entries.every(
            (entry) => jsonEncode(state[entry.key]) == jsonEncode(entry.value),
          )) {
        throw StateError('حالة المباراة غير متطابقة مع أوامرها');
      }
    }
    return match;
  }

  Map<String, dynamic> snapshot() {
    final players = (data['players'] as List).cast<Map>();
    List<int> remaining(int level) => List.generate(
      game.banks.length,
      (lane) => game.banks[lane]
          .where(
            (q) =>
                game.levelOf(lane, q) == level &&
                !game.usedTexts.contains(q.normalizedText),
          )
          .length,
    );
    return {
      'team': game.team,
      'scores': game.scores,
      'easy': game.answeredCounts.map((counts) => counts[0]).toList(),
      'medium': game.answeredCounts.map((counts) => counts[1]).toList(),
      'hard': game.answeredCounts.map((counts) => counts[2]).toList(),
      'cannonUsed': game.cannonUsed,
      'lootUsed': game.lootUsed,
      'cannonArmed': game.cannonArmed,
      'question': game.current == null
          ? null
          : '${players[game.team]['age']}_${game.current!.id}',
      'level': game.chosenLevel ?? 0,
      'wrongOption': game.wrongOption,
      'usedTexts': game.usedTexts.toList(),
      'remEasy': remaining(1),
      'remMedium': remaining(2),
      'remHard': remaining(3),
      'surprises': game.surpriseStones,
      'surpriseClaimed': game.surpriseClaimed,
      'surpriseQuestion': game.surpriseQuestion,
      'winner': game.winner,
      'answered': game.answered,
    };
  }

  static void apply(RaceMatch game, Map<String, dynamic> event) {
    final kind = event['kind'];
    final value = event['value'] as int?;
    switch (kind) {
      case 'choose':
        if (!game.chooseStone(value!)) throw StateError('اختيار سؤال غير متاح');
        final desired = event['selectedQuestion'] as RaceQuestion?;
        if (desired != null && desired != game.current) {
          game.usedIds.remove(
            '${game.current!.id}:${game.current!.normalizedText}',
          );
          game.usedTexts.remove(game.current!.normalizedText);
          game.current = desired;
          game.usedIds.add('${desired.id}:${desired.normalizedText}');
          game.usedTexts.add(desired.normalizedText);
        }
      case 'cannon':
        if (!game.armCannon()) throw StateError('القذيفة غير متاحة');
      case 'answer':
        if (game.current == null ||
            game.answered ||
            value == null ||
            value < 0 ||
            value >= game.current!.options.length ||
            (game.lootPending && value == game.wrongOption)) {
          throw StateError('إجابة غير متاحة');
        }
        if (game.lootPending) {
          game.stealLoot(value);
        } else {
          game.submit(value);
        }
      case 'timeout':
        if (game.current == null || game.answered) {
          throw StateError('لا يوجد سؤال');
        }
        if (game.lootPending) {
          game.declineLoot();
        } else {
          game.timeOut();
        }
      case 'decline':
        if (!game.lootPending) throw StateError('لا توجد غنيمة');
        game.declineLoot();
      case 'next':
        if (!game.answered || game.lootPending) {
          throw StateError('السؤال لم ينته');
        }
        if (game.finished) {
          game.current = null;
          game.chosenLevel = null;
          game.wrongOption = null;
          game.answered = false;
          game.cannonArmed = false;
          game.surpriseQuestion = false;
        } else {
          game.nextTurn();
        }
      case 'skip':
        if (game.current != null || game.hasPlayableQuestion) {
          throw StateError('الدور متاح');
        }
        game.skipExhaustedTurn();
      case 'forfeit':
        if (game.current != null || game.finished) {
          throw StateError('لا يمكن إنهاء هذا الدور');
        }
        game.winner = game.opponent;
        game.feedback =
            'انتهت مهلة اختيار الحجر؛ فاز اللاعب الآخر لعدم الاستجابة.';
      default:
        throw StateError('أمر غير معروف');
    }
  }

  static String phase(RaceMatch game) => game.current != null
      ? game.answered
            ? 'result'
            : game.lootPending
            ? 'loot'
            : 'answer'
      : game.finished
      ? 'finished'
      : 'choose';
}
