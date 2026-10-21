# Castle race

Solo and local team setup open `CastleRaceScreen`. Age choices select
`children_questions` or `adults_questions`. Each team needs 12 correct answers;
wrong answers consume the question but do not advance the token. Turns alternate
after the player presses the next-turn button. The first token at 12 wins.

A match shares a ledger of question IDs and normalized texts across teams.
Starting a new match clears the ledger. Question numbers preserve the workbook's
difficulty order; the bank is divided into 12 bands selected by each team's
progress. This assumes the workbook order reflects difficulty.

The repository reads Firestore through its REST API. It loads each selected bank
once per match, handles pagination, and falls back to the bundled validated JSON
when remote reads fail. The UI indicates that fallback is in use.

Firebase project: `castle-heroes-20261014`, default database, `europe-west3`.
The owner approved deployment of `firestore.rules`, which is now live. These
rules allow public reads of the two question collections (including correct
answers) and deny all client writes. Anonymous REST reads returned HTTP 200 for
190 children questions and 259 adult questions. Redeploy rule updates with:

```
firebase deploy --only firestore:rules --project castle-heroes-20261014
```

The landscape is drawn directly in Flutter: two winding roads, numbered stations,
a river, greenery, rocks, a castle icon and animated team shield tokens. The user's
reference photo is design inspiration, not an exact bitmap recreation.

Checks: `flutter analyze`, `flutter test`, `flutter build web`.
