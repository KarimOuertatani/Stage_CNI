-- =====================================================================
--  Programmes "prets a l'emploi" (modeles) + evolutions de schema
-- ---------------------------------------------------------------------
--  Objectif : offrir a l'adherent des programmes tout faits (Push/Pull/
--  Legs, Full Body debutant, Upper/Lower) composes de seances pretes,
--  chaque seance etant un ensemble d'exercices du referentiel.
--
--  Ces programmes n'appartiennent a personne (user_id = null) : ce sont
--  des MODELES partages (is_template = true). L'adherent peut les
--  parcourir puis les "adopter" (copie personnelle) ou creer les siens.
--
--  On ajoute aussi 2 colonnes de presentation utilisees par l'UI :
--   - description       : texte court de presentation
--   - experience_level  : niveau conseille (enum ExperienceLevel)
-- =====================================================================

-- ---------------------------------------------------------------------
--  1) Evolution du schema workout_programs
-- ---------------------------------------------------------------------
alter table workout_programs alter column user_id drop not null;

alter table workout_programs add column description varchar(500);

alter table workout_programs add column experience_level varchar(255)
    check (experience_level in ('DEBUTANT','INTERMEDIAIRE','AVANCE'));

-- ---------------------------------------------------------------------
--  2) Programmes modeles (UUID fixes pour reference dans ce script)
-- ---------------------------------------------------------------------
insert into workout_programs
    (id, user_id, title, description, goal, experience_level, duration_weeks, is_template)
values
    ('11111111-1111-1111-1111-111111111111', null,
        'Push / Pull / Legs',
        'Le grand classique en 3 seances : pousser, tirer, jambes. Ideal pour prendre du muscle en couvrant tout le corps sur la semaine.',
        'PRISE_MASSE', 'INTERMEDIAIRE', 6, true),
    ('22222222-2222-2222-2222-222222222222', null,
        'Full Body Debutant',
        'Trois seances completes par semaine pour poser des bases solides sur tout le corps. Parfait pour demarrer la musculation.',
        'MAINTIEN', 'DEBUTANT', 4, true),
    ('33333333-3333-3333-3333-333333333333', null,
        'Upper / Lower Force',
        'Deux seances haut du corps / bas du corps, charges lourdes et peu de repetitions pour gagner en force.',
        'FORCE', 'INTERMEDIAIRE', 4, true);

