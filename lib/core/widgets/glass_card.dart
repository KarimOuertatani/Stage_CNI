import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_depth.dart';
import 'tilt_card.dart';

/// Carte glassmorphisme premium FitForge.
///
/// Utilise [BackdropFilter] + fond semi-transparent pour créer l'effet verre.
///
/// ## Relief (30 juillet 2026)
///
/// Deux ajouts qui remontent **tout** l'écran où cette carte apparaît — et elle
/// apparaît partout :
///
/// - **une élévation par défaut** ([AppDepth.resting]) : la carte flotte au lieu
///   d'être posée à plat. Sans ombre, un fond translucide sur un fond sombre ne
///   se détache pas — on voit un rectangle un peu plus clair, pas un objet ;
/// - **une arête lumineuse** optionnelle en haut : le bord supérieur accroche la
///   lumière. C'est l'indice qui donne une **épaisseur** à la carte, là où une
///   bordure uniforme la laisse plate.
///
/// L'ombre reste **surchargeable** ([boxShadow]) : les cartes qui ont besoin
/// d'une teinte propre (tuiles de stats, rangées de navigation) passent la leur.
///
/// ## Inclinaison
///
/// [tilt] enveloppe la carte dans un [TiltCard] : elle s'incline vers le doigt
/// et reçoit un reflet. Réservé aux cartes **cliquables** — il ne se déclenche
/// que si un [onTap] est fourni, une carte inerte qui bouge étant une fausse
/// promesse d'interaction.
///
/// NB : sur Flutter Web, [BackdropFilter] déclenche une assertion réentrante du
/// mouse tracker (`mouse_tracker.dart:199`) qui bloque tous les clics. On le
/// désactive donc sur le web (le fond translucide conserve l'esthétique verre),
/// tout en le gardant sur mobile/desktop où il fonctionne parfaitement.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final double blur;

  /// Ombre personnalisée. Par défaut [AppDepth.resting].
  ///
  /// Passer une liste vide retire l'élévation — utile quand la carte est
  /// imbriquée dans une autre surface déjà élevée : deux ombres empilées se
  /// lisent comme une salissure, pas comme deux hauteurs.
  final List<BoxShadow>? boxShadow;

  final double? width;
  final double? height;
  final Gradient? gradient;
  final VoidCallback? onTap;

  /// Arête lumineuse sur le bord supérieur.
  final bool lightEdge;

  /// Teinte de l'arête et du reflet. Par défaut la couleur d'accent.
  final Color? tintColor;

  /// Inclinaison 3D au toucher. Sans effet si [onTap] est nul.
  final bool tilt;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 20,
    this.borderColor,
    this.backgroundColor,
    this.blur = 12,
    this.boxShadow,
    this.width,
    this.height,
    this.gradient,
    this.onTap,
    this.lightEdge = true,
    this.tintColor,
    this.tilt = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.glassBorder;
    final effectiveBg = backgroundColor ?? AppColors.glassSurface;
    final tint = tintColor ?? AppColors.accent;
    final radius = BorderRadius.circular(borderRadius);

    final Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? effectiveBg : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: effectiveBorderColor, width: 1),
      ),
      child: child,
    );

    Widget card = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // Pas de BackdropFilter sur le web (bug mouse tracker) : le fond
          // translucide suffit à rendre l'effet verre.
          kIsWeb
              ? content
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: content,
                ),
          if (lightEdge)
            Positioned(
              top: 0,
              // Retrait sur les côtés : la lumière frappe le milieu du bord et
              // s'éteint aux angles. Une ligne pleine bord à bord se lirait
              // comme un trait de séparation, pas comme un reflet.
              left: borderRadius,
              right: borderRadius,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        tint.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // L'ombre est portée par un parent du ClipRRect : posée à l'intérieur, elle
    // serait rognée avec le contenu et invisible.
    final elevated = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: boxShadow ?? AppDepth.resting,
      ),
      child: card,
    );

    if (onTap != null && tilt) {
      return Container(
        margin: margin,
        child: TiltCard(
          onTap: onTap,
          borderRadius: borderRadius,
          restingShadow: boxShadow ?? AppDepth.resting,
          liftedShadow: AppDepth.tinted(tint, strength: 0.9),
          sheenColor: Color.lerp(Colors.white, tint, 0.3)!,
          child: card,
        ),
      );
    }

    if (onTap != null) {
      return Container(
        margin: margin,
        child: GestureDetector(onTap: onTap, child: elevated),
      );
    }

    return Container(margin: margin, child: elevated);
  }
}

/// Variante opaque de [GlassCard], sans flou d'arrière-plan.
///
/// À utiliser dans les **listes longues** : un `BackdropFilter` par ligne coûte
/// une passe de composition par ligne, et une liste de trente cartes en verre
/// fait tomber le défilement.
///
/// ## Relief (30 juillet 2026)
///
/// Le retour au tap était un simple rétrécissement à 0,97 — correct mais plat.
/// La carte s'incline désormais vers le doigt ([TiltCard]) et porte une ombre
/// teintée. C'est ce qui remonte d'un coup toutes les listes de l'application :
/// coachs, repas, programmes, exercices, conversations.
class SolidCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Gradient? gradient;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final bool hasBorder;

  /// Teinte de l'ombre, de l'arête et du reflet.
  ///
  /// C'est le paramètre le plus utile de cette carte : donner à chaque ligne la
  /// couleur de son sujet (un coach, un macro, un groupe musculaire) évite qu'une
  /// liste ne se lise comme une suite de rectangles identiques.
  final Color? tintColor;

  /// Arête lumineuse sur le bord supérieur.
  final bool lightEdge;

  const SolidCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = 20,
    this.gradient,
    this.color,
    this.boxShadow,
    this.onTap,
    this.hasBorder = true,
    this.tintColor,
    this.lightEdge = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final tint = tintColor ?? AppColors.accent;

    final surface = Stack(
      children: [
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color: gradient == null ? (color ?? AppColors.card) : null,
            gradient: gradient,
            borderRadius: radius,
            border: hasBorder
                ? Border.all(color: AppColors.border, width: 1)
                : null,
          ),
          child: child,
        ),
        if (lightEdge)
          Positioned(
            top: 0,
            left: borderRadius,
            right: borderRadius,
            child: IgnorePointer(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      tint.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final clipped = ClipRRect(borderRadius: radius, child: surface);

    if (onTap == null) {
      return Container(
        margin: margin,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: boxShadow ?? AppDepth.resting,
          ),
          child: clipped,
        ),
      );
    }

    return Container(
      margin: margin,
      child: TiltCard(
        onTap: onTap,
        borderRadius: borderRadius,
        // Inclinaison plus discrète que sur l'accueil : dans une liste, six
        // degrés par ligne donneraient un écran qui gondole au moindre
        // effleurement.
        maxTilt: 4,
        restingShadow: boxShadow ?? AppDepth.resting,
        liftedShadow: AppDepth.tinted(tint, strength: 0.85),
        sheenColor: Color.lerp(Colors.white, tint, 0.3)!,
        sheenStrength: 0.12,
        child: clipped,
      ),
    );
  }
}
