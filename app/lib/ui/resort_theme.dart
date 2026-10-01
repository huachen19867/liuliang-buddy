import 'package:flutter/material.dart';

import '../data/models.dart';

/// Shared palette and small visual pieces for the seaside-resort UI.
///
/// Character art is original project art, loaded from assets with a drawn
/// fallback so missing artwork never removes controls or account data.
abstract final class ResortPalette {
  static const canvas = Color(0xFFFFFBF5);
  static const paper = Color(0xFFFFFEFB);
  static const ink = Color(0xFF394C49);
  static const muted = Color(0xFF74827D);
  static const border = Color(0xFFD8E5DD);
  static const pink = Color(0xFFE4A6B6);
  static const pinkWash = Color(0xFFFFF1F4);
  static const mint = Color(0xFF477B72);
  static const mintWash = Color(0xFFEAF4EF);
  static const lavender = Color(0xFF9388B2);
  static const lavenderWash = Color(0xFFF3F0F7);
  static const cream = Color(0xFFF4E6C5);
  static const sea = Color(0xFF8CC6B8);
}

Duration resortMotionDuration(BuildContext context, [int milliseconds = 180]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class ResortMiniScene extends StatelessWidget {
  const ResortMiniScene({
    super.key,
    required this.title,
    required this.subtitle,
    this.height = 118,
    this.eyebrow = '海风温泉 · 余量小站',
    this.mascotMessage = '今天的余量也陪你慢慢看。',
  });

  final String title;
  final String subtitle;
  final double height;
  final String eyebrow;
  final String mascotMessage;

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD5E4DA), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14507065),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/resort/hero.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const _ResortSceneFallback(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, .48, .82, 1],
                colors: [
                  Color(0xF9FFFBF5),
                  Color(0xDFFFFBF5),
                  Color(0x26FFFBF5),
                  Color(0x00FFFBF5),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 9, 9, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .78),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .9),
                          ),
                        ),
                        child: Text(
                          eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF67867B),
                            fontSize: scaled ? 9 : 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ResortPalette.ink,
                          fontSize: scaled ? 15 : 17,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.35,
                        ),
                      ),
                      if (!scaled) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF71807A),
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: 4,
                  child: ResortMascotSticker(
                    message: mascotMessage,
                    semanticsLabel: '温泉小助手，轻点听一句鼓励',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 7,
            child: IgnorePointer(
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: .9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small, optional character interaction. It remains still when the user
/// asks the system to reduce motion and never sits over account values.
class ResortMascotSticker extends StatefulWidget {
  const ResortMascotSticker({
    super.key,
    required this.message,
    this.semanticsLabel = '海滨温泉少女吉祥物',
  });

  final String message;
  final String semanticsLabel;

  @override
  State<ResortMascotSticker> createState() => _ResortMascotStickerState();
}

class _ResortMascotStickerState extends State<ResortMascotSticker> {
  bool _showMessage = false;
  bool _pressed = false;

  void _toggleMessage() {
    setState(() {
      _showMessage = !_showMessage;
      _pressed = !_pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      hint: '轻点显示角色短句',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleMessage,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 94,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                AnimatedScale(
                  scale: _pressed ? 1.045 : 1,
                  duration: resortMotionDuration(context),
                  curve: Curves.easeOutBack,
                  child: Image.asset(
                    'assets/resort/mascot.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (context, error, stackTrace) =>
                        const _MascotFallback(),
                  ),
                ),
                if (_showMessage)
                  Positioned(
                    left: -13,
                    right: 18,
                    top: 0,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: 1,
                        duration: resortMotionDuration(context, 120),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .96),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: ResortPalette.border),
                          ),
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ResortPalette.ink,
                              fontSize: 9,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResortPaper extends StatelessWidget {
  const ResortPaper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = ResortPalette.paper,
    this.borderRadius = 22,
    this.ticketNotches = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double borderRadius;
  final bool ticketNotches;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: ResortPalette.border, width: 1.15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F604A5A),
            blurRadius: 13,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (ticketNotches) ...[
            Positioned(
              left: -8,
              top: 81,
              child: _Notch(color: ResortPalette.canvas),
            ),
            Positioned(
              right: -8,
              top: 81,
              child: _Notch(color: ResortPalette.canvas),
            ),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class ResortCarrierMark extends StatelessWidget {
  const ResortCarrierMark({super.key, required this.carrier});

  final Carrier carrier;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EBF0)),
      ),
      child: Image.asset(
        'assets/carriers/${carrier.name}.png',
        fit: BoxFit.contain,
        semanticLabel: '${carrier.label}标识',
      ),
    );
  }
}

class ResortSticker extends StatelessWidget {
  const ResortSticker({
    super.key,
    required this.icon,
    required this.label,
    this.color = ResortPalette.pink,
    this.background = ResortPalette.pinkWash,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: ResortPalette.border, width: 1.1),
    ),
  );
}

class _ResortSceneFallback extends StatelessWidget {
  const _ResortSceneFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4F1E9), Color(0xFFFFF3D9), Color(0xFFBDE0D7)],
        ),
      ),
      child: CustomPaint(painter: _ScenePainter()),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sun = Paint()..color = const Color(0xFFFFD89B).withValues(alpha: .8);
    canvas.drawCircle(Offset(size.width * .77, size.height * .3), 23, sun);
    final sea = Paint()..color = const Color(0xFF8DCBC5).withValues(alpha: .5);
    final seaPath = Path()
      ..moveTo(0, size.height * .63)
      ..quadraticBezierTo(
        size.width * .4,
        size.height * .48,
        size.width,
        size.height * .66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(seaPath, sea);
    final foam = Paint()
      ..color = Colors.white.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var line = 0; line < 3; line++) {
      final y = size.height * (.72 + line * .09);
      final wave = Path()
        ..moveTo(size.width * (.52 + line * .06), y)
        ..quadraticBezierTo(
          size.width * (.67 + line * .04),
          y - 5,
          size.width * (.83 + line * .03),
          y,
        )
        ..quadraticBezierTo(size.width * .9, y + 4, size.width, y);
      canvas.drawPath(wave, foam);
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => false;
}

class _MascotFallback extends StatelessWidget {
  const _MascotFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F4).withValues(alpha: .95),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFBFD7CB)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.face_3_rounded, color: ResortPalette.mint, size: 36),
          SizedBox(height: 4),
          Icon(Icons.favorite_rounded, color: ResortPalette.pink, size: 11),
        ],
      ),
    );
  }
}
