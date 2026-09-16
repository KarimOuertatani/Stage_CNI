-- =====================================================================
--  FitForge AI - Schema initial (Partie 1 : adherent)
-- ---------------------------------------------------------------------
--  Ce script cree toutes les tables de la partie adherent. Il correspond
--  EXACTEMENT aux entites JPA (Hibernate est en mode "validate" : il
--  refuse de demarrer si une colonne ne correspond pas).
--
--  Conventions :
--   - id en uuid (genere par Hibernate cote application).
--   - float(53) = double precision (Double Java).
--   - timestamp with time zone = Instant Java.
--   - les enums sont stockes en varchar avec un check de valeurs autorisees.
-- =====================================================================

-- ---------------------------------------------------------------------
--  DOMAINE user : compte, profil, mensurations
-- ---------------------------------------------------------------------

-- Compte & authentification
create table users (
    id            uuid not null,
    email         varchar(255) not null unique,
    password_hash varchar(255) not null,
    full_name     varchar(255) not null,
    phone_number  varchar(255),
    avatar_url    varchar(255),
    role          varchar(255) not null check (role in ('ADHERENT','COACH','ADMIN')),
    enabled       boolean not null,
    email_verified boolean not null,
    created_at    timestamp(6) with time zone not null,
    updated_at    timestamp(6) with time zone not null,
    last_login_at timestamp(6) with time zone,
    primary key (id)
);

-- Profil physique & sportif (1-1 avec users)
create table user_profiles (
    id                     uuid not null,
    user_id                uuid not null unique,
    birth_date             date,
    gender                 varchar(255) check (gender in ('HOMME','FEMME','AUTRE')),
    height_cm              float(53),
    current_weight_kg      float(53),
    target_weight_kg       float(53),
    goal                   varchar(255) check (goal in ('PERTE_POIDS','PRISE_MASSE','MAINTIEN','FORCE','ENDURANCE')),
    activity_level         varchar(255) check (activity_level in ('SEDENTAIRE','LEGER','MODERE','ACTIF','TRES_ACTIF')),
    experience_level       varchar(255) check (experience_level in ('DEBUTANT','INTERMEDIAIRE','AVANCE')),
    weekly_workout_target  integer,
    preferred_location     varchar(255) check (preferred_location in ('SALLE','MAISON','EXTERIEUR')),
    medical_notes          varchar(1000),
    dietary_preference     varchar(255) check (dietary_preference in ('AUCUNE','VEGETARIEN','VEGAN','HALAL','SANS_GLUTEN','KETO')),
    daily_calorie_target   integer,
    water_target_ml        integer,
    average_sleep_hours    float(53),
    unit_system            varchar(255) check (unit_system in ('METRIQUE','IMPERIAL')),
    preferred_language     varchar(255),
    bmi                    float(53),
    tdee                   integer,
    age                    integer,
    onboarding_completed   boolean not null,
    updated_at             timestamp(6) with time zone not null,
    primary key (id),
    constraint fk_user_profiles_user foreign key (user_id) references users
);

