# Référence des muscles du modèle 3D

Ce fichier liste chaque muscle du modèle, son matériau associé
(à cibler pour la coloration selon l'effort) et son groupe anatomique.

**Nombre total de muscles : 467**

## Convention de coloration

Pour colorer un muscle sollicité par un exercice, l'agent doit
modifier la couleur du matériau (`Nom du matériau` ci-dessous),
PAS créer de nouveau matériau ni toucher au mesh.

## Notes d'intégration FitForge

Écarts entre ce document et ce que consomme l'app :

- **On cible le nom d'objet, pas le nom de matériau.** Le plugin
  `interactive_3d` résout les overrides par nom d'**entité** (`Nom objet`
  ci-dessous). Comme le modèle a exactement un matériau par muscle, le
  résultat est identique : seul le muscle visé change de couleur.
- **Les nœuds d'annotation Z-Anatomy ont disparu.** La première version du GLB
  contenait 5 libellés de texte (`Muscular system.g`, `Cranial part of muscular
  system.g`, `Muscles of head.g`, `Superficial muscles of head.g`, `Epicranius
  muscle.g`) qui flottaient à côté du corps et décentraient la boîte englobante
  dont Filament se sert pour cadrer la caméra (centre décalé de 0,43 sur X).
  Ils ont été retirés à la source, dans Blender.
- **Le fichier courant compte 466 entités**, et non les 467 annoncées ci-dessus
  : les 464 muscles plus les deux `Epicranial aponeurosis` (matériau `Tendon`,
  et non `mat_*`), désormais posées sur le crâne au lieu d'être suspendues
  au-dessus. Bounding box centrée sur (0 ; 0,856 ; 0), demi-étendue
  (0,33 ; 0,856 ; 0,129).
- **Deux conventions de côté coexistent** : les muscles suffixent en `_l` /
  `_r`, les aponévroses en `.l` / `.r`. Le résolveur de noms absorbe les deux.

Le rattachement de chaque muscle aux 6 groupes de l'app (nom français, région,
caractère superficiel) vit dans `muscle_catalog_3d.dart`, généré par
`scripts/gen_muscle_catalog_3d.py` — qui relit les noms directement dans le GLB
et échoue si le catalogue et le modèle divergent.

## Groupe : abdomen (18 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Ary epiglottic part of oblique arytenoid muscle | `ary_epiglottic_part_of_oblique_arytenoid_muscle_l` | `mat_ary_epiglottic_part_of_oblique_arytenoid_muscle_l.001` | gauche |
| Ary epiglottic part of oblique arytenoid muscle | `ary_epiglottic_part_of_oblique_arytenoid_muscle_r` | `mat_ary_epiglottic_part_of_oblique_arytenoid_muscle_r.001` | droite |
| External abdominal oblique muscle | `external_abdominal_oblique_muscle_l` | `mat_external_abdominal_oblique_muscle_l.001` | gauche |
| External abdominal oblique muscle | `external_abdominal_oblique_muscle_r` | `mat_external_abdominal_oblique_muscle_r.001` | droite |
| Inferior oblique muscle | `inferior_oblique_muscle_l` | `mat_inferior_oblique_muscle_l.001` | gauche |
| Inferior oblique muscle | `inferior_oblique_muscle_r` | `mat_inferior_oblique_muscle_r.001` | droite |
| Internal abdominal oblique muscle | `internal_abdominal_oblique_muscle_l` | `mat_internal_abdominal_oblique_muscle_l.001` | gauche |
| Internal abdominal oblique muscle | `internal_abdominal_oblique_muscle_r` | `mat_internal_abdominal_oblique_muscle_r.001` | droite |
| Oblique head of adductor hallucis | `oblique_head_of_adductor_hallucis_l` | `mat_oblique_head_of_adductor_hallucis_l.001` | gauche |
| Oblique head of adductor hallucis | `oblique_head_of_adductor_hallucis_r` | `mat_oblique_head_of_adductor_hallucis_r.001` | droite |
| Oblique part of cricothyroid muscle | `oblique_part_of_cricothyroid_muscle_l` | `mat_oblique_part_of_cricothyroid_muscle_l.001` | gauche |
| Oblique part of cricothyroid muscle | `oblique_part_of_cricothyroid_muscle_r` | `mat_oblique_part_of_cricothyroid_muscle_r.001` | droite |
| Rectus abdominis muscle | `rectus_abdominis_muscle_l` | `mat_rectus_abdominis_muscle_l.001` | gauche |
| Rectus abdominis muscle | `rectus_abdominis_muscle_r` | `mat_rectus_abdominis_muscle_r.001` | droite |
| Superior oblique muscle | `superior_oblique_muscle_l` | `mat_superior_oblique_muscle_l.001` | gauche |
| Superior oblique muscle | `superior_oblique_muscle_r` | `mat_superior_oblique_muscle_r.001` | droite |
| Transversus abdominis muscle | `transversus_abdominis_muscle_l` | `mat_transversus_abdominis_muscle_l.001` | gauche |
| Transversus abdominis muscle | `transversus_abdominis_muscle_r` | `mat_transversus_abdominis_muscle_r.001` | droite |

## Groupe : back (24 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Dorsal parts ofateral intertransversariiumborum muscles | `dorsal_parts_of_lateral_intertransversarii_lumborum_muscles_l` | `mat_dorsal_parts_of_lateral_intertransversarii_lumborum_mus.001` | gauche |
| Dorsal parts ofateral intertransversariiumborum muscles | `dorsal_parts_of_lateral_intertransversarii_lumborum_muscles_r` | `mat_dorsal_parts_of_lateral_intertransversarii_lumborum_mus.002` | droite |
| Iliocostalis colli muscle | `iliocostalis_colli_muscle_l` | `mat_iliocostalis_colli_muscle_l.001` | gauche |
| Iliocostalis colli muscle | `iliocostalis_colli_muscle_r` | `mat_iliocostalis_colli_muscle_r.001` | droite |
| Iliocostalisumborum muscle | `iliocostalis_lumborum_muscle_l` | `mat_iliocostalis_lumborum_muscle_l.001` | gauche |
| Iliocostalisumborum muscle | `iliocostalis_lumborum_muscle_r` | `mat_iliocostalis_lumborum_muscle_r.001` | droite |
| Iliocostalis thoracis muscle | `iliocostalis_thoracis_muscle_l` | `mat_iliocostalis_thoracis_muscle_l.001` | gauche |
| Iliocostalis thoracis muscle | `iliocostalis_thoracis_muscle_r` | `mat_iliocostalis_thoracis_muscle_r.001` | droite |
| Latissimus dorsi muscle | `latissimus_dorsi_muscle_l` | `mat_latissimus_dorsi_muscle_l.001` | gauche |
| Latissimus dorsi muscle | `latissimus_dorsi_muscle_r` | `mat_latissimus_dorsi_muscle_r.001` | droite |
| Longissimus capitis muscle | `longissimus_capitis_muscle_l` | `mat_longissimus_capitis_muscle_l.001` | gauche |
| Longissimus capitis muscle | `longissimus_capitis_muscle_r` | `mat_longissimus_capitis_muscle_r.001` | droite |
| Longissimus colli muscle | `longissimus_colli_muscle_l` | `mat_longissimus_colli_muscle_l.001` | gauche |
| Longissimus colli muscle | `longissimus_colli_muscle_r` | `mat_longissimus_colli_muscle_r.001` | droite |
| Longissimus thoracis muscle | `longissimus_thoracis_muscle_l` | `mat_longissimus_thoracis_muscle_l.001` | gauche |
| Longissimus thoracis muscle | `longissimus_thoracis_muscle_r` | `mat_longissimus_thoracis_muscle_r.001` | droite |
| Multifidus colli muscle | `multifidus_colli_muscle_l` | `mat_multifidus_colli_muscle_l.001` | gauche |
| Multifidus colli muscle | `multifidus_colli_muscle_r` | `mat_multifidus_colli_muscle_r.001` | droite |
| Multifidusumborum muscle | `multifidus_lumborum_muscle_l` | `mat_multifidus_lumborum_muscle_l.001` | gauche |
| Multifidusumborum muscle | `multifidus_lumborum_muscle_r` | `mat_multifidus_lumborum_muscle_r.001` | droite |
| Multifidus thoracis muscle | `multifidus_thoracis_muscle_l` | `mat_multifidus_thoracis_muscle_l.001` | gauche |
| Multifidus thoracis muscle | `multifidus_thoracis_muscle_r` | `mat_multifidus_thoracis_muscle_r.001` | droite |
| Ventral parts ofateral intertransversariiumborum muscles | `ventral_parts_of_lateral_intertransversarii_lumborum_muscles_l` | `mat_ventral_parts_of_lateral_intertransversarii_lumborum_mu.001` | gauche |
| Ventral parts ofateral intertransversariiumborum muscles | `ventral_parts_of_lateral_intertransversarii_lumborum_muscles_r` | `mat_ventral_parts_of_lateral_intertransversarii_lumborum_mu.002` | droite |

