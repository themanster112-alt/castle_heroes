import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'race_game.dart';
import 'menu_audio.dart';
import 'player_setup.dart';
import 'castle_character.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MenuAudio.initialize();
  runApp(const CastleHeroesApp());
}

const gold = Color(0xFFE9BD66);
const navy = Color(0xFF10192E);

class CastleHeroesApp extends StatelessWidget {
  const CastleHeroesApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'أبطال القلعة',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: navy,
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
      useMaterial3: true,
    ),
    builder: (_, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: const IntroScreen(),
  );
}

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/backgrounds/intro.png',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99090E0E), Color(0x99090E0E)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Image.asset(
            'assets/backgrounds/intro.png',
            fit: BoxFit.contain,
            semanticLabel: 'أبطال القلعة',
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                children: [
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: FantasyButton(
                      label: 'ابدأ التحدي',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ModeSelectionScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/backgrounds/mode_selection.png',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99090E0E), Color(0x99090E0E)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Image.asset(
            'assets/backgrounds/mode_selection.png',
            fit: BoxFit.contain,
            semanticLabel: 'اختر طريقة اللعب',
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
              child: Column(
                children: [
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: FantasyButton(
                      label: 'اللعب فردي',
                      icon: Icons.person,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const WarriorSetupScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: FantasyButton(
                      label: 'تحدي 1×1',
                      icon: Icons.groups,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const TeamSetupScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class WarriorSetupScreen extends StatefulWidget {
  const WarriorSetupScreen({super.key});

  @override
  State<WarriorSetupScreen> createState() => _WarriorSetupScreenState();
}

class _WarriorSetupScreenState extends State<WarriorSetupScreen> {
  final _nameController = TextEditingController();
  bool _youngWarrior = false;
  bool _veteranWarrior = false;
  CastleCharacter _character = CastleCharacter.guardian;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _start() {
    final name = _nameController.text.trim();
    if (name.isEmpty || (!_youngWarrior && !_veteranWarrior)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتب اسم المحارب واختر فئته العمرية للمتابعة.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CastleRaceScreen(
          names: [name],
          ages: [_youngWarrior ? WarriorAge.child : WarriorAge.adult],
          characters: [_character],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PlayerSetupBackdrop(
    children: [
      WarriorSetupCard(
        title: 'المحارب المنفرد',
        controller: _nameController,
        young: _youngWarrior,
        veteran: _veteranWarrior,
        character: _character,
        onCharacterChanged: (value) => setState(() => _character = value),
        onYoungChanged: (value) => setState(() {
          _youngWarrior = value;
          if (value) _veteranWarrior = false;
        }),
        onVeteranChanged: (value) => setState(() {
          _veteranWarrior = value;
          if (value) _youngWarrior = false;
        }),
      ),
      Center(
        child: FantasyButton(label: 'ابدأ', onPressed: _start),
      ),
    ],
  );
}

class TeamSetupScreen extends StatefulWidget {
  const TeamSetupScreen({super.key});

  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends State<TeamSetupScreen> {
  final _redNameController = TextEditingController();
  final _blueNameController = TextEditingController();
  bool _redYoung = false;
  bool _redVeteran = false;
  bool _blueYoung = false;
  bool _blueVeteran = false;
  CastleCharacter _redCharacter = CastleCharacter.guardian;
  CastleCharacter _blueCharacter = CastleCharacter.archer;

  @override
  void dispose() {
    _redNameController.dispose();
    _blueNameController.dispose();
    super.dispose();
  }

  void _startTeams() {
    if (_redNameController.text.trim().isEmpty ||
        _blueNameController.text.trim().isEmpty ||
        (!_redYoung && !_redVeteran) ||
        (!_blueYoung && !_blueVeteran)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل اسم كل فريق واختر الفئة العمرية لكليهما.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CastleRaceScreen(
          names: [
            _redNameController.text.trim(),
            _blueNameController.text.trim(),
          ],
          ages: [
            _redYoung ? WarriorAge.child : WarriorAge.adult,
            _blueYoung ? WarriorAge.child : WarriorAge.adult,
          ],
          characters: [_redCharacter, _blueCharacter],
        ),
      ),
    );
  }

  void _openRoomEntry() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RoomEntryScreen()),
    );
  }

  void _openRoomCreation() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const CreateRoomScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => PlayerSetupBackdrop(
    children: [
      WarriorSetupCard(
        title: 'الفريق الأحمر',
        accent: const Color(0xFFF28C7E),
        controller: _redNameController,
        young: _redYoung,
        veteran: _redVeteran,
        character: _redCharacter,
        onCharacterChanged: (value) => setState(() => _redCharacter = value),
        onYoungChanged: (value) => setState(() {
          _redYoung = value;
          if (value) _redVeteran = false;
        }),
        onVeteranChanged: (value) => setState(() {
          _redVeteran = value;
          if (value) _redYoung = false;
        }),
      ),
      WarriorSetupCard(
        title: 'الفريق الأزرق',
        accent: const Color(0xFF8BC9F2),
        controller: _blueNameController,
        young: _blueYoung,
        veteran: _blueVeteran,
        character: _blueCharacter,
        onCharacterChanged: (value) => setState(() => _blueCharacter = value),
        onYoungChanged: (value) => setState(() {
          _blueYoung = value;
          if (value) _blueVeteran = false;
        }),
        onVeteranChanged: (value) => setState(() {
          _blueVeteran = value;
          if (value) _blueYoung = false;
        }),
      ),
      Center(
        child: FantasyButton(label: 'ابدأ', onPressed: _startTeams),
      ),
      const SizedBox(height: 28),
      ExpansionTile(
        title: const Text(
          'اللعب أونلاين',
          style: TextStyle(
            fontFamily: 'Amiri',
            fontWeight: FontWeight.w700,
            color: gold,
            fontSize: 22,
          ),
        ),
        collapsedBackgroundColor: const Color(0xB309141C),
        backgroundColor: const Color(0xD909141C),
        iconColor: gold,
        collapsedIconColor: gold,
        childrenPadding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        children: [
          FantasyButton(
            label: 'فتح غرفة',
            icon: Icons.add_home_outlined,
            onPressed: _openRoomCreation,
          ),
          const SizedBox(height: 16),
          FantasyButton(
            label: 'الدخول إلى غرفة',
            icon: Icons.login,
            onPressed: _openRoomEntry,
          ),
        ],
      ),
    ],
  );
}

class CreateRoomScreen extends StatelessWidget {
  const CreateRoomScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: FantasyScenePainter(showCastle: true)),
          ),
          const Positioned.fill(child: ColoredBox(color: Color(0xB308111B))),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'رجوع',
              onPressed: () {
                unawaited(MenuAudio.playClick());
                Navigator.maybePop(context);
              },
              icon: const Icon(Icons.arrow_forward, color: gold),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_home, color: gold, size: 62),
                    const SizedBox(height: 12),
                    const Text(
                      'فتح غرفة جديدة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: gold,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'عند تفعيل الاتصال، سيُنشأ رقم غرفة لتشاركه مع أصدقائك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xAA17130D),
                        border: Border.all(color: gold, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'سيظهر رقم الغرفة هنا',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: gold,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'إنشاء الغرف أونلاين سيتاح بعد ربط خدمة الاتصال.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class RoomEntryScreen extends StatefulWidget {
  const RoomEntryScreen({super.key});

  @override
  State<RoomEntryScreen> createState() => _RoomEntryScreenState();
}

class _RoomEntryScreenState extends State<RoomEntryScreen> {
  final _roomController = TextEditingController();

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  void _joinRoom() {
    if (_roomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أدخل رقم الغرفة أولًا.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('الدخول إلى الغرف أونلاين سيتاح بعد تفعيل الاتصال.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: FantasyScenePainter(showCastle: true)),
          ),
          const Positioned.fill(child: ColoredBox(color: Color(0xB308111B))),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'رجوع',
              onPressed: () {
                unawaited(MenuAudio.playClick());
                Navigator.maybePop(context);
              },
              icon: const Icon(Icons.arrow_forward, color: gold),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.meeting_room, color: gold, size: 62),
                    const SizedBox(height: 12),
                    const Text(
                      'دخول غرفة أونلاين',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: gold,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'أدخل رقم الغرفة الذي شاركه معك صديقك',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _roomController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      maxLength: 8,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: 'رقم الغرفة',
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFD0D0D0),
                        hintStyle: const TextStyle(color: Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FantasyButton(label: 'دخول الغرفة', onPressed: _joinRoom),
                    const SizedBox(height: 14),
                    const Text(
                      'اللعب عبر الإنترنت قيد التجهيز وسيُفعّل عند ربط الخدمة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class FantasyButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const FantasyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        unawaited(MenuAudio.playClick());
        onPressed();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 216, minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF54320F), Color(0xFF21170D)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC89232), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 12,
              offset: Offset(0, 7),
            ),
            BoxShadow(color: Color(0xFF5A3510), blurRadius: 0, spreadRadius: 4),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: gold, size: 22),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  color: gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class FantasyScenePainter extends CustomPainter {
  final bool showCastle;
  const FantasyScenePainter({required this.showCastle});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF17272A),
          Color(0xFF764825),
          Color(0xFFD08A35),
          Color(0xFF26362C),
          Color(0xFF101914),
        ],
        stops: [0, .32, .53, .7, 1],
      ).createShader(bounds);
    canvas.drawRect(bounds, sky);

    final sunGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFBB55).withValues(alpha: .72),
              const Color(0xFFD6752A).withValues(alpha: .16),
              Colors.transparent,
            ],
            stops: const [0, .38, 1],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .52, size.height * .48),
              radius: size.width * .78,
            ),
          );
    canvas.drawRect(bounds, sunGlow);

    final distantMountains = Paint()..color = const Color(0xFF29332C);
    final mountainPath = Path()
      ..moveTo(0, size.height * .56)
      ..lineTo(size.width * .12, size.height * .43)
      ..lineTo(size.width * .23, size.height * .55)
      ..lineTo(size.width * .39, size.height * .4)
      ..lineTo(size.width * .56, size.height * .56)
      ..lineTo(size.width * .76, size.height * .42)
      ..lineTo(size.width, size.height * .54)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(mountainPath, distantMountains);

    if (showCastle) {
      _drawCastle(canvas, size);
    } else {
      _drawValleyCliffs(canvas, size);
      _drawKnight(
        canvas,
        Offset(size.width * .08, size.height * .61),
        false,
        size,
      );
      _drawKnight(
        canvas,
        Offset(size.width * .92, size.height * .61),
        true,
        size,
      );
    }

    final foreground = Paint()..color = const Color(0xFF121A16);
    final foregroundPath = Path()
      ..moveTo(0, size.height * .78)
      ..lineTo(size.width * .2, size.height * .69)
      ..lineTo(size.width * .37, size.height * .8)
      ..lineTo(size.width * .62, size.height * .72)
      ..lineTo(size.width, size.height * .79)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(foregroundPath, foreground);

    final road = Path()
      ..moveTo(size.width * .43, size.height)
      ..lineTo(size.width * .48, size.height * .72)
      ..quadraticBezierTo(
        size.width * .52,
        size.height * .68,
        size.width * .56,
        size.height * .72,
      )
      ..lineTo(size.width * .72, size.height)
      ..close();
    canvas.drawPath(
      road,
      Paint()..color = const Color(0xFF8A612D).withValues(alpha: .48),
    );

    final vignette = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.transparent, Color(0x99000000)],
        stops: [0.42, 1],
      ).createShader(bounds);
    canvas.drawRect(bounds, vignette);
  }

  void _drawCastle(Canvas canvas, Size size) {
    final baseY = size.height * .69;
    final castlePaint = Paint()..color = const Color(0xFF171A16);
    final litStone = Paint()..color = const Color(0xFF302319);

    void block(double x, double y, double width, double height, Paint paint) {
      canvas.drawRect(Rect.fromLTWH(x, y, width, height), paint);
    }

    block(
      size.width * .35,
      baseY - size.height * .14,
      size.width * .3,
      size.height * .14,
      castlePaint,
    );
    block(
      size.width * .42,
      baseY - size.height * .26,
      size.width * .14,
      size.height * .26,
      castlePaint,
    );
    block(
      size.width * .28,
      baseY - size.height * .2,
      size.width * .1,
      size.height * .2,
      castlePaint,
    );
    block(
      size.width * .62,
      baseY - size.height * .19,
      size.width * .1,
      size.height * .19,
      castlePaint,
    );
    block(
      size.width * .47,
      baseY - size.height * .34,
      size.width * .07,
      size.height * .12,
      castlePaint,
    );

    for (final tower in [
      Rect.fromLTWH(
        size.width * .27,
        baseY - size.height * .26,
        size.width * .12,
        size.height * .08,
      ),
      Rect.fromLTWH(
        size.width * .61,
        baseY - size.height * .25,
        size.width * .13,
        size.height * .08,
      ),
      Rect.fromLTWH(
        size.width * .45,
        baseY - size.height * .41,
        size.width * .11,
        size.height * .09,
      ),
    ]) {
      block(tower.left, tower.bottom, tower.width, tower.height, castlePaint);
      final roof = Path()
        ..moveTo(tower.left - tower.width * .1, tower.bottom)
        ..lineTo(tower.center.dx, tower.top)
        ..lineTo(tower.right + tower.width * .1, tower.bottom)
        ..close();
      canvas.drawPath(roof, litStone);
    }

    final windows = Paint()
      ..color = const Color(0xFFDA8B32).withValues(alpha: .72);
    for (final point in [
      Offset(size.width * .35, baseY - size.height * .12),
      Offset(size.width * .55, baseY - size.height * .1),
      Offset(size.width * .46, baseY - size.height * .23),
      Offset(size.width * .52, baseY - size.height * .3),
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: point, width: 4, height: 9),
        windows,
      );
    }
  }

  void _drawValleyCliffs(Canvas canvas, Size size) {
    final cliffPaint = Paint()..color = const Color(0xFF202C1C);
    final leftCliff = Path()
      ..moveTo(0, size.height * .25)
      ..lineTo(size.width * .09, size.height * .36)
      ..lineTo(size.width * .13, size.height * .48)
      ..lineTo(size.width * .24, size.height * .58)
      ..lineTo(0, size.height * .78)
      ..close();
    final rightCliff = Path()
      ..moveTo(size.width, size.height * .2)
      ..lineTo(size.width * .88, size.height * .35)
      ..lineTo(size.width * .84, size.height * .49)
      ..lineTo(size.width * .74, size.height * .57)
      ..lineTo(size.width, size.height * .77)
      ..close();
    canvas.drawPath(leftCliff, cliffPaint);
    canvas.drawPath(rightCliff, cliffPaint);
  }

  void _drawKnight(Canvas canvas, Offset origin, bool mirrored, Size size) {
    canvas.save();
    if (mirrored) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final knight = Paint()..color = const Color(0xFF101713);
    final armor = Paint()..color = const Color(0xFF344032);
    canvas.drawOval(
      Rect.fromLTWH(origin.dx, origin.dy, size.width * .22, size.height * .31),
      knight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          origin.dx + size.width * .035,
          origin.dy + size.height * .04,
          size.width * .14,
          size.height * .13,
        ),
        const Radius.circular(24),
      ),
      armor,
    );
    final face = Path()
      ..moveTo(origin.dx + size.width * .16, origin.dy + size.height * .1)
      ..lineTo(origin.dx + size.width * .22, origin.dy + size.height * .15)
      ..lineTo(origin.dx + size.width * .16, origin.dy + size.height * .18)
      ..close();
    canvas.drawPath(face, Paint()..color = const Color(0xFF9A6030));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FantasyScenePainter oldDelegate) =>
      oldDelegate.showCastle != showCastle;
}

