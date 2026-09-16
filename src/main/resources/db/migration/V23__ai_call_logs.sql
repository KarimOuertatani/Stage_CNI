-- =====================================================================
--  V23 - Journal des appels aux modeles de langage (supervision)
-- ---------------------------------------------------------------------
--  Cinq fonctions de l'application appellent Gemini (coach IA, photo de
--  repas, ajout vocal, ajout ecrit, generation de programme) et se
--  PARTAGENT UNE SEULE CLE. Quand le quota tombe ou que le service
--  repond 503, tout s'arrete en meme temps -- sans qu'aucune trace ne
--  permette de dire laquelle a consomme le quota des autres.
--
--  Cette table repond a trois questions, et a trois seulement :
--  quelle fonction, combien de temps, quelle erreur.
--
--  CE QU'ELLE NE CONTIENT PAS, VOLONTAIREMENT : ni la question posee,
--  ni la reponse, ni la photo, ni l'audio, ni meme l'identifiant de
--  l'utilisateur. Ces appels transportent ce qu'un adherent mange, ses
--  blessures, ce qu'il demande a un coach. Les conserver pour tracer une
--  courbe de latence serait sans commune mesure avec le besoin, et
--  recreerait le journal de conversations que le projet a precisement
--  evite (cf. ai_coach_messages, dont les colonnes topic/refused
--  existent pour verifier le perimetre SANS relire les echanges).
-- =====================================================================
create table ai_call_logs (
    id         uuid         not null,
    feature    varchar(255) not null
               check (feature in ('COACH_CHAT', 'MEAL_PHOTO', 'MEAL_VOICE',
                                  'MEAL_TEXT', 'PROGRAM_GENERATION', 'HEALTH_PROBE')),
    success    boolean      not null,
    latency_ms bigint       not null,

    --  Nom de classe d'exception ou code HTTP ("HTTP_503"), JAMAIS le
    --  corps de la reponse : Google y reprend parfois la cle d'API
    --  fournie. Les clients du projet appliquent deja cette regle dans
    --  leurs journaux ; il serait vain de la respecter dans les logs
    --  pour l'enfreindre en base.
    error_type varchar(120),

    created_at timestamp(6) with time zone not null,
    primary key (id)
);

--  Index de la page de supervision : agregation par fonction sur une
--  fenetre de temps. L'ordre des colonnes suit celui du filtrage --
--  on filtre TOUJOURS sur la date, puis on regroupe par fonction.
create index idx_ai_call_logs_created on ai_call_logs (created_at desc);
create index idx_ai_call_logs_feature on ai_call_logs (feature, created_at desc);

--  Index partiel des echecs : la page affiche « les dernieres erreurs »,
--  qui sont une infime minorite des lignes en fonctionnement normal.
--  Un index partiel reste donc minuscule meme quand la table grossit.
create index idx_ai_call_logs_failures
    on ai_call_logs (created_at desc)
    where success = false;