## Groupe : chest (10 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Abdominal part of pectoralis major muscle | `abdominal_part_of_pectoralis_major_muscle_l` | `mat_abdominal_part_of_pectoralis_major_muscle_l.001` | gauche |
| Abdominal part of pectoralis major muscle | `abdominal_part_of_pectoralis_major_muscle_r` | `mat_abdominal_part_of_pectoralis_major_muscle_r.001` | droite |
| Clavicular head of pectoralis major muscle | `clavicular_head_of_pectoralis_major_muscle_l` | `mat_clavicular_head_of_pectoralis_major_muscle_l.001` | gauche |
| Clavicular head of pectoralis major muscle | `clavicular_head_of_pectoralis_major_muscle_r` | `mat_clavicular_head_of_pectoralis_major_muscle_r.001` | droite |
| Pectoralis minor muscle | `pectoralis_minor_muscle_l` | `mat_pectoralis_minor_muscle_l.001` | gauche |
| Pectoralis minor muscle | `pectoralis_minor_muscle_r` | `mat_pectoralis_minor_muscle_r.001` | droite |
| Serratus anterior muscle | `serratus_anterior_muscle_l` | `mat_serratus_anterior_muscle_l.001` | gauche |
| Serratus anterior muscle | `serratus_anterior_muscle_r` | `mat_serratus_anterior_muscle_r.001` | droite |
| Sternocostal head of pectoralis major muscle | `sternocostal_head_of_pectoralis_major_muscle_l` | `mat_sternocostal_head_of_pectoralis_major_muscle_l.001` | gauche |
| Sternocostal head of pectoralis major muscle | `sternocostal_head_of_pectoralis_major_muscle_r` | `mat_sternocostal_head_of_pectoralis_major_muscle_r.001` | droite |

## Groupe : face (44 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Corrugator supercilii | `corrugator_supercilii_l` | `mat_corrugator_supercilii_l.001` | gauche |
| Corrugator supercilii | `corrugator_supercilii_r` | `mat_corrugator_supercilii_r.001` | droite |
| Deep part of masseter | `deep_part_of_masseter_l` | `mat_deep_part_of_masseter_l.001` | gauche |
| Deep part of masseter | `deep_part_of_masseter_r` | `mat_deep_part_of_masseter_r.001` | droite |
| Depressor anguli oris | `depressor_anguli_oris_l` | `mat_depressor_anguli_oris_l.001` | gauche |
| Depressor anguli oris | `depressor_anguli_oris_r` | `mat_depressor_anguli_oris_r.001` | droite |
| Depressorabii inferioris | `depressor_labii_inferioris_l` | `mat_depressor_labii_inferioris_l.001` | gauche |
| Depressorabii inferioris | `depressor_labii_inferioris_r` | `mat_depressor_labii_inferioris_r.001` | droite |
| Depressor septi nasi | `depressor_septi_nasi_l` | `mat_depressor_septi_nasi_l.001` | gauche |
| Depressor septi nasi | `depressor_septi_nasi_r` | `mat_depressor_septi_nasi_r.001` | droite |
| Frontalis muscle.001 | `frontalis_muscle_l.001` | `mat_frontalis_muscle_l.001` | — |
| Frontalis muscle 2 | `frontalis_muscle_l_2` | `mat_frontalis_muscle_l_2` | gauche |
| Frontalis muscle.001 | `frontalis_muscle_r.001` | `mat_frontalis_muscle_r.001` | — |
| Frontalis muscle 2 | `frontalis_muscle_r_2` | `mat_frontalis_muscle_r_2` | droite |
| Levator anguli oris | `levator_anguli_oris_l` | `mat_levator_anguli_oris_l.001` | gauche |
| Levator anguli oris | `levator_anguli_oris_r` | `mat_levator_anguli_oris_r.001` | droite |
| Levatorabii superioris | `levator_labii_superioris_l` | `mat_levator_labii_superioris_l.001` | gauche |
| Levatorabii superioris | `levator_labii_superioris_r` | `mat_levator_labii_superioris_r.001` | droite |
| Mentalis muscle | `mentalis_muscle_l` | `mat_mentalis_muscle_l.001` | gauche |
| Mentalis muscle | `mentalis_muscle_r` | `mat_mentalis_muscle_r.001` | droite |
| Nasalis muscle | `nasalis_muscle_l` | `mat_nasalis_muscle_l.001` | gauche |
| Nasalis muscle | `nasalis_muscle_r` | `mat_nasalis_muscle_r.001` | droite |
| Occipitalis muscle | `occipitalis_muscle_l` | `mat_occipitalis_muscle_l.001` | gauche |
| Occipitalis muscle | `occipitalis_muscle_r` | `mat_occipitalis_muscle_r.001` | droite |
| Orbicularis oris muscle | `orbicularis_oris_muscle_l` | `mat_orbicularis_oris_muscle_l.001` | gauche |
| Orbicularis oris muscle | `orbicularis_oris_muscle_r` | `mat_orbicularis_oris_muscle_r.001` | droite |
| Orbital part of orbicularis oculi | `orbital_part_of_orbicularis_oculi_l` | `mat_orbital_part_of_orbicularis_oculi_l.001` | gauche |
| Orbital part of orbicularis oculi | `orbital_part_of_orbicularis_oculi_r` | `mat_orbital_part_of_orbicularis_oculi_r.001` | droite |
| Palpebral part of orbicularis oculi | `palpebral_part_of_orbicularis_oculi_l` | `mat_palpebral_part_of_orbicularis_oculi_l.001` | gauche |
| Palpebral part of orbicularis oculi | `palpebral_part_of_orbicularis_oculi_r` | `mat_palpebral_part_of_orbicularis_oculi_r.001` | droite |
| Procerus muscle | `procerus_muscle_l` | `mat_procerus_muscle_l.001` | gauche |
| Procerus muscle | `procerus_muscle_r` | `mat_procerus_muscle_r.001` | droite |
| Risorius muscle | `risorius_muscle_l` | `mat_risorius_muscle_l.001` | gauche |
| Risorius muscle | `risorius_muscle_r` | `mat_risorius_muscle_r.001` | droite |
| Superficial part of masseter | `superficial_part_of_masseter_l` | `mat_superficial_part_of_masseter_l.001` | gauche |
| Superficial part of masseter | `superficial_part_of_masseter_r` | `mat_superficial_part_of_masseter_r.001` | droite |
| Temporalis muscle.001 | `temporalis_muscle_l.001` | `mat_temporalis_muscle_l.001` | — |
| Temporalis muscle 2 | `temporalis_muscle_l_2` | `mat_temporalis_muscle_l_2` | gauche |
| Temporalis muscle.001 | `temporalis_muscle_r.001` | `mat_temporalis_muscle_r.001` | — |
| Temporalis muscle 2 | `temporalis_muscle_r_2` | `mat_temporalis_muscle_r_2` | droite |
| Zygomaticus major muscle | `zygomaticus_major_muscle_l` | `mat_zygomaticus_major_muscle_l.001` | gauche |
| Zygomaticus major muscle | `zygomaticus_major_muscle_r` | `mat_zygomaticus_major_muscle_r.001` | droite |
| Zygomaticus minor muscle | `zygomaticus_minor_muscle_l` | `mat_zygomaticus_minor_muscle_l.001` | gauche |
| Zygomaticus minor muscle | `zygomaticus_minor_muscle_r` | `mat_zygomaticus_minor_muscle_r.001` | droite |

