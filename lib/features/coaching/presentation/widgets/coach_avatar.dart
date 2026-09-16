import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Avatar coach/adhérent : photo si dispo, sinon initiales sur dégradé de marque.
///
/// Peut porter une **pastille de présence** ([online]) : point vert si la
/// personne est connectée, gris sinon. Passer `null` (défaut) n'affiche aucune
/// pastille — c'est important : tant que le serveur n'a pas répondu, mieux vaut
/// ne rien afficher qu'affirmer « hors ligne » à tort.
class CoachAvatar extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  final double size;
  final Gradient? gradient;
  final bool? online;

  /// Couleur de l'anneau de la pastille : celle du fond sur lequel l'avatar est
  /// posé, pour que le point paraisse détouré. Défaut : [AppColors.surface].
  final Color? dotRingColor;

  const CoachAvatar({
    super.key,
    required this.initials,
    this.avatarUrl,
    this.size = 52,
    this.gradient,
    this.online,
    this.dotRingColor,
  });

  @override
  Widget build(BuildContext context) {
    // Les avatars sont stockés en chemin relatif (/media/...) : on résout
    // l'URL absolue via l'origine du backend.
    final resolved = ApiConstants.mediaUrl(avatarUrl);
    final hasImage = resolved != null;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImage ? null : (gradient ?? AppColors.primaryGradient),
        image: hasImage
            ? DecorationImage(image: NetworkImage(resolved), fit: BoxFit.cover)
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              initials,
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.onGradient,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.36,
              ),
            ),
    );

    if (online == null) return avatar;

    // La pastille est proportionnelle à l'avatar : lisible sur une grande photo
    // de profil comme sur une vignette de liste.
    final dot = (size * 0.28).clamp(9.0, 16.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: PresenceDot(
              size: dot,
              online: online!,
              ringColor: dotRingColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille de présence : point vert « en ligne », gris sinon.
///
/// L'anneau reprend la couleur du fond pour détacher la pastille de l'avatar,
/// quel que soit le contenu de la photo.
class PresenceDot extends StatelessWidget {
  final double size;
  final bool online;
  final Color? ringColor;

  const PresenceDot({
    super.key,
    required this.online,
    this.size = 12,
    this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.successText : AppColors.textDisabled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor ?? AppColors.surface,
          width: size * 0.18,
        ),
        boxShadow: online
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: size * 0.5,
                ),
              ]
            : null,
      ),
    );
  }
}
