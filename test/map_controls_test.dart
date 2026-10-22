import 'package:castle_heroes/race_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RaceMatch match() => RaceMatch(
  List.generate(
    2,
    (lane) => List.generate(
      6,
      (i) => RaceQuestion(
        id: '${lane * 10 + i}',
        number: i,
        text: 'سؤال $lane $i',
        level: i ~/ 2 + 1,
        options: ['أ', 'ب', 'ج'],
        answer: 0,
      ),
    ),
  ),
);

void main() {
  for (final width in [288.0, 320.0, 900.0]) {
    testWidgets('Solo map has one unobstructed trail at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var chosen = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MediaQuery(
                data: MediaQueryData(textScaler: const TextScaler.linear(1.3)),
                child: RaceArena(
                  game: match(),
                  names: const ['المحارب'],
                  onLevel: (level) => chosen = level,
                  onCannon: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('solo-map')), findsOneWidget);
      final image = tester.widget<Image>(
        find.byKey(const ValueKey('solo-map')),
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/backgrounds/solo_question_map.jpg',
      );
      expect(find.byKey(const ValueKey('stone-1-1')), findsNothing);
      final board = tester.getRect(find.byType(RaceBoard));
      final controls = tester.getRect(find.byType(DifficultyPicker));
      final score = tester.getRect(
        find.byKey(const ValueKey('player-helpers-0')),
      );
      expect(find.text('المحارب • 0 نقطة'), findsOneWidget);
      expect(board.contains(controls.topLeft), isTrue);
      expect(board.contains(controls.bottomRight), isTrue);
      for (var step = 1; step <= RaceMatch.stationCount; step++) {
        final stone = tester.getRect(find.byKey(ValueKey('stone-0-$step')));
        final expected = RaceBoard.position(0, step.toDouble(), solo: true);
        expect(
          stone.left,
          closeTo(board.left + expected.dx * board.width - 16, .01),
        );
        expect(
          stone.overlaps(controls),
          isFalse,
          reason: 'Station $step ($stone) must remain clear of $controls',
        );
        expect(
          stone.overlaps(score),
          isFalse,
          reason: 'Score must not cover station $step',
        );
      }
      await tester.ensureVisible(find.byKey(const ValueKey('difficulty-1')));
      await tester.tap(find.byKey(const ValueKey('difficulty-1')));
      expect(chosen, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 740), const Size(900, 900)]) {
    testWidgets('Map choices and complete helper cards fit $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final game = match();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: RaceArena(
                  game: game,
                  names: const ['المحارب الأول', 'المحارب الثاني'],
                  onLevel: (_) {},
                  onCannon: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final board = tester.getRect(find.byType(RaceBoard));
      expect(
        find.descendant(
          of: find.byType(RaceBoard),
          matching: find.byType(DifficultyPicker),
        ),
        findsOneWidget,
      );
      for (var level = 1; level <= 3; level++) {
        final button = tester.getRect(
          find.byKey(ValueKey('difficulty-$level')),
        );
        expect(board.contains(button.topLeft), isTrue);
        expect(board.contains(button.bottomRight), isTrue);
      }
      for (var lane = 0; lane < 2; lane++) {
        final panel = tester.getRect(
          find.byKey(ValueKey('player-helpers-$lane')),
        );
        for (final helper in ['cannon', 'loot']) {
          final card = find.byKey(
            ValueKey('helper-${helper}_${lane == 0 ? 'blue' : 'red'}'),
          );
          final rect = tester.getRect(card);
          expect(panel.contains(rect.topLeft), isTrue);
          expect(panel.contains(rect.bottomRight), isTrue);
          for (final widget in tester.widgetList<Text>(
            find.descendant(of: card, matching: find.byType(Text)),
          )) {
            final label = tester.getRect(find.byWidget(widget));
            expect(rect.contains(label.topLeft), isTrue);
            expect(rect.contains(label.bottomRight), isTrue);
          }
        }
      }
      expect(find.text('القذيفة المضاعفة'), findsNWidgets(2));
      expect(find.text('سرقة الغنيمة'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Available cannon activates on first tap without expanding', (
    tester,
  ) async {
    final game = match();
    game.scores[0] = 150;
    game.unlocked[0] = true;
    var activated = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RaceArena(
              game: game,
              names: const ['أ', 'ب'],
              onLevel: (_) {},
              onCannon: (_) => activated++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('helper-cannon_blue')));
    expect(activated, 1);
  });
}
