import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import 'online_match.dart';
import 'online_firebase_options.dart';
import 'race_game.dart';
import 'server_clock.dart';

class OnlineService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final List<List<RaceQuestion>> banks;
  final String bankVersion;
  final ServerClock clock = ServerClock();
  bool _syncingClock = false;
  OnlineService(this.db, this.auth, this.banks, this.bankVersion);
  String get uid => auth.currentUser!.uid;
  CollectionReference<Map<String, dynamic>> get rooms => db.collection('rooms');

  static Future<OnlineService>? _connection;
  static final Set<String> _configuredApps = {};
  static Future<OnlineService> connect() =>
      _connection ??= _connect().catchError((Object error) {
        _connection = null;
        throw error;
      });

  static Future<OnlineService> _connect() async {
    final app =
        Firebase.apps.where((app) => app.name == 'online').firstOrNull ??
        await Firebase.initializeApp(
          name: 'online',
          options: OnlineFirebaseOptions.current,
        ).timeout(const Duration(seconds: 20));
    final auth = FirebaseAuth.instanceFor(app: app);
    if (auth.currentUser == null) {
      await auth.signInAnonymously().timeout(const Duration(seconds: 20));
    }
    final banks = <List<RaceQuestion>>[];
    var hash = 0x811c9dc5;
    for (final name in ['children_questions', 'adults_questions']) {
      final content = await rootBundle.loadString('data/$name.json');
      for (final byte in utf8.encode(content)) {
        // Stays below JavaScript's exact-integer limit on web and matches native Dart.
        hash = (hash * 31 + byte) % 2147483647;
      }
      banks.add(
        (jsonDecode(content) as List)
            .map((q) => RaceQuestion.fromJson(Map<String, dynamic>.from(q)))
            .toList(),
      );
    }
    final db = FirebaseFirestore.instanceFor(app: app);
    if (_configuredApps.add(app.name)) {
      db.settings = const Settings(persistenceEnabled: true);
    }
    final service = OnlineService(
      db,
      auth,
      banks,
      '${OnlineMatch.version}-${hash.toRadixString(16)}',
    );
    await service.syncClock();
    return service;
  }

  Future<void> syncClock() async {
    if (_syncingClock) return;
    _syncingClock = true;
    final watch = Stopwatch()..start();
    try {
      final ref = db.collection('clocks').doc(uid);
      await ref
          .set({'at': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 10));
      final snapshot = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      clock.synchronize(
        (snapshot.data()!['at'] as Timestamp).toDate(),
        roundTrip: watch.elapsed,
      );
    } finally {
      _syncingClock = false;
    }
  }

  DateTime? deadline(Map<String, dynamic> data) {
    final start = data['phaseStartedAt'] as Timestamp?;
    return start?.toDate().add(Duration(seconds: data['phaseSeconds'] as int));
  }

  DateTime expiry(Map<String, dynamic> data) =>
      ((data['startedAt'] ?? data['createdAt']) as Timestamp).toDate().add(
        data['startedAt'] == null
            ? const Duration(minutes: 30)
            : const Duration(hours: 3),
      );

  Future<String> create(Map<String, dynamic> profile) async {
    final random = Random.secure();
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = (10000 + random.nextInt(90000)).toString();
      final created = await db.runTransaction<bool>((tx) async {
        final ref = rooms.doc(code);
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {
          'players': [
            {...profile, 'uid': uid},
          ],
          'status': 'waiting',
          'protocol': OnlineMatch.version,
          'version': bankVersion,
          'seed': random.nextInt(0x7fffffff),
          'events': <String, dynamic>{},
          'revision': 0,
          'phase': 'waiting',
          'turnUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'startedAt': null,
          'phaseStartedAt': null,
          'phaseSeconds': 0,
          'state': null,
        });
        return true;
      });
      if (created) return code;
    }
    throw StateError('تعذّر حجز كود غرفة، حاول مجددًا');
  }

  Future<void> join(String code, Map<String, dynamic> profile) async {
    if (!RegExp(r'^\d{5}$').hasMatch(code)) {
      throw StateError('أدخل كود غرفة من 5 أرقام');
    }
    await db.runTransaction((tx) async {
      final ref = rooms.doc(code);
      final data = (await tx.get(ref)).data();
      if (data == null) throw StateError('الغرفة غير موجودة');
      if (data['version'] != bankVersion) {
        throw StateError('نسخة اللعبة مختلفة؛ حدّث اللعبة على الجهازين');
      }
      final players = (data['players'] as List)
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
      if (players.any((p) => p['uid'] == uid)) return;
      if (data['status'] != 'waiting' || players.length != 1) {
        throw StateError('الغرفة ممتلئة أو انتهت');
      }
      if (expiry(data).isBefore(clock.now)) {
        throw StateError('انتهت صلاحية كود الغرفة');
      }
      final playersAfter = [
        ...players,
        {...profile, 'uid': uid},
      ];
      final match = OnlineMatch({...data, 'players': playersAfter}, banks);
      tx.update(ref, {
        'players': playersAfter,
        'status': 'playing',
        'phase': 'choose',
        'updatedAt': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(),
        'phaseStartedAt': FieldValue.serverTimestamp(),
        'phaseSeconds': 60,
        'state': match.snapshot(),
      });
    });
  }

  Future<void> command(
    String code,
    int revision,
    String kind, [
    int? value,
  ]) async {
    await db.runTransaction((tx) async {
      final ref = rooms.doc(code);
      final data = (await tx.get(ref)).data();
      if (data == null ||
          data['status'] != 'playing' ||
          data['revision'] != revision) {
        return;
      }
      final players = (data['players'] as List).cast<Map>();
      final lane = players.indexWhere((p) => p['uid'] == uid);
      if (lane < 0) throw StateError('لست مشاركًا بالغرفة');
      final automatic = ['timeout', 'next', 'forfeit'].contains(kind);
      final now = clock.now;
      final endsAt = deadline(data);
      if (automatic) {
        if (endsAt == null || now.isBefore(endsAt)) return;
      } else if (data['turnUid'] != uid) {
        throw StateError('انتظر دورك');
      } else if (endsAt != null && now.isAfter(endsAt)) {
        return;
      }
      final match = OnlineMatch(data, banks);
      final wasLoot = match.game.lootPending;
      final event = {'kind': kind, 'value': value, 'actor': lane};
      OnlineMatch.apply(match.game, event);
      if (kind == 'choose') {
        event['question'] =
            '${players[match.game.team]['age']}_${match.game.current!.id}';
      }
      final phase = OnlineMatch.phase(match.game);
      final seconds = phase == 'answer' || phase == 'loot'
          ? 15
          : phase == 'result'
          ? (wasLoot && kind == 'answer' ? 6 : 3)
          : phase == 'choose'
          ? 60
          : 0;
      tx.update(ref, {
        'events.$revision': event,
        'revision': revision + 1,
        'phase': phase,
        'turnUid': players[match.game.answeringTeam]['uid'],
        'phaseStartedAt': kind == 'cannon'
            ? data['phaseStartedAt']
            : FieldValue.serverTimestamp(),
        'phaseSeconds': seconds,
        'state': match.snapshot(),
        'status': phase == 'finished' ? 'finished' : 'playing',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // A direct write queues offline; leaving the screen never waits for its acknowledgement.
  Future<void> leave(String code) => rooms.doc(code).update({
    'status': 'closed',
    'leftBy': uid,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
