import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'question_scroll.dart';
import 'menu_audio.dart';
import 'castle_character.dart';
import 'helper_announcement.dart';

const raceGold = Color(0xFFE9BD66);

enum WarriorAge { child, adult }

class RaceQuestion {
  final String id, text;
  final String category;
  final List<String> options;
  final int answer, number;
  final int? level;
  final String? flagUrl;
  double get imageHeight =>
      flagAsset?.startsWith('assets/question_photos/') == true ? 180 : 75;
  String? get flagAsset {
    const photos = {
      'https://img.btolat.com/2024/6/15/news/346055/large.jpg':
          'assets/question_photos/ronaldinho.jpg',
      'https://cdn.al-ain.com/images/2020/4/03/138-011530-kaka-real-madrid-milan_700x400.jpg':
          'assets/question_photos/kaka.jpg',
    };
    if (photos.containsKey(flagUrl)) return photos[flagUrl];
    final uri = Uri.tryParse(flagUrl ?? '');
    if (uri == null) return null;
    if (uri.host == 'flagcdn.com') {
      final file = uri.pathSegments.lastOrNull;
      const bundled = {
        'ae',
        'au',
        'bd',
        'br',
        'bt',
        'ca',
        'cn',
        'de',
        'dz',
        'eg',
        'fr',
        'id',
        'in',
        'iq',
        'it',
        'jo',
        'jp',
        'kr',
        'lb',
        'ly',
        'ma',
        'no',
        'pk',
        'ps',
        'qa',
        'ru',
        'sa',
        'sd',
        'sk',
        'sy',
        'tn',
        'tr',
        'ye',
      };
      if (file != null &&
          file.endsWith('.png') &&
          bundled.contains(file.substring(0, file.length - 4))) {
        return 'assets/flags/$file';
      }
    }
    if (uri.host == 'upload.wikimedia.org') {
      const countries = {
        'Canada': 'ca',
        'Egypt': 'eg',
        'Turkey': 'tr',
        'Saudi_Arabia': 'sa',
        'Brazil': 'br',
        'France': 'fr',
        'Germany': 'de',
        'Japan': 'jp',
        'Tunisia': 'tn',
        'India': 'in',
      };
      final file = uri.pathSegments.lastOrNull;
      for (final entry in countries.entries) {
        if (file == 'Flag_of_${entry.key}.svg') {
          return 'assets/flags/${entry.value}.png';
        }
      }
    }
    return null;
  }

  RaceQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.answer,
    required this.number,
    this.level,
    this.flagUrl,
    this.category = 'ثقافة عامة',
  });
  factory RaceQuestion.fromJson(Map<String, dynamic> data) => RaceQuestion(
    id: data['id'].toString(),
    text: data['question'] as String,
    options: List<String>.from(data['options'] as List),
    answer: data['correctOptionIndex'] as int,
    number: int.parse((data['questionNumber'] ?? data['id']).toString()),
    flagUrl: data['flagUrl'] as String?,
    level: int.tryParse('${data['level']}'),
    category: (data['category'] as String?) ?? 'ثقافة عامة',
  );
  late final String normalizedText = text
      .replaceAll(RegExp(r'[\s\u064B-\u065F\u0640؟?!.,،]'), '')
      .toLowerCase();
}

class QuestionBank {
  final List<RaceQuestion> questions;
  final bool offline;
  QuestionBank(this.questions, {this.offline = false});
}

