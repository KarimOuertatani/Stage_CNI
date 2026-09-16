-- =====================================================================
--  Pieces jointes du chat : image, message vocal, document.
-- ---------------------------------------------------------------------
--  - content devient nullable (un message peut n'avoir qu'une piece jointe)
--  - colonnes attachment_* : URL publique + metadonnees du fichier
--  Types alignes sur l'entite ChatMessage (Hibernate en mode validate).
-- =====================================================================

alter table chat_messages alter column content drop not null;

alter table chat_messages add column attachment_url          varchar(255);
alter table chat_messages add column attachment_kind         varchar(255)
        check (attachment_kind in ('IMAGE','AUDIO','FILE'));
alter table chat_messages add column attachment_name         varchar(255);
alter table chat_messages add column attachment_size         bigint;
alter table chat_messages add column attachment_duration_sec integer;
