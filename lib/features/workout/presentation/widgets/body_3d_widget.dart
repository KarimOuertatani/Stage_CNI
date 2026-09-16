import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:interactive_3d/interactive_3d.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/muscle_catalog_3d.dart';
import '../../data/muscle_effort.dart';
import 'muscle_detail_sheet.dart';
import 'muscle_group_3d_mapper.dart';

/// Chemin du modèle anatomique (466 muscles, une entité + un matériau chacun).
const String _kModelPath = 'assets/models/fitforge_body.glb';

/// Nombre de muscles peints par appel natif.
///
/// Côté plugin, chaque entrée d'override déclenche un balayage des 466 entités
/// du modèle pour retrouver celle qui porte ce nom : le coût d'un appel est
/// donc proportionnel au nombre de muscles qu'il contient. Découper en lots
/// de cette taille garde chaque aller-retour court, quitte à en faire
/// plusieurs, plutôt que de bloquer le thread natif sur un lot géant.
const int _kPaintChunk = 24;

/// Nombre de paliers de couleur par lot durant une transition.
const int _kFadeSteps = 3;

/// Décalage entre deux lots pendant la séquence de révélation.
const Duration _kBatchStagger = Duration(milliseconds: 90);

/// Widget 3D interactif du corps musculaire — la fonctionnalité signature.
///
/// Rendu via [Interactive3d] (Filament sur Android, SceneKit sur iOS).
/// La rotation/zoom au toucher est gérée nativement par le moteur 3D.
///
/// ── Modèle ────────────────────────────────────────────────────────────
/// `fitforge_body.glb` est une planche anatomique : 466 muscles distincts,
/// nommés en latin anglicisé. Le catalogue (`muscle_catalog_3d.dart`) les
/// traduit et les rattache aux 6 groupes de l'app. Tous les muscles partent
/// au ton de repos ; seuls les **superficiels** portent la heatmap, les
/// muscles profonds étant masqués par les couches externes.
///
/// ── Stabilité (important) ─────────────────────────────────────────────
/// Le moteur Filament crashe si on le sature d'appels de matériaux. Les
/// règles de sûreté appliquées ici :
///  • **Aucun appel natif perpétuel** : les transitions de couleur sont
///    bornées dans le temps (~700 ms puis STOP). Le pulse "vivant" est fait
///    100 % côté Flutter (halo lumineux), donc zéro appel natif continu.
///  • Les couleurs sont poussées **par lot de [_kPaintChunk] muscles et par
///    groupe**, en [_kFadeSteps] paliers : le nombre total d'allers-retours
///    natifs reste du même ordre qu'avec l'ancien modèle à 11 zones, malgré
///    les 466 muscles.
///  • Le glow émissif des zones travaillées est **posé une seule fois** par
///    changement de données, jamais rafraîchi frame par frame.
///  • [_disposed] bloque tout appel natif après démontage (empêche le
///    use-after-free natif quand on quitte l'écran pendant une transition).
///  • [_fxHealthy] coupe tous les effets à la première erreur plateforme ;
///    le modèle reste affiché avec ses couleurs.
class Body3DWidget extends StatefulWidget {
  /// Charge par muscle : c'est elle qui pilote la couleur, muscle par muscle.
  final MuscleEffort effort;
  final double height;

  const Body3DWidget({super.key, required this.effort, this.height = 520});

  @override
  State<Body3DWidget> createState() => _Body3DWidgetState();
}

/// Un palier de couleur à pousser à un instant donné de la transition.
class _PaintEvent {
  final int atMs;
  final int batchIndex;
  final double progress;

  const _PaintEvent(this.atMs, this.batchIndex, this.progress);
}

