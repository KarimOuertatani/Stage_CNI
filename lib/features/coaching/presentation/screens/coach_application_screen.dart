import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/screen_background.dart';
import '../../../auth/data/auth_token_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/coach_application_models.dart';
import '../providers/coach_application_provider.dart';

/// Écran « Ma candidature » — le dossier que le coach constitue et soumet.
///
/// ═══════════════════════════════════════════════════════════════════
///  Pourquoi cet écran existe
/// ═══════════════════════════════════════════════════════════════════
/// Un coach ne peut plus exercer du seul fait de s'être inscrit. Entre la
/// création de son compte et son apparition dans l'annuaire, il doit
/// constituer un dossier — pièce d'identité, photos de ses diplômes — et le
/// soumettre à l'équipe FitForge, qui l'examine.
///
/// C'est le seul écran accessible à un coach tant que son dossier n'est pas
/// validé. Le laisser entrer dans son tableau de bord lui montrerait une
/// interface entièrement vide (aucun adhérent ne peut le trouver) sans lui
/// dire pourquoi.
///
/// ═══════════════════════════════════════════════════════════════════
///  L'écran change de nature selon l'état
/// ═══════════════════════════════════════════════════════════════════
/// - **Brouillon** : une liste de choses à faire, et un bouton d'envoi.
/// - **En attente** : rien à faire, tout est gelé. On dit ce qui se passe.
/// - **Refusé** : le motif en premier, puis de quoi corriger.
/// - **Validé** : ne s'affiche plus (le routeur laisse passer vers `/coach`).
class CoachApplicationScreen extends ConsumerWidget {
  const CoachApplicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coachApplicationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ma candidature'),
        actions: [
          // Actualiser : la décision vient de l'administration, pas d'une
          // action du coach. Sans bouton, un coach en attente n'aurait que la
          // déconnexion pour savoir si son dossier a bougé — et l'écran
          // « en attente » n'invite pas à tirer vers le bas.
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(coachApplicationProvider),
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: ScreenBackground(
        child: SafeArea(
          top: false,
          child: async.when(
            loading: () => const AppListSkeleton(itemCount: 4, itemHeight: 90),
            error: (e, _) => AppErrorState(
              message: 'Impossible de charger ta candidature.',
              onRetry: () => ref.invalidate(coachApplicationProvider),
            ),
            data: (app) => _Body(app: app),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final CoachApplication app;

  const _Body({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(coachApplicationProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _StatusBanner(app: app),
          const SizedBox(height: 18),

          // Le motif de refus passe AVANT tout le reste : c'est la seule
          // chose que le coach doit lire, et l'enfouir sous la liste des
          // documents lui ferait redéposer les mêmes pièces.
          if (app.status == CoachApplicationStatus.rejected &&
              app.rejectionReason != null) ...[
            _RejectionCard(reason: app.rejectionReason!),
            const SizedBox(height: 18),
          ],

          if (app.status.isEditable) ...[
            _Checklist(app: app),
            const SizedBox(height: 18),
          ],

          _DocumentsSection(app: app),

          if (app.status.isEditable) ...[
            const SizedBox(height: 26),
            _SubmitSection(app: app),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Bandeau d'état
// ═══════════════════════════════════════════════════════════════════

class _StatusBanner extends StatelessWidget {
  final CoachApplication app;

  const _StatusBanner({required this.app});

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, message) = switch (app.status) {
      CoachApplicationStatus.draft => (
        Icons.edit_note_rounded,
        AppColors.primary,
        'Constitue ton dossier',
        "Ton compte est créé. Pour apparaître dans l'annuaire et recevoir des "
            "adhérents, l'équipe FitForge doit d'abord vérifier tes qualifications.",
      ),
      CoachApplicationStatus.pending => (
        Icons.hourglass_top_rounded,
        AppColors.warning,
        'Dossier en cours d\'examen',
        "Ta demande a bien été reçue. L'équipe FitForge la consulte et vérifie "
            "tes justificatifs. Tu recevras un email dès que ton compte sera activé.",
      ),
      CoachApplicationStatus.rejected => (
        Icons.build_rounded,
        AppColors.error,
        'Une correction est demandée',
        "Ton compte reste ouvert. Corrige le point ci-dessous, puis renvoie ton "
            "dossier — il repassera en examen.",
      ),
      CoachApplicationStatus.suspended => (
        Icons.pause_circle_rounded,
        AppColors.error,
        'Compte suspendu',
        "Ton profil a été retiré de l'annuaire par l'administration. "
            "Contacte l'équipe FitForge pour en connaître la raison.",
      ),
      CoachApplicationStatus.approved => (
        Icons.verified_rounded,
        AppColors.success,
        'Profil validé',
        "Tu apparais dans l'annuaire et peux recevoir des demandes de suivi.",
      ),
    };

    return GlassCard(
      tintColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
              fontSize: 14,
            ),
          ),

          // Pendant l'examen, dire QUAND ça a été envoyé évite la question
          // « est-ce que ma demande est bien partie ? ».
          if (app.status == CoachApplicationStatus.pending &&
              app.submittedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Envoyé le ${_formatDate(app.submittedAt!)}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _RejectionCard extends StatelessWidget {
  final String reason;

  const _RejectionCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CE QUI DOIT ÊTRE CORRIGÉ',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reason,
            style: TextStyle(
              color: AppColors.textPrimary,
              height: 1.55,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Ce qu'il reste à faire
// ═══════════════════════════════════════════════════════════════════

/// Liste des exigences non satisfaites.
///
/// Le contenu vient **entièrement du serveur** (`missingRequirements`), déjà
/// rédigé en phrases à l'impératif. L'application n'en connaît pas la règle et
/// n'a rien à recalculer : c'est ce qui garantit que le bouton d'envoi et le
/// verdict du serveur ne peuvent jamais diverger.
class _Checklist extends StatelessWidget {
  final CoachApplication app;

  const _Checklist({required this.app});

  @override
  Widget build(BuildContext context) {
    if (app.missingRequirements.isEmpty) {
      return GlassCard(
        tintColor: AppColors.success,
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ton dossier est complet. Tu peux l\'envoyer.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      tintColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IL TE RESTE ${app.missingRequirements.length} POINT'
            '${app.missingRequirements.length > 1 ? "S" : ""}',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          ...app.missingRequirements.map(
            (requirement) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      requirement,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Un raccourci vers le formulaire de profil : plusieurs exigences
          // (accroche, présentation, spécialités) s'y remplissent, et
          // renvoyer le coach le chercher dans un menu serait une friction.
          TextButton.icon(
            onPressed: () => context.push('/coach/profile/edit'),
            icon: const Icon(Icons.person_outline_rounded, size: 18),
            label: const Text('Compléter mon profil'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Justificatifs
// ═══════════════════════════════════════════════════════════════════

class _DocumentsSection extends ConsumerWidget {
  final CoachApplication app;

  const _DocumentsSection({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = app.status.isEditable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes justificatifs',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          editable
              ? "Photographie tes documents à plat, en pleine lumière, en cadrant "
                    "les quatre coins. C'est ce qui fait échouer la plupart des dossiers."
              : "Les pièces transmises à l'équipe FitForge.",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),

        if (app.documents.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  color: AppColors.textSecondary,
                  size: 30,
                ),
                const SizedBox(height: 10),
                Text(
                  'Aucun justificatif déposé',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          ...app.documents.map(
            (doc) => _DocumentTile(document: doc, editable: editable),
          ),

        if (editable) ...[
          const SizedBox(height: 14),
          _AddDocumentButtons(app: app),
        ],
      ],
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  final CoachDocument document;
  final bool editable;

  const _DocumentTile({required this.document, required this.editable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SolidCard(
        tintColor: document.type == CoachDocumentType.identity
            ? AppColors.primary
            : AppColors.accent,
        child: Row(
          children: [
            // Vignette. Les fichiers privés exigent le JWT : `Image.network`
            // reçoit donc l'en-tête d'autorisation, ce qui n'est pas
            // nécessaire pour les avatars (servis publiquement).
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 54,
                height: 54,
                child: document.isImage
                    ? _AuthedImage(documentId: document.id)
                    : Container(
                        color: AppColors.cardLight,
                        child: Center(
                          child: Text(
                            document.isPdf ? '📄' : document.type.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${document.type.emoji} ${document.type.label}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (editable)
              IconButton(
                tooltip: 'Retirer',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: () => _confirmDelete(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer ce justificatif ?'),
        content: Text(
          'Le fichier sera définitivement supprimé du serveur. '
          'Tu pourras en redéposer un autre.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Retirer', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await ref
        .read(coachApplicationControllerProvider.notifier)
        .deleteDocument(document.id);

    if (!context.mounted) return;
    if (!ok) {
      _snack(context, 'Suppression impossible', AppColors.error);
    }
  }
}

/// Image d'un justificatif, chargée avec le jeton d'authentification.
///
/// ⚠️ Ces fichiers ne sont **pas** sous `/media/**` (public) mais derrière une
/// route authentifiée — c'est ce qui empêche qu'une pièce d'identité soit
/// lisible par toute personne connaissant son URL. `Image.network` doit donc
/// transmettre l'en-tête, faute de quoi le serveur répond 401 et la vignette
/// reste cassée.
class _AuthedImage extends StatelessWidget {
  final String documentId;

  const _AuthedImage({required this.documentId});

  @override
  Widget build(BuildContext context) {
    // Lecture SYNCHRONE du cache mémoire : `Image.network` ne peut pas
    // attendre un Future pour ses en-têtes. Le cache est rempli au démarrage
    // par la restauration de session, donc il est disponible ici.
    final token = AuthTokenStore.instance.cachedToken;

    return Image.network(
      ApiConstants.coachDocumentFile(documentId),
      fit: BoxFit.cover,
      headers: token != null
          ? {'Authorization': '${ApiConstants.bearerPrefix}$token'}
          : null,
      errorBuilder: (_, _, _) => Container(
        color: AppColors.cardLight,
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(color: AppColors.cardLight),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Ajout d'un justificatif
// ═══════════════════════════════════════════════════════════════════

class _AddDocumentButtons extends ConsumerWidget {
  final CoachApplication app;

  const _AddDocumentButtons({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // La pièce d'identité est présentée à part et en premier : c'est la
        // seule obligatoire, et la seule qui rattache les diplômes à une
        // personne. Noyée dans une liste de types, elle serait oubliée.
        _AddTile(
          type: CoachDocumentType.identity,
          done: app.hasIdentityDocument,
          subtitle: app.hasIdentityDocument
              ? 'Déposée · en ajouter une autre la remplacera'
              : 'Obligatoire — elle prouve que les diplômes sont bien les tiens',
        ),
        const SizedBox(height: 8),
        _AddTile(
          type: CoachDocumentType.diploma,
          done: false,
          subtitle: 'Photo ou PDF de tes diplômes',
        ),
        const SizedBox(height: 8),
        _AddTile(
          type: CoachDocumentType.certification,
          done: false,
          subtitle: 'BPJEPS, CQP, certifications professionnelles…',
        ),
        const SizedBox(height: 8),
        _AddTile(
          type: CoachDocumentType.other,
          done: false,
          subtitle: 'Attestation d\'assurance, carte professionnelle…',
        ),
      ],
    );
  }
}

class _AddTile extends ConsumerStatefulWidget {
  final CoachDocumentType type;
  final bool done;
  final String subtitle;

  const _AddTile({
    required this.type,
    required this.done,
    required this.subtitle,
  });

  @override
  ConsumerState<_AddTile> createState() => _AddTileState();
}

class _AddTileState extends ConsumerState<_AddTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _busy ? null : _pick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.done
                ? AppColors.success.withValues(alpha: 0.35)
                : AppColors.glassBorder,
          ),
        ),
        child: Row(
          children: [
            Text(widget.type.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.type.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                widget.done
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: widget.done ? AppColors.success : AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  /// Choix de la source, puis dépôt.
  ///
  /// L'appareil photo est proposé en premier : un justificatif se photographie
  /// bien plus souvent qu'il ne se retrouve dans la galerie.
  Future<void> _pick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.type.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: AppColors.accent),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      // Qualité volontairement haute : un diplôme doit rester LISIBLE. Les
      // 80 % utilisés pour les avatars rendraient les petits caractères
      // illisibles, et le dossier serait refusé pour cette seule raison.
      imageQuality: 92,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (file == null || !mounted) return;

    final label = await _askLabel();
    if (!mounted) return;

    setState(() => _busy = true);
    final ok = await ref
        .read(coachApplicationControllerProvider.notifier)
        .uploadDocument(
          filePath: file.path,
          type: widget.type,
          label: label,
          contentType: file.mimeType,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      _snack(context, 'Justificatif ajouté', AppColors.success);
    } else {
      final error = ref.read(coachApplicationControllerProvider);
      _snack(context, _messageOf(error), AppColors.error);
    }
  }

  /// Demande un intitulé.
  ///
  /// Facultatif, mais c'est ce que l'administrateur confronte à la photo :
  /// « Master STAPS 2021 » à côté de l'image indique ce que le coach affirme
  /// prouver. Sans intitulé, l'examen se réduit à deviner.
  Future<String?> _askLabel() async {
    if (widget.type == CoachDocumentType.identity) {
      // Une pièce d'identité n'a pas besoin d'être nommée : son type le dit.
      return null;
    }

    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Que montre ce ${widget.type.label.toLowerCase()} ?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ex. : BPJEPS AGFF 2019',
            helperText: 'Facultatif, mais ça accélère la vérification',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Passer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Soumission
// ═══════════════════════════════════════════════════════════════════

class _SubmitSection extends ConsumerWidget {
  final CoachApplication app;

  const _SubmitSection({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(coachApplicationControllerProvider).isLoading;

    return Column(
      children: [
        PrimaryButton(
          label: app.status == CoachApplicationStatus.rejected
              ? 'Renvoyer mon dossier'
              : 'Envoyer mon dossier',
          icon: Icons.send_rounded,
          isLoading: busy,
          // Désactivé tant que le serveur dit que le dossier est incomplet.
          // Le bouton et le verdict viennent de la même source.
          onPressed: app.canSubmit ? () => _submit(context, ref) : null,
        ),
        const SizedBox(height: 12),
        Text(
          app.canSubmit
              ? "Une fois envoyé, ton dossier est gelé le temps de l'examen : "
                    "tu ne pourras plus le modifier."
              : "Complète les points ci-dessus pour pouvoir envoyer.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Envoyer ton dossier ?'),
        content: Text(
          "L'équipe FitForge va examiner tes justificatifs. Pendant ce temps, "
          "tu ne pourras plus modifier ton dossier.\n\n"
          "Tu recevras un email dès que ton compte sera activé.",
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Pas encore'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await ref
        .read(coachApplicationControllerProvider.notifier)
        .submit();

    if (!context.mounted) return;
    if (ok) {
      _snack(context, 'Dossier envoyé. Tu recevras un email.', AppColors.success);
    } else {
      final error = ref.read(coachApplicationControllerProvider);
      _snack(context, _messageOf(error), AppColors.error);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Utilitaires
// ═══════════════════════════════════════════════════════════════════

void _snack(BuildContext context, String message, Color color) {
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

/// Extrait le message du backend, qui est déjà rédigé pour être lu
/// (« Ton dossier est incomplet : … »). Le remplacer par un texte générique
/// perdrait précisément l'information utile.
String _messageOf(AsyncValue<void> state) {
  final error = state.error;
  if (error == null) return 'Une erreur est survenue';

  final dynamic response = (error as dynamic).response;
  final data = response?.data;
  if (data is Map && data['message'] is String) return data['message'] as String;
  return 'Une erreur est survenue';
}

String _formatDate(DateTime date) {
  const months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