-- Listes rattachees au profil (@ElementCollection)
create table user_workout_days (
    profile_id uuid not null,
    day        varchar(255) check (day in ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY')),
    constraint fk_workout_days_profile foreign key (profile_id) references user_profiles
);

create table user_equipment (
    profile_id uuid not null,
    equipment  varchar(255) check (equipment in ('BARRE','HALTERE','MACHINE','POULIE','KETTLEBELL','POIDS_CORPS','ELASTIQUE')),
    constraint fk_equipment_profile foreign key (profile_id) references user_profiles
);

create table user_injuries (
    profile_id uuid not null,
    injury     varchar(255),
    constraint fk_injuries_profile foreign key (profile_id) references user_profiles
);

create table user_allergies (
    profile_id uuid not null,
    allergy    varchar(255),
    constraint fk_allergies_profile foreign key (profile_id) references user_profiles
);

-- Historique des mensurations (N-1 avec users)
create table body_measurements (
    id               uuid not null,
    user_id          uuid not null,
    measured_on      date not null,
    weight_kg        float(53),
    body_fat_percent float(53),
    waist_cm         float(53),
    chest_cm         float(53),
    arm_cm           float(53),
    thigh_cm         float(53),
    primary key (id),
    constraint fk_measurements_user foreign key (user_id) references users
);

-- ---------------------------------------------------------------------
--  DOMAINE training : exercices, programmes, seances, logs
-- ---------------------------------------------------------------------

-- Referentiel d'exercices
create table exercises (
    id             uuid not null,
    name           varchar(255) not null,
    primary_muscle varchar(255) check (primary_muscle in ('PECTORAUX','DOS','JAMBES','EPAULES','BICEPS','TRICEPS','ABDOS','FESSIERS','MOLLETS','CARDIO')),
    equipment      varchar(255) check (equipment in ('BARRE','HALTERE','MACHINE','POULIE','KETTLEBELL','POIDS_CORPS','ELASTIQUE')),
    instructions   varchar(1000),
    video_url      varchar(255),
    primary key (id)
);

-- Programmes (1 user -> N programmes)
create table workout_programs (
    id             uuid not null,
    user_id        uuid not null,
    title          varchar(255),
    goal           varchar(255) check (goal in ('PERTE_POIDS','PRISE_MASSE','MAINTIEN','FORCE','ENDURANCE')),
    duration_weeks integer,
    is_template    boolean not null,
    primary key (id),
    constraint fk_programs_user foreign key (user_id) references users
);

-- Seances-types (1 programme -> N seances)
create table workout_sessions (
    id          uuid not null,
    program_id  uuid not null,
    title       varchar(255),
    day_of_week integer,
    order_index integer,
    primary key (id),
    constraint fk_sessions_program foreign key (program_id) references workout_programs
);

-- Exercices places dans une seance (liaison enrichie)
create table session_exercises (
    id               uuid not null,
    session_id       uuid not null,
    exercise_id      uuid not null,
    target_sets      integer,
    target_reps      integer,
    target_weight_kg float(53),
    rest_seconds     integer,
    order_index      integer,
    primary key (id),
    constraint fk_session_exercises_session foreign key (session_id) references workout_sessions,
    constraint fk_session_exercises_exercise foreign key (exercise_id) references exercises
);

-- Seances effectuees (1 user -> N logs)
create table workout_logs (
    id               uuid not null,
    user_id          uuid not null,
    session_id       uuid,
    performed_on     date not null,
    duration_minutes integer,
    rpe              integer,
    primary key (id),
    constraint fk_logs_user foreign key (user_id) references users,
    constraint fk_logs_session foreign key (session_id) references workout_sessions
);

-- Series realisees (1 log -> N series)
create table set_logs (
    id             uuid not null,
    workout_log_id uuid not null,
    exercise_id    uuid not null,
    set_number     integer,
    reps           integer,
    weight_kg      float(53),
    completed      boolean not null,
    primary key (id),
    constraint fk_setlogs_log foreign key (workout_log_id) references workout_logs,
    constraint fk_setlogs_exercise foreign key (exercise_id) references exercises
);

-- ---------------------------------------------------------------------
--  DOMAINE nutrition : journal alimentaire
-- ---------------------------------------------------------------------
create table nutrition_entries (
    id             uuid not null,
    user_id        uuid not null,
    consumed_on    date not null,
    meal_type      varchar(255) check (meal_type in ('PETIT_DEJ','DEJEUNER','DINER','COLLATION')),
    food_name      varchar(255),
    quantity_grams float(53),
    calories       integer,
    proteing       float(53),
    carbsg         float(53),
    fatg           float(53),
    primary key (id),
    constraint fk_nutrition_user foreign key (user_id) references users
);

-- ---------------------------------------------------------------------
--  DOMAINE score : score d'entrainement hebdomadaire
-- ---------------------------------------------------------------------
create table training_scores (
    id                 uuid not null,
    user_id            uuid not null,
    score_date         date not null,
    score              integer,
    weekly_volume_kg   float(53),
    sessions_completed integer,
    consistency_rate   float(53),
    insight            varchar(500),
    primary key (id),
    constraint fk_scores_user foreign key (user_id) references users
);

-- ---------------------------------------------------------------------
--  INDEX sur les cles etrangeres les plus consultees (performances)
-- ---------------------------------------------------------------------
create index idx_measurements_user on body_measurements (user_id);
create index idx_programs_user on workout_programs (user_id);
create index idx_sessions_program on workout_sessions (program_id);
create index idx_session_exercises_session on session_exercises (session_id);
create index idx_logs_user_date on workout_logs (user_id, performed_on);
create index idx_setlogs_log on set_logs (workout_log_id);
create index idx_nutrition_user_date on nutrition_entries (user_id, consumed_on);
create index idx_scores_user_date on training_scores (user_id, score_date);
