-- =====================================================================
--  V22 - Signalement d'un probleme par un adherent ou un coach
-- ---------------------------------------------------------------------
--  Jusqu'ici, un utilisateur bloque n'avait aucun moyen de le faire
--  savoir depuis l'application. Cette table porte le canal complet :
--  l'envoi, le suivi cote utilisateur, et le traitement cote console.
-- =====================================================================
create table problem_reports (
    id             uuid         not null,
    reporter_id    uuid         not null,

    --  Role FIGE au moment du signalement, et non lu dans users.
    --  Un adherent peut devenir coach ensuite ; le signalement doit
    --  continuer a dire depuis quel espace il a ete envoye, sans quoi on
    --  cherche un bug dans le mauvais ecran.
    reporter_role  varchar(255) not null check (reporter_role in ('ADHERENT', 'COACH', 'ADMIN')),

    category       varchar(255) not null
                   check (category in ('BUG', 'ACCOUNT', 'CONTENT', 'ABUSE', 'SUGGESTION', 'OTHER')),
    subject        varchar(255)  not null,
    description    varchar(4000) not null,

    --  Capture d'ecran : URL du media PUBLIC (/media/...), le meme
    --  mecanisme que les pieces jointes du chat. Ce n'est pas une piece
    --  d'identite, seulement un ecran de l'application.
    attachment_url varchar(255),

    --  Renseignes par l'application, pas par l'utilisateur : sans eux,
    --  tout signalement de bug commence par « quelle version ? ».
    platform       varchar(255),
    app_version    varchar(255),

    status         varchar(255) not null
                   check (status in ('NEW', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
    admin_response varchar(2000),
    handled_by     uuid,
    handled_at     timestamp(6) with time zone,
    created_at     timestamp(6) with time zone not null,
    updated_at     timestamp(6) with time zone,

    primary key (id),

    --  CASCADE : un signalement n'a plus de sens sans son auteur, et on
    --  ne peut de toute facon plus lui repondre. Le garder reviendrait a
    --  conserver le texte libre d'une personne dont le compte a disparu.
    constraint fk_problem_reports_reporter
        foreign key (reporter_id) references users (id) on delete cascade,

    --  SET NULL : si le compte de l'administrateur qui a traite est
    --  supprime, on perd l'auteur du traitement, pas le traitement.
    constraint fk_problem_reports_handler
        foreign key (handled_by) references users (id) on delete set null
);

--  « Mes signalements » : tous ceux d'un utilisateur, les plus recents d'abord.
create index idx_problem_reports_reporter on problem_reports (reporter_id, created_at desc);

--  File de la console : par statut, du plus ancien au plus recent.
create index idx_problem_reports_status on problem_reports (status, created_at);
