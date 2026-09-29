/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Widgets de branding TogoAI : en-tête d'authentification avec dégradé vert et motif points, logo wordmark (icône + texte Togo/AI) et badge logo pour l'empty state du chat.
*/

import 'package:flutter/material.dart';

import '../../core/theme/togo_colors.dart';

/// En-tête visuel des écrans d'authentification avec identité de marque TogoAI.
///
/// Affiche un conteneur à dégradé vert (couleurs de la charte graphique),
/// un motif de points semi-transparents peint via [CustomPaint], le logo
/// wordmark et une phrase d'accroche. Inclut un bouton de bascule de thème
/// positionné en haut à droite pour permettre le changement clair/sombre
/// depuis les écrans de login/inscription.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.tagline,
    this.onToggleTheme,
    this.isDark = false,
    this.heightFactor = 0.32,
  });

  /// Texte d'accroche affiché sous le logo (ex. « Votre assistant IA togolais »).
  final String tagline;

  /// Callback déclenché au tap sur le bouton de bascule de thème.
  /// Peut être null si la bascule n'est pas disponible sur cet écran.
  final VoidCallback? onToggleTheme;

  /// Indique si le thème actuel est sombre – contrôle l'icône du bouton.
  final bool isDark;

  /// Facteur de hauteur relatif à l'écran (non utilisé directement ici
  /// mais exposé pour permettre un redimensionnement contextuel).
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      // Dégradé vertical tricolore – les couleurs proviennent du design system
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
          // Couche décorative : grille de points semi-transparents
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
                  // Bouton de bascule clair/sombre – aligné à droite
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
                  // Logo wordmark TogoAI en version fond sombre
                  const TogoLogoWordmark(size: 42, lightBackground: false),
                  const SizedBox(height: 12),
                  // Phrase d'accroche contextuelle
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

/// Peintre personnalisé générant une grille de points décoratifs.
///
/// Dessine des cercles blancs semi-transparents (opacité 8%) espacés
/// de [step] pixels, créant un motif subtil de texture sur le dégradé
/// de l'en-tête d'authentification. Stateless – ne nécessite pas de
/// repaint car le motif est fixe.
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    // Pas de la grille – valeur calibrée pour un rendu visuellement équilibré
    const step = 18.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  /// Retourne false car le motif est statique et ne dépend d'aucun paramètre
  /// externe. Optimise les performances en évitant les repaints inutiles.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo wordmark TogoAI composé de l'icône asset et du texte « TogoAI ».
///
/// Adapte automatiquement les couleurs selon le contexte :
/// - Sur fond sombre ou en mode dark : « Togo » en blanc teinté vert,
///   « AI » en couleur accent dark.
/// - Sur fond clair : « Togo » en bleu marine (navy), « AI » en accent light.
///
/// Inclut un fallback [Icons.chat_bubble] si l'asset image n'est pas trouvé,
/// pour éviter un crash en environnement de développement ou si les assets
/// n'ont pas été correctement embarqués.
class TogoLogoWordmark extends StatelessWidget {
  const TogoLogoWordmark({
    super.key,
    this.size = 36,
    this.lightBackground = true,
    this.showText = true,
  });

  /// Taille de l'icône logo en pixels logiques.
  final double size;

  /// Indique si le widget est placé sur un fond clair – influence le choix
  /// de couleur du texte « Togo ».
  final bool lightBackground;

  /// Si false, masque le texte et n'affiche que l'icône (mode compact).
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Logique de couleur adaptative : sur fond sombre ou dark mode,
    // utilise un blanc légèrement teinté vert pour la lisibilité
    final togoColor =
        (!lightBackground || isDark)
            ? const Color(0xFFE8F5EC)
            : TogoColors.navy;
    final aiColor = isDark ? TogoColors.accentDark : TogoColors.accentLight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icône logo depuis les assets – avec fallback gracieux
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
          // Texte bicolore « Togo » + « AI » via RichText
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

/// Badge logo arrondi pour l'état vide (empty state) de l'écran de chat.
///
/// Affiche l'icône TogoAI centrée dans un conteneur avec coins arrondis,
/// fond de carte et ombre portée subtile. Utilisé comme élément visuel
/// d'accueil quand aucun message n'a encore été envoyé.
class TogoLogoBadge extends StatelessWidget {
  const TogoLogoBadge({super.key, this.size = 64});

  /// Taille de l'icône interne – le conteneur ajoute 24px de padding.
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
        // Ombre légère pour créer un effet de profondeur
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