## Groupe : foot (18 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Abductor digiti minimi of foot | `abductor_digiti_minimi_of_foot_l` | `mat_abductor_digiti_minimi_of_foot_l.001` | gauche |
| Abductor digiti minimi of foot | `abductor_digiti_minimi_of_foot_r` | `mat_abductor_digiti_minimi_of_foot_r.001` | droite |
| Abductor hallucis | `abductor_hallucis_l` | `mat_abductor_hallucis_l.001` | gauche |
| Abductor hallucis | `abductor_hallucis_r` | `mat_abductor_hallucis_r.001` | droite |
| Extensor hallucis brevis | `extensor_hallucis_brevis_l` | `mat_extensor_hallucis_brevis_l.001` | gauche |
| Extensor hallucis brevis | `extensor_hallucis_brevis_r` | `mat_extensor_hallucis_brevis_r.001` | droite |
| Extensor hallucisongus | `extensor_hallucis_longus_l` | `mat_extensor_hallucis_longus_l.001` | gauche |
| Extensor hallucisongus | `extensor_hallucis_longus_r` | `mat_extensor_hallucis_longus_r.001` | droite |
| Flexor digiti minimi of foot | `flexor_digiti_minimi_of_foot_l` | `mat_flexor_digiti_minimi_of_foot_l.001` | gauche |
| Flexor digiti minimi of foot | `flexor_digiti_minimi_of_foot_r` | `mat_flexor_digiti_minimi_of_foot_r.001` | droite |
| Flexor hallucisongus | `flexor_hallucis_longus_l` | `mat_flexor_hallucis_longus_l.001` | gauche |
| Flexor hallucisongus | `flexor_hallucis_longus_r` | `mat_flexor_hallucis_longus_r.001` | droite |
| Lateral head of flexor hallucis brevis | `lateral_head_of_flexor_hallucis_brevis_l` | `mat_lateral_head_of_flexor_hallucis_brevis_l.001` | gauche |
| Lateral head of flexor hallucis brevis | `lateral_head_of_flexor_hallucis_brevis_r` | `mat_lateral_head_of_flexor_hallucis_brevis_r.001` | droite |
| Medial head of flexor hallucis brevis | `medial_head_of_flexor_hallucis_brevis_l` | `mat_medial_head_of_flexor_hallucis_brevis_l.001` | gauche |
| Medial head of flexor hallucis brevis | `medial_head_of_flexor_hallucis_brevis_r` | `mat_medial_head_of_flexor_hallucis_brevis_r.001` | droite |
| Opponens digiti minimi muscle of foot | `opponens_digiti_minimi_muscle_of_foot_l` | `mat_opponens_digiti_minimi_muscle_of_foot_l.001` | gauche |
| Opponens digiti minimi muscle of foot | `opponens_digiti_minimi_muscle_of_foot_r` | `mat_opponens_digiti_minimi_muscle_of_foot_r.001` | droite |

## Groupe : forearm (42 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Anconeus muscle | `anconeus_muscle_l` | `mat_anconeus_muscle_l.001` | gauche |
| Anconeus muscle | `anconeus_muscle_r` | `mat_anconeus_muscle_r.001` | droite |
| Brachioradialis muscle | `brachioradialis_muscle_l` | `mat_brachioradialis_muscle_l.001` | gauche |
| Brachioradialis muscle | `brachioradialis_muscle_r` | `mat_brachioradialis_muscle_r.001` | droite |
| Deep head of pronator teres | `deep_head_of_pronator_teres_l` | `mat_deep_head_of_pronator_teres_l.001` | gauche |
| Deep head of pronator teres | `deep_head_of_pronator_teres_r` | `mat_deep_head_of_pronator_teres_r.001` | droite |
| Extensor carpiadialis brevis | `extensor_carpi_radialis_brevis_l` | `mat_extensor_carpi_radialis_brevis_l.001` | gauche |
| Extensor carpiadialis brevis | `extensor_carpi_radialis_brevis_r` | `mat_extensor_carpi_radialis_brevis_r.001` | droite |
| Extensor carpiadialisongus | `extensor_carpi_radialis_longus_l` | `mat_extensor_carpi_radialis_longus_l.001` | gauche |
| Extensor carpiadialisongus | `extensor_carpi_radialis_longus_r` | `mat_extensor_carpi_radialis_longus_r.001` | droite |
| Extensor digitorum brevis | `extensor_digitorum_brevis_l` | `mat_extensor_digitorum_brevis_l.001` | gauche |
| Extensor digitorum brevis | `extensor_digitorum_brevis_r` | `mat_extensor_digitorum_brevis_r.001` | droite |
| Extensor digitorum | `extensor_digitorum_l` | `mat_extensor_digitorum_l.001` | gauche |
| Extensor digitorumongus | `extensor_digitorum_longus_l` | `mat_extensor_digitorum_longus_l.001` | gauche |
| Extensor digitorumongus | `extensor_digitorum_longus_r` | `mat_extensor_digitorum_longus_r.001` | droite |
| Extensor digitorum | `extensor_digitorum_r` | `mat_extensor_digitorum_r.001` | droite |
| Flexor carpiadialis | `flexor_carpi_radialis_l` | `mat_flexor_carpi_radialis_l.001` | gauche |
| Flexor carpiadialis | `flexor_carpi_radialis_r` | `mat_flexor_carpi_radialis_r.001` | droite |
| Flexor digitorum brevis | `flexor_digitorum_brevis_l` | `mat_flexor_digitorum_brevis_l.001` | gauche |
| Flexor digitorum brevis | `flexor_digitorum_brevis_r` | `mat_flexor_digitorum_brevis_r.001` | droite |
| Flexor digitorumongus | `flexor_digitorum_longus_l` | `mat_flexor_digitorum_longus_l.001` | gauche |
| Flexor digitorumongus | `flexor_digitorum_longus_r` | `mat_flexor_digitorum_longus_r.001` | droite |
| Flexor digitorum profundus | `flexor_digitorum_profundus_l` | `mat_flexor_digitorum_profundus_l.001` | gauche |
| Flexor digitorum profundus | `flexor_digitorum_profundus_r` | `mat_flexor_digitorum_profundus_r.001` | droite |
| Humeral head of extensor carpi ulnaris | `humeral_head_of_extensor_carpi_ulnaris_l` | `mat_humeral_head_of_extensor_carpi_ulnaris_l.001` | gauche |
| Humeral head of extensor carpi ulnaris | `humeral_head_of_extensor_carpi_ulnaris_r` | `mat_humeral_head_of_extensor_carpi_ulnaris_r.001` | droite |
| Humeral head of flexor carpi ulnaris | `humeral_head_of_flexor_carpi_ulnaris_l` | `mat_humeral_head_of_flexor_carpi_ulnaris_l.001` | gauche |
| Humeral head of flexor carpi ulnaris | `humeral_head_of_flexor_carpi_ulnaris_r` | `mat_humeral_head_of_flexor_carpi_ulnaris_r.001` | droite |
| Humero ulnar head of flexor digitorum superficialis | `humero_ulnar_head_of_flexor_digitorum_superficialis_l` | `mat_humero_ulnar_head_of_flexor_digitorum_superficialis_l.001` | gauche |
| Humero ulnar head of flexor digitorum superficialis | `humero_ulnar_head_of_flexor_digitorum_superficialis_r` | `mat_humero_ulnar_head_of_flexor_digitorum_superficialis_r.001` | droite |
| Pronator quadratus | `pronator_quadratus_l` | `mat_pronator_quadratus_l.001` | gauche |
| Pronator quadratus | `pronator_quadratus_r` | `mat_pronator_quadratus_r.001` | droite |
| Radial head of flexor digitorum superficialis | `radial_head_of_flexor_digitorum_superficialis_l` | `mat_radial_head_of_flexor_digitorum_superficialis_l.001` | gauche |
| Radial head of flexor digitorum superficialis | `radial_head_of_flexor_digitorum_superficialis_r` | `mat_radial_head_of_flexor_digitorum_superficialis_r.001` | droite |
| Superficial head of pronator teres | `superficial_head_of_pronator_teres_l` | `mat_superficial_head_of_pronator_teres_l.001` | gauche |
| Superficial head of pronator teres | `superficial_head_of_pronator_teres_r` | `mat_superficial_head_of_pronator_teres_r.001` | droite |
| Supinator | `supinator_l` | `mat_supinator_l.001` | gauche |
| Supinator | `supinator_r` | `mat_supinator_r.001` | droite |
| Ulnar head of extensor carpi ulnaris | `ulnar_head_of_extensor_carpi_ulnaris_l` | `mat_ulnar_head_of_extensor_carpi_ulnaris_l.001` | gauche |
| Ulnar head of extensor carpi ulnaris | `ulnar_head_of_extensor_carpi_ulnaris_r` | `mat_ulnar_head_of_extensor_carpi_ulnaris_r.001` | droite |
| Ulnar head of flexor carpi ulnaris | `ulnar_head_of_flexor_carpi_ulnaris_l` | `mat_ulnar_head_of_flexor_carpi_ulnaris_l.001` | gauche |
| Ulnar head of flexor carpi ulnaris | `ulnar_head_of_flexor_carpi_ulnaris_r` | `mat_ulnar_head_of_flexor_carpi_ulnaris_r.001` | droite |

