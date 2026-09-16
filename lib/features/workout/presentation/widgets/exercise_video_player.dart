import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Lecteur de la vidéo de démonstration d'un exercice (MP4 servi par CDN
/// ExerciseDB). Habillage Chewie : contrôles standards, plein écran, boucle.
///
/// Robuste par conception : tant que la vidéo n'est pas prête on affiche
/// [poster] (image de l'exercice) avec un indicateur ; en cas d'échec réseau,
/// un fallback visuel — jamais de crash. La vidéo ne se charge que sur cet
/// écran de détail, jamais dans les listes (performance).
class ExerciseVideoPlayer extends StatefulWidget {
  final String videoUrl;

  /// Image affichée pendant l'initialisation / en cas d'échec (facultative).
  final String? poster;

  const ExerciseVideoPlayer({super.key, required this.videoUrl, this.poster});

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  /// Au-delà, on considère que la vidéo ne viendra pas.
  ///
  /// `initialize()` n'a **aucun délai propre** : sur un Wi-Fi qui décroche ou
  /// un backend qui ne répond plus, il ne rend jamais la main. L'écran restait
  /// alors sur un poster et un indicateur qui tournait indéfiniment — pas
  /// d'erreur, pas de bouton, rien à faire sinon quitter l'écran. C'est
  /// exactement ce que veut dire « la vidéo ne se lance pas ».
  static const _initTimeout = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoPlayer old) {
    super.didUpdateWidget(old);
    // Le widget peut être réutilisé pour un AUTRE exercice (position identique
    // dans la liste, pas de clé) : sans cette relance, on continuerait à
    // afficher la démonstration du mouvement précédent.
    if (old.videoUrl != widget.videoUrl) {
      _disposeControllers();
      setState(() => _hasError = false);
      _initialize();
    }
  }

  /// Relance une initialisation après un échec (bouton « Réessayer »).
  void _retry() {
    _disposeControllers();
    setState(() => _hasError = false);
    _initialize();
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  Future<void> _initialize() async {
    final videoUrl =
        ApiConstants.proxiedMedia(widget.videoUrl) ?? widget.videoUrl;
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _videoController = controller;
    try {
      await controller.initialize().timeout(_initTimeout);
      if (!mounted) {
        controller.dispose();
        return;
      }
      // Une autre initialisation a pris la main entre-temps (changement
      // d'exercice, « Réessayer ») : ce contrôleur-ci est périmé.
      if (_videoController != controller) {
        controller.dispose();
        return;
      }
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: true,
          aspectRatio: controller.value.aspectRatio == 0
              ? 16 / 9
              : controller.value.aspectRatio,
          allowFullScreen: true,
          allowMuting: true,
          placeholder: _poster(),
          materialProgressColors: ChewieProgressColors(
            playedColor: AppColors.primary,
            handleColor: AppColors.primary,
            bufferedColor: AppColors.border,
            backgroundColor: AppColors.surface,
          ),
          // Erreur SURVENUE PENDANT la lecture : le contrôleur est vivant, le
          // recréer par « Réessayer » couperait la vidéo sous le lecteur.
          errorBuilder: (context, _) => _errorView(retryable: false),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  Widget _poster() {
    final posterUrl = ApiConstants.proxiedMedia(widget.poster);
    if (posterUrl == null || posterUrl.isEmpty) {
      return Container(color: Colors.black);
    }
    return Image.network(
      posterUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => Container(color: Colors.black),
    );
  }

  /// Écran d'échec — avec de quoi en sortir.
  ///
  /// La cause la plus fréquente est passagère (Wi-Fi qui décroche, backend
  /// redémarré) : sans bouton, il fallait quitter l'écran et y revenir pour
  /// retenter, ce que personne ne devine.
  Widget _errorView({bool retryable = true}) {
    return Container(
      color: AppColors.card,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded, color: AppColors.textHint, size: 34),
          const SizedBox(height: 10),
          Text(
            'Vidéo de démonstration indisponible.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          if (retryable) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_hasError) {
      content = _errorView();
    } else if (_chewieController == null) {
      // Poster + spinner pendant l'initialisation.
      content = Stack(
        fit: StackFit.expand,
        children: [
          _poster(),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
        ],
      );
    } else {
      content = Chewie(controller: _chewieController!);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: content),
    );
  }
}