class HomeScreen extends StatelessWidget {
  final String warriorName;

  const HomeScreen({super.key, this.warriorName = ''});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF293854),
                    child: Icon(Icons.person_outline, color: gold),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    warriorName.isEmpty
                        ? 'أهلًا، يا بطل!'
                        : 'أهلًا، $warriorName!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF304565), Color(0xFF1A263F)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: gold.withValues(alpha: .3)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.castle, size: 110, color: gold),
                    SizedBox(height: 18),
                    Text(
                      'أبطال القلعة',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: gold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'المعرفة قوتك. والقلعة تنتظر بطلها.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    SizedBox(height: 22),
                    Wrap(
                      spacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        Chip(label: Text('٥ أسئلة')),
                        Chip(label: Text('٢٠ ثانية للسؤال')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'اختر ساحة التحدّي',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'تدرّب قبل مواجهة الأبطال',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 18),
              for (final category in banks.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: const Color(0xFF1B2840),
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: Icon(
                        category == 'ثقافة عامة'
                            ? Icons.auto_awesome
                            : category == 'علوم وطبيعة'
                            ? Icons.science_outlined
                            : Icons.account_balance,
                        color: gold,
                        size: 30,
                      ),
                      title: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text('جولة تدريبية • ٥ أسئلة'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => QuizScreen(category: category),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const QuizScreen(category: 'ثقافة عامة'),
                  ),
                ),
                icon: const Icon(Icons.bolt),
                label: const Text(
                  'ابدأ التحدّي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'نسخة تجريبية محلية • المواجهات المباشرة قادمة لاحقًا',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Question {
  final String text;
  final List<String> options;
  final int answer;
  const Question(this.text, this.options, this.answer);
}

const banks = <String, List<Question>>{
  'ثقافة عامة': [
    Question('ما عاصمة الأردن؟', ['عمّان', 'بيروت', 'دمشق', 'القاهرة'], 0),
    Question('كم عدد قارات العالم؟', ['خمس', 'ست', 'سبع', 'ثمانٍ'], 2),
    Question('ما أكبر محيط في العالم؟', [
      'الأطلسي',
      'الهندي',
      'المتجمد الشمالي',
      'الهادئ',
    ], 3),
    Question('كم ضلعًا للمثلث؟', ['أربعة', 'ثلاثة', 'خمسة', 'ستة'], 1),
    Question('ما اللغة الرسمية في البرازيل؟', [
      'الإسبانية',
      'البرتغالية',
      'الفرنسية',
      'الإنجليزية',
    ], 1),
    Question('ما أكبر كوكب في المجموعة الشمسية؟', [
      'الأرض',
      'المشتري',
      'المريخ',
      'عطارد',
    ], 1),
    Question('ما الحيوان المعروف بسفينة الصحراء؟', [
      'الحصان',
      'الفيل',
      'الجمل',
      'الغزال',
    ], 2),
    Question('كم يومًا في الأسبوع؟', ['خمسة', 'ستة', 'سبعة', 'ثمانية'], 2),
    Question('ما لون الزمرد؟', ['أحمر', 'أخضر', 'أزرق', 'أصفر'], 1),
    Question('أي فصل يأتي بعد الشتاء؟', [
      'الصيف',
      'الخريف',
      'الربيع',
      'الشتاء',
    ], 2),
    Question('ما أسرع حيوان بري؟', ['الأسد', 'الفهد', 'الحصان', 'الذئب'], 1),
    Question('كم عدد أضلاع المربع؟', ['ثلاثة', 'أربعة', 'خمسة', 'ستة'], 1),
  ],
  'علوم وطبيعة': [
    Question('ما الكوكب الأحمر؟', ['الأرض', 'الزهرة', 'المريخ', 'زحل'], 2),
    Question('ما الغاز الذي يحتاجه الإنسان للتنفس؟', [
      'الأكسجين',
      'الهيدروجين',
      'الهيليوم',
      'النيون',
    ], 0),
    Question('كم عدد أرجل الحشرات؟', ['أربع', 'ست', 'ثمانٍ', 'عشر'], 1),
    Question('ما أقرب نجم إلى الأرض؟', [
      'الشعرى',
      'سهيل',
      'نجم القطب',
      'الشمس',
    ], 3),
    Question('ما العضو الذي يضخ الدم؟', [
      'الرئة',
      'الكبد',
      'القلب',
      'المعدة',
    ], 2),
  ],
  'تاريخ وحضارات': [
    Question('أين تقع البتراء؟', ['مصر', 'الأردن', 'العراق', 'المغرب'], 1),
    Question('أي حضارة بنت أهرامات الجيزة؟', [
      'الرومانية',
      'اليونانية',
      'المصرية القديمة',
      'الفارسية',
    ], 2),
    Question('بماذا اشتهر الفينيقيون؟', [
      'التجارة البحرية',
      'صناعة الطائرات',
      'السكك الحديدية',
      'البرمجة',
    ], 0),
    Question('أين يقع سور الصين العظيم؟', [
      'اليابان',
      'الهند',
      'كوريا',
      'الصين',
    ], 3),
    Question('ما كتابة المصريين القدماء؟', [
      'المسمارية',
      'الهيروغليفية',
      'اللاتينية',
      'السنسكريتية',
    ], 1),
  ],
};

class TeamQuizScreen extends StatefulWidget {
  final String redTeamName;
  final String blueTeamName;

  const TeamQuizScreen({
    super.key,
    required this.redTeamName,
    required this.blueTeamName,
  });

  @override
  State<TeamQuizScreen> createState() => _TeamQuizScreenState();
}

class _TeamQuizScreenState extends State<TeamQuizScreen> {
  static const _questionSeconds = 20;
  int _turn = 0;
  int _seconds = _questionSeconds;
  int _redScore = 0;
  int _blueScore = 0;
  int? _selected;
  bool _revealed = false;
  bool _finished = false;
  Timer? _timer;

  List<Question> get _questions => banks['ثقافة عامة']!;
  bool get _redTurn => _turn.isEven;
  Question get _question => _questions[_turn ~/ 2];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds <= 1) {
        _submit(null);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _submit(int? answer) {
    if (_revealed) return;
    _timer?.cancel();
    setState(() {
      _selected = answer;
      _revealed = true;
      if (answer == _question.answer) {
        if (_redTurn) {
          _redScore += 100;
        } else {
          _blueScore += 100;
        }
      }
      if (answer == null) _seconds = 0;
    });
  }

  void _nextTurn() {
    if (_turn == _questions.length * 2 - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _turn++;
      _seconds = _questionSeconds;
      _selected = null;
      _revealed = false;
    });
    _startTimer();
  }

  void _restart() {
    setState(() {
      _turn = 0;
      _seconds = _questionSeconds;
      _redScore = 0;
      _blueScore = 0;
      _selected = null;
      _revealed = false;
      _finished = false;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final redProgress = _redScore / (_questions.length * 100);
    final blueProgress = _blueScore / (_questions.length * 100);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(
                painter: FantasyScenePainter(showCastle: true),
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: Color(0xA608111B))),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'رجوع',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_forward, color: gold),
                        ),
                        const Expanded(
                          child: Text(
                            'سباق أبطال القلعة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: gold,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    TeamRaceBoard(
                      redTeamName: widget.redTeamName,
                      blueTeamName: widget.blueTeamName,
                      redProgress: redProgress,
                      blueProgress: blueProgress,
                      redScore: _redScore,
                      blueScore: _blueScore,
                    ),
                    const SizedBox(height: 18),
                    if (_finished) _buildResult() else _buildTurn(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurn() {
    final teamName = _redTurn ? widget.redTeamName : widget.blueTeamName;
    final teamColor = _redTurn
        ? const Color(0xFFFF5555)
        : const Color(0xFF5AAEFF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: teamColor.withValues(alpha: .2),
            border: Border.all(color: teamColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'دور فريق $teamName • السؤال ${_turn ~/ 2 + 1} من ${_questions.length}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: teamColor,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, color: gold),
            const SizedBox(width: 8),
            Text('$_seconds ثانية'),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _question.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            height: 1.4,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < _question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: _revealed ? null : () => _submit(i),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(17),
                alignment: Alignment.centerRight,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                backgroundColor: _revealed && i == _question.answer
                    ? const Color(0xFF235D47)
                    : _revealed && i == _selected
                    ? const Color(0xFF783A42)
                    : const Color(0xD91B2840),
                side: BorderSide(color: teamColor.withValues(alpha: .7)),
              ),
              child: Text(
                _question.options[i],
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        if (_revealed) ...[
          const SizedBox(height: 6),
          Text(
            _selected == null
                ? 'انتهى الوقت.'
                : _selected == _question.answer
                ? 'إجابة صحيحة! تقدم خطوة نحو القلعة.'
                : 'إجابة غير صحيحة. ينتقل الدور للفريق الآخر.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: gold,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _nextTurn,
            child: Text(
              _turn == _questions.length * 2 - 1
                  ? 'عرض النتيجة'
                  : 'الدور التالي',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResult() {
    final heading = _redScore == _blueScore
        ? 'تعادل الفريقان!'
        : _redScore > _blueScore
        ? 'الفريق ${widget.redTeamName} بطل القلعة!'
        : 'الفريق ${widget.blueTeamName} بطل القلعة!';

    return Column(
      children: [
        const Icon(Icons.emoji_events, color: gold, size: 100),
        const SizedBox(height: 12),
        Text(
          heading,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: gold,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '${widget.redTeamName}: ${_redScore ~/ 100} / ${_questions.length}',
          style: const TextStyle(color: Color(0xFFFF7777), fontSize: 20),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.blueTeamName}: ${_blueScore ~/ 100} / ${_questions.length}',
          style: const TextStyle(color: Color(0xFF79BDFF), fontSize: 20),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _restart, child: const Text('إعادة السباق')),
      ],
    );
  }
}

class TeamRaceBoard extends StatelessWidget {
  final String redTeamName;
  final String blueTeamName;
  final double redProgress;
  final double blueProgress;
  final int redScore;
  final int blueScore;

  const TeamRaceBoard({
    super.key,
    required this.redTeamName,
    required this.blueTeamName,
    required this.redProgress,
    required this.blueProgress,
    required this.redScore,
    required this.blueScore,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 470,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFF18251D),
      border: Border.all(color: gold.withValues(alpha: .72), width: 2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final mapSize = Size(constraints.maxWidth, constraints.maxHeight);
        final redPosition = _CastleRoutePainter.positionForProgress(
          mapSize,
          redProgress,
          horizontalOffset: -12,
        );
        final bluePosition = _CastleRoutePainter.positionForProgress(
          mapSize,
          blueProgress,
          horizontalOffset: 12,
        );

        return Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _CastleRoutePainter()),
            ),
            const Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    'المسار إلى القلعة',
                    style: TextStyle(
                      color: gold,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'رحلة من 12 نقطة',
                    style: TextStyle(
                      color: Color(0xFFF4DDAE),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 68,
              left: 0,
              right: 0,
              child: Icon(
                Icons.castle,
                size: 48,
                color: Color(0xFFFFD47A),
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
            for (var i = 0; i < _CastleRoutePainter.checkpoints.length; i++)
              Positioned(
                left:
                    _CastleRoutePainter.checkpoints[i].dx * mapSize.width - 15,
                top:
                    _CastleRoutePainter.checkpoints[i].dy * mapSize.height - 15,
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF253442),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == 11 ? gold : const Color(0xFFF2D49D),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black87, blurRadius: 7),
                    ],
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: redPosition.dx - 11,
              top: redPosition.dy - 11,
              child: const _TeamMapToken(color: Color(0xFFFF6464)),
            ),
            Positioned(
              left: bluePosition.dx - 11,
              top: bluePosition.dy - 11,
              child: const _TeamMapToken(color: Color(0xFF61B5FF)),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 9,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TeamMapLegend(
                    name: redTeamName,
                    score: redScore,
                    color: const Color(0xFFFF7777),
                  ),
                  _TeamMapLegend(
                    name: blueTeamName,
                    score: blueScore,
                    color: const Color(0xFF79BDFF),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _TeamMapToken extends StatelessWidget {
  final Color color;

  const _TeamMapToken({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 7)],
    ),
    child: const Icon(Icons.shield, size: 13, color: Color(0xFF17212A)),
  );
}

class _TeamMapLegend extends StatelessWidget {
  final String name;
  final int score;
  final Color color;

  const _TeamMapLegend({
    required this.name,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Flexible(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE6101713),
        border: Border.all(color: color.withValues(alpha: .8)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield, color: color, size: 15),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$name • ${score ~/ 100}/6',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CastleRoutePainter extends CustomPainter {
  const _CastleRoutePainter();

  static const checkpoints = <Offset>[
    Offset(.28, .86),
    Offset(.47, .81),
    Offset(.65, .75),
    Offset(.52, .69),
    Offset(.34, .63),
    Offset(.45, .57),
    Offset(.65, .51),
    Offset(.56, .45),
    Offset(.36, .39),
    Offset(.48, .33),
    Offset(.67, .27),
    Offset(.52, .22),
  ];

  static Offset positionForProgress(
    Size size,
    double progress, {
    double horizontalOffset = 0,
  }) {
    final boundedProgress = progress.clamp(0.0, 1.0);
    final routePosition = boundedProgress * (checkpoints.length - 1);
    final startIndex = routePosition.floor().clamp(0, checkpoints.length - 2);
    final fraction = routePosition - startIndex;
    final point = Offset.lerp(
      checkpoints[startIndex],
      checkpoints[startIndex + 1],
      fraction,
    )!;
    return Offset(
      point.dx * size.width + horizontalOffset,
      point.dy * size.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF506047), Color(0xFF263A2A), Color(0xFF18251D)],
        ).createShader(bounds),
    );

    final river = Path()
      ..moveTo(size.width * .95, size.height * .14)
      ..cubicTo(
        size.width * .82,
        size.height * .28,
        size.width * 1.02,
        size.height * .34,
        size.width * .89,
        size.height * .47,
      )
      ..cubicTo(
        size.width * .78,
        size.height * .58,
        size.width * .99,
        size.height * .68,
        size.width * .86,
        size.height * .82,
      )
      ..cubicTo(
        size.width * .8,
        size.height * .88,
        size.width * .91,
        size.height * .94,
        size.width * .83,
        size.height,
      );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFF31758A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .075
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFF9BDCE0).withValues(alpha: .72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final foliage = Paint()..color = const Color(0xFF17271D);
    for (var i = 0; i < 14; i++) {
      final y = size.height * (.18 + i * .055);
      final spread = (i % 3) * size.width * .035;
      canvas.drawCircle(Offset(size.width * .03 + spread, y), 17, foliage);
      canvas.drawCircle(
        Offset(size.width * .98 - spread, y + size.height * .018),
        20,
        foliage,
      );
      canvas.drawCircle(
        Offset(size.width * .11 + spread, y + size.height * .028),
        11,
        Paint()..color = const Color(0xFF45613A),
      );
    }

    final route = Path()
      ..moveTo(
        checkpoints.first.dx * size.width,
        checkpoints.first.dy * size.height,
      );
    for (final point in checkpoints.skip(1)) {
      route.lineTo(point.dx * size.width, point.dy * size.height);
    }
    final roadWidth = size.width * .14;
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFF171A19).withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadWidth + 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFF766044)
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = const Color(0xFFB59868).withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final rock = Paint()..color = const Color(0xFF4A4D43);
    final rockHighlight = Paint()..color = const Color(0xFF777366);
    for (var i = 0; i < checkpoints.length; i++) {
      final center = Offset(
        checkpoints[i].dx * size.width,
        checkpoints[i].dy * size.height,
      );
      final side = i.isEven ? -1.0 : 1.0;
      for (var j = 0; j < 3; j++) {
        final x = center.dx + side * (roadWidth * .68 + j * 7);
        final y = center.dy + (j - 1) * 11;
        canvas.drawCircle(Offset(x, y), 7 - j.toDouble(), rock);
        canvas.drawCircle(Offset(x - 2, y - 2), 2, rockHighlight);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CastleRoutePainter oldDelegate) => false;
}

class QuizScreen extends StatefulWidget {
  final String category;
  final String playerName;

  const QuizScreen({super.key, required this.category, this.playerName = ''});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int index = 0, seconds = 20, score = 0;
  int? selected;
  bool revealed = false, finished = false;
  Timer? timer;
  List<Question> get items => banks[widget.category]!;
  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds <= 1) {
        submit(null);
      } else {
        setState(() => seconds--);
      }
    });
  }

  void submit(int? value) {
    if (revealed) return;
    timer?.cancel();
    setState(() {
      selected = value;
      revealed = true;
      if (value == items[index].answer) score += 100;
      if (value == null) seconds = 0;
    });
  }

  void next() {
    if (index == items.length - 1) {
      setState(() => finished = true);
      return;
    }
    setState(() {
      index++;
      seconds = 20;
      selected = null;
      revealed = false;
    });
    startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: FantasyScenePainter(showCastle: true)),
          ),
          const Positioned.fill(child: ColoredBox(color: Color(0x9908111B))),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'رجوع',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_forward, color: gold),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.playerName.isEmpty
                              ? 'رحلة أبطال القلعة'
                              : 'رحلة ${widget.playerName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: gold,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (finished) ...[
                    const Icon(Icons.emoji_events, size: 120, color: gold),
                    const SizedBox(height: 24),
                    const Text(
                      'أصبحت بطل القلعة!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '$score / ${items.length * 100}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 48, color: gold),
                    ),
                    Text(
                      'إجابات صحيحة: ${score ~/ 100} من ${items.length}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          index = 0;
                          seconds = 20;
                          score = 0;
                          selected = null;
                          revealed = false;
                          finished = false;
                        });
                        startTimer();
                      },
                      child: const Text('تحدٍّ جديد'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('العودة إلى القلعة'),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('السؤال ${index + 1} من ${items.length}'),
                        Text(
                          '$score نقطة',
                          style: const TextStyle(color: gold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: (index + 1) / items.length,
                      color: gold,
                      minHeight: 6,
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Chip(
                        avatar: const Icon(Icons.timer_outlined, color: gold),
                        label: Text('$seconds ثانية'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      items[index].text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton(
                          onPressed: revealed ? null : () => submit(i),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(20),
                            alignment: Alignment.centerRight,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                            backgroundColor:
                                revealed && i == items[index].answer
                                ? const Color(0xFF235D47)
                                : revealed && i == selected
                                ? const Color(0xFF783A42)
                                : const Color(0xFF1B2840),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            items[index].options[i],
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    if (revealed) ...[
                      Text(
                        selected == null
                            ? 'انتهى الوقت! الإجابة الصحيحة باللون الأخضر.'
                            : selected == items[index].answer
                            ? 'إجابة صحيحة! +١٠٠ نقطة'
                            : 'الإجابة الصحيحة باللون الأخضر.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: gold),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: next,
                        child: Text(
                          index == items.length - 1
                              ? 'عرض النتيجة'
                              : 'السؤال التالي',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