## Groupe : hand (40 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Abductor digiti minimi of hand | `abductor_digiti_minimi_of_hand_l` | `mat_abductor_digiti_minimi_of_hand_l.001` | gauche |
| Abductor digiti minimi of hand | `abductor_digiti_minimi_of_hand_r` | `mat_abductor_digiti_minimi_of_hand_r.001` | droite |
| Abductor pollicis brevis | `abductor_pollicis_brevis_l` | `mat_abductor_pollicis_brevis_l.001` | gauche |
| Abductor pollicis brevis | `abductor_pollicis_brevis_r` | `mat_abductor_pollicis_brevis_r.001` | droite |
| Abductor pollicisongus | `abductor_pollicis_longus_l` | `mat_abductor_pollicis_longus_l.001` | gauche |
| Abductor pollicisongus | `abductor_pollicis_longus_r` | `mat_abductor_pollicis_longus_r.001` | droite |
| Deep head of flexor pollicis brevis | `deep_head_of_flexor_pollicis_brevis_l` | `mat_deep_head_of_flexor_pollicis_brevis_l.001` | gauche |
| Deep head of flexor pollicis brevis | `deep_head_of_flexor_pollicis_brevis_r` | `mat_deep_head_of_flexor_pollicis_brevis_r.001` | droite |
| Dorsal interossei muscles of foot | `dorsal_interossei_muscles_of_foot_l` | `mat_dorsal_interossei_muscles_of_foot_l.001` | gauche |
| Dorsal interossei muscles of foot | `dorsal_interossei_muscles_of_foot_r` | `mat_dorsal_interossei_muscles_of_foot_r.001` | droite |
| Dorsal interossei muscles of hand | `dorsal_interossei_muscles_of_hand_l` | `mat_dorsal_interossei_muscles_of_hand_l.001` | gauche |
| Dorsal interossei muscles of hand | `dorsal_interossei_muscles_of_hand_r` | `mat_dorsal_interossei_muscles_of_hand_r.001` | droite |
| Extensor pollicis brevis | `extensor_pollicis_brevis_l` | `mat_extensor_pollicis_brevis_l.001` | gauche |
| Extensor pollicis brevis | `extensor_pollicis_brevis_r` | `mat_extensor_pollicis_brevis_r.001` | droite |
| Extensor pollicisongus | `extensor_pollicis_longus_l` | `mat_extensor_pollicis_longus_l.001` | gauche |
| Extensor pollicisongus | `extensor_pollicis_longus_r` | `mat_extensor_pollicis_longus_r.001` | droite |
| Flexor digiti minimi of hand | `flexor_digiti_minimi_of_hand_l` | `mat_flexor_digiti_minimi_of_hand_l.001` | gauche |
| Flexor digiti minimi of hand | `flexor_digiti_minimi_of_hand_r` | `mat_flexor_digiti_minimi_of_hand_r.001` | droite |
| Flexor pollicisongus | `flexor_pollicis_longus_l` | `mat_flexor_pollicis_longus_l.001` | gauche |
| Flexor pollicisongus | `flexor_pollicis_longus_r` | `mat_flexor_pollicis_longus_r.001` | droite |
| Lumbrical muscles of foot | `lumbrical_muscles_of_foot_l` | `mat_lumbrical_muscles_of_foot_l.001` | gauche |
| Lumbrical muscles of foot | `lumbrical_muscles_of_foot_r` | `mat_lumbrical_muscles_of_foot_r.001` | droite |
| Lumbrical muscles of hand | `lumbrical_muscles_of_hand_l` | `mat_lumbrical_muscles_of_hand_l.001` | gauche |
| Lumbrical muscles of hand | `lumbrical_muscles_of_hand_r` | `mat_lumbrical_muscles_of_hand_r.001` | droite |
| Oblique head of adductor pollicis | `oblique_head_of_adductor_pollicis_l` | `mat_oblique_head_of_adductor_pollicis_l.001` | gauche |
| Oblique head of adductor pollicis | `oblique_head_of_adductor_pollicis_r` | `mat_oblique_head_of_adductor_pollicis_r.001` | droite |
| Opponens digiti minimi muscle of hand | `opponens_digiti_minimi_muscle_of_hand_l` | `mat_opponens_digiti_minimi_muscle_of_hand_l.001` | gauche |
| Opponens digiti minimi muscle of hand | `opponens_digiti_minimi_muscle_of_hand_r` | `mat_opponens_digiti_minimi_muscle_of_hand_r.001` | droite |
| Opponens pollicis muscle | `opponens_pollicis_muscle_l` | `mat_opponens_pollicis_muscle_l.001` | gauche |
| Opponens pollicis muscle | `opponens_pollicis_muscle_r` | `mat_opponens_pollicis_muscle_r.001` | droite |
| Palmar interossei muscles | `palmar_interossei_muscles_l` | `mat_palmar_interossei_muscles_l.001` | gauche |
| Palmar interossei muscles | `palmar_interossei_muscles_r` | `mat_palmar_interossei_muscles_r.001` | droite |
| Palmarisongus muscle | `palmaris_longus_muscle_l` | `mat_palmaris_longus_muscle_l.001` | gauche |
| Palmarisongus muscle | `palmaris_longus_muscle_r` | `mat_palmaris_longus_muscle_r.001` | droite |
| Plantar interossei muscles | `plantar_interossei_muscles_l` | `mat_plantar_interossei_muscles_l.001` | gauche |
| Plantar interossei muscles | `plantar_interossei_muscles_r` | `mat_plantar_interossei_muscles_r.001` | droite |
| Superficial head of flexor pollicis brevis | `superficial_head_of_flexor_pollicis_brevis_l` | `mat_superficial_head_of_flexor_pollicis_brevis_l.001` | gauche |
| Superficial head of flexor pollicis brevis | `superficial_head_of_flexor_pollicis_brevis_r` | `mat_superficial_head_of_flexor_pollicis_brevis_r.001` | droite |
| Transverse head of adductor pollicis | `transverse_head_of_adductor_pollicis_l` | `mat_transverse_head_of_adductor_pollicis_l.001` | gauche |
| Transverse head of adductor pollicis | `transverse_head_of_adductor_pollicis_r` | `mat_transverse_head_of_adductor_pollicis_r.001` | droite |

## Groupe : hip (26 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Coccygeus muscle | `coccygeus_muscle_l` | `mat_coccygeus_muscle_l.001` | gauche |
| Coccygeus muscle | `coccygeus_muscle_r` | `mat_coccygeus_muscle_r.001` | droite |
| Gluteus maximus muscle | `gluteus_maximus_muscle_l` | `mat_gluteus_maximus_muscle_l.001` | gauche |
| Gluteus maximus muscle | `gluteus_maximus_muscle_r` | `mat_gluteus_maximus_muscle_r.001` | droite |
| Gluteus medius muscle | `gluteus_medius_muscle_l` | `mat_gluteus_medius_muscle_l.001` | gauche |
| Gluteus medius muscle | `gluteus_medius_muscle_r` | `mat_gluteus_medius_muscle_r.001` | droite |
| Gluteus minimus muscle | `gluteus_minimus_muscle_l` | `mat_gluteus_minimus_muscle_l.001` | gauche |
| Gluteus minimus muscle | `gluteus_minimus_muscle_r` | `mat_gluteus_minimus_muscle_r.001` | droite |
| Iliacus muscle | `iliacus_muscle_l` | `mat_iliacus_muscle_l.001` | gauche |
| Iliacus muscle | `iliacus_muscle_r` | `mat_iliacus_muscle_r.001` | droite |
| Iliococcygeus muscle | `iliococcygeus_muscle_l` | `mat_iliococcygeus_muscle_l.001` | gauche |
| Iliococcygeus muscle | `iliococcygeus_muscle_r` | `mat_iliococcygeus_muscle_r.001` | droite |
| Inferior gemellus muscle | `inferior_gemellus_muscle_l` | `mat_inferior_gemellus_muscle_l.001` | gauche |
| Inferior gemellus muscle | `inferior_gemellus_muscle_r` | `mat_inferior_gemellus_muscle_r.001` | droite |
| Obturator externus | `obturator_externus_l` | `mat_obturator_externus_l.001` | gauche |
| Obturator externus | `obturator_externus_r` | `mat_obturator_externus_r.001` | droite |
| Obturator internus | `obturator_internus_l` | `mat_obturator_internus_l.001` | gauche |
| Obturator internus | `obturator_internus_r` | `mat_obturator_internus_r.001` | droite |
| Piriformis muscle | `piriformis_muscle_l` | `mat_piriformis_muscle_l.001` | gauche |
| Piriformis muscle | `piriformis_muscle_r` | `mat_piriformis_muscle_r.001` | droite |
| Psoas major | `psoas_major_l` | `mat_psoas_major_l.001` | gauche |
| Psoas major | `psoas_major_r` | `mat_psoas_major_r.001` | droite |
| Pubococcygeus muscle | `pubococcygeus_muscle_l` | `mat_pubococcygeus_muscle_l.001` | gauche |
| Pubococcygeus muscle | `pubococcygeus_muscle_r` | `mat_pubococcygeus_muscle_r.001` | droite |
| Superior gemellus muscle | `superior_gemellus_muscle_l` | `mat_superior_gemellus_muscle_l.001` | gauche |
| Superior gemellus muscle | `superior_gemellus_muscle_r` | `mat_superior_gemellus_muscle_r.001` | droite |

