import 'dart:math';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:castle_heroes/main.dart';
import 'package:castle_heroes/race_game.dart';
import 'package:castle_heroes/question_scroll.dart';
import 'package:castle_heroes/menu_audio.dart';
import 'package:castle_heroes/castle_character.dart';
import 'package:castle_heroes/player_setup.dart';
import 'package:castle_heroes/helper_announcement.dart';
import 'package:castle_heroes/online_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

List<RaceQuestion> bank() => List.generate(
  120,
  (i) => RaceQuestion(
    id: '$i',
    number: i,
    text: 'سؤال $i',
    options: ['صحيح', 'خطأ', 'بديل'],
    answer: 0,
  ),
);

class FakeRepository extends QuestionRepository {
  final requested = <WarriorAge>[];
  @override
  Future<QuestionBank> load(WarriorAge age) async {
    requested.add(age);
    return QuestionBank(bank());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Leaving a local race requires confirmation and cancel keeps the match',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CastleRaceScreen(
                      names: const ['أ'],
                      ages: const [WarriorAge.child],
                      repository: FakeRepository(),
                    ),
                  ),
                ),
                child: const Text('فتح'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('مغادرة المباراة؟'), findsOneWidget);
      await tester.tap(find.text('متابعة اللعب'));
      await tester.pumpAndSettle();
      expect(find.byType(CastleRaceScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مغادرة'));
      await tester.pumpAndSettle();
      expect(find.byType(CastleRaceScreen), findsNothing);
    },
  );
  testWidgets(
    'Online entry forms fit narrow screens and reject missing profiles',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final join in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: OnlineEntryScreen(key: UniqueKey(), join: join),
          ),
        );
        final submit = find.widgetWithText(
          FilledButton,
          join ? 'انضمام' : 'إنشاء غرفة',
        );
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        expect(find.textContaining('أدخل اسمك وفئتك العمرية'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('Locked remaining questions do not trap an exhausted turn', () {
    final game = RaceMatch([
      [
        RaceQuestion(
          id: 'easy',
          number: 1,
          text: 'سهل وحيد',
          options: ['نعم', 'لا'],
          answer: 0,
          level: 1,
        ),
        RaceQuestion(
          id: 'hard',
          number: 2,
          text: 'صعب مقفل',
          options: ['نعم', 'لا'],
          answer: 0,
          level: 3,
        ),
      ],
      bank(),
    ]);
    game.chooseStone(1);
    game.timeOut();
    game.nextTurn();
    game.chooseStone(1);
    game.submit(0);
    game.nextTurn();
    expect(game.team, 0);
    expect(game.available(3), isNotEmpty);
    expect(game.hasPlayableQuestion, isFalse);
    game.skipExhaustedTurn();
    expect(game.team, 1);
    expect(game.hasPlayableQuestion, isTrue);
  });
  testWidgets(
    'An early reduced-motion answer does not restart the question timer',
    (tester) async {
      final game = RaceMatch([bank()]);
      game.chooseStone(1);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: QuestionScrollScreen(
              game: game,
              names: const ['الأول'],
              onContinue: () {},
            ),
          ),
        ),
      );
      final correct = find.widgetWithText(OutlinedButton, 'صحيح');
      await tester.ensureVisible(correct);
      await tester.tap(correct);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(seconds: 1));
      expect(game.answered, isTrue);
      expect(find.text('الوقت المتبقي: 15 ثانية'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Helper announcement names the player, blocks play and closes automatically',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var choices = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  choices++;
                  showHelperAnnouncement(
                    context,
                    player: 'أحمد',
                    helper: 'القذيفة المضاعفة',
                    asset: 'assets/helpers/cannon_blue.png',
                  );
                },
                child: const Text('تفعيل'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('تفعيل'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('أحمد اختار'), findsOneWidget);
      expect(find.text('القذيفة المضاعفة'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('helper-announcement')), findsOneWidget);
      expect(choices, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('helper-announcement')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final answerLoot in [true, false]) {
    testWidgets(
      'Loot gets a fresh timer and clear handoff (answer: $answerLoot)',
      (tester) async {
        final game = RaceMatch([bank(), bank()]);
        game.scores[1] = 50;
        game.chooseStone(1);
        var returns = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: QuestionScrollScreen(
              game: game,
              names: const ['الأول', 'الثاني'],
              onContinue: () => returns++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 10));
        final wrong = find.widgetWithText(OutlinedButton, 'خطأ');
        await tester.ensureVisible(wrong);
        await tester.tap(wrong);
        await tester.pump();
        expect(game.lootPending, isTrue);
        expect(find.byKey(const ValueKey('loot-banner')), findsOneWidget);
        expect(find.text('دورك الآن يا الثاني'), findsOneWidget);
        expect(find.text('الوقت المتبقي: 15 ثانية'), findsOneWidget);
        expect(find.text('العودة إلى السباق خلال 3 ثوانٍ'), findsNothing);
        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(tester.widget<OutlinedButton>(wrong).onPressed, isNull);
        final background = tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('loot-background')),
        );
        expect(
          (background.decoration as BoxDecoration).color,
          const Color(0xCC123D56),
        );
        await tester.pump(const Duration(seconds: 4));
        expect(returns, 0);
        expect(game.lootPending, isTrue);
        if (answerLoot) {
          final correct = find.widgetWithText(OutlinedButton, 'صحيح');
          await tester.ensureVisible(correct);
          await tester.tap(correct);
          await tester.pump();
          expect(game.lootUsed[1], isTrue);
          expect(game.scores[1], 60);
          expect(find.text('رسالة إلى الثاني'), findsOneWidget);
          expect(
            tester
                .widget<CharacterPortrait>(find.byType(CharacterPortrait))
                .character,
            CastleCharacter.values[1],
          );
          expect(find.text('الثاني اختار'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('helper-announcement')),
            findsOneWidget,
          );
          await tester.pump(const Duration(seconds: 3));
          await tester.pump(const Duration(milliseconds: 400));
          expect(returns, 0);
        } else {
          await tester.pump(const Duration(seconds: 11));
          expect(game.lootUsed[1], isFalse);
          expect(game.scores[1], 50);
        }
        expect(game.answered, isTrue);
        expect(game.lootPending, isFalse);
        expect(returns, 0);
        await tester.pump(const Duration(seconds: 3));
        expect(returns, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('Character selection is independent for each team', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TeamSetupScreen()));
    await tester.pumpAndSettle();
    final redPicker = find.byType(CharacterPicker).at(0);
    final scout = find.descendant(
      of: redPicker,
      matching: find.byKey(const ValueKey('character-scout')),
    );
    await tester.ensureVisible(scout);
    await tester.pumpAndSettle();
    await tester.tap(scout);
    await tester.pump();
    final cards = tester
        .widgetList<WarriorSetupCard>(find.byType(WarriorSetupCard))
        .toList();
    expect(cards[0].character, CastleCharacter.scout);
    expect(cards[1].character, CastleCharacter.archer);
    expect(tester.takeException(), isNull);
  });
  test('All character assets decode and preserve transparency', () async {
    for (final character in CastleCharacter.values) {
      final data = await rootBundle.load(character.asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      final pixels = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(pixels.getUint8(3), lessThan(5), reason: character.label);
      final center =
          ((frame.image.height ~/ 2) * frame.image.width +
                  frame.image.width ~/ 2) *
              4 +
          3;
      expect(
        pixels.getUint8(center),
        greaterThan(240),
        reason: character.label,
      );
      expect(frame.image.height, greaterThan(100));
      frame.image.dispose();
      codec.dispose();
    }
  });
  test(
    'Surprise stone awards ten once and cannon doubles only question points',
    () {
      final game = RaceMatch([bank()]);
      game.surpriseStones[0] = 1;
      game.chooseStone(1);
      game.submit(1);
      expect(game.scores, [0]);
      expect(game.surpriseClaimed, [false]);
      game.nextTurn();
      game.chooseStone(1);
      game.timeOut();
      expect(game.surpriseClaimed, [false]);
      game.nextTurn();
      game.unlocked[0] = true;
      game.armCannon();
      game.chooseStone(1);
      game.submit(0);
      expect(game.scores, [30]);
      expect(game.feedback, contains('حجر المفاجأة'));
      expect(game.surpriseClaimed, [true]);
      game.nextTurn();
      game.chooseStone(1);
      game.submit(0);
      expect(game.scores, [40]);
    },
  );
  testWidgets('Sound toggle updates its action and icon', (tester) async {
    GameSound.muted.value = false;
    addTearDown(() => GameSound.muted.value = false);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SoundToggleButton())),
    );
    await tester.tap(find.byTooltip('كتم الصوت'));
    await tester.pump();
    expect(GameSound.muted.value, isTrue);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    await tester.tap(find.byTooltip('تشغيل الصوت'));
    await tester.pump();
    expect(GameSound.muted.value, isFalse);
  });
  testWidgets('Rematch keeps players and banks and resets progress', (
    tester,
  ) async {
    final repository = FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CastleRaceScreen(
          names: const ['المحارب'],
          ages: const [WarriorAge.child],
          characters: const [CastleCharacter.scholar],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final stone = find.byKey(const ValueKey('stone-0-1'));
    await tester.ensureVisible(stone);
    await tester.pumpAndSettle();
    await tester.tap(stone);
    await tester.pumpAndSettle();
    final game = tester
        .widget<QuestionScrollScreen>(find.byType(QuestionScrollScreen))
        .game;
    game.scores[0] = 270;
    final answer = find.widgetWithText(OutlinedButton, 'صحيح');
    await tester.ensureVisible(answer);
    await tester.tap(answer);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('المحارب بطل القلعة!'), findsOneWidget);
    await tester.tap(find.text('إعادة المباراة بنفس اللاعبين'));
    await tester.pumpAndSettle();
    expect(tester.widget<RaceBoard>(find.byType(RaceBoard)).scores, [0]);
    expect(tester.widget<RaceBoard>(find.byType(RaceBoard)).characters, [
      CastleCharacter.scholar,
    ]);
    expect(tester.widget<RaceBoard>(find.byType(RaceBoard)).names, ['المحارب']);
    expect(repository.requested, [WarriorAge.child]);
  });
  test('Summary counts correct, wrong, timed out and loot answers once', () {
    final game = RaceMatch([bank(), bank()]);
    game.chooseStone(1);
    game.submit(0);
    game.submit(0);
    game.nextTurn();
    game.chooseStone(1);
    game.timeOut();
    game.timeOut();
    game.nextTurn();
    game.scores[1] = 50;
    game.chooseStone(4);
    game.submit(1);
    game.stealLoot(0);
    expect(game.correctAnswers, [1, 1]);
    expect(game.wrongAnswers, [1, 0]);
    expect(game.timedOutAnswers, [0, 1]);
    expect(game.stoneLockReason(10), contains('2'));
  });
  testWidgets('Wrong answer reveals correct answer with colors and icons', (
    tester,
  ) async {
    final game = RaceMatch([bank()]);
    game.chooseStone(1);
    await tester.pumpWidget(
      MaterialApp(
        home: QuestionScrollScreen(
          game: game,
          names: const ['المحارب'],
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final wrong = find.widgetWithText(OutlinedButton, 'خطأ');
    await tester.ensureVisible(wrong);
    await tester.tap(wrong);
    await tester.pump();
    final correctButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'صحيح'),
    );
    final wrongButton = tester.widget<OutlinedButton>(wrong);
    expect(
      correctButton.style!.backgroundColor!.resolve({WidgetState.disabled}),
      const Color(0xFF365A32),
    );
    expect(
      wrongButton.style!.backgroundColor!.resolve({WidgetState.disabled}),
      const Color(0xFF893A29),
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Summary fits a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = RaceMatch([bank(), bank()]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RaceSummary(
            game: game,
            names: const ['المحارب الأول', 'المحارب الثاني'],
          ),
        ),
      ),
    );
    expect(find.text('ملخص السباق'), findsOneWidget);
    expect(find.text('صحيحة: 0'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  test('Stones unlock by answered difficulty for each player', () {
    final game = RaceMatch([bank(), bank()]);
    expect(game.chooseStone(4), isFalse);
    expect(game.chooseStone(10), isFalse);
    expect(game.chooseStone(1), isTrue);
    game.submit(1);
    game.nextTurn();
    expect(game.chooseStone(4), isFalse);
    game.chooseStone(3);
    game.submit(0);
    game.nextTurn();
    for (var i = 0; i < 3; i++) {
      expect(game.chooseStone(4 + i), isTrue);
      game.submit(1);
      game.nextTurn();
      game.chooseStone(1);
      game.submit(1);
      game.nextTurn();
      expect(game.levelUnlocked(3), i == 2);
    }
    expect(game.chooseStone(14), isTrue);
  });
  testWidgets('Timeout awards zero and returns after three seconds', (
    tester,
  ) async {
    final game = RaceMatch([bank()]);
    game.chooseStone(1);
    var returns = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: QuestionScrollScreen(
          game: game,
          names: const ['المحارب'],
          onContinue: () => returns++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(game.answered, isTrue);
    expect(game.scores, [0]);
    expect(find.text('انتهى الوقت • 0 نقطة'), findsOneWidget);
    expect(returns, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(returns, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Question parchment waits, opens and fits small and wide screens',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [const Size(320, 640), const Size(1024, 600)]) {
        await tester.binding.setSurfaceSize(size);
        final game = RaceMatch([
          [
            RaceQuestion(
              id: 'scroll',
              number: 1,
              level: 1,
              text: 'ما اسم هذه الدولة التي يظهر علمها في الرسالة المرسلة إلى المحارب؟',
              options: ['ألمانيا', 'فرنسا', 'إيطاليا'],
              answer: 0,
              flagUrl: 'https://flagcdn.com/w320/de.png',
            ),
          ],
        ]);
        game.chooseLevel(1);
        await tester.pumpWidget(
          MaterialApp(
            home: QuestionScrollScreen(
              key: UniqueKey(),
              game: game,
              names: const ['المحارب'],
              onContinue: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0);
        await tester.pumpAndSettle();
        expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
        final answer = find.widgetWithText(OutlinedButton, 'ألمانيا');
        await tester.ensureVisible(answer);
        await tester.tap(answer);
        await tester.pumpAndSettle();
        expect(game.scores, [10]);
        expect(find.text('إجابة صحيحة! +10 نقطة'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('Setup forms fit narrow and wide screens', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(320, 640), const Size(1024, 600)]) {
      await tester.binding.setSurfaceSize(size);
      for (final screen in [
        const WarriorSetupScreen(),
        const TeamSetupScreen(),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!),
            home: screen,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final field in find.byType(TextField).evaluate()) {
          expect(
            tester.getSize(find.byWidget(field.widget)).width,
            lessThanOrEqualTo(460),
          );
        }
        await tester.ensureVisible(find.text('ابدأ'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
  test('Every question flag decodes from bundled PNG assets', () async {
    for (final bank in ['children_questions', 'adults_questions']) {
      final rows =
          jsonDecode(await rootBundle.loadString('data/$bank.json')) as List;
      for (final row in rows) {
        final question = RaceQuestion.fromJson(Map<String, dynamic>.from(row));
        if (question.flagUrl == null) continue;
        expect(question.flagAsset, isNotNull, reason: question.flagUrl);
        final bytes = await rootBundle.load(question.flagAsset!);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    }
  });
  testWidgets('Bundled banks work when Firestore is unavailable', (
    tester,
  ) async {
    const repository = QuestionRepository();
    final children = (await tester.runAsync(
      () => repository.load(WarriorAge.child),
    ))!;
    final adults = (await tester.runAsync(
      () => repository.load(WarriorAge.adult),
    ))!;
    expect(children.offline, isTrue);
    expect(adults.offline, isTrue);
    expect(children.questions.length, 190);
    expect(adults.questions.length, 259);
    expect(children.questions.every((q) => q.options.length == 3), isTrue);
    expect(adults.questions.any((q) => q.id == '107'), isFalse);
  });
  test('Difficulty scoring, threshold win and duplicate submissions', () {
    final game = RaceMatch([bank()]);
    for (var turn = 0; turn < 28; turn++) {
      expect(game.chooseLevel(1), isTrue);
      game.submit(0);
      game.submit(0);
      expect(game.scores[0], (turn + 1) * 10);
      if (turn < 27) game.nextTurn();
    }
    expect(game.winner, 0);
    expect(game.steps, [14]);
    expect(game.chooseLevel(3), isFalse);
  });
  test('Questions and duplicate text never repeat between teams', () {
    final game = RaceMatch([bank(), bank()], random: Random(7));
    for (final counts in game.answeredCounts) {
      counts[0] = 1;
    }
    final seen = <String>{};
    for (var turn = 0; turn < 80; turn++) {
      expect(game.chooseLevel(turn ~/ 40 + 1), isTrue);
      expect(seen.add(game.current!.normalizedText), isTrue);
      game.submit(1);
      game.nextTurn();
    }
    expect(game.scores, [0, 0]);
  });
  test('Cannon unlocks at 150, doubles reward and is single use', () {
    final game = RaceMatch([bank()]);
    expect(game.armCannon(), isFalse);
    for (var i = 0; i < 15; i++) {
      game.chooseLevel(1);
      game.submit(0);
      game.nextTurn();
    }
    expect(game.unlocked[0], isTrue);
    expect(game.armCannon(), isTrue);
    expect(game.armCannon(), isFalse);
    game.answeredCounts[game.team][1] = 3;
    game.chooseLevel(3);
    expect(game.armCannon(), isFalse);
    game.submit(0);
    expect(game.scores, [210]);
    game.nextTurn();
    expect(game.armCannon(), isFalse);
  });
  test('Failed cannon loses base value and never produces negative scores', () {
    final game = RaceMatch([bank()]);
    for (var i = 0; i < 15; i++) {
      game.chooseLevel(1);
      game.submit(0);
      game.nextTurn();
    }
    game.armCannon();
    game.answeredCounts[game.team][1] = 3;
    game.chooseLevel(3);
    game.submit(1);
    expect(game.scores, [120]);
    expect(game.unlocked[0], isTrue);
    expect(game.lootPending, isFalse);
  });
  test(
    'Loot waits before revealing, preserves normal turn and cannot repeat',
    () {
      final game = RaceMatch([bank(), bank()]);
      // Both players reach the unlock threshold through normal play.
      for (var i = 0; i < 10; i++) {
        game.chooseLevel(1);
        game.submit(0);
        game.nextTurn();
      }
      game.answeredCounts[game.team][1] = 3;
      game.chooseLevel(3);
      game.submit(1);
      expect(game.answered, isFalse);
      expect(game.lootPending, isTrue);
      game.nextTurn();
      expect(game.team, 0);
      expect(game.stealLoot(1), isFalse);
      expect(game.lootPending, isTrue);
      expect(game.stealLoot(0), isTrue);
      expect(game.scores, [50, 80]);
      expect(game.lootUsed, [false, true]);
      expect(game.stealLoot(0), isFalse);
      game.nextTurn();
      expect(game.team, 1);
      expect(game.current, isNull);
    },
  );
  test(
    'Declining loot saves it and failing loot consumes it without penalty',
    () {
      final game = RaceMatch([bank(), bank()]);
      for (var i = 0; i < 10; i++) {
        game.chooseLevel(1);
        game.submit(0);
        game.nextTurn();
      }
      game.answeredCounts[game.team][0] = 1;
      game.chooseLevel(2);
      game.submit(1);
      game.declineLoot();
      expect(game.lootUsed[1], isFalse);
      game.nextTurn();
      game.chooseLevel(1);
      game.submit(0);
      game.nextTurn();
      game.answeredCounts[game.team][0] = 1;
      game.chooseLevel(2);
      game.submit(1);
      expect(game.stealLoot(2), isFalse);
      expect(game.lootUsed[1], isTrue);
      expect(game.scores, [50, 60]);
      expect(game.answered, isTrue);
    },
  );
  testWidgets('Age choices are exclusive', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const CastleHeroesApp());
    await tester.tap(find.text('ابدأ التحدي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تحدي 1×1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value, isFalse);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value, isTrue);
  });
  testWidgets('Race loads selected banks and renders on narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CastleRaceScreen(
          names: const ['الأحمر', 'الأزرق'],
          ages: const [WarriorAge.child, WarriorAge.adult],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.requested, [WarriorAge.child, WarriorAge.adult]);
    expect(find.byType(RaceBoard), findsOneWidget);
    expect(find.text('14'), findsNWidgets(2));
    final locked = find.byKey(const ValueKey('stone-0-4'));
    await tester.ensureVisible(locked);
    await tester.pumpAndSettle();
    await tester.tap(locked);
    await tester.pump();
    expect(
      find.text('جاوب على سؤال سهل لفتح الأحجار المتوسطة'),
      findsOneWidget,
    );
    expect(find.byType(QuestionScrollScreen), findsNothing);
    final easy = find.byKey(const ValueKey('stone-0-1'));
    await tester.scrollUntilVisible(easy, 250);
    await tester.ensureVisible(easy);
    await tester.pumpAndSettle();
    await tester.tap(easy);
    await tester.pumpAndSettle();
    expect(find.byType(RaceBoard), findsNothing);
    expect(find.byType(QuestionScrollScreen), findsOneWidget);
    final correct = find.widgetWithText(OutlinedButton, 'صحيح');
    await tester.scrollUntilVisible(correct, 250);
    await tester.ensureVisible(correct);
    await tester.tap(correct);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final scores = tester.widget<RaceBoard>(find.byType(RaceBoard)).scores!;
    expect(scores[0], anyOf(10, 20));
    expect(scores[1], 0);
    expect(
      find.text('دور الأزرق • اضغط على حجر لاختيار السؤال'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