class QuestionRepository {
  const QuestionRepository();
  static String collection(WarriorAge age) =>
      age == WarriorAge.child ? 'children_questions' : 'adults_questions';
  Future<QuestionBank> load(WarriorAge age) async {
    final name = collection(age);
    try {
      final questions = <RaceQuestion>[];
      String? page;
      do {
        final uri = Uri.https(
          'firestore.googleapis.com',
          '/v1/projects/castle-heroes-20261014/databases/(default)/documents/$name',
          {'pageSize': '300', 'pageToken': ?page},
        );
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw StateError('Firestore ${response.statusCode}');
        }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        for (final doc in body['documents'] as List? ?? []) {
          final fields = doc['fields'] as Map<String, dynamic>;
          dynamic decode(Map<String, dynamic> v) {
            if (v.containsKey('nullValue')) return null;
            if (v.containsKey('integerValue')) {
              return int.parse(v['integerValue'].toString());
            }
            if (v.containsKey('arrayValue')) {
              return (v['arrayValue']['values'] as List)
                  .map((e) => decode(Map<String, dynamic>.from(e)))
                  .toList();
            }
            return v['stringValue'];
          }

          questions.add(
            RaceQuestion.fromJson({
              'id': (doc['name'] as String).split('/').last,
              ...fields.map(
                (key, value) =>
                    MapEntry(key, decode(Map<String, dynamic>.from(value))),
              ),
            }),
          );
        }
        page = body['nextPageToken'] as String?;
      } while (page != null);
      if (questions.isEmpty) throw StateError('Empty bank');
      return QuestionBank(questions);
    } catch (_) {
      final data =
          jsonDecode(await rootBundle.loadString('data/$name.json')) as List;
      return QuestionBank(
        data
            .map((e) => RaceQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        offline: true,
      );
    }
  }
}

/// One shared ledger per match, including questions answered incorrectly.
class RaceMatch {
  static const questionSeconds = 20;
  final categoryHistory = <String>[];
  final categoryCounts = <String, int>{};
  static const stationCount = 14;
  static const winningScore = 280, unlockScore = 150;
  static const surpriseBonus = 10;
  final List<List<RaceQuestion>> banks;
  final Random random;
  late final List<Map<RaceQuestion, int>> _levels;
  final usedIds = <String>{}, usedTexts = <String>{};
  late final List<int> scores, steps;
  late final List<int> correctAnswers, wrongAnswers, timedOutAnswers;
  late final List<List<int>> answeredCounts;
  late final List<bool> unlocked, cannonUsed, lootUsed;
  late final List<int> surpriseStones;
  late final List<bool> surpriseClaimed;
  int? selectedStone;
  bool surpriseQuestion = false;
  int team = 0;
  RaceQuestion? current;
  int? winner, chosenLevel, wrongOption;
  bool answered = false, cannonArmed = false, lootPending = false;
  String feedback = '';
  int get opponent => (team + 1) % banks.length;
  int get answeringTeam => lootPending ? opponent : team;
  int get questionPoints => (chosenLevel ?? 1) * 10;

  RaceMatch(this.banks, {Random? random}) : random = random ?? Random() {
    answeredCounts = List.generate(banks.length, (_) => List.filled(3, 0));
    scores = List.filled(banks.length, 0);
    correctAnswers = List.filled(banks.length, 0);
    wrongAnswers = List.filled(banks.length, 0);
    timedOutAnswers = List.filled(banks.length, 0);
    steps = List.filled(banks.length, 0);
    unlocked = List.filled(banks.length, false);
    cannonUsed = List.filled(banks.length, false);
    lootUsed = List.filled(banks.length, false);
    surpriseStones = List.generate(
      banks.length,
      (_) => this.random.nextInt(stationCount) + 1,
    );
    surpriseClaimed = List.filled(banks.length, false);
    for (final bank in banks) {
      bank.sort((a, b) => a.number.compareTo(b.number));
    }
    _levels = banks
        .map(
          (bank) => Map<RaceQuestion, int>.fromEntries(
            bank.asMap().entries.map(
              (entry) => MapEntry(
                entry.value,
                entry.value.level?.clamp(1, 3) ??
                    min(3, entry.key * 3 ~/ max(1, bank.length) + 1),
              ),
            ),
          ),
        )
        .toList();
  }

  int levelOf(int lane, RaceQuestion question) {
    return _levels[lane][question]!;
  }

  List<RaceQuestion> available(int level) => banks[team]
      .where(
        (q) =>
            levelOf(team, q) == level &&
            !usedIds.contains('${q.id}:${q.normalizedText}') &&
            !usedTexts.contains(q.normalizedText),
      )
      .toList();

  static int stoneLevel(int stone) => stone <= 3
      ? 1
      : stone <= 9
      ? 2
      : 3;
  bool levelUnlocked(int level) =>
      level == 1 ||
      (level == 2 && answeredCounts[team][0] >= 1) ||
      (level == 3 && answeredCounts[team][1] >= 3);
  int stoneForLevel(int level) {
    // Protocol 2 carries a platform number. Rotate within the chosen difficulty
    // without making the progress stones interactive or losing surprise bonuses.
    final first = level == 1
        ? 1
        : level == 2
        ? 4
        : 10;
    final count = level == 1
        ? 3
        : level == 2
        ? 6
        : 5;
    return first + answeredCounts[team][level - 1] % count;
  }

