/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Bibliothèque de widgets réutilisables de l'application : boutons primaire et secondaire, champ de texte avec label, chips de sélection et séparateur « ou ».
*/

import 'package:flutter/material.dart';

import '../../core/theme/togo_colors.dart';

/// Bouton d'action principale de l'application (forme pill, pleine largeur).
///
/// Utilisé pour les actions primaires des formulaires : « Se connecter »,
/// « Créer un compte », « Enregistrer », etc. Intègre nativement un état
/// de chargement qui désactive l'interaction et affiche un indicateur
/// circulaire, évitant ainsi les doubles soumissions.
///
/// Le style (couleur de fond, border-radius, typographie) est hérité du
/// thème global défini dans [AppTheme.elevatedButtonTheme].
class TogoPrimaryButton extends StatelessWidget {
  const TogoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  /// Texte du bouton (ex. « Se connecter »).
  final String label;

  /// Callback déclenché au tap – null désactive le bouton.
  final VoidCallback? onPressed;

  /// Quand true, remplace le label par un [CircularProgressIndicator]
  /// et empêche toute interaction.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        // Désactive le bouton pendant le chargement pour éviter les doubles taps
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Bouton secondaire avec bordure (outlined), pleine largeur.
///
/// Utilisé pour les actions secondaires ou alternatives comme
/// « Se connecter avec Google ». Supporte un widget [leading] optionnel
/// (typiquement une icône ou un logo) placé à gauche du label.
///
/// Le style de bordure est hérité de [AppTheme.outlinedButtonTheme].
class TogoSecondaryButton extends StatelessWidget {
  const TogoSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.loading = false,
  });

  /// Texte du bouton.
  final String label;

  /// Callback déclenché au tap – null désactive le bouton.
  final VoidCallback? onPressed;

  /// Widget optionnel affiché à gauche du texte (ex. logo Google).
  final Widget? leading;

  /// Quand true, affiche un indicateur de chargement en lieu et place du contenu.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 10),
                  ],
                  // Flexible + ellipsis pour gérer les textes longs
                  // sans débordement
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}

/// Champ de texte stylisé avec label flottant au-dessus.
///
/// Encapsule un [TextFormField] standard en ajoutant un label externe
/// (au-dessus du champ) avec un espacement cohérent. Supporte le mode
/// mot de passe avec toggle de visibilité via [onToggleObscure].
///
/// La décoration du champ (border-radius, couleurs) est héritée du
/// thème global [AppTheme.inputDecorationTheme].
class TogoTextField extends StatelessWidget {
  const TogoTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onToggleObscure,
    this.hintText,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  /// Label affiché au-dessus du champ de saisie.
  final String label;

  /// Contrôleur de texte pour lecture/écriture programmatique.
  final TextEditingController? controller;

  /// Active le masquage du texte (mode mot de passe).
  final bool obscureText;

  /// Type de clavier à afficher (email, numérique, etc.).
  final TextInputType? keyboardType;

  /// Action du bouton de validation du clavier (suivant, terminé, etc.).
  final TextInputAction? textInputAction;

  /// Callback pour basculer la visibilité du mot de passe.
  /// Si non-null, un bouton œil est affiché en suffix.
  final VoidCallback? onToggleObscure;

  /// Texte d'indication (placeholder) dans le champ vide.
  final String? hintText;

  /// Fonction de validation pour les formulaires ([Form]).
  final String? Function(String?)? validator;

  /// Callback déclenché à chaque modification du texte.
  final ValueChanged<String>? onChanged;

  /// Si false, le champ est visuellement désactivé et non interactif.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label externe – typo semi-bold pour différencier du placeholder
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            // Bouton toggle visibilité – affiché uniquement si le callback est fourni
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: context.togo.textSecondary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Chip de sélection stylisé pour les choix exclusifs (thème, langue, mode).
///
/// Affiche un chip en forme de stade (StadiumBorder) avec une bordure
/// colorée et un fond teinté lorsqu'il est sélectionné. Utilise les
/// couleurs sémantiques du design system ([TogoColors]) via l'extension
/// [context.togo] pour garantir la cohérence visuelle.
///
/// Supporte un widget [leading] optionnel (ex. emoji drapeau) et
/// des paramètres de padding/fontSize personnalisables pour s'adapter
/// à différents contextes d'utilisation.
class TogoChoiceChip extends StatelessWidget {
  const TogoChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    this.fontSize = 13,
  });

  /// Texte du chip.
  final String label;

  /// État de sélection – contrôle la couleur de fond et de bordure.
  final bool selected;

  /// Callback déclenché au tap.
  final VoidCallback onTap;

  /// Widget optionnel affiché avant le texte (ex. icône, emoji).
  final Widget? leading;

  /// Padding interne du chip.
  final EdgeInsetsGeometry padding;

  /// Taille de police du label.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.togo;
    return Material(
      // Fond teinté accent en mode sélectionné, fond carte sinon
      color: selected ? t.accentSoft : t.bgCard,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? t.accent : t.border,
          // Bordure plus épaisse en mode sélectionné pour renforcer le feedback visuel
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 6),
              ],
              Text(
                label,
                softWrap: false,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? t.accent : Theme.of(context).colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Séparateur horizontal avec texte centré (ex. « ou »).
///
/// Utilisé entre les boutons de connexion pour séparer visuellement
/// les méthodes d'authentification (email vs OAuth). Le [label] est
/// entouré de deux lignes horizontales extensibles.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});

  /// Texte central du séparateur (ex. « ou », « or »).
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.togo.border;
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(color: context.togo.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}
