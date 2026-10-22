import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'castle_character.dart';
import 'helper_announcement.dart';
import 'online_match.dart';
import 'online_service.dart';
import 'player_setup.dart';
import 'race_game.dart';

String onlineError(Object error) {
  if (error is StateError) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'الغرفة غير متاحة أو انتهت صلاحيتها.',
      'unavailable' || 'network-request-failed' =>
        'تعذّر الاتصال. تأكد من الإنترنت وحاول مجددًا.',
      'operation-not-allowed' => 'تسجيل دخول الضيوف غير مفعّل في خدمة اللعب.',
      _ => 'تعذّر إكمال الطلب (${error.code}). حاول مجددًا.',
    };
  }
  return 'تعذّر الاتصال بالغرفة. حاول مجددًا.';
}

class OnlineEntryScreen extends StatefulWidget {
  final bool join;
  const OnlineEntryScreen({super.key, required this.join});
  @override
  State<OnlineEntryScreen> createState() => _OnlineEntryScreenState();
}

class _OnlineEntryScreenState extends State<OnlineEntryScreen> {
  final _name = TextEditingController(), _code = TextEditingController();
  WarriorAge? _age;
  CastleCharacter _character = CastleCharacter.guardian;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty ||
        _age == null ||
        (widget.join && !RegExp(r'^\d{5}$').hasMatch(_code.text))) {
      setState(
        () => _error =
            'أدخل اسمك وفئتك العمرية${widget.join ? ' وكود الغرفة من 5 أرقام' : ''}.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = await OnlineService.connect();
      final profile = {
        'name': _name.text.trim(),
        'age': _age!.index,
        'character': _character.index,
      };
      final code = widget.join ? _code.text : await service.create(profile);
      if (widget.join) await service.join(code, profile);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OnlineRoomScreen(service: service, code: code),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = onlineError(error);
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlayerSetupBackdrop(
    children: [
      Text(
        widget.join ? 'الدخول إلى غرفة' : 'إنشاء غرفة أونلاين',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, color: raceGold),
      ),
      const SizedBox(height: 16),
      WarriorSetupCard(
        title: 'محاربك',
        controller: _name,
        young: _age == WarriorAge.child,
        veteran: _age == WarriorAge.adult,
        onYoungChanged: (_) => setState(() => _age = WarriorAge.child),
        onVeteranChanged: (_) => setState(() => _age = WarriorAge.adult),
        character: _character,
        onCharacterChanged: (value) => setState(() => _character = value),
      ),
      if (widget.join)
        TextField(
          controller: _code,
          maxLength: 5,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'كود الغرفة — 5 أرقام',
            border: OutlineInputBorder(),
          ),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(),
              )
            : Text(widget.join ? 'انضمام' : 'إنشاء غرفة'),
      ),
      const SizedBox(height: 12),
      const Text(
        'كل لاعب يدخل من جهازه. لا يحتاج إنشاء حساب.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class OnlineRoomScreen extends StatefulWidget {
  final OnlineService service;
  final String code;
  const OnlineRoomScreen({
    super.key,
    required this.service,
    required this.code,
  });
  @override
  State<OnlineRoomScreen> createState() => _OnlineRoomScreenState();
}

class _OnlineRoomScreenState extends State<OnlineRoomScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _clock;
  Map<String, dynamic>? _data;
  OnlineMatch? _match;
  String? _error;
  bool _sending = false, _cached = true, _allowExit = false, _leaving = false;
  int _seenRevision = -1;
  Duration _lastClockAttempt = Duration.zero;
  Duration _automaticRetryAt = Duration.zero;
  int get _revision => _data?['revision'] as int? ?? 0;
  bool get _expired =>
      _data != null &&
      widget.service.expiry(_data!).isBefore(widget.service.clock.now);
  int get _lane => (_data!['players'] as List).indexWhere(
    (p) => p['uid'] == widget.service.uid,
  );
  int get _seconds {
    final deadline = _data == null ? null : widget.service.deadline(_data!);
    return deadline == null
        ? 0
        : max(
            0,
            (deadline.millisecondsSinceEpoch -
                    widget.service.clock.now.millisecondsSinceEpoch +
                    999) ~/
                1000,
          );
  }

  @override
  void initState() {
    super.initState();
    _listen();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {});
      final clock = widget.service.clock;
      if (!_cached &&
          clock.age > const Duration(minutes: 1) &&
          clock.elapsed - _lastClockAttempt > const Duration(minutes: 1)) {
        _lastClockAttempt = clock.elapsed;
        unawaited(widget.service.syncClock().catchError((Object _) {}));
      }
      if (_data?['status'] == 'playing' &&
          !_expired &&
          !_cached &&
          _seconds == 0) {
        final phase = _data!['phase'];
        if (phase == 'choose') _send('forfeit');
        if (phase == 'result') _send('next');
        if (phase == 'answer' || phase == 'loot') _send('timeout');
      }
    });
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = widget.service.rooms
        .doc(widget.code)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (!mounted) return;
            final data = snapshot.data();
            if (data == null) {
              setState(() => _error = 'الغرفة غير موجودة');
              return;
            }
            try {
              final match = OnlineMatch(data, widget.service.banks);
              final revision = data['revision'] as int;
              final events = data['events'] as Map;
              final last = events['${revision - 1}'] as Map?;
              final show =
                  _seenRevision >= 0 &&
                  revision > _seenRevision &&
                  last != null &&
                  (last['kind'] == 'cannon' ||
                      (last['kind'] == 'answer' && _data?['phase'] == 'loot'));
              setState(() {
                _data = data;
                _match = match;
                _cached = snapshot.metadata.isFromCache;
                _error = null;
              });
              _seenRevision = revision;
              if (show) {
                final players = data['players'] as List;
                final actor = last['actor'] as int;
                final cannon = last['kind'] == 'cannon';
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  showHelperAnnouncement(
                    context,
                    player: players[actor]['name'] as String,
                    helper: cannon ? 'القذيفة المضاعفة' : 'سرقة الغنيمة',
                    asset:
                        'assets/helpers/${cannon ? 'cannon' : 'loot'}_${actor == 0 ? 'blue' : 'red'}.png',
                  );
                });
              }
            } catch (_) {
              setState(
                () => _error = 'تعذّرت مزامنة المباراة. تأكد أن الجهازين يستخدمان نفس النسخة.',
              );
            }
          },
          onError: (Object error) {
            if (mounted) setState(() => _error = onlineError(error));
          },
        );
  }

  Future<void> _send(String kind, [int? value]) async {
    if (_sending || _cached || _data == null) return;
    final automatic = ['timeout', 'next', 'forfeit'].contains(kind);
    if (automatic && widget.service.clock.elapsed < _automaticRetryAt) return;
    setState(() => _sending = true);
    try {
      await widget.service.command(widget.code, _revision, kind, value);
    } catch (error) {
      if (automatic) {
        _automaticRetryAt =
            widget.service.clock.elapsed + const Duration(seconds: 2);
        unawaited(widget.service.syncClock().catchError((Object _) {}));
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(onlineError(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final active = ['waiting', 'playing'].contains(_data?['status']);
    final confirmed =
        !active ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('مغادرة الغرفة؟'),
                content: const Text(
                  'ستُغلق الغرفة ويُبلّغ اللاعب الآخر بالمغادرة.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('البقاء'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('مغادرة'),
                  ),
                ],
              ),
            ) ==
            true;
    if (!mounted) return;
    if (!confirmed) {
      _leaving = false;
      return;
    }
    if (active) {
      unawaited(
        widget.service.leave(widget.code).catchError((Object _) {
          // Firestore retains offline writes. A finished/closed room may reject a stale leave.
        }),
      );
    }
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: Text('غرفة ${widget.code}'),
      ),
      body: _data == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _listen,
                          child: const Text('إعادة الاتصال'),
                        ),
                      ],
                    ),
            )
          : _content(),
    ),
  );

  Widget _content() {
    final data = _data!;
    final game = _match!.game;
    final players = (data['players'] as List).cast<Map>();
    final names = players.map((p) => p['name'] as String).toList();
    final characters = players
        .map((p) => CastleCharacter.values[p['character'] as int])
        .toList();
    if (_expired) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('انتهت صلاحية الغرفة. أنشئ غرفة جديدة.'),
            FilledButton(onPressed: _leave, child: const Text('العودة')),
          ],
        ),
      );
    }
    if (data['status'] == 'waiting') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 64, color: raceGold),
              const Text(
                'بانتظار اللاعب الثاني',
                style: TextStyle(fontSize: 26),
              ),
              const SizedBox(height: 20),
              SelectableText(
                widget.code,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 56,
                  letterSpacing: 8,
                  color: raceGold,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: widget.code));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ كود الغرفة')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('نسخ الكود'),
              ),
              const Text(
                'شارك الكود مع صديقك. تبدأ المباراة تلقائيًا بعد دخوله.',
                textAlign: TextAlign.center,
              ),
              const Text('الكود صالح لمدة 30 دقيقة.'),
              if (_cached) const Text('جاري الاتصال بالخادم…'),
            ],
          ),
        ),
      );
    }
    if (data['status'] == 'closed') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'غادر أحد اللاعبين. أُغلقت الغرفة.',
              style: TextStyle(fontSize: 24),
            ),
            FilledButton(onPressed: _leave, child: const Text('العودة')),
          ],
        ),
      );
    }
    final myTurn =
        data['turnUid'] == widget.service.uid && !_sending && !_cached;
    final phase = data['phase'];
    final question = game.current;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_cached)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'الاتصال متوقف؛ جارٍ إعادة المزامنة…',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          children: [
            for (var i = 0; i < players.length; i++)
              Text(
                '${names[i]}${i == _lane ? ' (أنت)' : ''}: ${game.scores[i]} نقطة',
                style: const TextStyle(fontSize: 20, color: raceGold),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (phase == 'finished') ...[
          if (game.feedback.contains('مهلة اختيار الحجر'))
            Text(game.feedback, textAlign: TextAlign.center),
          Text(
            game.resultWinner == null
                ? 'انتهت المباراة بالتعادل!'
                : '${names[game.resultWinner!]} بطل القلعة!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, color: raceGold),
          ),
          RaceSummary(game: game, names: names, characters: characters),
          FilledButton(onPressed: _leave, child: const Text('العودة')),
        ] else if (question == null) ...[
          Text(
            'مهلة اختيار المستوى: $_seconds ثانية',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _seconds <= 10 ? Colors.redAccent : raceGold,
            ),
          ),
          const Text(
            'عند انتهاء المهلة تُحسب المباراة للخصم.',
            textAlign: TextAlign.center,
          ),
          Text(
            myTurn
                ? 'دورك الآن، اختر مستوى السؤال'
                : 'بانتظار ${names[game.team]} لاختيار السؤال',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24),
          ),
          DifficultyPicker(
            game: game,
            enabled: myTurn,
            onSelected: (level) => _send('choose', game.stoneForLevel(level)),
          ),
          const SizedBox(height: 16),
          const Text('تقدّم اللاعبين نحو القلعة', textAlign: TextAlign.center),
          RaceBoard(
            names: names,
            characters: characters,
            steps: game.steps,
            scores: game.scores,
            active: game.team,
          ),
          if (game.cannonArmed)
            const Text('القذيفة مفعّلة ×2', textAlign: TextAlign.center),
          if (myTurn && game.unlocked[game.team] && !game.cannonUsed[game.team])
            FilledButton.icon(
              onPressed: () => _send('cannon'),
              icon: const Icon(Icons.local_fire_department),
              label: const Text('القذيفة المضاعفة'),
            ),
          if (myTurn && !game.hasPlayableQuestion)
            FilledButton(
              onPressed: () => _send('skip'),
              child: const Text('تجاوز الدور'),
            ),
        ] else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: phase == 'loot'
                  ? const Color(0xFF123D56)
                  : const Color(0xFF26313F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: raceGold),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (phase == 'loot') ...[
                  Image.asset(
                    'assets/helpers/loot_${game.opponent == 0 ? 'blue' : 'red'}.png',
                    height: 85,
                  ),
                  Text(
                    'سرقة الغنيمة — دور ${names[game.opponent]}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, color: raceGold),
                  ),
                ] else
                  Text(
                    phase == 'result'
                        ? 'نتيجة السؤال'
                        : 'السؤال إلى ${names[game.team]}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                  ),
                Text(
                  phase == 'result'
                      ? 'متابعة خلال $_seconds ثوانٍ'
                      : 'الوقت المتبقي: $_seconds ثانية',
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${game.questionPoints} نقطة',
                  textAlign: TextAlign.center,
                ),
                if (question.flagAsset != null)
                  Image.asset(question.flagAsset!, height: 70),
                const SizedBox(height: 16),
                Text(
                  question.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                for (var i = 0; i < question.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: OutlinedButton(
                      onPressed:
                          myTurn &&
                              !game.answered &&
                              i != game.wrongOption &&
                              _seconds > 0
                          ? () => _send('answer', i)
                          : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: game.answered && i == question.answer
                            ? const Color(0xFF365A32)
                            : i == game.wrongOption
                            ? const Color(0xFF893A29)
                            : null,
                        disabledForegroundColor: Colors.white,
                      ),
                      child: Text(
                        question.options[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 21),
                      ),
                    ),
                  ),
                if (phase == 'loot' && myTurn)
                  TextButton(
                    onPressed: () => _send('decline'),
                    child: const Text('الاحتفاظ بسرقة الغنيمة'),
                  ),
                if (game.answered)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(game.feedback, textAlign: TextAlign.center),
                  ),
                if (!myTurn && !game.answered)
                  const Text(
                    'تابع السؤال، الإجابة عند اللاعب الآخر.',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