## Groupe : larynx (11 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| External part of thyro arytenoid muscle | `external_part_of_thyro_arytenoid_muscle_l` | `mat_external_part_of_thyro_arytenoid_muscle_l.001` | gauche |
| External part of thyro arytenoid muscle | `external_part_of_thyro_arytenoid_muscle_r` | `mat_external_part_of_thyro_arytenoid_muscle_r.001` | droite |
| Lateral crico arytenoid muscle | `lateral_crico_arytenoid_muscle_l` | `mat_lateral_crico_arytenoid_muscle_l.001` | gauche |
| Lateral crico arytenoid muscle | `lateral_crico_arytenoid_muscle_r` | `mat_lateral_crico_arytenoid_muscle_r.001` | droite |
| Posterior crico arytenoid muscle | `posterior_crico_arytenoid_muscle_l` | `mat_posterior_crico_arytenoid_muscle_l.001` | gauche |
| Posterior crico arytenoid muscle | `posterior_crico_arytenoid_muscle_r` | `mat_posterior_crico_arytenoid_muscle_r.001` | droite |
| Straight part of cricothyroid muscle | `straight_part_of_cricothyroid_muscle_l` | `mat_straight_part_of_cricothyroid_muscle_l.001` | gauche |
| Straight part of cricothyroid muscle | `straight_part_of_cricothyroid_muscle_r` | `mat_straight_part_of_cricothyroid_muscle_r.001` | droite |
| Thyro epiglottic part of thyro arytenoid muscle | `thyro_epiglottic_part_of_thyro_arytenoid_muscle_l` | `mat_thyro_epiglottic_part_of_thyro_arytenoid_muscle_l.001` | gauche |
| Thyro epiglottic part of thyro arytenoid muscle | `thyro_epiglottic_part_of_thyro_arytenoid_muscle_r` | `mat_thyro_epiglottic_part_of_thyro_arytenoid_muscle_r.001` | droite |
| Transverse arytenoid muscle | `transverse_arytenoid_muscle_l` | `mat_transverse_arytenoid_muscle_l.001` | gauche |

## Groupe : lower_leg (20 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Fibularis brevis muscle | `fibularis_brevis_muscle_l` | `mat_fibularis_brevis_muscle_l.001` | gauche |
| Fibularis brevis muscle | `fibularis_brevis_muscle_r` | `mat_fibularis_brevis_muscle_r.001` | droite |
| Fibularisongus muscle | `fibularis_longus_muscle_l` | `mat_fibularis_longus_muscle_l.001` | gauche |
| Fibularisongus muscle | `fibularis_longus_muscle_r` | `mat_fibularis_longus_muscle_r.001` | droite |
| Fibularis tertius muscle | `fibularis_tertius_muscle_l` | `mat_fibularis_tertius_muscle_l.001` | gauche |
| Fibularis tertius muscle | `fibularis_tertius_muscle_r` | `mat_fibularis_tertius_muscle_r.001` | droite |
| Lateral head of gastrocnemius | `lateral_head_of_gastrocnemius_l` | `mat_lateral_head_of_gastrocnemius_l.001` | gauche |
| Lateral head of gastrocnemius | `lateral_head_of_gastrocnemius_r` | `mat_lateral_head_of_gastrocnemius_r.001` | droite |
| Medial head of gastrocnemius | `medial_head_of_gastrocnemius_l` | `mat_medial_head_of_gastrocnemius_l.001` | gauche |
| Medial head of gastrocnemius | `medial_head_of_gastrocnemius_r` | `mat_medial_head_of_gastrocnemius_r.001` | droite |
| Plantaris muscle | `plantaris_muscle_l` | `mat_plantaris_muscle_l.001` | gauche |
| Plantaris muscle | `plantaris_muscle_r` | `mat_plantaris_muscle_r.001` | droite |
| Popliteus muscle | `popliteus_muscle_l` | `mat_popliteus_muscle_l.001` | gauche |
| Popliteus muscle | `popliteus_muscle_r` | `mat_popliteus_muscle_r.001` | droite |
| Soleus muscle | `soleus_muscle_l` | `mat_soleus_muscle_l.001` | gauche |
| Soleus muscle | `soleus_muscle_r` | `mat_soleus_muscle_r.001` | droite |
| Tibialis anterior muscle | `tibialis_anterior_muscle_l` | `mat_tibialis_anterior_muscle_l.001` | gauche |
| Tibialis anterior muscle | `tibialis_anterior_muscle_r` | `mat_tibialis_anterior_muscle_r.001` | droite |
| Tibialis posterior muscle | `tibialis_posterior_muscle_l` | `mat_tibialis_posterior_muscle_l.001` | gauche |
| Tibialis posterior muscle | `tibialis_posterior_muscle_r` | `mat_tibialis_posterior_muscle_r.001` | droite |

## Groupe : neck (20 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Anterior belly of digastric muscle | `anterior_belly_of_digastric_muscle_l` | `mat_anterior_belly_of_digastric_muscle_l.001` | gauche |
| Anterior belly of digastric muscle | `anterior_belly_of_digastric_muscle_r` | `mat_anterior_belly_of_digastric_muscle_r.001` | droite |
| Geniohyoid muscle | `geniohyoid_muscle_l` | `mat_geniohyoid_muscle_l.001` | gauche |
| Geniohyoid muscle | `geniohyoid_muscle_r` | `mat_geniohyoid_muscle_r.001` | droite |
| Mylohyoid muscle | `mylohyoid_muscle_l` | `mat_mylohyoid_muscle_l.001` | gauche |
| Mylohyoid muscle | `mylohyoid_muscle_r` | `mat_mylohyoid_muscle_r.001` | droite |
| Omohyoid muscle | `omohyoid_muscle_l` | `mat_omohyoid_muscle_l.001` | gauche |
| Omohyoid muscle | `omohyoid_muscle_r` | `mat_omohyoid_muscle_r.001` | droite |
| Platysma | `platysma_l` | `mat_platysma_l.001` | gauche |
| Platysma | `platysma_r` | `mat_platysma_r.001` | droite |
| Posterior belly of digastric muscle | `posterior_belly_of_digastric_muscle_l` | `mat_posterior_belly_of_digastric_muscle_l.001` | gauche |
| Posterior belly of digastric muscle | `posterior_belly_of_digastric_muscle_r` | `mat_posterior_belly_of_digastric_muscle_r.001` | droite |
| Sternocleidomastoid muscle | `sternocleidomastoid_muscle_l` | `mat_sternocleidomastoid_muscle_l.001` | gauche |
| Sternocleidomastoid muscle | `sternocleidomastoid_muscle_r` | `mat_sternocleidomastoid_muscle_r.001` | droite |
| Sternohyoid muscle | `sternohyoid_muscle_l` | `mat_sternohyoid_muscle_l.001` | gauche |
| Sternohyoid muscle | `sternohyoid_muscle_r` | `mat_sternohyoid_muscle_r.001` | droite |
| Stylohyoid muscle | `stylohyoid_muscle_l` | `mat_stylohyoid_muscle_l.001` | gauche |
| Stylohyoid muscle | `stylohyoid_muscle_r` | `mat_stylohyoid_muscle_r.001` | droite |
| Thyrohyoid muscle | `thyrohyoid_muscle_l` | `mat_thyrohyoid_muscle_l.001` | gauche |
| Thyrohyoid muscle | `thyrohyoid_muscle_r` | `mat_thyrohyoid_muscle_r.001` | droite |

