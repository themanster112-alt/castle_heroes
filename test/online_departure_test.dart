// Firestore's annotated model types are faked only at this UI boundary.
// ignore_for_file: invalid_use_of_type_outside_library, subtype_of_sealed_class
import 'dart:async';

import 'package:castle_heroes/online_screen.dart';
import 'package:castle_heroes/online_service.dart';
import 'package:castle_heroes/race_game.dart';
import 'package:castle_heroes/server_clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RoomMetadata extends Fake implements SnapshotMetadata {
  final bool cached;
  RoomMetadata(this.cached);
  @override
  bool get isFromCache => cached;
}

class RoomSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> value;
  final bool cached;
  RoomSnapshot(this.value, this.cached);
  @override
  Map<String, dynamic> data() => value;
  @override
  SnapshotMetadata get metadata => RoomMetadata(cached);
}

class RoomDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final RoomSnapshot snapshot;
  RoomDocument(this.snapshot);
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(snapshot);
}

class RoomCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final RoomSnapshot snapshot;
  RoomCollection(this.snapshot);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      RoomDocument(snapshot);
}

class OfflineRoomService extends Fake implements OnlineService {
  @override
  final ServerClock clock = ServerClock()
    ..synchronize(DateTime.utc(2026, 10, 21));
  @override
  String get uid => 'host';
  @override
  List<List<RaceQuestion>> get banks => List.generate(
    2,
    (age) => [
      RaceQuestion(
        id: '1',
        number: 1,
        level: 1,
        text: 'سؤال $age',
        options: ['أ', 'ب', 'ج'],
        answer: 0,
      ),
    ],
  );
  final pendingLeave = Completer<void>();
  bool requestedLeave = false;
  final commands = <String>[];
  final bool active;
  OfflineRoomService({this.active = false});
  @override
  CollectionReference<Map<String, dynamic>> get rooms => RoomCollection(
    RoomSnapshot({
      'players': [
        {'uid': 'host', 'name': 'الأول', 'age': 0, 'character': 0},
        if (active)
          {'uid': 'guest', 'name': 'الثاني', 'age': 1, 'character': 1},
      ],
      'seed': 7,
      'revision': 0,
      'events': <String, dynamic>{},
      'state': null,
      'status': active ? 'playing' : 'waiting',
      'phase': active ? 'choose' : 'waiting',
      'turnUid': 'host',
      'phaseSeconds': active ? 60 : 0,
      'phaseStartedAt': active
          ? Timestamp.fromDate(clock.now.subtract(const Duration(seconds: 61)))
          : null,
    }, !active),
  );
  @override
  DateTime expiry(Map<String, dynamic> data) =>
      clock.now.add(const Duration(hours: 1));
  @override
  DateTime? deadline(Map<String, dynamic> data) =>
      (data['phaseStartedAt'] as Timestamp?)?.toDate().add(
        Duration(seconds: data['phaseSeconds'] as int),
      );
  @override
  Future<void> leave(String code) {
    requestedLeave = true;
    return pendingLeave.future;
  }

  @override
  Future<void> command(
    String code,
    int revision,
    String kind, [
    int? value,
  ]) async {
    commands.add(kind);
  }
}

void main() {
  testWidgets(
    'Offline departure returns immediately while the server write remains pending',
    (tester) async {
      final service = OfflineRoomService();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        OnlineRoomScreen(service: service, code: '12345'),
                  ),
                ),
                child: const Text('فتح غرفة'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('فتح غرفة'));
      await tester.pumpAndSettle();
      expect(find.text('بانتظار اللاعب الثاني'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مغادرة'));
      await tester.pumpAndSettle();
      expect(service.requestedLeave, isTrue);
      expect(service.pendingLeave.isCompleted, isFalse);
      expect(find.byType(OnlineRoomScreen), findsNothing);
      service.pendingLeave.completeError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'An expired selection deadline requests a forfeit on either device',
    (tester) async {
      final service = OfflineRoomService(active: true);
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineRoomScreen(service: service, code: '12345'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(service.commands, contains('forfeit'));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
