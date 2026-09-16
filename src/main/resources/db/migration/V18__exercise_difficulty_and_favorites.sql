-- =====================================================================
--  Niveau de difficulte des exercices + favoris de l'adherent
-- ---------------------------------------------------------------------
--  DEUX MANQUES QUI SE REJOIGNENT : retrouver un exercice.
--
--  1) LE NIVEAU. Jusqu'ici, l'application DEDUISAIT le niveau d'un
--     exercice de son seul materiel, cote client : « barre = avance,
--     machine = intermediaire ». La deduction est fausse aussi souvent
--     qu'elle est juste (un curl a la barre n'est pas un arrache), elle
--     etait recalculee a chaque affichage, et elle ne pouvait pas servir
--     de FILTRE cote serveur ni etre lue par le generateur de programme.
--     On stocke donc le niveau. Le calcul lui-meme reste en Java
--     (ExerciseDifficultyRules) et non dans un CASE SQL ici : la meme
--     regle sert a l'import de nouveaux exercices, et une regle ecrite
--     deux fois est une regle qui divergera. Cette migration cree la
--     colonne ; ExerciseDifficultyBackfiller la remplit au demarrage
--     pour toutes les lignes encore nulles (base existante comme base
--     neuve, sans aucun appel a l'API externe).
--
--  2) LES FAVORIS. Le catalogue compte 220 exercices ; un adherent en
--     pratique une quinzaine. Les mettre en favori evite de retraverser
--     zone -> liste -> recherche a chaque seance. Cote serveur et non
--     dans le telephone : un favori suit l'adherent d'un appareil a
--     l'autre et survit a une reinstallation.
-- =====================================================================

alter table exercises
    add column difficulty varchar(20);

-- Le filtre « niveau » est presque toujours combine a une zone du corps
-- (« exercices de dos pour debutant »), d'ou l'index compose. L'ordre
-- (body_part, difficulty) et non l'inverse : body_part est le critere le
-- plus selectif des deux — 15 valeurs contre 3.
create index idx_exercises_bodypart_difficulty on exercises (body_part, difficulty);

create table exercise_favorites (
    id          uuid not null,
    user_id     uuid not null,
    exercise_id uuid not null,
    created_at  timestamp(6) with time zone not null,

    primary key (id)
);

alter table exercise_favorites
    add constraint fk_exercise_favorites_user foreign key (user_id) references users;

-- ON DELETE CASCADE cote exercice : si un exercice disparait du
-- catalogue, les favoris qui le designent n'ont plus d'objet. Sans le
-- cascade, la suppression echouerait sur une contrainte et laisserait le
-- catalogue impossible a nettoyer.
alter table exercise_favorites
    add constraint fk_exercise_favorites_exercise foreign key (exercise_id)
        references exercises (id) on delete cascade;

-- UN SEUL FAVORI PAR EXERCICE ET PAR ADHERENT. C'est ce qui rend l'appel
-- « ajouter aux favoris » REJOUABLE : un double appui, ou un retry reseau,
-- ne cree pas deux lignes. Cet index sert aussi la lecture principale
-- (« mes favoris »), qui filtre sur user_id.
alter table exercise_favorites
    add constraint uk_exercise_favorites unique (user_id, exercise_id);
