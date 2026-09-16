-- =====================================================================
--  Journal de sommeil
-- ---------------------------------------------------------------------
--  Une ligne par NUIT : l'heure de coucher, l'heure de lever, et la
--  duree qui en decoule. L'adherent la saisit une fois par jour, a la
--  premiere ouverture de l'application.
--
--  POURQUOI PAS SIMPLEMENT user_profiles.average_sleep_hours ?
--  Cette colonne existe deja, et elle reste : c'est une moyenne DECLAREE
--  a l'inscription (« je dors environ 7 h »). Elle repond a « comment
--  dors-tu en general ? », pas a « comment as-tu dormi cette nuit ? ».
--  Un historique par nuit permet trois choses qu'une moyenne declaree ne
--  permettra jamais : montrer une semaine, mesurer la REGULARITE (deux
--  personnes a 7 h de moyenne ne dorment pas pareil si l'une alterne
--  4 h et 10 h), et rattacher une baisse de forme a une periode precise.
--
--  La moyenne declaree est desormais recalculee a partir des nuits
--  reellement saisies (voir SleepService) : le coach IA et le generateur
--  de programme, qui la lisent deja, deviennent plus justes sans changer
--  une ligne de leur code.
-- =====================================================================

create table sleep_entries (
    id               uuid not null,
    user_id          uuid not null,

    -- LA DATE DU REVEIL, et non celle du coucher. Une nuit a cheval sur
    -- deux jours doit etre rangee quelque part, et le reveil est le seul
    -- reperage qui ne bouge pas : quelqu'un qui se couche a 23 h et
    -- quelqu'un qui se couche a 1 h du matin parlent de la meme nuit,
    -- mais pas du meme jour de coucher. C'est aussi le jour ou l'adherent
    -- ouvre l'application pour saisir sa nuit.
    sleep_date       date not null,

    bed_time         time not null,
    wake_time        time not null,

    -- Duree DERIVEE (bed_time -> wake_time, passage de minuit gere), mais
    -- STOCKEE. Elle est lue bien plus souvent qu'ecrite — chaque affichage
    -- d'une semaine, chaque calcul de moyenne, chaque score — et la
    -- recalculer a la volee imposerait de reproduire partout la regle du
    -- passage de minuit. Une seule ecriture, un seul endroit ou se tromper.
    duration_minutes integer not null,

    created_at       timestamp(6) with time zone not null,
    updated_at       timestamp(6) with time zone not null,

    primary key (id)
);

alter table sleep_entries
    add constraint fk_sleep_entries_user foreign key (user_id) references users;

-- UNE SEULE NUIT PAR DATE ET PAR ADHERENT. C'est ce qui rend la saisie
-- REJOUABLE : reouvrir le formulaire et renvoyer sa nuit corrige la
-- valeur au lieu d'en empiler une seconde. Sans cette contrainte, un
-- double appui produirait deux nuits le meme jour et fausserait toutes
-- les moyennes en silence.
alter table sleep_entries
    add constraint uk_sleep_entries_user_date unique (user_id, sleep_date);

-- Index (user_id, sleep_date desc) : c'est exactement la requete de
-- l'ecran — les nuits d'UN adherent sur une plage de dates, les plus
-- recentes d'abord. La contrainte unique ci-dessus cree deja un index
-- sur (user_id, sleep_date), mais en ordre croissant ; celui-ci sert la
-- recherche de la DERNIERE nuit, qui est l'appel le plus frequent
-- (tuile de l'accueil, a chaque ouverture).
create index idx_sleep_entries_user_date on sleep_entries (user_id, sleep_date desc);

-- Une duree hors de ces bornes n'est pas une nuit : c'est une erreur de
-- saisie ou un appel malveillant. 15 minutes a 16 heures laisse passer
-- la sieste la plus courte comme la grasse matinee la plus longue.
alter table sleep_entries
    add constraint ck_sleep_entries_duration check (duration_minutes between 15 and 960);