  bool canChooseStone(int stone) =>
      levelUnlocked(stoneLevel(stone)) &&
      available(stoneLevel(stone)).isNotEmpty;
  bool get hasPlayableQuestion => [
    1,
    2,
    3,
  ].any((level) => levelUnlocked(level) && available(level).isNotEmpty);
  bool get finished =>
      winner != null ||
      ((current == null || answered) &&
          !banks.asMap().entries.any(
            (entry) => entry.value.any((q) {
              final level = levelOf(entry.key, q);
              final open =
                  level == 1 ||
                  (level == 2 && answeredCounts[entry.key][0] >= 1) ||
                  (level == 3 && answeredCounts[entry.key][1] >= 3);
              return open &&
                  !usedIds.contains('${q.id}:${q.normalizedText}') &&
                  !usedTexts.contains(q.normalizedText);
            }),
          ));
  int? get resultWinner {
    if (winner != null) return winner;
    if (!finished) return null;
    final best = scores.reduce(max);
    return scores.where((score) => score == best).length == 1
        ? scores.indexOf(best)
        : null;
  }

  String? stoneLockReason(int stone) {
    final level = stoneLevel(stone);
    if (!levelUnlocked(level)) {
      if (level == 2) return 'جاوب على سؤال سهل لفتح الأحجار المتوسطة';
      final remaining = 3 - answeredCounts[team][1];
      return 'جاوب على $remaining من الأسئلة المتوسطة لفتح الأحجار الصعبة';
    }
    if (available(level).isEmpty) return 'انتهت أسئلة هذا المستوى دون تكرار';
    return null;
  }

  bool chooseStone(int stone, {RaceQuestion? selectedQuestion}) {
    if (stone < 1 || stone > stationCount || !canChooseStone(stone)) {
      return false;
    }
    if (!chooseLevel(stoneLevel(stone), selectedQuestion: selectedQuestion)) {
      return false;
    }
    selectedStone = stone;
    surpriseQuestion = !surpriseClaimed[team] && surpriseStones[team] == stone;
    return true;
  }

  List<RaceQuestion> selectionCandidates(int level) {
    var questions = available(level);
    if (questions.isEmpty) return questions;
    if (categoryHistory.isNotEmpty) {
      final alternatives = questions
          .where((q) => q.category != categoryHistory.last)
          .toList();
      if (alternatives.isNotEmpty) questions = alternatives;
    }
    final leastUsed = questions
        .map((q) => categoryCounts[q.category] ?? 0)
        .reduce(min);
    return questions
        .where((q) => (categoryCounts[q.category] ?? 0) == leastUsed)
        .toList();
  }

