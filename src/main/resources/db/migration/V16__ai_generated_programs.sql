-- =====================================================================
--  Programmes generes par l'IA FitForge
-- ---------------------------------------------------------------------
--  L'adherent repond a un questionnaire (objectif, jours disponibles,
--  duree de seance, materiel, charges de reference, blessures...), le
--  serveur y ajoute son profil, et Gemini compose un programme complet.
--  Le resultat est MATERIALISE comme n'importe quel autre programme :
--  memes tables workout_programs / workout_sessions / session_exercises.
--
--  POURQUOI PAS UNE TABLE A PART ? Parce qu'un programme genere doit
--  vivre exactement comme les autres : on l'ouvre, on le modifie, on
--  ajoute une seance, on logue une serie dessus. Une table parallele
--  aurait impose de dupliquer tout l'ecran de detail et tout le suivi.
--  Trois colonnes suffisent a dire d'ou il vient.
-- =====================================================================

-- ── 1. Provenance du programme ───────────────────────────────────────
--  generated_by_ai joue le meme role que created_by pour un coach : il
--  dit QUI a compose le programme. L'app affiche « Cree avec l'IA
--  FitForge » la ou elle afficherait « Cree par <coach> ».
alter table workout_programs add column generated_by_ai boolean not null default false;

--  Le mot du coach IA : pourquoi CE decoupage, CE volume, CES exercices.
--  Ce n'est pas un ornement — c'est ce qui separe un programme qu'on
--  suit d'une liste d'exercices qu'on subit. Affiche en tete du detail.
alter table workout_programs add column ai_rationale text;

alter table workout_programs add column ai_generated_at timestamp(6) with time zone;

-- Un adherent consulte « mes programmes IA » assez souvent pour que le
-- filtre merite un index partiel (seules les lignes generees y entrent).
create index idx_programs_ai on workout_programs (user_id)
    where generated_by_ai = true;

-- ── 2. La consigne du coach, exercice par exercice ───────────────────
--  « Descends en 3 secondes », « garde 2 repetitions en reserve »,
--  « si le genou tire, reduis l'amplitude ». C'est ce qui distingue un
--  programme ecrit par un coach d'un tableau de series et de reps.
--
--  La colonne est sur session_exercises (et non reservee a l'IA) parce
--  qu'une consigne d'exercice n'a rien de specifique a l'IA : un coach
--  humain aura le meme besoin. Elle reste simplement vide sur les
--  programmes composes a la main aujourd'hui.
alter table session_exercises add column notes varchar(300);

-- ── 3. Journal des demandes de generation ────────────────────────────
--  Sert a trois choses, dans cet ordre d'importance :
--   1. PLAFONNER : chaque generation coute un appel Gemini avec un gros
--      contexte (catalogue d'exercices). Sans compteur, un appui repete
--      viderait le quota partage avec le coach IA, l'analyse photo et
--      l'ajout vocal.
--   2. REJOUER : le brief est conserve tel qu'il a ete envoye. Si un
--      programme est mauvais, on sait exactement sur quelles reponses il
--      a ete construit — sinon le diagnostic est impossible.
--   3. MESURER : combien de generations aboutissent reellement a un
--      programme (program_id non nul) ?
create table ai_program_requests (
    id             uuid not null,
    user_id        uuid not null,
    -- Programme produit. NULL si la generation a echoue : on garde quand
    -- meme la ligne, sinon les echecs seraient invisibles ET gratuits
    -- (ils consomment pourtant du quota).
    program_id     uuid,
    -- Le brief complet envoye au modele (questionnaire + profil), en
    -- texte lisible. Volontairement pas du JSON : c'est ce que le modele
    -- a reellement lu, on veut pouvoir le relire tel quel.
    brief          text not null,
    -- Message d'erreur quand la generation n'a rien produit.
    error_message  varchar(500),
    created_at     timestamp(6) with time zone not null,
    primary key (id)
);

alter table ai_program_requests
    add constraint fk_ai_program_requests_user foreign key (user_id) references users;

-- Le programme peut etre supprime par l'adherent : la demande, elle,
-- reste (c'est un journal). D'ou ON DELETE SET NULL plutot qu'un
-- CASCADE qui effacerait la trace de la generation.
alter table ai_program_requests
    add constraint fk_ai_program_requests_program foreign key (program_id)
        references workout_programs on delete set null;

-- Index (user_id, created_at) : exactement la requete du plafond
-- journalier — les demandes d'UN adherent depuis une date.
create index idx_ai_program_requests_user_created
    on ai_program_requests (user_id, created_at);
