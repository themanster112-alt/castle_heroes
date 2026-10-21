import 'package:flutter/material.dart';

enum CastleCharacter {
  guardian('حارس القلعة', 'guardian'),
  archer('رامية السهام', 'archer'),
  scholar('حكيم القلعة', 'scholar'),
  scout('كشّافة القلعة', 'scout');

  const CastleCharacter(this.label, this.fileName);
  final String label, fileName;
  String get asset => 'assets/characters/$fileName.png';
}

class CharacterPortrait extends StatelessWidget {
  final CastleCharacter character;
  final double size;
  const CharacterPortrait({super.key, required this.character, this.size = 90});

  @override
  Widget build(BuildContext context) => Image.asset(
    character.asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
    semanticLabel: character.label,
    filterQuality: FilterQuality.medium,
  );
}

class CharacterPicker extends StatelessWidget {
  final CastleCharacter selected;
  final ValueChanged<CastleCharacter> onChanged;
  final Color accent;
  const CharacterPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.accent = const Color(0xFFE9BD66),
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'اختر شخصيتك',
        style: TextStyle(
          color: Color(0xFFE9BD66),
          fontFamily: 'Amiri',
          fontWeight: FontWeight.bold,
          fontSize: 21,
        ),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final character in CastleCharacter.values)
              SizedBox(
                width: (box.maxWidth - 8) / 2,
                child: Semantics(
                  selected: character == selected,
                  button: true,
                  label: character.label,
                  child: InkWell(
                    key: ValueKey('character-${character.name}'),
                    onTap: () => onChanged(character),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: character == selected
                            ? accent.withValues(alpha: .18)
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: character == selected
                              ? accent
                              : Colors.white24,
                          width: character == selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          CharacterPortrait(character: character),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (character == selected)
                                Icon(
                                  Icons.check_circle,
                                  color: accent,
                                  size: 16,
                                ),
                              Flexible(
                                child: Text(
                                  character.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: character == selected
                                        ? accent
                                        : Colors.white,
                                    fontFamily: 'Amiri',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
