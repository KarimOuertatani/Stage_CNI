import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_states.dart';
import '../../data/coach_application_models.dart';
import '../providers/coach_application_provider.dart';
import 'coach_application_screen.dart';
import 'coach_shell.dart';

/// Porte d'entrée de l'espace coach.
///
/// ═══════════════════════════════════════════════════════════════════
///  Pourquoi un widget, et non une redirection du routeur
/// ═══════════════════════════════════════════════════════════════════
/// La décision dépend d'une donnée **serveur** (le statut de la
/// candidature), donc d'un appel asynchrone. Or la fonction `redirect` de
/// go_router est synchrone : elle devrait trancher avant d'avoir la réponse.
/// On aurait donc soit renvoyé le coach vers son dossier à chaque démarrage
/// avant de le ramener au tableau de bord — un clignotement —, soit maintenu
/// un cache du statut dans le routeur, avec le risque qu'il diverge du
/// serveur.
///
/// Ici, l'écran ne se monte qu'une fois la réponse connue.
///
/// C'est le même raisonnement que `SleepPromptGate` : un widget qui porte une
/// décision, plutôt que de disperser la logique dans une couche qui n'est pas
/// faite pour elle.
///
/// ═══════════════════════════════════════════════════════════════════
///  Ce qui est réellement protégé, et ce qui ne l'est pas
/// ═══════════════════════════════════════════════════════════════════
/// Cette porte protège l'**expérience** : elle évite qu'un coach non validé
/// contemple un tableau de bord désespérément vide sans comprendre pourquoi
/// personne ne le contacte.
///
/// Elle ne protège pas les **données** — c'est le serveur qui le fait :
/// l'annuaire ne renvoie que les coachs approuvés, et une demande de suivi
/// visant un coach non approuvé est refusée en 404. Contourner cet écran ne
/// donnerait donc accès à rien.
class CoachGate extends ConsumerStatefulWidget {
  const CoachGate({super.key});

  @override
  ConsumerState<CoachGate> createState() => _CoachGateState();
}

class _CoachGateState extends ConsumerState<CoachGate> {
  @override
  void initState() {
    super.initState();

    // ⚠️ On RELIT le statut à chaque entrée dans l'espace coach.
    //
    // C'est la seule donnée de l'application qu'une AUTRE personne peut
    // changer sans que le coach fasse quoi que ce soit : l'administration
    // valide, refuse ou suspend de son côté. Un `FutureProvider` garde sa
    // valeur tant que rien ne l'invalide — donc, sans cette ligne, un coach
    // dont le dossier vient d'être refusé continuerait de voir « en cours
    // d'examen », c'est-à-dire l'état où il ne peut rien modifier.
    //
    // Le coût est d'un appel par entrée dans l'espace coach. Le laisser
    // périmer coûte un coach bloqué qui n'a aucun moyen de s'en sortir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(coachApplicationProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coachApplicationProvider);

    return async.when(
      // Écran d'attente sobre : on ne sait pas encore quoi montrer, et
      // afficher le squelette du tableau de bord promettrait un écran que le
      // coach n'obtiendra peut-être pas.
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      ),

      // En cas d'échec réseau, on laisse passer vers le tableau de bord.
      //
      // Le choix est délibéré : bloquer un coach déjà validé parce que le
      // serveur a hoqueté serait bien pire que de laisser entrer un coach non
      // validé dans une interface qui, de toute façon, ne lui montrera aucune
      // donnée — le serveur refusant ses requêtes.
      error: (e, _) => const CoachShell(),

      data: (app) => app.status == CoachApplicationStatus.approved
          ? const CoachShell()
          : const CoachApplicationScreen(),
    );
  }
}

/// Affiché si un écran de l'espace coach est atteint alors que le compte
/// n'est pas validé. Conservé pour les accès directs par URL (web/deep link).
class CoachNotApprovedNotice extends StatelessWidget {
  const CoachNotApprovedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Accès restreint')),
      body: const AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Ton compte n\'est pas encore validé',
        message:
            'Cette partie de l\'application s\'ouvrira dès que l\'équipe '
            'FitForge aura vérifié ton dossier.',
      ),
    );
  }
}