## Groupe : other (126 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Epicranial aponeurosis.l | `Epicranial aponeurosis.l` | `Tendon.001` | — |
| Epicranial aponeurosis.r | `Epicranial aponeurosis.r` | `Tendon.001` | — |
| Muscular system.g | `Muscular system.g` | `Text.001` | — |
| Bucinator | `bucinator_l` | `mat_bucinator_l.001` | gauche |
| Bucinator | `bucinator_r` | `mat_bucinator_r.001` | droite |
| Diaphragm | `diaphragm` | `mat_diaphragm.001` | — |
| Extensor digiti minimi | `extensor_digiti_minimi_l` | `mat_extensor_digiti_minimi_l.001` | gauche |
| Extensor digiti minimi | `extensor_digiti_minimi_r` | `mat_extensor_digiti_minimi_r.001` | droite |
| Extensor indicis | `extensor_indicis_l` | `mat_extensor_indicis_l.001` | gauche |
| Extensor indicis | `extensor_indicis_r` | `mat_extensor_indicis_r.001` | droite |
| External intercostal muscles | `external_intercostal_muscles_l` | `mat_external_intercostal_muscles_l.001` | gauche |
| External intercostal muscles | `external_intercostal_muscles_r` | `mat_external_intercostal_muscles_r.001` | droite |
| Genioglossus muscle | `genioglossus_muscle_l` | `mat_genioglossus_muscle_l.001` | gauche |
| Genioglossus muscle | `genioglossus_muscle_r` | `mat_genioglossus_muscle_r.001` | droite |
| Hyoglossus muscle | `hyoglossus_muscle_l` | `mat_hyoglossus_muscle_l.001` | gauche |
| Hyoglossus muscle | `hyoglossus_muscle_r` | `mat_hyoglossus_muscle_r.001` | droite |
| Iliotibial tract | `iliotibial_tract_l` | `mat_iliotibial_tract_l.001` | gauche |
| Iliotibial tract | `iliotibial_tract_r` | `mat_iliotibial_tract_r.001` | droite |
| Inferior head ofateral pterygoid muscle | `inferior_head_of_lateral_pterygoid_muscle_l` | `mat_inferior_head_of_lateral_pterygoid_muscle_l.001` | gauche |
| Inferior head ofateral pterygoid muscle | `inferior_head_of_lateral_pterygoid_muscle_r` | `mat_inferior_head_of_lateral_pterygoid_muscle_r.001` | droite |
| Inferior pharyngeal constrictor | `inferior_pharyngeal_constrictor_l` | `mat_inferior_pharyngeal_constrictor_l.001` | gauche |
| Inferior pharyngeal constrictor | `inferior_pharyngeal_constrictor_r` | `mat_inferior_pharyngeal_constrictor_r.001` | droite |
| Inferiorectus muscle | `inferior_rectus_muscle_l` | `mat_inferior_rectus_muscle_l.001` | gauche |
| Inferiorectus muscle | `inferior_rectus_muscle_r` | `mat_inferior_rectus_muscle_r.001` | droite |
| Innermost intercostal muscles | `innermost_intercostal_muscles_l` | `mat_innermost_intercostal_muscles_l.001` | gauche |
| Innermost intercostal muscles | `innermost_intercostal_muscles_r` | `mat_innermost_intercostal_muscles_r.001` | droite |
| Internal intercostal muscles | `internal_intercostal_muscles_l` | `mat_internal_intercostal_muscles_l.001` | gauche |
| Internal intercostal muscles | `internal_intercostal_muscles_r` | `mat_internal_intercostal_muscles_r.001` | droite |
| Interspinales colli muscles | `interspinales_colli_muscles_l` | `mat_interspinales_colli_muscles_l.001` | gauche |
| Interspinales colli muscles | `interspinales_colli_muscles_r` | `mat_interspinales_colli_muscles_r.001` | droite |
| Interspinalesumborum muscles | `interspinales_lumborum_muscles_l` | `mat_interspinales_lumborum_muscles_l.001` | gauche |
| Interspinalesumborum muscles | `interspinales_lumborum_muscles_r` | `mat_interspinales_lumborum_muscles_r.001` | droite |
| Interspinales thoracis muscles | `interspinales_thoracis_muscles_l` | `mat_interspinales_thoracis_muscles_l.001` | gauche |
| Interspinales thoracis muscles | `interspinales_thoracis_muscles_r` | `mat_interspinales_thoracis_muscles_r.001` | droite |
| Levator nasolabialis | `levator_nasolabialis_l` | `mat_levator_nasolabialis_l.001` | gauche |
| Levator nasolabialis | `levator_nasolabialis_r` | `mat_levator_nasolabialis_r.001` | droite |
| Levator scapulae | `levator_scapulae_l` | `mat_levator_scapulae_l.001` | gauche |
| Levator scapulae | `levator_scapulae_r` | `mat_levator_scapulae_r.001` | droite |
| Levatores breves costarum | `levatores_breves_costarum_l` | `mat_levatores_breves_costarum_l.001` | gauche |
| Levatores breves costarum | `levatores_breves_costarum_r` | `mat_levatores_breves_costarum_r.001` | droite |
| Levatoresongi costarum | `levatores_longi_costarum_l` | `mat_levatores_longi_costarum_l.001` | gauche |
| Levatoresongi costarum | `levatores_longi_costarum_r` | `mat_levatores_longi_costarum_r.001` | droite |
| Longus capitis muscle | `longus_capitis_muscle_l` | `mat_longus_capitis_muscle_l.001` | gauche |
| Longus capitis muscle | `longus_capitis_muscle_r` | `mat_longus_capitis_muscle_r.001` | droite |
| Longus colli muscle | `longus_colli_muscle_l` | `mat_longus_colli_muscle_l.001` | gauche |
| Longus colli muscle | `longus_colli_muscle_r` | `mat_longus_colli_muscle_r.001` | droite |
| Medial pterygoid muscle | `medial_pterygoid_muscle_l` | `mat_medial_pterygoid_muscle_l.001` | gauche |
| Medial pterygoid muscle | `medial_pterygoid_muscle_r` | `mat_medial_pterygoid_muscle_r.001` | droite |
| Medialectus muscle | `medial_rectus_muscle_l` | `mat_medial_rectus_muscle_l.001` | gauche |
| Medialectus muscle | `medial_rectus_muscle_r` | `mat_medial_rectus_muscle_r.001` | droite |
| Middle pharyngeal constrictor | `middle_pharyngeal_constrictor_l` | `mat_middle_pharyngeal_constrictor_l.001` | gauche |
| Middle pharyngeal constrictor | `middle_pharyngeal_constrictor_r` | `mat_middle_pharyngeal_constrictor_r.001` | droite |
| Obliquus inferior capitis muscle | `obliquus_inferior_capitis_muscle_l` | `mat_obliquus_inferior_capitis_muscle_l.001` | gauche |
| Obliquus inferior capitis muscle | `obliquus_inferior_capitis_muscle_r` | `mat_obliquus_inferior_capitis_muscle_r.001` | droite |
| Obliquus superior capitis muscle | `obliquus_superior_capitis_muscle_l` | `mat_obliquus_superior_capitis_muscle_l.001` | gauche |
| Obliquus superior capitis muscle | `obliquus_superior_capitis_muscle_r` | `mat_obliquus_superior_capitis_muscle_r.001` | droite |
| Palatopharyngeus muscle | `palatopharyngeus_muscle_l` | `mat_palatopharyngeus_muscle_l.001` | gauche |
| Palatopharyngeus muscle | `palatopharyngeus_muscle_r` | `mat_palatopharyngeus_muscle_r.001` | droite |
| Pectineus muscle | `pectineus_muscle_l` | `mat_pectineus_muscle_l.001` | gauche |
| Pectineus muscle | `pectineus_muscle_r` | `mat_pectineus_muscle_r.001` | droite |
| Pubo analis muscle | `pubo_analis_muscle_l` | `mat_pubo_analis_muscle_l.001` | gauche |
| Pubo analis muscle | `pubo_analis_muscle_r` | `mat_pubo_analis_muscle_r.001` | droite |
| Pyramidalis muscle | `pyramidalis_muscle_l` | `mat_pyramidalis_muscle_l.001` | gauche |
| Pyramidalis muscle | `pyramidalis_muscle_r` | `mat_pyramidalis_muscle_r.001` | droite |
| Quadratus femoris muscle | `quadratus_femoris_muscle_l` | `mat_quadratus_femoris_muscle_l.001` | gauche |
| Quadratus femoris muscle | `quadratus_femoris_muscle_r` | `mat_quadratus_femoris_muscle_r.001` | droite |
| Quadratusumborum muscle | `quadratus_lumborum_muscle_l` | `mat_quadratus_lumborum_muscle_l.001` | gauche |
| Quadratusumborum muscle | `quadratus_lumborum_muscle_r` | `mat_quadratus_lumborum_muscle_r.001` | droite |
| Quadratus plantae muscle | `quadratus_plantae_muscle_l` | `mat_quadratus_plantae_muscle_l.001` | gauche |
| Quadratus plantae muscle | `quadratus_plantae_muscle_r` | `mat_quadratus_plantae_muscle_r.001` | droite |
| Rectus anterior capitis muscle | `rectus_anterior_capitis_muscle_l` | `mat_rectus_anterior_capitis_muscle_l.001` | gauche |
| Rectus anterior capitis muscle | `rectus_anterior_capitis_muscle_r` | `mat_rectus_anterior_capitis_muscle_r.001` | droite |
| Rectusateralis capitis muscle | `rectus_lateralis_capitis_muscle_l` | `mat_rectus_lateralis_capitis_muscle_l.001` | gauche |
| Rectusateralis capitis muscle | `rectus_lateralis_capitis_muscle_r` | `mat_rectus_lateralis_capitis_muscle_r.001` | droite |
| Rectus posterior major capitis muscle | `rectus_posterior_major_capitis_muscle_l` | `mat_rectus_posterior_major_capitis_muscle_l.001` | gauche |
| Rectus posterior major capitis muscle | `rectus_posterior_major_capitis_muscle_r` | `mat_rectus_posterior_major_capitis_muscle_r.001` | droite |
| Rectus posterior minor capitis muscle | `rectus_posterior_minor_capitis_muscle_l` | `mat_rectus_posterior_minor_capitis_muscle_l.001` | gauche |
| Rectus posterior minor capitis muscle | `rectus_posterior_minor_capitis_muscle_r` | `mat_rectus_posterior_minor_capitis_muscle_r.001` | droite |
| Rotatores | `rotatores_l` | `mat_rotatores_l.001` | gauche |
| Rotatores | `rotatores_r` | `mat_rotatores_r.001` | droite |
| Scalenus anterior muscle | `scalenus_anterior_muscle_l` | `mat_scalenus_anterior_muscle_l.001` | gauche |
| Scalenus anterior muscle | `scalenus_anterior_muscle_r` | `mat_scalenus_anterior_muscle_r.001` | droite |
| Scalenus medius muscle | `scalenus_medius_muscle_l` | `mat_scalenus_medius_muscle_l.001` | gauche |
| Scalenus medius muscle | `scalenus_medius_muscle_r` | `mat_scalenus_medius_muscle_r.001` | droite |
| Scalenus posterior muscle | `scalenus_posterior_muscle_l` | `mat_scalenus_posterior_muscle_l.001` | gauche |
| Scalenus posterior muscle | `scalenus_posterior_muscle_r` | `mat_scalenus_posterior_muscle_r.001` | droite |
| Semispinalis colli muscle | `semispinalis_colli_muscle_l` | `mat_semispinalis_colli_muscle_l.001` | gauche |
| Semispinalis colli muscle | `semispinalis_colli_muscle_r` | `mat_semispinalis_colli_muscle_r.001` | droite |
| Semispinalis thoracis muscle | `semispinalis_thoracis_muscle_l` | `mat_semispinalis_thoracis_muscle_l.001` | gauche |
| Semispinalis thoracis muscle | `semispinalis_thoracis_muscle_r` | `mat_semispinalis_thoracis_muscle_r.001` | droite |
| Serratus posterior inferior muscle | `serratus_posterior_inferior_muscle_l` | `mat_serratus_posterior_inferior_muscle_l.001` | gauche |
| Serratus posterior inferior muscle | `serratus_posterior_inferior_muscle_r` | `mat_serratus_posterior_inferior_muscle_r.001` | droite |
| Serratus posterior superior muscle | `serratus_posterior_superior_muscle_l` | `mat_serratus_posterior_superior_muscle_l.001` | gauche |
| Serratus posterior superior muscle | `serratus_posterior_superior_muscle_r` | `mat_serratus_posterior_superior_muscle_r.001` | droite |
| Spinalis capitis muscle | `spinalis_capitis_muscle_l` | `mat_spinalis_capitis_muscle_l.001` | gauche |
| Spinalis capitis muscle | `spinalis_capitis_muscle_r` | `mat_spinalis_capitis_muscle_r.001` | droite |
| Spinalis colli muscle | `spinalis_colli_muscle_l` | `mat_spinalis_colli_muscle_l.001` | gauche |
| Spinalis colli muscle | `spinalis_colli_muscle_r` | `mat_spinalis_colli_muscle_r.001` | droite |
| Spinalis thoracis muscle | `spinalis_thoracis_muscle_l` | `mat_spinalis_thoracis_muscle_l.001` | gauche |
| Spinalis thoracis muscle | `spinalis_thoracis_muscle_r` | `mat_spinalis_thoracis_muscle_r.001` | droite |
| Splenius capitis muscle | `splenius_capitis_muscle_l` | `mat_splenius_capitis_muscle_l.001` | gauche |
| Splenius capitis muscle | `splenius_capitis_muscle_r` | `mat_splenius_capitis_muscle_r.001` | droite |
| Splenius colli muscle | `splenius_colli_muscle_l` | `mat_splenius_colli_muscle_l.001` | gauche |
| Splenius colli muscle | `splenius_colli_muscle_r` | `mat_splenius_colli_muscle_r.001` | droite |
| Sternothyroid muscle | `sternothyroid_muscle_l` | `mat_sternothyroid_muscle_l.001` | gauche |
| Sternothyroid muscle | `sternothyroid_muscle_r` | `mat_sternothyroid_muscle_r.001` | droite |
| Stylopharyngeus muscle | `stylopharyngeus_muscle_l` | `mat_stylopharyngeus_muscle_l.001` | gauche |
| Stylopharyngeus muscle | `stylopharyngeus_muscle_r` | `mat_stylopharyngeus_muscle_r.001` | droite |
| Subclavius muscle | `subclavius_muscle_l` | `mat_subclavius_muscle_l.001` | gauche |
| Subclavius muscle | `subclavius_muscle_r` | `mat_subclavius_muscle_r.001` | droite |
| Superior head ofateral pterygoid muscle | `superior_head_of_lateral_pterygoid_muscle_l` | `mat_superior_head_of_lateral_pterygoid_muscle_l.001` | gauche |
| Superior head ofateral pterygoid muscle | `superior_head_of_lateral_pterygoid_muscle_r` | `mat_superior_head_of_lateral_pterygoid_muscle_r.001` | droite |
| Superior pharyngeal constrictor | `superior_pharyngeal_constrictor_l` | `mat_superior_pharyngeal_constrictor_l.001` | gauche |
| Superior pharyngeal constrictor | `superior_pharyngeal_constrictor_r` | `mat_superior_pharyngeal_constrictor_r.001` | droite |
| Superiorectus muscle | `superior_rectus_muscle_l` | `mat_superior_rectus_muscle_l.001` | gauche |
| Superiorectus muscle | `superior_rectus_muscle_r` | `mat_superior_rectus_muscle_r.001` | droite |
| Temporoparietalis muscle.001 | `temporoparietalis_muscle_l.001` | `mat_temporoparietalis_muscle_l.001` | — |
| Temporoparietalis muscle 2 | `temporoparietalis_muscle_l_2` | `mat_temporoparietalis_muscle_l_2` | gauche |
| Temporoparietalis muscle.001 | `temporoparietalis_muscle_r.001` | `mat_temporoparietalis_muscle_r.001` | — |
| Temporoparietalis muscle 2 | `temporoparietalis_muscle_r_2` | `mat_temporoparietalis_muscle_r_2` | droite |
| Teres major muscle | `teres_major_muscle_l` | `mat_teres_major_muscle_l.001` | gauche |
| Teres major muscle | `teres_major_muscle_r` | `mat_teres_major_muscle_r.001` | droite |
| Teres minor muscle | `teres_minor_muscle_l` | `mat_teres_minor_muscle_l.001` | gauche |
| Teres minor muscle | `teres_minor_muscle_r` | `mat_teres_minor_muscle_r.001` | droite |
| Transversus thoracis muscle | `transversus_thoracis_muscle_l` | `mat_transversus_thoracis_muscle_l.001` | gauche |
| Transversus thoracis muscle | `transversus_thoracis_muscle_r` | `mat_transversus_thoracis_muscle_r.001` | droite |

