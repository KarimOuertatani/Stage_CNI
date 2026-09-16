-- =====================================================================
--  V21 - Notifications de la console d'administration
-- ---------------------------------------------------------------------
--  Un enregistrement par EVENEMENT (candidature soumise, adherent
--  inscrit, probleme signale), et non un compteur recalcule.
--
--  Pourquoi ? Un « select count(*) » sur coach_profiles dirait combien
--  de dossiers attendent, mais ne pourrait jamais etre marque comme lu :
--  l'administrateur reverrait indefiniment ce qu'il a deja traite. Le
--  read_at ci-dessous est precisement ce qu'un compteur ne peut pas
--  porter.
-- =====================================================================
create table admin_notifications (
    id         uuid         not null,
    type       varchar(255) not null
               check (type in ('COACH_APPLICATION_SUBMITTED', 'MEMBER_REGISTERED', 'PROBLEM_REPORTED')),
    title      varchar(255) not null,
    body       varchar(500),
    --  Aucune cle etrangere sur target_id, VOLONTAIREMENT : une
    --  notification est le recit d'un evenement passe et doit survivre a
    --  la suppression de ce qu'elle designe. Une contrainte
    --  referentielle imposerait de choisir entre effacer l'historique
    --  (CASCADE) et bloquer la suppression du compte (RESTRICT) : deux
    --  mauvaises reponses a une question qui ne devrait pas se poser.
    target_id  uuid,
    read_at    timestamp(6) with time zone,
    created_at timestamp(6) with time zone not null,
    primary key (id)
);

--  Index de la cloche : « les non lues, les plus recentes d'abord ».
--  Partiel (where read_at is null) parce que c'est la seule question
--  posee en continu, et que l'index reste petit meme quand la table
--  grandit -- les lignes lues en sortent au lieu de l'alourdir.
create index idx_admin_notifications_unread
    on admin_notifications (created_at desc)
    where read_at is null;

--  Index de la page « toutes les notifications », qui pagine par date.
create index idx_admin_notifications_created on admin_notifications (created_at desc);
