
import 'package:flutter/material.dart';

import '../../core/theme/togo_colors.dart';

/// Header auth : dégradé vert + motif points + logo + tagline.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.tagline,
    this.onToggleTheme,
    this.isDark = false,
    this.heightFactor = 0.32,
  });

  final String tagline;
  final VoidCallback? onToggleTheme;
  final bool isDark;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            TogoColors.authGreenTop,
            TogoColors.authGreenMid,
            TogoColors.authGreenBottom,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter()),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: onToggleTheme,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: TogoColors.navy,
                      ),
                      icon: Icon(
                        isDark
                            ? Icons.wb_sunny_outlined
                            : Icons.dark_mode_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const TogoLogoWordmark(size: 42, lightBackground: false),
                  const SizedBox(height: 12),
                  Text(
                    tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    const step = 18.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wordmark TogoAI (icône asset + texte).
class TogoLogoWordmark extends StatelessWidget {
  const TogoLogoWordmark({
    super.key,
    this.size = 36,
    this.lightBackground = true,
    this.showText = true,
  });

  final double size;
  final bool lightBackground;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Sur fond sombre : blanc légèrement teinté vert ; sinon navy
    final togoColor =
        (!lightBackground || isDark)
            ? const Color(0xFFE8F5EC)
            : TogoColors.navy;
    final aiColor = isDark ? TogoColors.accentDark : TogoColors.accentLight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo_icon.png',
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => Icon(
            Icons.chat_bubble,
            size: size,
            color: aiColor,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: size * 0.72,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(text: 'Togo', style: TextStyle(color: togoColor)),
                TextSpan(text: 'AI', style: TextStyle(color: aiColor)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Logo centré pour empty state chat (badge arrondi).
class TogoLogoBadge extends StatelessWidget {
  const TogoLogoBadge({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.togo;
    return Container(
      width: size + 24,
      height: size + 24,
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/logo_icon.png',
        width: size,
        height: size,
      ),
    );
  }
}
