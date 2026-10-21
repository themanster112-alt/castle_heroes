import 'dart:async';

import 'package:flutter/material.dart';

/// Blocks play while everyone sees which player activated a helper.
Future<void> showHelperAnnouncement(
  BuildContext context, {
  required String player,
  required String helper,
  required String asset,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: const Color(0xDD07121F),
  transitionDuration: const Duration(milliseconds: 350),
  pageBuilder: (context, animation, secondaryAnimation) =>
      _HelperAnnouncement(player: player, helper: helper, asset: asset),
  transitionBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
    );
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: .65, end: 1).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .15),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  },
);

class _HelperAnnouncement extends StatefulWidget {
  final String player, helper, asset;
  const _HelperAnnouncement({
    required this.player,
    required this.helper,
    required this.asset,
  });

  @override
  State<_HelperAnnouncement> createState() => _HelperAnnouncementState();
}

class _HelperAnnouncementState extends State<_HelperAnnouncement> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            liveRegion: true,
            child: Material(
              key: const ValueKey('helper-announcement'),
              color: const Color(0xFF123D56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFE9BD66), width: 3),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      widget.asset,
                      height: 140,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.player} اختار',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        color: Colors.white,
                        fontSize: 26,
                      ),
                    ),
                    Text(
                      widget.helper,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        color: Color(0xFFE9BD66),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
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
  );
}
