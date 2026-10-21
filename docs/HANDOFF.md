# Continue development on another computer

The Flutter project is in `castle_heroes/` inside the `store_app` repository.

## Current implementation

- Cannon unlocks at 150 points; loot unlocks at 50.
- Select questions by tapping stones: 1–3 easy, 4–9 medium, 10–14 hard.
- Each player unlocks medium after answering one easy question and hard after answering three medium questions. Incorrect submitted answers count toward unlocking; timeouts do not.
- Questions allow 15 seconds after the entrance animation. Timeout earns zero. Results return automatically after three seconds.
- Helpers start half visible and expand when tapped.
- Locked stones explain their requirements. Last five seconds show a red countdown and soft audio.
- Answer results use green/red with icons. Final summary includes correct, incorrect and timed out answers.
- One hidden random surprise stone per player awards 10 bonus points once after a correct answer. Cannon doubles base points only.
- Rematch retains players, ages and characters and resets the match without reloading question banks.
- Sound toggle controls menu clicks and question timer. Current choice lasts for the running app session.
- Four Arab castle characters are selectable independently per player/team: guardian, archer, scholar and scout. They appear on the board, question screen and summary, including after rematch. Character choices are cosmetic.
- Character artwork is bundled under `assets/characters/`; generation descriptions are in `docs/character-art.md`.

## Validation

Last run: 22 Flutter tests passed; Dart analysis of `lib` and `test` reported no issues.

## On the other computer

1. Clone the repository or pull the latest `main`.
2. Open `castle_heroes/`.
3. Run `flutter pub get`.
4. Run `flutter test` and `flutter run` with the desired device.

The project declares Dart SDK `^3.13.4`; use a compatible Flutter SDK. Dependencies and SDK installations are not committed.