## Groupe : shoulder (22 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Acromial part of deltoid muscle | `acromial_part_of_deltoid_muscle_l` | `mat_acromial_part_of_deltoid_muscle_l.001` | gauche |
| Acromial part of deltoid muscle | `acromial_part_of_deltoid_muscle_r` | `mat_acromial_part_of_deltoid_muscle_r.001` | droite |
| Ascending part of trapezius muscle | `ascending_part_of_trapezius_muscle_l` | `mat_ascending_part_of_trapezius_muscle_l.001` | gauche |
| Ascending part of trapezius muscle | `ascending_part_of_trapezius_muscle_r` | `mat_ascending_part_of_trapezius_muscle_r.001` | droite |
| Clavicular part of deltoid muscle | `clavicular_part_of_deltoid_muscle_l` | `mat_clavicular_part_of_deltoid_muscle_l.001` | gauche |
| Clavicular part of deltoid muscle | `clavicular_part_of_deltoid_muscle_r` | `mat_clavicular_part_of_deltoid_muscle_r.001` | droite |
| Descending part of trapezius muscle | `descending_part_of_trapezius_muscle_l` | `mat_descending_part_of_trapezius_muscle_l.001` | gauche |
| Descending part of trapezius muscle | `descending_part_of_trapezius_muscle_r` | `mat_descending_part_of_trapezius_muscle_r.001` | droite |
| Infraspinatus muscle | `infraspinatus_muscle_l` | `mat_infraspinatus_muscle_l.001` | gauche |
| Infraspinatus muscle | `infraspinatus_muscle_r` | `mat_infraspinatus_muscle_r.001` | droite |
| Rhomboid major muscle | `rhomboid_major_muscle_l` | `mat_rhomboid_major_muscle_l.001` | gauche |
| Rhomboid major muscle | `rhomboid_major_muscle_r` | `mat_rhomboid_major_muscle_r.001` | droite |
| Rhomboid minor muscle | `rhomboid_minor_muscle_l` | `mat_rhomboid_minor_muscle_l.001` | gauche |
| Rhomboid minor muscle | `rhomboid_minor_muscle_r` | `mat_rhomboid_minor_muscle_r.001` | droite |
| Scapular spinal part of deltoid muscle | `scapular_spinal_part_of_deltoid_muscle_l` | `mat_scapular_spinal_part_of_deltoid_muscle_l.001` | gauche |
| Scapular spinal part of deltoid muscle | `scapular_spinal_part_of_deltoid_muscle_r` | `mat_scapular_spinal_part_of_deltoid_muscle_r.001` | droite |
| Subscapularis muscle | `subscapularis_muscle_l` | `mat_subscapularis_muscle_l.001` | gauche |
| Subscapularis muscle | `subscapularis_muscle_r` | `mat_subscapularis_muscle_r.001` | droite |
| Supraspinatus muscle | `supraspinatus_muscle_l` | `mat_supraspinatus_muscle_l.001` | gauche |
| Supraspinatus muscle | `supraspinatus_muscle_r` | `mat_supraspinatus_muscle_r.001` | droite |
| Transverse part of trapezius muscle | `transverse_part_of_trapezius_muscle_l` | `mat_transverse_part_of_trapezius_muscle_l.001` | gauche |
| Transverse part of trapezius muscle | `transverse_part_of_trapezius_muscle_r` | `mat_transverse_part_of_trapezius_muscle_r.001` | droite |

