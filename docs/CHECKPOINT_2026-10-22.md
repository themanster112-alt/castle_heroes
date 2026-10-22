# Saved release — 2026-10-22

Replaced tappable question stones with shared easy/medium/hard buttons in local and online matches. Stones remain a display of each player's score progress. Medium opens after one submitted easy answer; hard after three submitted medium answers. Each player unlocks levels independently. Wrong submitted answers count; timeouts do not. Questions remain random within the selected difficulty.

Online selection retains protocol 2 compatibility and existing Firestore validation. Only the active connected player can select a difficulty. Internal platform selection rotates within that level to preserve surprise bonuses.

Validation: 38 Flutter tests passed, Flutter analysis found no issues, release web build succeeded. Deployed to https://castle-heroes-online-20261021.web.app and passed the two-browser production test, including difficulty locks, turn restrictions, synchronized easy-question selection and offline departure.

## Question-bank update

The user selected the latest one-sheet, 21-question workbook, replacing the earlier two-sheet draft. Added 19 adult hard questions (IDs 261–279); kept the two player-photo questions pending because the images/direct URLs are missing. No questions from the removed worksheet were added. Source rows and the reviewed import are in data/imports; see QUESTION_BANK.md.

Reviewed explicit difficulty for all 449 existing questions, preserving their IDs, text, options and answer indices. Total is now 468 questions: children 190 (47 easy, 122 medium, 21 hard), adults 278 (99 easy, 138 medium, 41 hard). This is an editorial difficulty pass, not a complete fact-check of the legacy bank.

Synced 379 changes to the original question-bank Firebase project and published online catalog version `2-95d8f08`. Existing catalog versions remain intact. Added a reusable Excel reader, validated repeatable batch merge, safe bank-sync tool and LF attributes so bank fingerprints survive cross-platform Git checkouts.

Validation: 40 Flutter tests, 2 Node import tests, Flutter analysis, release web build, deployed Firestore transition tests, and byte-for-byte public catalog verification passed. Both players should refresh and create a new room after the bank update.

## Completed player-photo questions

The user supplied both missing direct image URLs. Added Ronaldinho and Kaka questions as adult hard IDs 280 and 281, completing all 21 questions in the approved workbook. Images are bundled under assets/question_photos and mapped from their source URLs, with a 180-pixel display in local and online play. Generic image semantics do not reveal the correct answer. Shirt descriptions distinguish the two prompts so text deduplication does not hide either question.

Total: 470 questions (190 child, 280 adult); adult difficulty counts are 99 easy, 138 medium, 43 hard. Published catalog `2-6a19ce68`. The workbook import now has no pending rows. Validation: 41 Flutter tests, Flutter analysis, release web build and deployed Firestore security tests passed. Hosting is deployed; public bank assets and both published JPEGs match the local files byte for byte.

## Curated sixty-question batch

The user approved a sixty-question mixed batch and specifically required medium/hard Islamic and Quran questions. Added 30 questions per age bank, including 15 religious questions per bank, all levels 2 or 3. Other additions cover science, history, geography, arithmetic and logic. Each reviewed row has an explanation and references; religious evidence is matched against Quran.com's imlaei verse API, and arithmetic uses checked expression trees. No generation service runs during matches.

IDs: child 191–220; adult 282–311. New totals: 530 questions; children 220 (50/138/32 easy/medium/hard), adults 310 (102/151/57). Original IDs, text and answers remain intact. Published catalog `2-29988b28`. See QUESTION_BATCH_2026-10-22.md for all sixty questions, choices, correct answers, explanations and references.

Validation: 42 Flutter tests, 4 Node tests, Flutter analysis, web release build and deployed Firestore transition/security checks passed. Hosting is deployed, the public assets match the local banks byte for byte, and remote synchronization has no pending writes. New tests reject easy religious additions, corrupted verse anchors and wrong arithmetic results. Editorial difficulty estimates remain subject to playtesting; evidence checks do not replace contextual review.

## Twenty seconds and topic variety

The user requested a fixed twenty-second timer and topic variety. Local questions and fresh loot attempts now use RaceMatch.questionSeconds = 20. Online protocol 3 enforces the same duration through server rules; legacy protocol 2 rooms retain 15 seconds. Current clients require matching room protocol and bank fingerprint. Active rules/config now reference firestore.online.v3.rules.

All 530 bank records now carry explicit topic categories. Selection remains within the selected unlocked difficulty, avoids the previous delivered topic when alternatives exist, then favors least-used available topics across the match. Exhausting other topics never blocks a still-playable level. Canonical event replay records the delivered question category, so replay does not count a temporary random choice. New imports preserve/normalize reviewed topic labels.

Original question text, options, correct answers, IDs and difficulty levels are preserved. Bank Firebase synchronization updates topic metadata only. Published catalog: `3-204f53e0`. Validation: 45 Flutter tests, 5 Node tests, clean Flutter analysis, web build, deployed rules tests (including rejecting 15 seconds in protocol 3 and preserving protocol 2 timing), and public bank byte verification passed. Hosting is deployed. Refresh both clients and create a new room for this release.

Production browser checks passed twice after an initial cold-profile guest-entry attempt showed the generic connection error. The latter two runs verified room creation/join, difficulty locks, synchronized phaseSeconds=20, immediate offline departure and eventual remote closure. One repeat used exception tracing; the final repeat used fresh profiles and the normal harness. The initial connection failure's cause was not established and was not reproduced. Dedicated test profiles/accounts were cleaned up.

## Map controls and fully visible helpers

Local and online selection now share RaceArena: easy/medium/hard buttons sit in the map's center, while both players' complete helper cards stay above it. Removed half-width clipping and tap-to-expand behavior. Names, images and readiness/used/locked labels remain visible; a ready cannon activates on the first tap. Solo loot explains that it requires an opponent. Map stones continue to show progress and difficulty unlocking is unchanged.

Validation: all 48 Flutter tests passed, Flutter analysis is clean, and the release web build succeeded. New geometry checks cover 320px and 900px screens at 130% text scale and require the difficulty buttons to stay inside the map and helper text to stay inside complete cards. A separate interaction check verifies first-tap cannon activation. No bank, rules or protocol changes.

Hosting is deployed. Two successful production checks at a 390px mobile viewport verified room creation/join, per-player difficulty locks, synchronized easy-question selection, immediate offline departure and eventual remote closure. Screenshots confirmed the map controls and complete helper text fit. Large artwork was not yet visible at capture time; direct hosting checks returned the expected PNG bytes for the map and cannon. An intermediate repeat timed out on a blank page before startup; a fresh-profile repeat with a 90-second initial-load allowance passed. The underlying cold-load delay was not established. Browser profiles and anonymous test accounts were cleaned up. Public bank/catalog checks also passed for all 530 questions.
