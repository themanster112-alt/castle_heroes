import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'race_game.dart';
import 'menu_audio.dart';
import 'castle_character.dart';
import 'helper_announcement.dart';

/// The question has its own view; its match stays owned by the selection view.
class QuestionScrollScreen extends StatefulWidget {
  final RaceMatch game;
  final List<String> names;
  final VoidCallback onContinue;
  final List<CastleCharacter>? characters;
  const QuestionScrollScreen({
    super.key,
    required this.game,
    required this.names,
    required this.onContinue,
    this.characters,
  });

  @override
  State<QuestionScrollScreen> createState() => _QuestionScrollScreenState();
}

class _QuestionScrollScreenState extends State<QuestionScrollScreen>
    with SingleTickerProviderStateMixin {
  static const ink = Color(0xFF35200D);
  late final AnimationController _entrance;
  final ScrollController _scrollController = ScrollController();
  int? selected;
  int? _resultTeam;
  Timer? _timer, _returnTimer;
  int remaining = 15;
  AudioPlayer? _warningPlayer;
  bool get _urgent => remaining <= 5 && !widget.game.answered;

  Future<void> _playWarning() async {
    if (GameSound.muted.value) return;
    try {
      final player = _warningPlayer ??= AudioPlayer();
      await player.play(AssetSource('audio/timer_tick.wav'), volume: .25);
    } catch (_) {
      // Visual countdown remains available on devices without audio support.
    }
  }

  void _applyMute() {
    if (GameSound.muted.value) unawaited(_warningPlayer?.stop());
  }

  void _finish() {
    _timer?.cancel();
    _returnTimer?.cancel();
    _returnTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      widget.onContinue();
    });
  }

  Future<void> _answer(int option) async {
    if (widget.game.answered) return;
    final stealing = widget.game.lootPending;
    if (stealing) _timer?.cancel();
    setState(() {
      _resultTeam = widget.game.answeringTeam;
      selected = option;
      if (widget.game.lootPending) {
        widget.game.stealLoot(option);
      } else {
        widget.game.submit(option);
      }
    });
    if (widget.game.lootPending) {
      selected = null;
      remaining = 15;
      _startTimer();
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } else {
      if (stealing) {
        await showHelperAnnouncement(
          context,
          player: widget.names[widget.game.opponent],
          helper: 'سرقة الغنيمة',
          asset:
              'assets/helpers/loot_${widget.game.opponent == 0 ? 'blue' : 'red'}.png',
        );
        if (!mounted) return;
      }
      _finish();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _returnTimer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        remaining--;
        if (remaining == 0) {
          if (widget.game.lootPending) {
            widget.game.declineLoot();
          } else {
            widget.game.timeOut();
          }
        }
      });
      if (remaining > 0 && remaining <= 5) unawaited(_playWarning());
      if (remaining == 0) _finish();
    });
  }

  @override
  void initState() {
    super.initState();
    GameSound.muted.addListener(_applyMute);
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _entrance.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (widget.game.answered || (_timer?.isActive ?? false)) return;
      _startTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _returnTimer?.cancel();
    GameSound.muted.removeListener(_applyMute);
    _entrance.dispose();
    _scrollController.dispose();
    unawaited(_warningPlayer?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final question = game.current!;
    final displayTeam = game.answered
        ? (_resultTeam ?? game.team)
        : game.answeringTeam;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/question/battle.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
            AnimatedContainer(
              key: const ValueKey('loot-background'),
              duration: const Duration(milliseconds: 400),
              color: game.lootPending
                  ? const Color(0xCC123D56)
                  : const Color(0x20000000),
            ),
            SafeArea(
              child: AnimatedBuilder(
                animation: _entrance,
                builder: (context, child) {
                  final reducedMotion = MediaQuery.disableAnimationsOf(context);
                  final progress = reducedMotion
                      ? 1.0
                      : const Interval(
                          .375,
                          1,
                          curve: Curves.easeOutCubic,
                        ).transform(_entrance.value);
                  return IgnorePointer(
                    ignoring: !reducedMotion && !_entrance.isCompleted,
                    child: ExcludeSemantics(
                      excluding: progress == 0,
                      child: Opacity(
                        opacity: progress,
                        child: Transform.translate(
                          offset: Offset(0, -35 * (1 - progress)),
                          child: ClipRect(
                            clipper: _ScrollRevealClipper(progress),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: LayoutBuilder(
                  builder: (context, viewport) => SingleChildScrollView(
                    controller: _scrollController,
                    key: const ValueKey('question-scroll'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: LayoutBuilder(
                          builder: (context, paper) => Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/question/parchment.png',
                                  fit: BoxFit.fill,
                                  excludeFromSemantics: true,
                                ),
                              ),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: max(580, viewport.maxHeight - 24),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    paper.maxWidth * .105,
                                    paper.maxWidth * .24,
                                    paper.maxWidth * .105,
                                    paper.maxWidth * .22,
                                  ),
                                  child: DefaultTextStyle(
                                    style: const TextStyle(
                                      fontFamily: 'Amiri',
                                      fontWeight: FontWeight.w700,
                                      color: ink,
                                      fontSize: 19,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (game.lootPending)
                                          Semantics(
                                            liveRegion: true,
                                            child: Container(
                                              key: const ValueKey(
                                                'loot-banner',
                                              ),
                                              margin: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF123D56),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFEBC76A,
                                                  ),
                                                  width: 2,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Image.asset(
                                                    'assets/helpers/loot_${game.opponent == 0 ? 'blue' : 'red'}.png',
                                                    height: 64,
                                                    excludeFromSemantics: true,
                                                  ),
                                                  const Text(
                                                    'سرقة الغنيمة',
                                                    style: TextStyle(
                                                      color: Color(0xFFEBC76A),
                                                      fontSize: 26,
                                                    ),
                                                  ),
                                                  Text(
                                                    'دورك الآن يا ${widget.names[game.opponent]}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 23,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        CharacterPortrait(
                                          character:
                                              widget.characters?[displayTeam] ??
                                              CastleCharacter
                                                  .values[displayTeam %
                                                  CastleCharacter
                                                      .values
                                                      .length],
                                          size: 68,
                                        ),
                                        Text(
                                          game.lootPending
                                              ? 'غنيمة المعركة • ${widget.names[game.opponent]}'
                                              : 'رسالة إلى ${widget.names[displayTeam]}',
                                          style: const TextStyle(fontSize: 23),
                                        ),
                                        Text(
                                          '${['سهل', 'متوسط', 'صعب'][game.chosenLevel! - 1]} • ${game.questionPoints} نقطة${game.cannonArmed ? ' • القذيفة مفعّلة ×2' : ''}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        Text(
                                          'الوقت المتبقي: $remaining ثانية',
                                          key: const ValueKey('answer-timer'),
                                          style: TextStyle(
                                            color: _urgent
                                                ? const Color(0xFFB3261E)
                                                : ink,
                                            fontSize: _urgent ? 24 : 19,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Divider(
                                          color: Color(0x805F3915),
                                          height: 24,
                                        ),
                                        if (game.lootPending) ...[
                                          const Text(
                                            'أخطأ الخصم! أجب لتكسب الغنيمة، أو احتفظ بقدرتك.',
                                          ),
                                          TextButton(
                                            onPressed: () => setState(() {
                                              game.declineLoot();
                                              _finish();
                                            }),
                                            style: TextButton.styleFrom(
                                              foregroundColor: ink,
                                            ),
                                            child: const Text(
                                              'الاحتفاظ بسرقة الغنيمة',
                                            ),
                                          ),
                                        ],
                                        if (question.flagUrl != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: Image(
                                              image: question.flagAsset != null
                                                  ? AssetImage(
                                                      question.flagAsset!,
                                                    )
                                                  : NetworkImage(
                                                      question.flagUrl!,
                                                    ),
                                              height: 75,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, error, trace) =>
                                                  const Text('تعذّر عرض العلم'),
                                            ),
                                          ),
                                        Text(
                                          question.text,
                                          style: const TextStyle(fontSize: 25),
                                        ),
                                        const SizedBox(height: 22),
                                        for (
                                          var i = 0;
                                          i < question.options.length;
                                          i++
                                        )
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: OutlinedButton(
                                              onPressed:
                                                  game.answered ||
                                                      (game.lootPending &&
                                                          i == game.wrongOption)
                                                  ? null
                                                  : () => _answer(i),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: ink,
                                                disabledForegroundColor:
                                                    game.answered &&
                                                        (i == question.answer ||
                                                            i == selected)
                                                    ? Colors.white
                                                    : ink.withValues(alpha: .5),
                                                backgroundColor:
                                                    game.answered &&
                                                        i == question.answer
                                                    ? const Color(0xFF365A32)
                                                    : game.answered &&
                                                          (i == selected ||
                                                              i ==
                                                                  game.wrongOption)
                                                    ? const Color(0xFF893A29)
                                                    : game.lootPending &&
                                                          i == game.wrongOption
                                                    ? const Color(0xFF893A29)
                                                    : const Color(0x30FFF2CF),
                                                side: const BorderSide(
                                                  color: Color(0xFF805321),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12,
                                                    ),
                                                textStyle: const TextStyle(
                                                  fontFamily: 'Amiri',
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 20,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  if (game.answered &&
                                                      i == question.answer)
                                                    const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  if ((game.answered &&
                                                          i !=
                                                              question.answer &&
                                                          (i == selected ||
                                                              i ==
                                                                  game.wrongOption)) ||
                                                      (game.lootPending &&
                                                          i ==
                                                              game.wrongOption))
                                                    const Icon(
                                                      Icons.cancel,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  Flexible(
                                                    child: Text(
                                                      question.options[i],
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        if (game.answered) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            game.feedback,
                                            semanticsLabel: game.feedback,
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'العودة إلى السباق خلال 3 ثوانٍ',
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 0,
              right: 8,
              child: SafeArea(child: SoundToggleButton()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollRevealClipper extends CustomClipper<Rect> {
  final double progress;
  const _ScrollRevealClipper(this.progress);
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * progress);
  @override
  bool shouldReclip(_ScrollRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}
