-- =====================================================================
--  Referentiel des parties du corps (navigation « par zone » cote app)
-- ---------------------------------------------------------------------
--  Sert a proposer une entree visuelle « Parcourir par zone » : chaque
--  ligne porte le libelle FR et une image illustrative (servie par le CDN
--  ExerciseDB, la meme que l'endpoint /bodyparts de l'API). Les exercices
--  sont rattaches par leur colonne texte body_part (valeurs ExerciseDB en
--  majuscules : CHEST, BACK, WAIST...). L'API expose /bodyparts avec le
--  nombre d'exercices par zone (calcule a la volee). Le client Flutter
--  n'appelle donc jamais l'API externe.
-- =====================================================================

create table body_parts (
    name       varchar(32) not null,   -- code ExerciseDB (CHEST, BACK...)
    label_fr   varchar(48) not null,   -- libelle affiche (FR)
    image_url  text,                   -- illustration (CDN ExerciseDB)
    sort_order integer not null default 0,
    primary key (name)
);

insert into body_parts (name, label_fr, image_url, sort_order) values
    ('CHEST',      'Pectoraux',       'https://cdn.exercisedb.dev/bodyparts/chest.webp',      1),
    ('BACK',       'Dos',             'https://cdn.exercisedb.dev/bodyparts/back.webp',       2),
    ('SHOULDERS',  'Épaules',         'https://cdn.exercisedb.dev/bodyparts/shoulders.webp',  3),
    ('BICEPS',     'Biceps',          'https://cdn.exercisedb.dev/bodyparts/biceps.webp',     4),
    ('TRICEPS',    'Triceps',         'https://cdn.exercisedb.dev/bodyparts/triceps.webp',    5),
    ('UPPER ARMS', 'Bras',            'https://cdn.exercisedb.dev/bodyparts/biceps.webp',     6),
    ('FOREARMS',   'Avant-bras',      'https://cdn.exercisedb.dev/bodyparts/forearms.webp',   7),
    ('WAIST',      'Abdominaux',      'https://cdn.exercisedb.dev/bodyparts/waist.webp',      8),
    ('HIPS',       'Fessiers',        'https://cdn.exercisedb.dev/bodyparts/hips.webp',       9),
    ('QUADRICEPS', 'Quadriceps',      'https://cdn.exercisedb.dev/bodyparts/quadriceps.webp', 10),
    ('THIGHS',     'Cuisses',         'https://cdn.exercisedb.dev/bodyparts/thighs.webp',     11),
    ('HAMSTRINGS', 'Ischio-jambiers', 'https://cdn.exercisedb.dev/bodyparts/hamstrings.webp', 12),
    ('CALVES',     'Mollets',         'https://cdn.exercisedb.dev/bodyparts/calves.webp',     13),
    ('NECK',       'Nuque',           'https://cdn.exercisedb.dev/bodyparts/neck.webp',       14),
    ('FULL BODY',  'Corps entier',    'https://cdn.exercisedb.dev/bodyparts/fullbody.webp',   15);
