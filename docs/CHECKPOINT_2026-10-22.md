# Saved release — 2026-10-22

Replaced tappable question stones with shared easy/medium/hard buttons in local and online matches. Stones remain a display of each player's score progress. Medium opens after one submitted easy answer; hard after three submitted medium answers. Each player unlocks levels independently. Wrong submitted answers count; timeouts do not. Questions remain random within the selected difficulty.

Online selection retains protocol 2 compatibility and existing Firestore validation. Only the active connected player can select a difficulty. Internal platform selection rotates within that level to preserve surprise bonuses.

Validation: 38 Flutter tests passed, Flutter analysis found no issues, release web build succeeded. Deployed to https://castle-heroes-online-20261021.web.app and passed the two-browser production test, including difficulty locks, turn restrictions, synchronized easy-question selection and offline departure.
