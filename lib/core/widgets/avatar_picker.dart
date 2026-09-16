import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/coaching/presentation/widgets/coach_avatar.dart';
import '../theme/app_colors.dart';

/// Avatar éditable : affiche la photo de profil (ou les initiales) avec un
/// bouton appareil photo. Un tap ouvre les options (galerie / appareil /
/// suppression). L'upload passe par [AuthNotifier.updateAvatar], ce qui met à
/// jour l'utilisateur en mémoire et propage la photo partout.
///
/// [onChanged] permet au parent de rafraîchir ses propres providers (profil,
/// profil coach…) après un changement d'avatar.
class AvatarPicker extends ConsumerStatefulWidget {
  final double size;
  final Gradient? gradient;
  final VoidCallback? onChanged;

  const AvatarPicker({
    super.key,
    this.size = 96,
    this.gradient,
    this.onChanged,
  });

  @override
  ConsumerState<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<AvatarPicker> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null) return;
      setState(() => _busy = true);
      final ok = await ref
          .read(authProvider.notifier)
          .updateAvatar(
            file.path,
            filename: file.name,
            contentType: file.mimeType,
          );
      if (!mounted) return;
      setState(() => _busy = false);
      if (ok) {
        widget.onChanged?.call();
        _toast('Photo de profil mise à jour', AppColors.success);
      } else {
        _toast('Échec de la mise à jour', AppColors.error);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Impossible de sélectionner l\'image', AppColors.error);
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    final ok = await ref.read(authProvider.notifier).removeAvatar();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onChanged?.call();
      _toast('Photo supprimée', AppColors.textHint);
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openSheet() {
    HapticFeedback.selectionClick();
    final hasPhoto = (ref.read(authProvider).user?.avatarUrl ?? '').isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primaryText,
              ),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_rounded,
                color: AppColors.primaryText,
              ),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.errorText,
                ),
                title: const Text('Supprimer la photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _remove();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final name = user?.fullName ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return GestureDetector(
      onTap: _busy ? null : _openSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CoachAvatar(
            initials: initials,
            avatarUrl: user?.avatarUrl,
            size: widget.size,
            gradient: widget.gradient,
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black45,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                size: widget.size * 0.18,
                color: AppColors.onGradient,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
