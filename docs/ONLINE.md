# Online rooms

Firebase project: `castle-heroes-online-20261021` (separate from the question-bank project).

## Play

Open **تحدي 1×1 → اللعب أونلاين**. Choose **فتح غرفة**, enter your own name, age and character, and share the five-digit code. The other player chooses **الدخول إلى غرفة**, enters their own profile and the code. Both devices start automatically after the room is claimed. No account registration is required; Firebase signs each device in anonymously.

Codes expire after 30 minutes while waiting. Active rooms last up to three hours. Each stone-selection turn allows 60 seconds; if it expires, the other player wins for non-response. Activating the cannon does not restart that timer. Either connected participant can advance an expired question/result or claim the expired selection turn.

Closing a room requires confirmation and immediately returns to the previous screen, including offline. A direct Firestore write is queued with persistence enabled and closes the remote room when connectivity returns; the UI never waits for its acknowledgement. A finished room can reject a stale queued departure without blocking navigation. A temporary network interruption disables play inputs until Firestore reconnects. To rejoin after a page reload, enter the same code in the same browser profile; anonymous authentication persists there. Private browsing, clearing site data, or another device creates a different player identity.

Protocol 2 rooms store an ordered command journal, seed, participant profiles, revision and a validated state snapshot. Both clients replay the journal and compare it with the snapshot. A content fingerprint rejects incompatible bank versions. An explicit canonical question key makes replay independent of differences in random selection between platforms. Firestore transactions resolve simultaneous joins and duplicate commands.

All phase start timestamps are server-generated. Rules derive deadlines from those timestamps and fixed durations. Each client calibrates a monotonic clock against its own server-timestamped clock document; changing the device wall clock does not change the game clock. A connected room refreshes calibration periodically. Network latency can still cause small display differences; Firebase's server deadline decides whether a request is timely.

## Firebase configuration

- Anonymous Firebase Authentication enabled.
- Firestore Standard database in `europe-west1`, free tier.
- Web and Android applications registered; public SDK configuration in `lib/online_firebase_options.dart`.
- Active rules are `firestore.online.v2.rules`, referenced by the **separate** configuration below. Do not deploy `firestore.rules` from the original question-bank project here.
- Immutable versioned metadata for all 449 questions is published under `online_catalog/{version}`. It contains only normalized public question texts, answer indices, difficulty and occurrence counts derived from the already-published bundled assets. It contains no administrator credentials or player data.

```powershell
node tools/publish_online_catalog.cjs --dry-run
# Publish metadata when changing bundled questions; requires the owner's Firebase CLI login.
node tools/publish_online_catalog.cjs
firebase deploy --only firestore:rules --config firebase.online.json --project castle-heroes-online-20261021
flutter build web --release
firebase deploy --only hosting --config firebase.online.json --project castle-heroes-online-20261021
```

Firebase client configuration is public identification, not an administrator credential. Administrative access continues to require the user's Firebase CLI login. No service-account key is included.

## Validation

```powershell
flutter analyze
flutter test
node tools/publish_online_catalog.cjs --dry-run
flutter test --dart-define=EXPORT_RULE_FIXTURES=true test/online_protocol_test.dart
node tools/test_online_live.cjs
```

Live tests require the owner's Firebase CLI login. They use temporary anonymous users and newly-created random test rooms with a create-if-absent precondition. Administrative setup seeds only those test documents from Dart-generated fixtures, including expired phases so timeout checks need no real-time wait. Client requests then exercise the actual deployed rules. Cleanup deletes only the newly-created test documents and users.

`node tools/test_online_browser.cjs` checks the production UI using two dedicated headless Edge profiles with remote-debugging ports 8791 and 8792. Launch those profiles on the hosted URL first. It creates/joins a room through the actual forms, disconnects the host through DevTools, verifies immediate navigation after confirming departure, reconnects and checks delivery to the guest. It closes its test profiles and removes their temporary anonymous accounts. It never attaches to the user's ordinary browser profile.

## Scope

Rules validate exact score changes, difficulty unlocks, exhausted levels, cannon thresholds and single use, loot eligibility and rewards, surprise bonuses, winners, state-field types, immutable journal history, turn ownership and server-time deadlines against the immutable catalog. Client-suggested state changes that violate these checks are rejected. Repeated state lookups are cached inside rule functions to remain within Firebase's expression budget. Tests verify rejection of forged rewards, invalid helper payloads, floating-point fields that could break native replay, rewritten history, arbitrary turn changes, locked questions, forged clocks and extended deadlines.

Question content/answer indices are already public in the bundled app. These checks prevent invalid state changes; they do not conceal answers or prevent collusion or a modified client selecting a particular otherwise-valid question. This is a casual two-player game, not a system guaranteeing competitive secrecy.

Old closed/expired room documents currently remain in Firestore. Codes are collision-checked; at high volume, add retention/code recycling before the 90,000-code space fills. Protocol 1 rooms cannot continue with protocol 2; refresh both devices and create a new room after this upgrade.

Other fixes included with online rooms: question identity distinguishes different content with the same numeric ID; text repeats still stay blocked. Exhaustion ends the match with the highest score, or a draw on equal scores. Leaving a local match requires confirmation.
