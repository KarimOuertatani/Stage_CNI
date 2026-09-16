# Prompt pour agent IA — Ajout d'une vue 3D du corps musculaire dans FitForge AI

> ⚠️ **Document historique — déjà exécuté, puis dépassé.** Il décrit
> `corps_fitforge.glb` et ses 12 zones (`abs`, `pectoraux`, `corps_neutre`…),
> modèle qui a été **remplacé** par la planche anatomique `fitforge_body.glb`
> (464 muscles, une entité + un matériau chacun). Le principe de coloration est
> resté le même ; l'état courant est décrit dans
> [`docs/SCORE_ET_HEATMAP.md`](../docs/SCORE_ET_HEATMAP.md) et
> `assets/models/muscles_reference.md`.

Copie-colle tout ce qui suit dans ton agent (Claude Code, Cursor, etc.).

---

## Contexte du projet

FitForge AI est une app fitness Flutter (Riverpod, go_router, Dio). L'app affiche déjà un écran avec un corps humain coloré selon l'intensité de sollicitation musculaire d'une séance d'entraînement, actuellement en 2D (`Body2DWidget`), piloté par une liste `List<MuscleIntensity>` où chaque élément a un `group` (String, français : `Pectoraux`, `Dos`, `Épaules`, `Bras`, `Abdominaux`, `Jambes`) et une `intensity` (double, 0.0 à 1.0).

Échelle de couleur existante (à réutiliser depuis `AppColors`), NE PAS la redéfinir :
- intensity == 0 → `AppColors.muscleNone`
- intensity < 0.3 → `AppColors.muscleLow`
- intensity < 0.6 → `AppColors.muscleMedium`
- intensity < 0.85 → `AppColors.muscleHigh`
- intensity >= 0.85 → `AppColors.muscleMax`

## Objectif

Ajouter une **nouvelle vue 3D interactive et rotative** du corps musculaire, en complément (pas en remplacement) de la vue 2D existante. L'utilisateur doit pouvoir basculer entre les deux vues (ex. un toggle "2D / 3D" en haut de l'écran, ou deux onglets).

## Asset fourni

Un modèle 3D `.glb` a été préparé sur mesure dans Blender : `corps_fitforge.glb`, à placer dans `assets/models/corps_fitforge.glb`. Le modèle contient **12 objets/meshes séparés**, chacun avec son propre matériau nommé, prêts à être colorés indépendamment :

| Nom de l'objet Blender | Nom du matériau |
|---|---|
| `abs` | `mat_abs` |
| `avant_bras` | `mat_avant_bras` |
| `biceps` | `mat_biceps` |
| `corps_neutre` | `mat_corps` |
| `dos` | `mat_dos` |
| `epaule` | `mat_epaule` |
| `fessier` | `mat_fessier` |
| `hams` | `mat_hams` |
| `mollet` | `mat_mollet` |
| `pectoraux` | `mat_pectoraux` |
| `quads` | `mat_quads` |
| `triceps` | `mat_triceps` |

Le modèle est en pose "A" (bras légèrement écartés du corps), exporté depuis Blender en glTF Binary. Vérifie le nom exact des objets/nœuds une fois le `.glb` chargé dans l'app (le nom peut légèrement varier après export, ex. suffixes numériques) — inspecte la hiérarchie du fichier au runtime ou via un outil d'inspection glTF si besoin, ne suppose pas aveuglément que les noms sont identiques à 100% à cette table.

## Mapping groupes français → objets 3D

Certains groupes français couvrent plusieurs objets 3D (le modèle est plus détaillé que les 6 groupes de base) :

```dart
const Map<String, List<String>> muscleGroupTo3DObjects = {
  'Pectoraux': ['pectoraux'],
  'Dos': ['dos'],
  'Épaules': ['epaule'],
  'Bras': ['biceps', 'triceps', 'avant_bras'],
  'Abdominaux': ['abs'],
  'Jambes': ['quads', 'hams', 'mollet', 'fessier'],
};
```

L'objet `corps_neutre` (tête, cou, mains, pieds, tronc non musclé) reste **toujours** à `AppColors.muscleNone`, il n'est jamais coloré selon une intensité.

## Package à utiliser

**`interactive_3d`** (pub.dev) — rendu natif GLB/GLTF (Filament sur Android, SceneKit sur iOS), pas de WebView. Vérifie la dernière version stable et l'API réelle du package sur pub.dev et dans son code source une fois ajouté au projet (ne pas halluciner les noms de méthodes/paramètres — regarde la doc et les exemples officiels du package avant de coder).

## Étapes techniques attendues

1. **Ajouter la dépendance** dans `pubspec.yaml` :
   ```yaml
   interactive_3d: ^<dernière version stable>
   ```
   puis `flutter pub get`.

