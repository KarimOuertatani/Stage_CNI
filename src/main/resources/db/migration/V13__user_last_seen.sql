-- =====================================================================
--  Presence : derniere activite connue d'un utilisateur
-- ---------------------------------------------------------------------
--  Le statut « en ligne » est porte par la session WebSocket/STOMP, qui
--  vit en MEMOIRE : elle disparait a la fermeture de l'app comme au
--  redemarrage du serveur. C'est exactement ce qu'on veut pour « en
--  ligne », mais cela ne dit rien de l'utilisateur ABSENT.
--
--  Cette colonne repond a la seule question qui reste : « vu quand ? ».
--  Elle est ecrite a chaque connexion ET a chaque deconnexion WebSocket,
--  ce qui garantit une valeur saine meme apres un redemarrage serveur
--  (sans elle, tout le monde apparaitrait « jamais vu »).
--
--  A NE PAS CONFONDRE avec last_login_at (V1), qui date l'authentification
--  et ne bouge plus tant que le token JWT reste valide.
-- =====================================================================

alter table users add column last_seen_at timestamp(6) with time zone;
