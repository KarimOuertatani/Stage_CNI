import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_depth.dart';
import 'auth_backdrop.dart';

/// Coquille commune aux écrans d'authentification.
///
/// Elle porte trois décisions qui étaient absentes ou dupliquées :
///
/// ### ① Une largeur maximale
///
/// Le formulaire s'étirait sur **toute** la largeur. Sur une tablette ou en
/// fenêtre desktop, cela donnait des champs de 900 px de long — une ligne de
/// saisie plus large que l'écran d'un téléphone, que l'œil ne peut pas suivre.
/// La coquille plafonne à 440 px et centre : sur téléphone rien ne change, sur
/// grand écran le formulaire redevient lisible.
///
/// ### ② Le clavier ne masque plus le bas du formulaire
///
/// Le contenu était dans un `Center`, donc verticalement figé : à l'ouverture du
/// clavier, le bas du formulaire passait dessous sans qu'on puisse y accéder.
/// Ici le contenu est **centré tant qu'il tient**, et défile dès qu'il ne tient
/// plus — y compris à cause du clavier.
///
/// ### ③ Un seul fond pour les deux écrans
///
/// Voir [AuthBackdrop] : passer de la connexion à l'inscription ne fait plus
/// sauter le décor.
class AuthShell extends StatelessWidget {
  final Widget child;

  /// Largeur maximale du formulaire.
  ///
  /// 440 px : au-delà, une ligne de saisie devient trop longue pour être
  /// balayée du regard d'un seul coup.
  static const double maxContentWidth = 440;

  const AuthShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Le fond est peint par AuthBackdrop, pas par le Scaffold.
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    // `minHeight` + `Center` : le contenu reste centré quand il
                    // y a de la place, et défile normalement dès qu'il dépasse
                    // — ce qu'un simple `Center` ne permet pas.
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: maxContentWidth,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de formulaire en verre, avec relief.
///
/// ## Ce qui change par rapport à l'ancienne version
///
/// Elle avait un fond translucide et deux ombres réglées à la main. Trois
/// ajouts :
///
/// - **un vrai flou d'arrière-plan** ([BackdropFilter]) : le verre laisse
///   maintenant passer les halos du fond en les diffusant. Sans flou, un fond
///   semi-transparent ne se lit pas comme du verre mais comme un calque gris ;
/// - **le système d'ombres du projet** ([AppDepth]) : la carte flotte à la même
///   hauteur que celles de l'accueil, au lieu d'une élévation réglée à part ;
/// - **une arête lumineuse en haut** : le bord supérieur accroche la lumière,
///   ce qui donne une épaisseur à la carte. Une bordure uniforme la laisse
///   plate.
///
/// ⚠️ Pas d'inclinaison 3D ici, contrairement aux cartes de l'accueil. Incliner
/// une surface dans laquelle on **tape du texte** rend la saisie désagréable et
/// déplace les champs sous le doigt. Le relief s'arrête à ce qui ne gêne pas.
class AuthGlassCard extends StatelessWidget {
  final List<Widget> children;

  /// Teinte de l'ombre colorée — violet à la connexion, cyan à l'inscription.
  final Color tint;

  const AuthGlassCard({
    super.key,
    required this.children,
    this.tint = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;

    final content = Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.glassSurface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        // L'arête : un dégradé, pas une ligne pleine. La lumière frappe le
        // milieu du bord et s'éteint aux angles.
        Positioned(
          top: 0,
          left: 24,
          right: 24,
          child: IgnorePointer(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.onGradient.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppDepth.tinted(tint, strength: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        // Pas de BackdropFilter sur le web : il déclenche une assertion
        // réentrante du mouse tracker qui bloque TOUS les clics — donc un
        // formulaire de connexion inutilisable. Le fond translucide suffit.
        child: kIsWeb
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: content,
              ),
      ),
    );
  }
}