  bool chooseLevel(int level, {RaceQuestion? selectedQuestion}) {
    if (!levelUnlocked(level) ||
        level < 1 ||
        level > 3 ||
        current != null ||
        answered ||
        winner != null) {
      return false;
    }
    final questions = selectedQuestion == null
        ? selectionCandidates(level)
        : available(level);
    if (questions.isEmpty) return false;
    if (selectedQuestion != null && !questions.contains(selectedQuestion)) {
      return false;
    }
    chosenLevel = level;
    selectedStone = null;
    surpriseQuestion = false;
    current = selectedQuestion ?? questions[random.nextInt(questions.length)];
    categoryHistory.add(current!.category);
    categoryCounts.update(
      current!.category,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    usedIds.add('${current!.id}:${current!.normalizedText}');
    usedTexts.add(current!.normalizedText);
    return true;
  }

  bool armCannon() {
    if (winner != null ||
        answered ||
        current != null ||
        !unlocked[team] ||
        cannonUsed[team] ||
        cannonArmed) {
      return false;
    }
    cannonArmed = true;
    cannonUsed[team] = true;
    return true;
  }

  void _award(int lane, int delta) {
    scores[lane] = max(0, scores[lane] + delta);
    steps[lane] = min(
      stationCount,
      scores[lane] * stationCount ~/ winningScore,
    );
    if (scores[lane] >= unlockScore) unlocked[lane] = true;
    if (scores[lane] >= winningScore) winner = lane;
  }

  bool submit(int option) {
    if (answered ||
        lootPending ||
        current == null ||
        winner != null ||
        option < 0 ||
        option >= current!.options.length) {
      return false;
    }
    answeredCounts[team][chosenLevel! - 1]++;
    final correct = option == current!.answer;
    if (correct) {
      correctAnswers[team]++;
    } else {
      wrongAnswers[team]++;
    }
    final value = questionPoints * (cannonArmed ? 2 : 1);
    if (correct) {
      final bonus = surpriseQuestion ? surpriseBonus : 0;
      if (surpriseQuestion) surpriseClaimed[team] = true;
      _award(team, value + bonus);
      feedback = 'إجابة صحيحة! +$value نقطة';
      if (bonus > 0) feedback += ' • حجر المفاجأة! +$bonus نقاط إضافية 🎁';
    } else {
      wrongOption = option;
      if (cannonArmed) _award(team, -questionPoints);
      feedback = cannonArmed
          ? 'أخطأت القذيفة! خسرت $questionPoints نقطة.'
          : 'إجابة خاطئة.';
      lootPending =
          banks.length > 1 && scores[opponent] >= 50 && !lootUsed[opponent];
    }
    answered = !lootPending;
    cannonArmed = false;
    surpriseQuestion = false;
    return correct;
  }

  void timeOut() {
    if (answered || current == null) return;
    if (!lootPending) timedOutAnswers[team]++;
    lootPending = false;
    answered = true;
    cannonArmed = false;
    surpriseQuestion = false;
    feedback = 'انتهى الوقت • 0 نقطة';
  }

  bool stealLoot(int option) {
    if (!lootPending ||
        winner != null ||
        current == null ||
        option == wrongOption ||
        option < 0 ||
        option >= current!.options.length) {
      return false;
    }
    lootUsed[opponent] = true;
    final correct = option == current!.answer;
    if (correct) {
      correctAnswers[opponent]++;
    } else {
      wrongAnswers[opponent]++;
    }
    if (correct) _award(opponent, questionPoints);
    feedback = correct
        ? 'نجحت سرقة الغنيمة! +$questionPoints نقطة للخصم.'
        : 'فشلت سرقة الغنيمة.';
    lootPending = false;
    answered = true;
    return correct;
  }

  void declineLoot() {
    if (!lootPending) return;
    lootPending = false;
    answered = true;
    feedback += ' تم تجاوز الغنيمة.';
  }

  void nextTurn() {
    if (!answered || lootPending || winner != null) return;
    team = (team + 1) % banks.length;
    current = null;
    chosenLevel = null;
    selectedStone = null;
    surpriseQuestion = false;
    wrongOption = null;
    answered = false;
    cannonArmed = false;
    feedback = '';
  }

  void skipExhaustedTurn() {
    if (current != null || winner != null || hasPlayableQuestion) {
      return;
    }
    answered = true;
    nextTurn();
  }
}

class CastleRaceScreen extends StatefulWidget {
  final List<String> names;
  final List<WarriorAge> ages;
  final QuestionRepository repository;
  final List<CastleCharacter>? characters;
  const CastleRaceScreen({
    super.key,
    required this.names,
    required this.ages,
    this.repository = const QuestionRepository(),
    this.characters,
  });
  @override
  State<CastleRaceScreen> createState() => _CastleRaceScreenState();
}

class _CastleRaceScreenState extends State<CastleRaceScreen> {
  bool _allowExit = false, _confirmingExit = false;
  Future<void> _leave() async {
    if (_confirmingExit) return;
    _confirmingExit = true;
    final confirmed =
        match == null ||
        match!.finished ||
        await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('مغادرة المباراة؟'),
                content: const Text(
                  'لن تُحفظ نتيجة المباراة الحالية إذا غادرت.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('متابعة اللعب'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('مغادرة'),
                  ),
                ],
              ),
            ) ==
            true;
    if (!mounted) return;
    _confirmingExit = false;
    if (!confirmed) return;
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  RaceMatch? match;
  bool offline = false;
  bool failed = false;
  int? selected;
  List<int>? previousSteps, previousScores;

  void _rematch() {
    final game = match;
    if (game == null) return;
    setState(() {
      previousSteps = null;
      previousScores = null;
      match = RaceMatch(
        game.banks.map((bank) => List<RaceQuestion>.of(bank)).toList(),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      match = null;
      failed = false;
      selected = null;
      previousSteps = null;
      previousScores = null;
    });
    try {
      final loaded = <WarriorAge, QuestionBank>{};
      for (final age in widget.ages.toSet()) {
        loaded[age] = await widget.repository.load(age);
      }
      if (!mounted) return;
      setState(() {
        offline = loaded.values.any((bank) => bank.offline);
        match = RaceMatch(
          widget.ages
              .map((age) => List<RaceQuestion>.of(loaded[age]!.questions))
              .toList(),
        );
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = match;
    if (game?.current != null) {
      return QuestionScrollScreen(
        key: ValueKey(game!.current),
        game: game,
        names: widget.names,
        characters: widget.characters,
        onContinue: () => setState(() {
          if (game.finished) {
            game.current = null;
          } else {
            game.nextTurn();
          }
        }),
      );
    }
    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          title: const Text('المسار إلى القلعة'),
          centerTitle: true,
          actions: const [SoundToggleButton()],
        ),
        body: game == null
            ? Center(
                child: failed
                    ? FilledButton(
                        onPressed: _load,
                        child: const Text('تعذّر تحميل الأسئلة • حاول مجددًا'),
                      )
                    : const CircularProgressIndicator(),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'اجمع 280 نقطة للوصول إلى القلعة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: raceGold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (offline)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'تلعب بالنسخة المحفوظة من الأسئلة • الاتصال غير متاح',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (game.finished) ...[
                        const Icon(
                          Icons.emoji_events,
                          color: raceGold,
                          size: 80,
                        ),
                        Text(
                          game.resultWinner == null
                              ? 'انتهت المباراة بالتعادل!'
                              : '${widget.names[game.resultWinner!]} بطل القلعة!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: raceGold,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        FilledButton(
                          onPressed: _rematch,
                          child: const Text('إعادة المباراة بنفس اللاعبين'),
                        ),
                        RaceSummary(
                          game: game,
                          names: widget.names,
                          characters: widget.characters,
                        ),
                      ] else if (game.current == null) ...[
                        Text(
                          'دور ${widget.names[game.team]} • اختر مستوى السؤال',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: raceGold,
                            fontFamily: 'Amiri',
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (game.cannonArmed)
                          const Card(
                            color: Color(0xFF5B3A12),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                '💣 ×2 القذيفة مفعّلة للسؤال القادم',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: raceGold,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        RaceArena(
                          game: game,
                          names: widget.names,
                          characters: widget.characters,
                          previousSteps: previousSteps,
                          previousScores: previousScores,
                          onLevel: (level) => setState(() {
                            previousSteps = List.of(game.steps);
                            previousScores = List.of(game.scores);
                            game.chooseStone(game.stoneForLevel(level));
                          }),
                          onCannon: (lane) {
                            if (!game.armCannon()) return;
                            setState(() {});
                            showHelperAnnouncement(
                              context,
                              player: widget.names[lane],
                              helper: 'القذيفة المضاعفة',
                              asset:
                                  'assets/helpers/cannon_${lane == 0 ? 'blue' : 'red'}.png',
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        if (!game.hasPlayableQuestion) ...[
                          const Text(
                            'لا توجد أسئلة متاحة في المستويات المفتوحة لهذا اللاعب.',
                            textAlign: TextAlign.center,
                          ),
                          FilledButton(
                            onPressed: () => setState(game.skipExhaustedTurn),
                            child: const Text('تجاوز الدور'),
                          ),
                          TextButton(
                            onPressed: _load,
                            child: const Text('مباراة جديدة'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class DifficultyPicker extends StatelessWidget {
  final RaceMatch game;
  final bool enabled;
  final ValueChanged<int> onSelected;
  final bool compact;

  const DifficultyPicker({
    super.key,
    required this.game,
    required this.onSelected,
    this.enabled = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => compact
      ? _compactPicker()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var level = 1; level <= 3; level++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OutlinedButton(
                  key: ValueKey('difficulty-$level'),
                  onPressed:
                      enabled && game.canChooseStone(game.stoneForLevel(level))
                      ? () => onSelected(level)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          game.levelUnlocked(level)
                              ? Icons.quiz
                              : Icons.lock_outline,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                level == 1
                                    ? 'سهل'
                                    : level == 2
                                    ? 'متوسط'
                                    : 'صعب',
                                style: const TextStyle(fontSize: 22),
                              ),
                              Text(
                                !game.levelUnlocked(level)
                                    ? level == 2
                                          ? 'لفتح المتوسط: سهل ${game.answeredCounts[game.team][0].clamp(0, 1)}/1'
                                          : 'لفتح الصعب: متوسط ${game.answeredCounts[game.team][1].clamp(0, 3)}/3'
                                    : game.available(level).isEmpty
                                    ? 'انتهت أسئلة هذا المستوى'
                                    : '${level * 10} نقطة • سؤال عشوائي',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Text(
              'ابدأ بالسهل؛ بعد إجابة سهلة يُفتح المتوسط، وبعد ثلاث إجابات متوسطة يُفتح الصعب. لكل لاعب تقدّمه الخاص.',
              textAlign: TextAlign.center,
            ),
          ],
        );

  Widget _compactPicker() => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xED10192E),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: raceGold),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'اختر المستوى',
          textAlign: TextAlign.center,
          style: TextStyle(color: raceGold, fontSize: 12),
        ),
        for (var level = 1; level <= 3; level++)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Tooltip(
              message:
                  game.stoneLockReason(game.stoneForLevel(level)) ??
                  '${level * 10} نقطة',
              child: OutlinedButton(
                key: ValueKey('difficulty-$level'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 7,
                  ),
                  foregroundColor: raceGold,
                  disabledForegroundColor: Colors.white60,
                  backgroundColor: const Color(0xF2203042),
                ),
                onPressed:
                    enabled && game.canChooseStone(game.stoneForLevel(level))
                    ? () => onSelected(level)
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ['سهل', 'متوسط', 'صعب'][level - 1],
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      !game.levelUnlocked(level)
                          ? level == 2
                                ? 'سهل ${game.answeredCounts[game.team][0].clamp(0, 1)}/1'
                                : 'متوسط ${game.answeredCounts[game.team][1].clamp(0, 3)}/3'
                          : game.available(level).isEmpty
                          ? 'نفدت الأسئلة'
                          : '${level * 10} نقطة',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class RaceArena extends StatelessWidget {
  final RaceMatch game;
  final List<String> names;
  final List<CastleCharacter>? characters;
  final List<int>? previousSteps, previousScores;
  final bool enabled;
  final ValueChanged<int> onLevel;
  final ValueChanged<int> onCannon;
  const RaceArena({
    super.key,
    required this.game,
    required this.names,
    this.characters,
    this.previousSteps,
    this.previousScores,
    this.enabled = true,
    required this.onLevel,
    required this.onCannon,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var lane = 0; lane < names.length; lane++) ...[
                if (lane > 0) const SizedBox(width: 8),
                Expanded(
                  child: PlayerHelpers(
                    key: ValueKey('player-helpers-$lane'),
                    name: names[lane],
                    blue: lane == 0,
                    unlocked: game.unlocked[lane],
                    lootUnlocked: game.scores[lane] >= 50,
                    cannonUsed: game.cannonUsed[lane],
                    lootUsed: game.lootUsed[lane],
                    armed: game.team == lane && game.cannonArmed,
                    lootAvailable: names.length > 1,
                    onCannon:
                        enabled &&
                            game.team == lane &&
                            game.unlocked[lane] &&
                            !game.cannonUsed[lane] &&
                            !game.cannonArmed
                        ? () => onCannon(lane)
                        : null,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          RaceBoard(
            names: names,
            steps: game.steps,
            scores: game.scores,
            previousSteps: previousSteps,
            previousScores: previousScores,
            active: game.team,
            characters: characters,
            controls: DifficultyPicker(
              game: game,
              enabled: enabled,
              compact: true,
              onSelected: onLevel,
            ),
          ),
        ],
      ),
    ),
  );
}

class RaceSummary extends StatelessWidget {
  final RaceMatch game;
  final List<String> names;
  final List<CastleCharacter>? characters;
  const RaceSummary({
    super.key,
    required this.game,
    required this.names,
    this.characters,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'ملخص السباق',
        textAlign: TextAlign.center,
        style: TextStyle(color: raceGold, fontSize: 24),
      ),
      for (var lane = 0; lane < names.length; lane++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CharacterPortrait(
                  character:
                      characters?[lane] ??
                      CastleCharacter.values[lane %
                          CastleCharacter.values.length],
                ),
                Text(
                  names[lane],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: raceGold, fontSize: 21),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('${game.scores[lane]} نقطة'),
                    Text('صحيحة: ${game.correctAnswers[lane]}'),
                    Text('خاطئة: ${game.wrongAnswers[lane]}'),
                    Text('انتهى الوقت: ${game.timedOutAnswers[lane]}'),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class RaceBoard extends StatelessWidget {
  final Widget? controls;
  final List<String> names;
  final List<int> steps;
  final List<int>? scores;
  final List<int>? previousSteps, previousScores;
  final int active;
  final bool Function(int)? canChooseStone;
  final ValueChanged<int>? onStone;
  final List<CastleCharacter>? characters;
  const RaceBoard({
    super.key,
    this.controls,
    required this.names,
    required this.steps,
    this.scores,
    this.previousSteps,
    this.previousScores,
    required this.active,
    this.canChooseStone,
    this.onStone,
    this.characters,
  });
  // Normalized centers of the fourteen platforms, ordered toward the castle.
  static const leftPlatforms = <Offset>[
    Offset(.263, .889),
    Offset(.210, .807),
    Offset(.232, .740),
    Offset(.190, .675),
    Offset(.232, .612),
    Offset(.175, .547),
    Offset(.184, .492),
    Offset(.214, .440),
    Offset(.261, .391),
    Offset(.163, .347),
    Offset(.204, .303),
    Offset(.266, .264),
    Offset(.344, .229),
    Offset(.408, .198),
  ];
  static const rightPlatforms = <Offset>[
    Offset(.753, .889),
    Offset(.808, .808),
    Offset(.762, .740),
    Offset(.812, .675),
    Offset(.775, .612),
    Offset(.828, .547),
    Offset(.827, .492),
    Offset(.794, .440),
    Offset(.811, .391),
    Offset(.852, .347),
    Offset(.802, .303),
    Offset(.735, .264),
    Offset(.677, .229),
    Offset(.604, .198),
  ];
  static Offset position(int lane, double step) {
    final points = lane == 0 ? leftPlatforms : rightPlatforms;
    final progress = step.clamp(0.0, RaceMatch.stationCount.toDouble());
    final index = progress.floor();
    final start = index == 0 ? Offset(points.first.dx, .95) : points[index - 1];
    if (index == RaceMatch.stationCount) return start;
    return Offset.lerp(start, points[index], progress - index)!;
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 938 / 1677,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: LayoutBuilder(
        builder: (context, box) {
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/backgrounds/question_map.png',
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
              for (var lane = 0; lane < names.length; lane++) ...[
                for (var n = 1; n <= RaceMatch.stationCount; n++)
                  Positioned(
                    left: position(lane, n.toDouble()).dx * box.maxWidth - 13,
                    top: position(lane, n.toDouble()).dy * box.maxHeight - 13,
                    child: GestureDetector(
                      key: ValueKey('stone-$lane-$n'),
                      onTap: lane == active && onStone != null
                          ? () => onStone!(n)
                          : null,
                      child: Opacity(
                        opacity:
                            lane == active && !(canChooseStone?.call(n) ?? true)
                            ? .4
                            : 1,
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: steps[lane] >= n
                                ? raceGold
                                : const Color(0xFF26352F),
                            shape: BoxShape.circle,
                            border: Border.all(color: raceGold),
                          ),
                          child: Text(
                            '$n',
                            style: TextStyle(
                              color: steps[lane] >= n
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 850),
                  builder: (context, progress, child) {
                    final reducedMotion = MediaQuery.disableAnimationsOf(
                      context,
                    );
                    final t = reducedMotion ? 1.0 : progress;
                    final start = previousSteps?[lane] ?? steps[lane];
                    final step =
                        start +
                        (steps[lane] - start) * Curves.easeInOut.transform(t);
                    final delta =
                        (scores?[lane] ?? 0) -
                        (previousScores?[lane] ?? scores?[lane] ?? 0);
                    final point = position(lane, step);
                    return Positioned(
                      left: point.dx * box.maxWidth - 25,
                      top:
                          point.dy * box.maxHeight -
                          65 -
                          (delta > 0 ? sin(pi * t) * 18 : 0),
                      child: IgnorePointer(
                        child: Semantics(
                          label: '${names[lane]}، المحطة ${steps[lane]} من 14',
                          child: Container(
                            width: 50,
                            height: 64,
                            decoration: BoxDecoration(
                              color:
                                  (lane == 0
                                          ? Colors.blueAccent
                                          : Colors.redAccent)
                                      .withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: lane == 0
                                    ? Colors.blueAccent
                                    : Colors.redAccent,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 8),
                              ],
                            ),
                            child: CharacterPortrait(
                              character:
                                  characters?[lane] ??
                                  CastleCharacter.values[lane %
                                      CastleCharacter.values.length],
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (scores != null &&
                    previousScores != null &&
                    scores![lane] > previousScores![lane])
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1500),
                    builder: (context, progress, _) {
                      final point = position(lane, steps[lane].toDouble());
                      return Positioned(
                        left: point.dx * box.maxWidth - 35,
                        top: point.dy * box.maxHeight - 70 - progress * 30,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 1 - progress,
                            child: Text(
                              '+${scores![lane] - previousScores![lane]}',
                              style: const TextStyle(
                                color: raceGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Positioned(
                  bottom: 12,
                  left: lane == 0 ? 8 : box.maxWidth * .52,
                  width: box.maxWidth * .46,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xDC10192E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active == lane ? raceGold : Colors.white24,
                      ),
                    ),
                    child: Text(
                      '${names[lane]} • ${scores?[lane] ?? 0} نقطة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
              if (controls != null)
                Positioned.fill(
                  key: const ValueKey('map-difficulty-controls'),
                  child: Align(
                    alignment: const Alignment(0, .05),
                    child: SizedBox(
                      width: min(box.maxWidth * .34, 180),
                      child: controls!,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class PlayerHelpers extends StatelessWidget {
  final String name;
  final bool blue,
      unlocked,
      lootUnlocked,
      cannonUsed,
      lootUsed,
      armed,
      lootAvailable;
  final VoidCallback? onCannon;
  const PlayerHelpers({
    super.key,
    required this.name,
    required this.blue,
    required this.unlocked,
    required this.lootUnlocked,
    required this.cannonUsed,
    required this.lootUsed,
    required this.armed,
    required this.lootAvailable,
    required this.onCannon,
  });

  @override
  Widget build(BuildContext context) {
    final color = blue ? Colors.lightBlueAccent : Colors.redAccent;
    final suffix = blue ? 'blue' : 'red';
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xED10192E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _helper(
                  context,
                  'القذيفة المضاعفة',
                  'cannon_$suffix',
                  armed
                      ? 'مفعّلة'
                      : cannonUsed
                      ? 'استُخدمت'
                      : unlocked
                      ? 'جاهزة'
                      : '150 نقطة',
                  'ضعف نقاط الإجابة الصحيحة، وخسارة قيمة السؤال عند الخطأ. استخدام واحد في دورك.',
                  color,
                  unlocked && (!cannonUsed || armed),
                  onCannon,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _helper(
                  context,
                  'سرقة الغنيمة',
                  'loot_$suffix',
                  !lootAvailable
                      ? 'تحتاج خصمًا'
                      : lootUsed
                      ? 'استُخدمت'
                      : lootUnlocked
                      ? 'جاهزة'
                      : '50 نقطة',
                  !lootAvailable ? 'سرقة الغنيمة متاحة في تحدي لاعبين فقط.' : 'تتاح عند خطأ الخصم بعد جمع 50 نقطة. أجب عن سؤاله لكسب نقاطه. استخدام واحد.',
                  color,
                  lootAvailable && lootUnlocked && !lootUsed,
                  null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _helper(
    BuildContext context,
    String title,
    String asset,
    String status,
    String description,
    Color color,
    bool available,
    VoidCallback? action,
  ) => Semantics(
    label: '$name، $title، $status',
    button: true,
    child: Tooltip(
      message: '$title: $description',
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap:
            action ??
            () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('$title • $status'),
                content: Text(description),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('حسنًا'),
                  ),
                ],
              ),
            ),
        child: Container(
          key: ValueKey('helper-$asset'),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xCC243044),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: available ? color : Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: available ? 1 : .5,
                child: Image.asset(
                  'assets/helpers/$asset.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: available ? color : Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