class _Body3DWidgetState extends State<Body3DWidget>
    with SingleTickerProviderStateMixin {
  final Interactive3dController _controller = Interactive3dController();

  // ── Cycle de vie ──────────────────────────────────────────────
  bool _disposed = false;
  bool _modelReady = false;
  Timer? _loadTimer;

  // ── Couleurs / transition ─────────────────────────────────────
  /// Couleur actuellement appliquée à **chaque muscle coloré** (source de
  /// vérité côté Flutter). Chaque muscle porte sa propre charge, donc sa
  /// propre couleur : on ne peut plus raisonner par groupe.
  late Map<String, Color> _currentColors;

  /// Ton de repos des 466 muscles, poussé une seule fois au chargement.
  late final List<MaterialOverride> _restingOverrides = [
    for (final name in kAllMuscleNodes3D)
      MaterialOverride(
        name: name,
        color: colorToRgba(restingColorFor3D(name)),
        roughness: _neutralRoughness,
        metallic: 0.0,
      ),
  ];

  /// Jeton d'annulation : incrémenté à chaque transition ; les boucles en
  /// cours s'arrêtent dès qu'il change.
  int _transitionToken = 0;

  /// Kill switch : coupé à la première erreur du canal plateforme.
  bool _fxHealthy = true;

  // ── Pulse d'ambiance (100 % Flutter) ──────────────────────────
  late final AnimationController _glowCtrl;

  // ── HUD ───────────────────────────────────────────────────────
  /// Cadrage d'ouverture : corps entier visible, tête et pieds compris.
  /// Le moteur cadre sur la plus grande dimension de la boîte englobante (la
  /// hauteur), donc au-delà de ~2,2 les extrémités sortent du cadre.
  double _currentZoom = 2.1;
  bool _hintVisible = true;
  Timer? _hintTimer;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const _neutralRoughness = 0.78;
  static const _activeRoughness = 0.5;

  /// Couleur d'ambiance = muscle le plus travaillé (pour le halo Flutter).
  Color get _ambientColor =>
      colorFromIntensitySmooth(widget.effort.peakIntensity);

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _currentColors = {
      for (final node in kHeatmapNodesTopDown) node: AppColors.muscleNone,
    };
    if (!_isMobile) return;

    // Le package ne fournit pas de callback "model loaded" : on estime le
    // temps de chargement du GLB puis on lance la séquence de révélation.
    // 7 Mo et 466 entités à mettre au ton de repos : compter plus large que
    // pour l'ancien modèle.
    _loadTimer = Timer(const Duration(milliseconds: 3200), _onModelReady);
    _hintTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  @override
  void didUpdateWidget(covariant Body3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isMobile || !_modelReady) return;
    if (!identical(oldWidget.effort, widget.effort)) {
      _animateColorsTo(
        buildMuscle3DColorMap(widget.effort),
        duration: const Duration(milliseconds: 700),
      );
    }
  }

  @override
  void dispose() {
    // Bloque tout appel natif AVANT de démonter l'Interactive3d enfant.
    _disposed = true;
    _transitionToken++;
    _loadTimer?.cancel();
    _hintTimer?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────
  // Effets dynamiques (bornés)
  // ────────────────────────────────────────────────────────────────

  void _onModelReady() {
    if (!mounted || _disposed) return;
    setState(() => _modelReady = true);
    HapticFeedback.lightImpact();
    _playRevealSequence();
  }

  /// Séquence d'entrée : scan du haut du corps vers le bas, chaque lot de
  /// muscles s'illumine avec un léger décalage. Bornée dans le temps puis STOP.
  Future<void> _playRevealSequence() => _animateColorsTo(
    buildMuscle3DColorMap(widget.effort),
    duration: const Duration(milliseconds: 420),
    staggered: true,
  );

  /// Relance la séquence de révélation (bouton replay du HUD).
  Future<void> _replayReveal() async {
    if (!_fxHealthy || !_modelReady || _disposed) return;
    HapticFeedback.mediumImpact();
    await _animateColorsTo({
      for (final node in kHeatmapNodesTopDown) node: AppColors.muscleNone,
    }, duration: const Duration(milliseconds: 220));
    await _playRevealSequence();
  }

  /// Anime la couleur de chaque **muscle** de [_currentColors] vers [target].
  ///
  /// Seuls les muscles dont la couleur change émettent des appels natifs :
  /// après une séance de biceps, quatre entités bougent, pas cent-vingt-huit.
  /// Ils sont découpés en lots de [_kPaintChunk] et poussés en [_kFadeSteps]
  /// paliers. Avec [staggered], les lots démarrent en cascade — la liste étant
  /// triée par hauteur réelle du muscle, la vague descend le corps.
  /// Le glow émissif est posé UNE fois, au dernier palier.
  Future<void> _animateColorsTo(
    Map<String, Color> target, {
    required Duration duration,
    bool staggered = false,
  }) async {
    if (!_fxHealthy || _disposed) return;
    final token = ++_transitionToken;

    final changed = [
      for (final node in kHeatmapNodesTopDown)
        if (target[node] != _currentColors[node]) node,
    ];
    if (changed.isEmpty) return;

    final from = {for (final node in changed) node: _currentColors[node]!};
    final batches = [
      for (var i = 0; i < changed.length; i += _kPaintChunk)
        changed.sublist(i, math.min(i + _kPaintChunk, changed.length)),
    ];

    final events = <_PaintEvent>[];
    for (var b = 0; b < batches.length; b++) {
      final delay = staggered ? b * _kBatchStagger.inMilliseconds : 0;
      for (var s = 1; s <= _kFadeSteps; s++) {
        final at = delay + (duration.inMilliseconds * s / _kFadeSteps).round();
        events.add(_PaintEvent(at, b, s / _kFadeSteps));
      }
    }
    events.sort((a, b) => a.atMs.compareTo(b.atMs));

    // Horloge réelle : les allers-retours natifs prennent du temps, et se
    // rattacher au temps nominal ferait glisser toute la cascade.
    final clock = Stopwatch()..start();
    for (final event in events) {
      final wait = event.atMs - clock.elapsedMilliseconds;
      if (wait > 0) await Future.delayed(Duration(milliseconds: wait));
      if (!mounted || _disposed || token != _transitionToken) return;

      final progress = Curves.easeOutCubic.transform(event.progress);
      final last = event.progress >= 1.0;
      final overrides = <MaterialOverride>[];

      for (final node in batches[event.batchIndex]) {
        final goal = target[node]!;
        final color = Color.lerp(from[node], goal, progress)!;
        // L'intensité se lit sur la couleur visée, pas sur les données :
        // pendant la remise à neutre du bouton replay, un muscle travaillé
        // doit bien repasser par un état de repos complet.
        final intensity = goal == AppColors.muscleNone
            ? 0.0
            : intensityForObject3D(node, widget.effort);
        // Glow émissif doux, proportionnel à l'intensité, non pulsé.
        final glow = last && intensity >= 0.4 ? 0.18 * intensity : 0.0;

        overrides.add(
          MaterialOverride(
            name: node,
            // Au repos, on rend à chaque muscle son ton propre : sans ça, une
            // zone qui redevient inactive s'aplatit en une teinte unique et
            // perd le relief anatomique posé au chargement.
            color: colorToRgba(
              last && intensity == 0 ? restingColorFor3D(node) : color,
            ),
            roughness: intensity > 0 ? _activeRoughness : _neutralRoughness,
            metallic: 0.0,
            emissive: last ? colorToEmissive(color, glow) : null,
          ),
        );
        _currentColors[node] = last ? goal : color;
      }

      if (!await _safeApply(overrides)) return;
    }
  }

  /// Applique un batch de matériaux ; coupe les effets à la première erreur
  /// et ne touche jamais le natif après démontage.
  Future<bool> _safeApply(List<MaterialOverride> batch) async {
    if (_disposed || !_fxHealthy) return false;
    try {
      await _controller.setEntityMaterials(batch);
      return !_disposed;
    } catch (e) {
      debugPrint('Body3D: effets dynamiques désactivés ($e)');
      _fxHealthy = false;
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Interactions
  // ────────────────────────────────────────────────────────────────

  void _setZoom(double next) {
    final clamped = next.clamp(0.9, 5.0);
    if (clamped == _currentZoom || _disposed) return;
    HapticFeedback.selectionClick();
    setState(() => _currentZoom = clamped);
    try {
      _controller.setCameraZoomLevel(clamped);
    } catch (_) {}
  }

  Future<void> _onEntityTapped(List<EntityData> entities) async {
    if (entities.isEmpty || _disposed) return;

    // Chaque entité du modèle est un muscle : le nom brut est anatomique
    // (`long_head_of_biceps_brachii_r`), le catalogue le traduit.
    final objectName = entities.first.name;
    HapticFeedback.mediumImpact();
    final muscle = muscle3DFor(objectName);
    final intensity = intensityForObject3D(objectName, widget.effort);

    if (!mounted) return;
    await showMuscleDetailSheet(
      context,
      muscleName: frenchNameFor3D(objectName),
      groupName: groupLabelFor3D(objectName),
      intensity: intensity,
      trainable: muscle?.group != null,
    );
    if (_disposed) return;
    try {
      await _controller.clearSelections();
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────

  List<double> get _sceneBackground => AppColors.isDark
      ? const [0.028, 0.043, 0.094, 1.0]
      : const [0.918, 0.925, 0.965, 1.0];

  @override
  Widget build(BuildContext context) {
    if (!_isMobile) return _DesktopFallback(height: widget.height);

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (context, child) {
          // Halo de bordure qui respire, teinté par la zone la plus active.
          final wave = 0.5 + 0.5 * math.sin(_glowCtrl.value * math.pi);
          final ambient = _ambientColor;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Color.lerp(
                  AppColors.border,
                  ambient.withValues(alpha: 0.5),
                  _modelReady ? wave : 0.0,
                )!,
              ),
              boxShadow: [
                BoxShadow(
                  color: ambient.withValues(
                    alpha: (_modelReady ? 0.22 : 0.10) * (0.4 + 0.6 * wave),
                  ),
                  blurRadius: 34,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Moteur 3D plein cadre ────────────────────────────
              Positioned.fill(
                child: Interactive3d(
                  controller: _controller,
                  modelPath: _kModelPath,
                  solidBackgroundColor: _sceneBackground,
                  defaultZoom: _currentZoom,
                  selectionColor: const [0.45, 0.85, 1.0, 0.85],
                  onSelectionChanged: _onEntityTapped,
                  initialMaterialOverrides: _restingOverrides,
                  backgroundColor: AppColors.isDark
                      ? const Color(0xFF070B18)
                      : const Color(0xFFEAECF6),
                  loadingWidget: const SizedBox.shrink(),
                ),
              ),

              // ── Vignette + glow de sol (laissent passer le toucher) ─
              const IgnorePointer(child: _SceneOverlays()),

              // ── Voile de chargement ──────────────────────────────
              _LoadingVeil(visible: !_modelReady),

              // ── HUD : hint d'usage, puis signature du modèle ─────
              // Un seul emplacement pour les deux : côte à côte ils ne
              // tiendraient pas sur un écran étroit.
              if (_modelReady)
                Positioned(
                  top: 14,
                  left: 14,
                  child: IgnorePointer(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, -0.35),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _hintVisible
                          ? const _HudChip(
                              key: ValueKey('hint'),
                              icon: Icons.threed_rotation_rounded,
                              label: 'Pivotez • Touchez un muscle',
                            )
                          : _HudChip(
                              key: const ValueKey('count'),
                              icon: Icons.biotech_rounded,
                              label: '${kAllMuscleNodes3D.length} muscles',
                            ),
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.15),
                ),

              // ── HUD : contrôles zoom / replay ────────────────────
              if (_modelReady)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child:
                      Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _HudButton(
                                  icon: Icons.add_rounded,
                                  tooltip: 'Zoom avant',
                                  onTap: () => _setZoom(_currentZoom + 0.3),
                                ),
                                const SizedBox(height: 10),
                                _HudButton(
                                  icon: Icons.remove_rounded,
                                  tooltip: 'Zoom arrière',
                                  onTap: () => _setZoom(_currentZoom - 0.3),
                                ),
                                const SizedBox(height: 10),
                                _HudButton(
                                  icon: Icons.replay_rounded,
                                  tooltip: 'Rejouer l\'animation',
                                  onTap: _replayReveal,
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 500.ms)
                          .slideX(begin: 0.2),
                ),

              // ── HUD : légende heatmap ────────────────────────────
              if (_modelReady)
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(child: Center(child: _HeatmapLegend()))
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 600.ms)
                      .slideY(begin: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlays de scène (vignette, glow de sol)
// ─────────────────────────────────────────────────────────────────────────────

class _SceneOverlays extends StatelessWidget {
  const _SceneOverlays();

  @override
  Widget build(BuildContext context) {
    final edge = AppColors.isDark ? Colors.black : const Color(0xFFD6DAEB);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Colors.transparent,
                Colors.transparent,
                edge.withValues(alpha: AppColors.isDark ? 0.55 : 0.45),
              ],
              stops: const [0.0, 0.72, 1.0],
              radius: 1.1,
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1.4),
                radius: 1.6,
                colors: [
                  AppColors.primary.withValues(
                    alpha: AppColors.isDark ? 0.16 : 0.10,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 90,
            margin: const EdgeInsets.only(bottom: 30),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 1),
                radius: 1.2,
                colors: [
                  AppColors.accent.withValues(
                    alpha: AppColors.isDark ? 0.10 : 0.08,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voile de chargement
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingVeil extends StatelessWidget {
  final bool visible;
  const _LoadingVeil({required this.visible});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(gradient: AppColors.darkGradient),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                      Icons.accessibility_new_rounded,
                      size: 72,
                      color: AppColors.primary.withValues(alpha: 0.5),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.94, 0.94),
                      end: const Offset(1.04, 1.04),
                      duration: 900.ms,
                      curve: Curves.easeInOut,
                    )
                    .shimmer(duration: 1400.ms, color: AppColors.accent),
                const SizedBox(height: 20),
                Text(
                  'Préparation du modèle 3D…',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Éléments HUD
// ─────────────────────────────────────────────────────────────────────────────

class _HudChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HudChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.accentText),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HudButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HudButton> createState() => _HudButtonState();
}

class _HudButtonState extends State<_HudButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.88),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: AppColors.isDark ? 0.30 : 0.10,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 22, color: AppColors.primaryText),
          ),
        ),
      ),
    );
  }
}

/// Légende compacte de la heatmap (gradient continu Repos → Max).
class _HeatmapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Repos',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 110,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                colors: [
                  AppColors.muscleNone,
                  AppColors.muscleLow,
                  AppColors.muscleMedium,
                  AppColors.muscleHigh,
                  AppColors.muscleMax,
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Max',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback Desktop / Web
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopFallback extends StatelessWidget {
  final double height;
  const _DesktopFallback({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        gradient: AppColors.darkGradient,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.view_in_ar_rounded,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.06, 1.06),
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 24),
              Text(
                'Expérience 3D disponible sur mobile',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Le modèle 3D interactif (rotation, zoom, zones tactiles) '
                'est optimisé pour Android et iOS.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swipe_left_alt_rounded,
                      size: 16,
                      color: AppColors.accentText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Basculez sur la vue 2D pour continuer ici',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
