-- =====================================================================
--  Coach IA : le fil de discussion
-- ---------------------------------------------------------------------
--  L'adherent discute entrainement, nutrition et blessures avec un coach
--  IA (meme cle Gemini que l'analyse de photo et l'ajout vocal).
--
--  UN SEUL FIL PAR ADHERENT, et il est prive. Pas de table de
--  conversation : contrairement au chat humain, il n'existe pas de
--  CoachingRelationship a resoudre — le coach IA est toujours
--  disponible, sans demande de suivi ni acceptation.
--
--  POURQUOI PERSISTER ? Un coach qui oublie tout entre deux ouvertures
--  de l'app n'est pas un coach. L'historique sert a reafficher le fil,
--  mais surtout a le RENVOYER AU MODELE comme contexte : c'est ce qui
--  permet a « et pour les jambes ? » de vouloir dire quelque chose.
--
--  topic / refused sont des colonnes d'AUDIT : elles permettent de
--  verifier apres coup que le perimetre est bien tenu (combien de refus,
--  combien de questions blessure) sans avoir a relire les conversations
--  des adherents.
-- =====================================================================

create table ai_coach_messages (
    id          uuid not null,
    user_id     uuid not null,
    -- USER = ecrit par l'adherent, ASSISTANT = reponse du coach IA.
    -- La consigne systeme n'est JAMAIS stockee ici : elle appartient au
    -- code. Sinon elle serait modifiable par le contenu de la
    -- conversation, ce qui est precisement la faille a eviter.
    role        varchar(16) not null check (role in ('USER', 'ASSISTANT')),
    -- 4000 : la saisie de l'adherent est plafonnee bien plus bas (1000),
    -- mais une reponse de coach peut etre longue.
    content     varchar(4000) not null,
    topic       varchar(16) check (
                    topic in ('ENTRAINEMENT', 'NUTRITION', 'BLESSURE',
                              'MOTIVATION', 'HORS_SUJET')),
    -- Demande declinee pour sortie de perimetre. Le texte stocke est
    -- alors le refus DE L'APPLICATION, pas celui du modele.
    refused     boolean not null default false,
    created_at  timestamp(6) with time zone not null,
    primary key (id)
);

alter table ai_coach_messages
    add constraint fk_ai_coach_user foreign key (user_id) references users;

-- Index compose (user_id, created_at) : c'est exactement la requete du
-- chargement d'un fil — les messages d'UN adherent, dans l'ordre. Un
-- index sur user_id seul obligerait a trier apres coup.
create index idx_ai_coach_user_created on ai_coach_messages (user_id, created_at);
