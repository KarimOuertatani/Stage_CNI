-- =====================================================================
--  V20 - Validation des candidatures de coach par l'administration
-- ---------------------------------------------------------------------
--  Avant cette migration, un coach etait APPROVED des la creation de son
--  compte : il apparaissait dans l'annuaire et pouvait recevoir des
--  demandes de suivi sans qu'aucun diplome n'ait jamais ete verifie.
--
--  Cette migration apporte :
--    1. l'etat DRAFT (dossier en cours de constitution) ;
--    2. les colonnes de tracabilite de la decision ;
--    3. la table des justificatifs (piece d'identite, diplomes, certifs).
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. Elargir la contrainte de statut a la valeur DRAFT
-- ---------------------------------------------------------------------
--  /!\ PIEGE, deja rencontre en V14 sur food_items.
--
--  La contrainte de V4 a ete ecrite en CONTRAINTE DE COLONNE :
--
--      status varchar(255) not null check (status in ('PENDING', ...))
--
--  PostgreSQL lui a donc attribue un nom genere (coach_profiles_status_check
--  en general, mais rien ne le garantit -- le suffixe change des qu'un homonyme
--  existe). Ecrire « alter table ... drop constraint coach_profiles_status_check »
--  fonctionnerait sur cette base et echouerait sur une autre.
--
--  On la retrouve donc dynamiquement : on cherche, parmi les contraintes de
--  verification de la table, celle dont la definition mentionne la colonne
--  status, et on la supprime par son vrai nom.
do $$
declare
    constraint_name text;
begin
    select con.conname into constraint_name
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where rel.relname = 'coach_profiles'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) like '%status%'
    limit 1;

    if constraint_name is not null then
        execute format('alter table coach_profiles drop constraint %I', constraint_name);
    end if;
end $$;

alter table coach_profiles
    add constraint coach_profiles_status_check
    check (status in ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED'));

-- ---------------------------------------------------------------------
--  2. Tracabilite de la decision
-- ---------------------------------------------------------------------
alter table coach_profiles add column if not exists submitted_at     timestamp(6) with time zone;
alter table coach_profiles add column if not exists reviewed_at      timestamp(6) with time zone;
alter table coach_profiles add column if not exists reviewed_by      uuid;
alter table coach_profiles add column if not exists rejection_reason varchar(1000);

alter table coach_profiles
    add constraint fk_coach_profiles_reviewed_by
    foreign key (reviewed_by) references users (id) on delete set null;

--  ON DELETE SET NULL, et non CASCADE : si le compte administrateur qui a
--  valide un coach est un jour supprime, c'est l'AUTEUR de la decision qu'on
--  perd, pas la decision elle-meme. Un CASCADE effacerait le profil du coach.

-- ---------------------------------------------------------------------
--  3. Les coachs deja en place restent APPROVED
-- ---------------------------------------------------------------------
--  Ils exercent aujourd'hui, certains ont des adherents en suivi et des
--  conversations ouvertes. Les basculer en DRAFT « pour regulariser »
--  couperait ces suivis du jour au lendemain, sans que ni le coach ni son
--  adherent n'aient rien fait. La regle nouvelle s'applique aux nouvelles
--  inscriptions ; l'existant est repute valide, et l'administration dispose
--  de SUSPENDED pour traiter un cas particulier a posteriori.
--
--  On leur pose malgre tout une date de soumission et d'examen, pour que les
--  ecrans n'aient pas a traiter un APPROVED sans aucune date.
update coach_profiles
   set submitted_at = coalesce(submitted_at, now()),
       reviewed_at  = coalesce(reviewed_at, now())
 where status = 'APPROVED';

-- ---------------------------------------------------------------------
--  4. Les justificatifs
-- ---------------------------------------------------------------------
--  storage_key n'est PAS une URL : c'est le nom du fichier dans le dossier
--  prive (app.media.private-dir), que rien ne sert statiquement. Les
--  justificatifs ne peuvent donc pas etre lus par simple connaissance d'une
--  URL, contrairement aux fichiers de /media/**.
create table coach_documents (
    id               uuid          not null,
    coach_profile_id uuid          not null,
    type             varchar(255)  not null check (type in ('IDENTITY', 'DIPLOMA', 'CERTIFICATION', 'OTHER')),
    label            varchar(255),
    storage_key      varchar(255)  not null,
    original_name    varchar(255),
    content_type     varchar(255),
    size_bytes       bigint,
    uploaded_at      timestamp(6) with time zone not null,
    primary key (id),
    constraint fk_coach_documents_profile
        foreign key (coach_profile_id) references coach_profiles (id) on delete cascade
);

--  CASCADE ici : un justificatif n'a aucune existence propre. Si le profil
--  disparait, garder la photo d'une piece d'identite orpheline serait au mieux
--  inutile, au pire une donnee personnelle conservee sans motif.

create index idx_coach_documents_profile on coach_documents (coach_profile_id);

--  Index de la file d'attente de l'administrateur : « les dossiers soumis, du
--  plus ancien au plus recent ». C'est la requete la plus frequente de la
--  console, et la seule qui grandit avec le nombre d'inscriptions.
create index idx_coach_profiles_status_submitted on coach_profiles (status, submitted_at);
