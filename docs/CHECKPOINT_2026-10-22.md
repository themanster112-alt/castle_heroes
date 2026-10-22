# Saved release — 2026-10-22

Replaced tappable question stones with shared easy/medium/hard buttons in local and online matches. Stones remain a display of each player's score progress. Medium opens after one submitted easy answer; hard after three submitted medium answers. Each player unlocks levels independently. Wrong submitted answers count; timeouts do not. Questions remain random within the selected difficulty.

Online selection retains protocol 2 compatibility and existing Firestore validation. Only the active connected player can select a difficulty. Internal platform selection rotates within that level to preserve surprise bonuses.

Validation: 38 Flutter tests passed, Flutter analysis found no issues, release web build succeeded. Deployed to https://castle-heroes-online-20261021.web.app and passed the two-browser production test, including difficulty locks, turn restrictions, synchronized easy-question selection and offline departure.

## Question-bank update

The user selected the latest one-sheet, 21-question workbook, replacing the earlier two-sheet draft. Added 19 adult hard questions (IDs 261–279); kept the two player-photo questions pending because the images/direct URLs are missing. No questions from the removed worksheet were added. Source rows and the reviewed import are in data/imports; see QUESTION_BANK.md.

Reviewed explicit difficulty for all 449 existing questions, preserving their IDs, text, options and answer indices. Total is now 468 questions: children 190 (47 easy, 122 medium, 21 hard), adults 278 (99 easy, 138 medium, 41 hard). This is an editorial difficulty pass, not a complete fact-check of the legacy bank.

Synced 379 changes to the original question-bank Firebase project and published online catalog version `2-95d8f08`. Existing catalog versions remain intact. Added a reusable Excel reader, validated repeatable batch merge, safe bank-sync tool and LF attributes so bank fingerprints survive cross-platform Git checkouts.

Validation: 40 Flutter tests, 2 Node import tests, Flutter analysis, release web build, deployed Firestore transition tests, and byte-for-byte public catalog verification passed. Both players should refresh and create a new room after the bank update.