-- ---------------------------------------------------------------------
--  3) Seances des modeles
-- ---------------------------------------------------------------------
insert into workout_sessions (id, program_id, title, day_of_week, order_index) values
    -- Push / Pull / Legs
    ('a1000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Push - Pectoraux / Epaules / Triceps', 1, 0),
    ('a1000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Pull - Dos / Biceps', 3, 1),
    ('a1000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'Legs - Jambes / Fessiers', 5, 2),
    -- Full Body Debutant
    ('a2000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'Full Body A', 1, 0),
    ('a2000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Full Body B', 3, 1),
    ('a2000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'Full Body C', 5, 2),
    -- Upper / Lower Force
    ('a3000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'Upper - Haut du corps', 1, 0),
    ('a3000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'Lower - Bas du corps', 4, 1);

-- ---------------------------------------------------------------------
--  4) Exercices places dans chaque seance
--     L'exercice est reference par son nom (le referentiel V2 les a seeds
--     avec des UUID aleatoires). ex(name) -> id via sous-requete.
-- ---------------------------------------------------------------------

-- Push (a1..01)
insert into session_exercises (id, session_id, exercise_id, target_sets, target_reps, target_weight_kg, rest_seconds, order_index)
select gen_random_uuid(), 'a1000000-0000-0000-0000-000000000001', e.id, v.sets, v.reps, null, v.rest, v.ord
from (values
    ('Developpe couche barre', 4, 8, 120, 0),
    ('Developpe militaire', 3, 10, 120, 1),
    ('Developpe incline haltere', 3, 10, 90, 2),
    ('Elevations laterales', 3, 15, 60, 3),
    ('Dips', 3, 12, 90, 4),
    ('Extension triceps poulie', 3, 12, 60, 5)
) as v(name, sets, reps, rest, ord)
join exercises e on e.name = v.name;

-- Pull (a1..02)
insert into session_exercises (id, session_id, exercise_id, target_sets, target_reps, target_weight_kg, rest_seconds, order_index)
select gen_random_uuid(), 'a1000000-0000-0000-0000-000000000002', e.id, v.sets, v.reps, null, v.rest, v.ord
from (values
    ('Traction pronation', 4, 8, 120, 0),
    ('Rowing barre', 4, 10, 120, 1),
    ('Tirage vertical poulie', 3, 12, 90, 2),
    ('Curl biceps barre', 3, 12, 60, 3),
    ('Curl marteau', 3, 12, 60, 4)
) as v(name, sets, reps, rest, ord)
join exercises e on e.name = v.name;

-- Legs (a1..03)
insert into session_exercises (id, session_id, exercise_id, target_sets, target_reps, target_weight_kg, rest_seconds, order_index)
select gen_random_uuid(), 'a1000000-0000-0000-0000-000000000003', e.id, v.sets, v.reps, null, v.rest, v.ord
from (values
    ('Squat barre', 4, 8, 150, 0),
    ('Presse a cuisses', 3, 12, 120, 1),
    ('Fentes halteres', 3, 12, 90, 2),
    ('Hip thrust', 3, 12, 90, 3),
    ('Mollets debout', 4, 15, 60, 4)
) as v(name, sets, reps, rest, ord)
join exercises e on e.name = v.name;

-- Full Body A (a2..01)
insert into session_exercises (id, session_id, exercise_id, target_sets, target_reps, target_weight_kg, rest_seconds, order_index)
select gen_random_uuid(), 'a2000000-0000-0000-0000-000000000001', e.id, v.sets, v.reps, null, v.rest, v.ord
from (values
    ('Squat barre', 3, 10, 120, 0),
    ('Developpe couche barre', 3, 10, 120, 1),
    ('Rowing barre', 3, 10, 120, 2),
    ('Developpe militaire', 3, 12, 90, 3),
    ('Gainage planche', 3, 45, 60, 4)
) as v(name, sets, reps, rest, ord)
join exercises e on e.name = v.name;

-- Full Body B (a2..02)
insert into session_exercises (id, session_id, exercise_id, target_sets, target_reps, target_weight_kg, rest_seconds, order_index)
select gen_random_uuid(), 'a2000000-0000-0000-0000-000000000002', e.id, v.sets, v.reps, null, v.rest, v.ord
from (values
    ('Presse a cuisses', 3, 12, 120, 0),
    ('Pompes', 3, 12, 60, 1),
    ('Tirage vertical poulie', 3, 12, 90, 2),
    ('Elevations laterales', 3, 15, 60, 3),
    ('Crunch', 3, 20, 45, 4)
) as v(name, sets, reps, rest, ord)
join exercises e on e.name = v.name;

-- Full Body C (a2..03)
insert into session_exercises (id, session_id, exercise_id, target_sets, target_reps, target_weight_kg, rest_seconds, order_index)
select gen_random_uuid(), 'a2000000-0000-0000-0000-000000000003', e.id, v.sets, v.reps, null, v.rest, v.ord
from (values
    ('Fentes halteres', 3, 12, 90, 0),
    ('Developpe incline haltere', 3, 12, 90, 1),
    ('Traction pronation', 3, 8, 120, 2),
    ('Curl biceps barre', 3, 12, 60, 3),
    ('Mollets debout', 3, 15, 60, 4)
) as v(name, sets, reps, rest, ord)
join exercises e on e.name = v.name;

-- Upper (a3..01)
insert into session_exercises (id, session_id, exercise_id, target_sets, target_reps, target_weight_kg, rest_seconds, order_index)
select gen_random_uuid(), 'a3000000-0000-0000-0000-000000000001', e.id, v.sets, v.reps, null, v.rest, v.ord
from (values
    ('Developpe couche barre', 4, 6, 180, 0),
    ('Rowing barre', 4, 6, 180, 1),
    ('Developpe militaire', 3, 8, 150, 2),
    ('Traction pronation', 3, 8, 120, 3),
    ('Curl biceps barre', 3, 10, 60, 4),
    ('Extension triceps poulie', 3, 10, 60, 5)
) as v(name, sets, reps, rest, ord)
join exercises e on e.name = v.name;

-- Lower (a3..02)
insert into session_exercises (id, session_id, exercise_id, target_sets, target_reps, target_weight_kg, rest_seconds, order_index)
select gen_random_uuid(), 'a3000000-0000-0000-0000-000000000002', e.id, v.sets, v.reps, null, v.rest, v.ord
from (values
    ('Squat barre', 4, 6, 210, 0),
    ('Presse a cuisses', 3, 10, 150, 1),
    ('Hip thrust', 3, 10, 120, 2),
    ('Fentes halteres', 3, 12, 90, 3),
    ('Mollets debout', 4, 15, 60, 4),
    ('Gainage planche', 3, 45, 60, 5)
) as v(name, sets, reps, rest, ord)
join exercises e on e.name = v.name;
