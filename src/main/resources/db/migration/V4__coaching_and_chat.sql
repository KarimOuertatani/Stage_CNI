-- =====================================================================
--  Partie COACH : profils coach + relation de suivi adherent<->coach + chat
-- ---------------------------------------------------------------------
--  - coach_profiles           : CV professionnel du coach (1-1 users)
--  - coach_specialties        : specialites (ElementCollection)
--  - coach_certifications     : certifications / diplomes pro
--  - coach_educations         : formations / etudes
--  - coach_experiences        : experiences professionnelles
--  - coaching_relationships   : demande + suivi (aussi le "fil" de chat)
--  - chat_messages            : messages persistes (temps reel via WebSocket)
--
--  Types alignes sur les entites JPA (Hibernate en mode validate).
-- =====================================================================

-- ---------------------------------------------------------------------
--  Profil coach
-- ---------------------------------------------------------------------
create table coach_profiles (
    id                uuid not null,
    user_id           uuid not null unique,
    headline          varchar(255),
    bio               varchar(2000),
    years_experience  integer,
    hourly_rate       float(53),
    city              varchar(255),
    status            varchar(255) not null check (status in ('PENDING','APPROVED','REJECTED','SUSPENDED')),
    accepting_clients boolean not null,
    rating_average    float(53) not null,
    rating_count      integer not null,
    primary key (id),
    constraint fk_coach_profiles_user foreign key (user_id) references users
);

create table coach_specialties (
    coach_profile_id uuid not null,
    specialty        varchar(255) check (specialty in (
        'MUSCULATION','PERTE_POIDS','PRISE_MASSE','FORCE','CROSSFIT',
        'CARDIO_ENDURANCE','YOGA_MOBILITE','NUTRITION','PREPARATION_PHYSIQUE',
        'REEDUCATION','HALTEROPHILIE','FITNESS_FEMININ')),
    constraint fk_coach_specialties_profile foreign key (coach_profile_id) references coach_profiles
);

create table coach_certifications (
    id               uuid not null,
    coach_profile_id uuid not null,
    title            varchar(255) not null,
    organization     varchar(255),
    year             integer,
    credential_url   varchar(255),
    primary key (id),
    constraint fk_coach_certifications_profile foreign key (coach_profile_id) references coach_profiles
);

create table coach_educations (
    id               uuid not null,
    coach_profile_id uuid not null,
    degree           varchar(255) not null,
    institution      varchar(255),
    field_of_study   varchar(255),
    year             integer,
    primary key (id),
    constraint fk_coach_educations_profile foreign key (coach_profile_id) references coach_profiles
);

create table coach_experiences (
    id               uuid not null,
    coach_profile_id uuid not null,
    title            varchar(255) not null,
    organization     varchar(255),
    start_year       integer,
    end_year         integer,
    description      varchar(1000),
    primary key (id),
    constraint fk_coach_experiences_profile foreign key (coach_profile_id) references coach_profiles
);

-- ---------------------------------------------------------------------
--  Relation de suivi (demande + suivi actif = fil de conversation)
-- ---------------------------------------------------------------------
create table coaching_relationships (
    id              uuid not null,
    coach_id        uuid not null,
    member_id       uuid not null,
    status          varchar(255) not null check (status in ('PENDING','ACCEPTED','DECLINED','ENDED')),
    request_message varchar(1000),
    created_at      timestamp(6) with time zone not null,
    responded_at    timestamp(6) with time zone,
    ended_at        timestamp(6) with time zone,
    primary key (id),
    constraint fk_coaching_coach foreign key (coach_id) references users,
    constraint fk_coaching_member foreign key (member_id) references users
);

create index idx_coaching_coach on coaching_relationships (coach_id);
create index idx_coaching_member on coaching_relationships (member_id);

-- ---------------------------------------------------------------------
--  Messages de chat
-- ---------------------------------------------------------------------
create table chat_messages (
    id              uuid not null,
    relationship_id uuid not null,
    sender_id       uuid not null,
    content         varchar(2000) not null,
    sent_at         timestamp(6) with time zone not null,
    read_at         timestamp(6) with time zone,
    primary key (id),
    constraint fk_chat_relationship foreign key (relationship_id) references coaching_relationships,
    constraint fk_chat_sender foreign key (sender_id) references users
);

create index idx_chat_relationship on chat_messages (relationship_id);
