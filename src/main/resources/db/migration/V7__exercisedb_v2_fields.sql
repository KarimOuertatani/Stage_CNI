-- =====================================================================
--  Enrichissement du referentiel d'exercices avec les donnees ExerciseDB V2
-- ---------------------------------------------------------------------
--  On importe une base reelle d'exercices (video de demonstration,
--  instructions pas-a-pas, conseils, variations, images multi-resolutions)
--  depuis l'API EXERCISEDB V2 (AscendAPI via RapidAPI) dans notre propre
--  table. Le client Flutter n'appelle JAMAIS l'API externe : il consomme
--  notre API comme d'habitude. Voir ExerciseImportService.
--
--  Les enums existants (primary_muscle / equipment) sont CONSERVES : le
--  service d'import y projette les valeurs ExerciseDB (mapping best-effort,
--  null si non mappable). Les champs texte riches ci-dessous s'ajoutent.
-- =====================================================================

-- Identifiant ExerciseDB (ex : exr_41n2h...), garant de l'unicite a l'import.
alter table exercises add column external_id varchar(64);
alter table exercises add constraint uk_exercises_external_id unique (external_id);

-- Champ cle de cette tache : la video de demonstration (MP4 servi par CDN).
-- On elargit video_url (varchar(255) -> text) et instructions (varchar(1000)
-- -> text) car les donnees importees depassent ces tailles.
alter table exercises alter column video_url type text;
alter table exercises alter column instructions type text;

-- Metadonnees d'aperçu / filtrage (valeurs ExerciseDB brutes, en anglais).
alter table exercises add column body_part         varchar(64);
alter table exercises add column exercise_type      varchar(64);
alter table exercises add column target_muscles     text;
alter table exercises add column secondary_muscles  text;
alter table exercises add column keywords           text;

-- Contenu pedagogique complet (renvoye par l'endpoint detail ExerciseDB).
alter table exercises add column overview       text;
alter table exercises add column exercise_tips  text;
alter table exercises add column variations     text;

-- Images multi-resolutions (l'ecran de detail utilise le 720p ; les listes
-- utilisent image_url / 360p pour rester rapides — jamais la video).
alter table exercises add column image_url        text;
alter table exercises add column image_url_360p   text;
alter table exercises add column image_url_480p   text;
alter table exercises add column image_url_720p   text;
alter table exercises add column image_url_1080p  text;
