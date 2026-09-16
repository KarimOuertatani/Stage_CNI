-- =====================================================================
--  Seed du referentiel d'exercices
-- ---------------------------------------------------------------------
--  Quelques exercices de base pour que l'app soit utilisable tout de
--  suite. gen_random_uuid() est disponible nativement dans PostgreSQL 16.
--  Les valeurs de primary_muscle / equipment respectent les enums Java.
-- =====================================================================

insert into exercises (id, name, primary_muscle, equipment, instructions, video_url) values
    (gen_random_uuid(), 'Developpe couche barre', 'PECTORAUX', 'BARRE',
        'Allonge sur le banc, descends la barre a la poitrine puis pousse.', null),
    (gen_random_uuid(), 'Developpe incline haltere', 'PECTORAUX', 'HALTERE',
        'Banc incline a 30 degres, pousse les halteres vers le haut.', null),
    (gen_random_uuid(), 'Pompes', 'PECTORAUX', 'POIDS_CORPS',
        'Corps gaine, descends la poitrine pres du sol puis remonte.', null),
    (gen_random_uuid(), 'Traction pronation', 'DOS', 'POIDS_CORPS',
        'Suspendu a la barre, tire le menton au-dessus de la barre.', null),
    (gen_random_uuid(), 'Rowing barre', 'DOS', 'BARRE',
        'Buste penche, tire la barre vers le nombril, dos droit.', null),
    (gen_random_uuid(), 'Tirage vertical poulie', 'DOS', 'POULIE',
        'Assis, tire la barre vers le haut de la poitrine.', null),
    (gen_random_uuid(), 'Squat barre', 'JAMBES', 'BARRE',
        'Barre sur les trapezes, descends en gardant le dos droit.', null),
    (gen_random_uuid(), 'Presse a cuisses', 'JAMBES', 'MACHINE',
        'Pousse la plateforme avec les pieds, sans bloquer les genoux.', null),
    (gen_random_uuid(), 'Fentes halteres', 'JAMBES', 'HALTERE',
        'Un pas en avant, descends le genou arriere vers le sol.', null),
    (gen_random_uuid(), 'Developpe militaire', 'EPAULES', 'BARRE',
        'Debout, pousse la barre au-dessus de la tete.', null),
    (gen_random_uuid(), 'Elevations laterales', 'EPAULES', 'HALTERE',
        'Bras legerement flechis, monte les halteres a l''horizontale.', null),
    (gen_random_uuid(), 'Curl biceps barre', 'BICEPS', 'BARRE',
        'Coudes fixes, remonte la barre par flexion des avant-bras.', null),
    (gen_random_uuid(), 'Curl marteau', 'BICEPS', 'HALTERE',
        'Prise neutre, remonte les halteres en gardant les coudes fixes.', null),
    (gen_random_uuid(), 'Extension triceps poulie', 'TRICEPS', 'POULIE',
        'Coudes colles au corps, tends les bras vers le bas.', null),
    (gen_random_uuid(), 'Dips', 'TRICEPS', 'POIDS_CORPS',
        'Aux barres paralleles, descends puis pousse pour remonter.', null),
    (gen_random_uuid(), 'Crunch', 'ABDOS', 'POIDS_CORPS',
        'Allonge, enroule le buste vers les genoux.', null),
    (gen_random_uuid(), 'Gainage planche', 'ABDOS', 'POIDS_CORPS',
        'Sur les avant-bras, corps aligne, tiens la position.', null),
    (gen_random_uuid(), 'Hip thrust', 'FESSIERS', 'BARRE',
        'Dos sur un banc, monte le bassin avec la barre sur les hanches.', null),
    (gen_random_uuid(), 'Mollets debout', 'MOLLETS', 'MACHINE',
        'Monte sur la pointe des pieds puis redescends lentement.', null),
    (gen_random_uuid(), 'Course sur tapis', 'CARDIO', 'MACHINE',
        'Course a allure reguliere pour le travail cardio.', null);