2. **Placer l'asset** :
   ```yaml
   flutter:
     assets:
       - assets/models/corps_fitforge.glb
   ```
   Le fichier `corps_fitforge.glb` doit être copié dans `assets/models/` (déjà fourni par l'utilisateur, ne pas le régénérer).

3. **Créer un fichier de mapping séparé** `lib/.../muscle_group_3d_mapper.dart` contenant :
   - La table `muscleGroupTo3DObjects` ci-dessus.
   - Une fonction qui, à partir d'un `List<MuscleIntensity>`, calcule une `Map<String, Color>` (nom d'objet 3D → couleur cible), en utilisant l'échelle de couleur existante de `AppColors`. Si un groupe français n'est pas trouvé dans la liste, ses objets restent à `AppColors.muscleNone`.

4. **Créer `Body3DWidget`** (nouveau fichier, ne pas modifier `Body2DWidget` existant) :
   - Widget stateful, prend `List<MuscleIntensity> intensities` en paramètre (même contrat que la version 2D).
   - Affiche le composant `Interactive3d` (ou équivalent exact selon l'API réelle du package) pointant vers `assets/models/corps_fitforge.glb`.
   - Rotation/zoom/pan **activés par défaut** (comportement natif du package — vérifier si c'est déjà le cas ou s'il faut l'activer explicitement).
   - **Auto-rotation lente** au chargement (2-3 secondes), qui s'arrête dès que l'utilisateur touche/interagit avec le modèle.
   - **Applique les couleurs** à chaque objet 3D selon la map calculée à l'étape 3, avec une **animation progressive** au chargement de l'écran : chaque couleur doit s'animer depuis `AppColors.muscleNone` vers sa couleur cible sur ~1000-1200ms avec `Curves.easeOutCubic` (utiliser un `AnimationController` qui pilote l'interpolation de couleur frame par frame, en appelant la méthode du package qui change la couleur d'un matériau/entité par son nom, à chaque tick).
   - **Interaction tap** : quand l'utilisateur tape une zone du modèle, afficher son nom (traduit en français, ex. "epaule" → "Épaules") et son intensité exacte en pourcentage, dans une bottom sheet légère ou un tooltip.
   - **Loader** : pendant le chargement du `.glb` (peut prendre 1-2s), afficher un indicateur de chargement (shimmer ou `CircularProgressIndicator` stylé selon la charte de l'app), jamais un écran vide.
   - **Fond** : dégradé sombre assorti à `AppColors` (pas de fond blanc par défaut), coins arrondis, cohérent visuellement avec le reste de l'app.
   - **Retour haptique léger** (`HapticFeedback.selectionClick()`) au tap sur une zone.
   - Gérer le cas `intensities` vide sans crash (tout reste en `muscleNone`).

5. **Toggle 2D/3D** : sur l'écran qui utilise actuellement `Body2DWidget`, ajoute un composant de bascule (ex. `SegmentedButton` ou deux `Tab`) "2D" / "3D" permettant d'afficher soit `Body2DWidget`, soit `Body3DWidget`, selon le choix de l'utilisateur. Mémorise le choix localement (ex. simple état local ou `SharedPreferences` si un mécanisme de préférences existe déjà dans le projet — vérifie avant d'en ajouter un nouveau).

6. **Éclairage** (optionnel mais recommandé si le temps le permet) : si le package `interactive_3d` supporte un paramètre d'image-based lighting (IBL) / skybox au format `.ktx`, prévoir la structure pour l'ajouter plus tard (`assets/models/studio_ibl.ktx`), mais ne bloque pas l'implémentation principale dessus si le fichier `.ktx` n'est pas encore fourni — dans ce cas utilise un éclairage/fond par défaut propre.

## Qualité de code attendue

- Dart idiomatique, null-safety strict, `flutter analyze` propre sans warning.
- Commentaires en français sur les parties non triviales (mapping, animation des couleurs par entité).
- Aucune régression sur `Body2DWidget` existant (fichier non modifié, sauf éventuellement l'écran parent qui ajoute le toggle).
- Si un nom d'objet du `.glb` ne correspond pas exactement à la table fournie une fois chargé dans l'app (suffixes, casse différente), adapte le mapping et **signale clairement** cette différence dans ta réponse plutôt que de la corriger silencieusement.

## Résultat attendu

Un écran 3D fluide, avec un vrai effet "premium" : rotation douce, couleurs qui s'animent à l'apparition, tap réactif avec retour haptique, aucun freeze au chargement du modèle. Fournis la liste exacte des fichiers créés/modifiés à la fin.

---

**Fin du prompt.**