## Groupe : thigh (32 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Adductor brevis | `adductor_brevis_l` | `mat_adductor_brevis_l.001` | gauche |
| Adductor brevis | `adductor_brevis_r` | `mat_adductor_brevis_r.001` | droite |
| Adductorongus | `adductor_longus_l` | `mat_adductor_longus_l.001` | gauche |
| Adductorongus | `adductor_longus_r` | `mat_adductor_longus_r.001` | droite |
| Adductor magnus | `adductor_magnus_l` | `mat_adductor_magnus_l.001` | gauche |
| Adductor magnus | `adductor_magnus_r` | `mat_adductor_magnus_r.001` | droite |
| Adductor minimus | `adductor_minimus_l` | `mat_adductor_minimus_l.001` | gauche |
| Adductor minimus | `adductor_minimus_r` | `mat_adductor_minimus_r.001` | droite |
| Gracilis muscle | `gracilis_muscle_l` | `mat_gracilis_muscle_l.001` | gauche |
| Gracilis muscle | `gracilis_muscle_r` | `mat_gracilis_muscle_r.001` | droite |
| Long head of biceps femoris | `long_head_of_biceps_femoris_l` | `mat_long_head_of_biceps_femoris_l.001` | gauche |
| Long head of biceps femoris | `long_head_of_biceps_femoris_r` | `mat_long_head_of_biceps_femoris_r.001` | droite |
| Rectus femoris muscle | `rectus_femoris_muscle_l` | `mat_rectus_femoris_muscle_l.001` | gauche |
| Rectus femoris muscle | `rectus_femoris_muscle_r` | `mat_rectus_femoris_muscle_r.001` | droite |
| Sartorius muscle | `sartorius_muscle_l` | `mat_sartorius_muscle_l.001` | gauche |
| Sartorius muscle | `sartorius_muscle_r` | `mat_sartorius_muscle_r.001` | droite |
| Semimembranosus muscle | `semimembranosus_muscle_l` | `mat_semimembranosus_muscle_l.001` | gauche |
| Semimembranosus muscle | `semimembranosus_muscle_r` | `mat_semimembranosus_muscle_r.001` | droite |
| Semitendinosus muscle | `semitendinosus_muscle_l` | `mat_semitendinosus_muscle_l.001` | gauche |
| Semitendinosus muscle | `semitendinosus_muscle_r` | `mat_semitendinosus_muscle_r.001` | droite |
| Short head of biceps femoris | `short_head_of_biceps_femoris_l` | `mat_short_head_of_biceps_femoris_l.001` | gauche |
| Short head of biceps femoris | `short_head_of_biceps_femoris_r` | `mat_short_head_of_biceps_femoris_r.001` | droite |
| Tensor fasciaeatae | `tensor_fasciae_latae_l` | `mat_tensor_fasciae_latae_l.001` | gauche |
| Tensor fasciaeatae | `tensor_fasciae_latae_r` | `mat_tensor_fasciae_latae_r.001` | droite |
| Transverse head of adductor hallucis | `transverse_head_of_adductor_hallucis_l` | `mat_transverse_head_of_adductor_hallucis_l.001` | gauche |
| Transverse head of adductor hallucis | `transverse_head_of_adductor_hallucis_r` | `mat_transverse_head_of_adductor_hallucis_r.001` | droite |
| Vastus intermedius muscle | `vastus_intermedius_muscle_l` | `mat_vastus_intermedius_muscle_l.001` | gauche |
| Vastus intermedius muscle | `vastus_intermedius_muscle_r` | `mat_vastus_intermedius_muscle_r.001` | droite |
| Vastusateralis muscle | `vastus_lateralis_muscle_l` | `mat_vastus_lateralis_muscle_l.001` | gauche |
| Vastusateralis muscle | `vastus_lateralis_muscle_r` | `mat_vastus_lateralis_muscle_r.001` | droite |
| Vastus medialis muscle | `vastus_medialis_muscle_l` | `mat_vastus_medialis_muscle_l.001` | gauche |
| Vastus medialis muscle | `vastus_medialis_muscle_r` | `mat_vastus_medialis_muscle_r.001` | droite |

## Groupe : upper_arm (14 muscles)

| Nom lisible | Nom objet | Nom du matériau | Côté |
|---|---|---|---|
| Brachialis muscle | `brachialis_muscle_l` | `mat_brachialis_muscle_l.001` | gauche |
| Brachialis muscle | `brachialis_muscle_r` | `mat_brachialis_muscle_r.001` | droite |
| Coracobrachialis muscle | `coracobrachialis_muscle_l` | `mat_coracobrachialis_muscle_l.001` | gauche |
| Coracobrachialis muscle | `coracobrachialis_muscle_r` | `mat_coracobrachialis_muscle_r.001` | droite |
| Lateral head of triceps brachii | `lateral_head_of_triceps_brachii_l` | `mat_lateral_head_of_triceps_brachii_l.001` | gauche |
| Lateral head of triceps brachii | `lateral_head_of_triceps_brachii_r` | `mat_lateral_head_of_triceps_brachii_r.001` | droite |
| Long head of biceps brachii | `long_head_of_biceps_brachii_l` | `mat_long_head_of_biceps_brachii_l.001` | gauche |
| Long head of biceps brachii | `long_head_of_biceps_brachii_r` | `mat_long_head_of_biceps_brachii_r.001` | droite |
| Long head of triceps brachii | `long_head_of_triceps_brachii_l` | `mat_long_head_of_triceps_brachii_l.001` | gauche |
| Long head of triceps brachii | `long_head_of_triceps_brachii_r` | `mat_long_head_of_triceps_brachii_r.001` | droite |
| Medial head of triceps brachii | `medial_head_of_triceps_brachii_l` | `mat_medial_head_of_triceps_brachii_l.001` | gauche |
| Medial head of triceps brachii | `medial_head_of_triceps_brachii_r` | `mat_medial_head_of_triceps_brachii_r.001` | droite |
| Short head of biceps brachii | `short_head_of_biceps_brachii_l` | `mat_short_head_of_biceps_brachii_l.001` | gauche |
| Short head of biceps brachii | `short_head_of_biceps_brachii_r` | `mat_short_head_of_biceps_brachii_r.001` | droite |
