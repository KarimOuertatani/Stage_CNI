-- =====================================================================
--  Programmes crees par un coach pour un adherent
-- ---------------------------------------------------------------------
--  Ajoute la colonne created_by : l'auteur du programme quand il differe
--  du proprietaire (ex : un COACH compose un programme pour son adherent).
--  Le programme reste rattache a l'adherent (user_id) : il apparait donc
--  dans SA liste de programmes, avec la mention du coach createur.
-- =====================================================================
alter table workout_programs add column created_by uuid;

alter table workout_programs
    add constraint fk_programs_created_by foreign key (created_by) references users;

create index idx_programs_created_by on workout_programs (created_by);
