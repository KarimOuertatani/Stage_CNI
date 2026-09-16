import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/profile_model.dart';
import '../../data/ai_program_models.dart';
import 'program_provider.dart';

/// La génération par l'IA est-elle disponible sur ce serveur ?
///
/// ## On ne masque que sur un « non » explicite
///
/// Le seul cas qui justifie de cacher l'entrée est un serveur qui **répond**
/// `{"available": false}` : il n'a pas de clé Gemini, la fonctionnalité ne peut
/// pas marcher, et un bouton qui ne mène qu'à une erreur promet quelque chose
/// que l'app n'a pas.
///
/// **Tout le reste affiche le bouton** — appel en échec, serveur injoignable,
/// backend d'une version antérieure qui ne connaît pas encore la route. La
/// première version de ce provider renvoyait `false` sur n'importe quelle
/// exception, et le résultat était bien pire que le problème évité : contre un
/// backend pas encore redémarré, la fonctionnalité était **entièrement
/// invisible, sans le moindre message**. Impossible de comprendre pourquoi
/// sans lire le code.
///
/// Un bouton qui explique son échec quand on le touche vaut toujours mieux
/// qu'un bouton absent : l'un se diagnostique, l'autre non. Et si le serveur
/// est réellement injoignable, la liste des programmes échoue elle aussi —
/// l'écran est alors en erreur de toute façon, cette carte ne s'affiche pas.
///
/// Le résultat est mis en cache par Riverpod pour la session : la réponse ne
/// change pas tant que le serveur n'a pas redémarré.
final aiProgramAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.read(programApiProvider).aiAvailable();
  } catch (_) {
    return true;
  }
});

/// La bande d'annonce de la génération IA a-t-elle été masquée ?
///
/// ## Pourquoi un provider et pas un `setState` dans l'écran
///
/// L'onglet Programmes est **reconstruit** à chaque retour dessus depuis un
/// écran de détail. Un booléen local repartirait donc à `false` et la bande
/// reviendrait alors qu'on vient de la masquer — exactement ce qu'on ne veut
/// pas. Un provider vit dans le `ProviderScope` racine : il traverse les
/// reconstructions et les changements d'onglet.
///
/// ## Pourquoi rien n'est écrit sur le disque
///
/// L'état meurt avec le processus : la bande **revient au prochain démarrage**
/// de l'application. C'est voulu — taper une croix veut dire « pas maintenant »,
/// pas « plus jamais ». Et persister la préférence d'une bande d'annonce dans
/// un fichier serait disproportionné par rapport à ce qu'elle vaut.
///
/// L'entrée permanente de la fonctionnalité, elle, ne se masque jamais : c'est
/// le bouton à côté de « Créer » (`AiCreateButton`).
class AiCtaDismissNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final aiCtaDismissedProvider =
    NotifierProvider<AiCtaDismissNotifier, bool>(AiCtaDismissNotifier.new);

/// Le questionnaire pré-rempli depuis le profil de l'adhérent.
///
/// **C'est ce qui rend l'assistant supportable.** Sans pré-remplissage, on
/// redemande à quelqu'un qui a déjà rempli son profil son objectif, son niveau
/// et son rythme — et il se demande à quoi sert le profil. Avec, les trois
/// premières questions sont déjà répondues : il les confirme d'un geste ou les
/// change pour ce programme-là, sans que son profil bouge.
///
/// Les valeurs par défaut de [AiProgramBrief] prennent le relais quand le
/// profil est vide.
AiProgramBrief aiBriefFromProfile(ProfileModel? profile) {
  if (profile == null) return const AiProgramBrief();

  const fallback = AiProgramBrief();
  final weekly = profile.weeklyWorkoutTarget;

  return fallback.copyWith(
    goal: profile.goal,
    experienceLevel: profile.experienceLevel,
    // Le profil vise un nombre de séances ; on le borne à ce que l'assistant
    // sait proposer plutôt que d'afficher une valeur hors échelle.
    daysPerWeek: weekly?.clamp(1, 7),
  );
}
