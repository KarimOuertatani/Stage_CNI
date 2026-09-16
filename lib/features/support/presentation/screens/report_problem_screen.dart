import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/media_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/screen_background.dart';
import '../../data/problem_report_models.dart';
import '../providers/problem_report_provider.dart';

/// Écran « Signaler un problème ».
///
/// ═══════════════════════════════════════════════════════════════════
///  Le même écran pour les deux rôles
/// ═══════════════════════════════════════════════════════════════════
/// Adhérent et coach signalent de la même façon. Le serveur fige le rôle au
/// moment de l'envoi : c'est lui qui indiquera à l'administration depuis quel
/// espace le problème a été rencontré. Dupliquer l'écran par rôle aurait
/// produit deux formulaires à maintenir pour une seule différence, que le
/// serveur déduit tout seul.
///
/// ═══════════════════════════════════════════════════════════════════
///  Pourquoi on insiste sur la description
/// ═══════════════════════════════════════════════════════════════════
/// Le serveur exige 20 caractères. Ce n'est pas une chicane de formulaire :
/// « ça marche pas » ne permet ni de reproduire, ni de répondre, ni même de
/// savoir de quel écran on parle. Le seul résultat serait un aller-retour
/// pour demander des précisions, auquel la plupart des gens ne répondent pas.
///
/// L'écran l'explique donc **avant** la saisie, avec trois questions
/// concrètes, plutôt que d'attendre le refus du serveur pour le dire.
class ReportProblemScreen extends ConsumerStatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  ConsumerState<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends ConsumerState<ReportProblemScreen> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  ProblemCategory? _category;
  String? _attachmentUrl;
  String? _attachmentName;
  bool _uploading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSend =>
      _category != null &&
      _subjectController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().length >= 20;

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(problemReportControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Signaler un problème'),
        actions: [
          TextButton(
            onPressed: () => context.push('/signalements'),
            child: const Text('Mes signalements'),
          ),
        ],
      ),
      body: ScreenBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                "Dis-nous ce qui ne va pas. L'équipe FitForge lit chaque "
                "signalement et te répond dans l'application.",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),

              // ── Catégorie ─────────────────────────────────────────
              Text(
                'De quoi s\'agit-il ?',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...ProblemCategory.values.map(_categoryTile),

              const SizedBox(height: 24),

              // ── Sujet ─────────────────────────────────────────────
              Text(
                'En une phrase',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _subjectController,
                maxLength: 150,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Ex. : le minuteur de repos ne se déclenche pas',
                  counterText: '',
                ),
              ),

              const SizedBox(height: 22),

              // ── Description ───────────────────────────────────────
              Text(
                'Raconte',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                "Trois choses nous aident vraiment : sur quel écran, ce que tu "
                "as fait, et ce qui s'est passé à la place.",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: 6,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:
                      "Sur l'écran de séance, j'ai validé une série et le "
                      "minuteur est resté à zéro…",
                  // Le compteur ne s'affiche qu'en dessous du minimum : une
                  // fois le seuil franchi, il n'apprend plus rien et
                  // ressemblerait à une contrainte de longueur maximale.
                  counterText: _descriptionController.text.trim().length < 20
                      ? '${_descriptionController.text.trim().length}/20 minimum'
                      : '',
                ),
              ),

              const SizedBox(height: 16),

              // ── Capture ───────────────────────────────────────────
              _AttachmentField(
                fileName: _attachmentName,
                uploading: _uploading,
                onPick: _pickScreenshot,
                onRemove: () => setState(() {
                  _attachmentUrl = null;
                  _attachmentName = null;
                }),
              ),

              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Envoyer',
                icon: Icons.send_rounded,
                isLoading: sending,
                onPressed: _canSend && !_uploading ? _send : null,
              ),
              const SizedBox(height: 14),
              Text(
                "Ta version de l'application et ton appareil sont joints "
                "automatiquement : ils nous évitent de te les redemander.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryTile(ProblemCategory category) {
    final selected = _category == category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _category = category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 19)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (category.hint.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        category.hint,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dépose une capture d'écran.
  ///
  /// Elle passe par le média **public** (`POST /media`), le même chemin que
  /// les pièces jointes du chat. Contrairement aux justificatifs de coach, il
  /// ne s'agit pas d'une pièce d'identité mais d'un écran de l'application que
  /// l'utilisateur choisit d'envoyer : dupliquer un second mécanisme de
  /// stockage privé serait disproportionné.
  Future<void> _pickScreenshot() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final media = await ref
          .read(mediaApiProvider)
          .uploadPath(file.path, filename: file.name, contentType: file.mimeType);
      if (!mounted) return;
      setState(() {
        _attachmentUrl = media.url;
        _attachmentName = file.name;
        _uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _snack("La capture n'a pas pu être envoyée", AppColors.error);
    }
  }

  Future<void> _send() async {
    final ok = await ref
        .read(problemReportControllerProvider.notifier)
        .submit(
          category: _category!,
          subject: _subjectController.text,
          description: _descriptionController.text,
          attachmentUrl: _attachmentUrl,
        );

    if (!mounted) return;

    if (ok) {
      // On quitte l'écran vers la liste : le signalement y apparaît avec son
      // statut, ce qui montre qu'il est bien parti. Un simple message de
      // confirmation laisserait un doute.
      context.pushReplacement('/signalements');
      _snack('Signalement envoyé. Merci !', AppColors.success);
    } else {
      _snack(
        ref.read(problemReportControllerProvider.notifier).errorMessage(),
        AppColors.error,
      );
    }
  }

  void _snack(String message, Color color) {
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
}

class _AttachmentField extends StatelessWidget {
  final String? fileName;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _AttachmentField({
    required this.fileName,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (fileName != null) {
      return SolidCard(
        tintColor: AppColors.accent,
        child: Row(
          children: [
            Icon(Icons.image_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fileName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.error, size: 18),
              onPressed: onRemove,
            ),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: uploading ? null : onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            if (uploading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                uploading
                    ? 'Envoi de la capture…'
                    : 'Joindre une capture d\'écran (facultatif)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
