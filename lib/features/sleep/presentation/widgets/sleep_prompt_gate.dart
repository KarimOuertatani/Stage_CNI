import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sleep_provider.dart';
import 'sleep_prompt_sheet.dart';

/// Le déclencheur du pop-up de sommeil. **Ne dessine rien.**
///
/// ## Pourquoi un widget invisible plutôt que du code dans l'accueil
///
/// L'accueil est un `ConsumerWidget` — sans état, et c'est très bien ainsi. Le
/// déclenchement, lui, a besoin d'un état : « l'ai-je déjà proposé pendant
/// cette construction ? ». Le placer dans l'accueil aurait obligé à convertir
/// tout l'écran en `ConsumerStatefulWidget` pour un besoin qui ne le concerne
/// pas, et aurait dispersé la logique du sommeil dans une feature voisine.
///
/// Ici, tout ce qui décide de l'ouverture tient dans un seul fichier de la
/// feature sommeil, et l'accueil ne porte qu'une ligne.
///
/// ## Les trois conditions
///
/// Il faut les trois, et elles ne viennent pas du même endroit :
///
/// 1. le statut est **chargé** — sinon on ne sait rien ;
/// 2. la nuit du jour n'est **pas déjà enregistrée** → le serveur le sait ;
/// 3. la question n'a **pas déjà été posée aujourd'hui** → seul l'appareil le
///    sait, parce que le serveur ignore qu'on a appuyé sur « Plus tard ».
///
/// La troisième est celle qu'on oublie, et son absence transforme un rappel
/// quotidien en pop-up qui revient à chaque retour sur l'accueil.
///
/// ## Après la première image, jamais pendant
///
/// L'ouverture passe par un `addPostFrameCallback` : afficher une feuille
/// modale pendant la construction d'un widget est interdit, et le faire
/// pendant la toute première image donnerait un pop-up qui apparaît avant
/// l'écran qu'il recouvre.
class SleepPromptGate extends ConsumerStatefulWidget {
  const SleepPromptGate({super.key});

  @override
  ConsumerState<SleepPromptGate> createState() => _SleepPromptGateState();
}

class _SleepPromptGateState extends ConsumerState<SleepPromptGate> {
  /// Une seule tentative par cycle de vie de l'accueil. Sans ce verrou, un
  /// rebuild déclenché par n'importe quel autre provider de l'écran rouvrirait
  /// la feuille par-dessus elle-même.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    if (_handled) return;
    _handled = true;

    try {
      // On attend que le statut soit réellement chargé. Lire la valeur
      // courante suffirait rarement : au lancement, l'appel est encore en vol.
      await ref.read(sleepStatusProvider.future);
    } catch (_) {
      // Serveur injoignable : on ne demande rien. Un pop-up qui s'ouvre pour
      // échouer à l'enregistrement est pire que pas de pop-up du tout — et le
      // rappel reviendra demain.
      return;
    }
    if (!mounted) return;

    final status = ref.read(sleepStatusProvider).value;
    if (!await shouldPromptForSleep(status)) return;
    if (!mounted) return;

    await showSleepPromptSheet(context, ref);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
