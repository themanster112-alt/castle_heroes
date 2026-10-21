import 'package:flutter/material.dart';

import 'castle_character.dart';

const _setupGold = Color(0xFFE9BD66);

class PlayerSetupBackdrop extends StatelessWidget {
  final List<Widget> children;
  const PlayerSetupBackdrop({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/backgrounds/player_setup.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          excludeFromSemantics: true,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x10071018), Color(0x80071018)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextButton.icon(
                    key: const ValueKey('setup-back'),
                    onPressed: () => Navigator.maybePop(context),
                    icon: const BackButtonIcon(),
                    label: const Text('العودة لاختيار نوع اللعب'),
                    style: TextButton.styleFrom(
                      foregroundColor: _setupGold,
                      backgroundColor: const Color(0xCC09141C),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: constraints.maxHeight > 700 ? 56 : 8,
                            ),
                            ...children,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class WarriorSetupCard extends StatelessWidget {
  final String title;
  final Color accent;
  final TextEditingController controller;
  final bool young, veteran;
  final ValueChanged<bool> onYoungChanged, onVeteranChanged;
  final CastleCharacter character;
  final ValueChanged<CastleCharacter> onCharacterChanged;
  const WarriorSetupCard({
    super.key,
    required this.title,
    this.accent = _setupGold,
    required this.controller,
    required this.young,
    required this.veteran,
    required this.onYoungChanged,
    required this.onVeteranChanged,
    required this.character,
    required this.onCharacterChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xE51A2830), Color(0xD909141C)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: .65)),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, color: accent, size: 27),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLength: 20,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          textInputAction: TextInputAction.done,
          style: const TextStyle(color: Color(0xFFFFF0D3), fontSize: 18),
          cursorColor: accent,
          decoration: InputDecoration(
            labelText: 'اسم المحارب',
            hintText: 'اكتب الاسم',
            counterText: '',
            labelStyle: TextStyle(
              color: accent,
              fontFamily: 'Amiri',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0x99071017),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accent.withValues(alpha: .35)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'الفئة العمرية',
          style: TextStyle(
            fontFamily: 'Amiri',
            color: _setupGold,
            fontWeight: FontWeight.w700,
            fontSize: 21,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ageChoice('محارب صغير', young, onYoungChanged),
            _ageChoice('محارب كبير', veteran, onVeteranChanged),
          ],
        ),
        const SizedBox(height: 20),
        CharacterPicker(
          selected: character,
          onChanged: onCharacterChanged,
          accent: accent,
        ),
      ],
    ),
  );

  Widget _ageChoice(
    String label,
    bool selected,
    ValueChanged<bool> onChanged,
  ) => Container(
    decoration: BoxDecoration(
      color: selected ? accent.withValues(alpha: .16) : const Color(0x55050E15),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: accent.withValues(alpha: selected ? .8 : .2)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
              activeColor: accent,
              checkColor: const Color(0xFF0C1720),
              side: BorderSide(color: accent.withValues(alpha: .7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : const Color(0xFFE4D8BF),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
