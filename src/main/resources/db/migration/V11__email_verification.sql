-- =====================================================================
--  Verification de l'adresse email par code a 6 chiffres
-- ---------------------------------------------------------------------
--  A l'inscription, le compte est cree avec enabled = false. Un code a
--  6 chiffres (SecureRandom) valable 10 minutes est envoye par email ;
--  le login JWT reste refuse tant que le compte n'est pas verifie.
--
--  Le code n'est JAMAIS stocke en clair : seule son empreinte BCrypt est
--  conservee (code_hash), comme pour un mot de passe.
--
--  Une seule ligne active par utilisateur (user_id unique) : demander un
--  nouveau code remplace le precedent.
--
--  Types alignes sur l'entite JPA (Hibernate en mode validate).
-- =====================================================================

create table email_verification_codes (
    id         uuid not null,
    user_id    uuid not null unique,
    code_hash  varchar(255) not null,
    expires_at timestamp(6) with time zone not null,
    attempts   integer not null,
    created_at timestamp(6) with time zone not null,
    primary key (id),
    constraint fk_email_verif_user foreign key (user_id) references users
);

create index idx_email_verif_user on email_verification_codes (user_id);

-- ---------------------------------------------------------------------
--  Comptes existants : ils ont ete crees AVANT la verification d'email.
--  On les considere verifies pour ne pas les bloquer retroactivement
--  (ils sont deja enabled = true ; on aligne juste email_verified).
-- ---------------------------------------------------------------------
update users set email_verified = true where enabled = true;
