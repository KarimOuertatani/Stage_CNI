-- =====================================================================
--  Nutrition : catalogue d'aliments (cache USDA FoodData Central)
-- ---------------------------------------------------------------------
--  Objectif : l'adherent ne saisit plus les macros a la main. Il cherche
--  un aliment, saisit une quantite en grammes, et le serveur calcule les
--  macros au prorata a partir des valeurs POUR 100 g.
--
--  * food_items : catalogue local. Chaque aliment recupere depuis USDA y
--    est stocke DEFINITIVEMENT (cle usda_fdc_id unique) -> on ne rappelle
--    jamais l'API externe pour le meme aliment. Accueille aussi les
--    aliments personnalises (source = CUSTOM, usda_fdc_id null).
--
--  * nutrition_entries gagne :
--      - food_item_id : provenance de l'entree (null = saisie manuelle),
--      - fiber_g      : fibres, macro renvoyee par USDA et jusqu'ici absente.
--
--  Types alignes sur les entites JPA (Hibernate en mode validate).
-- =====================================================================

create table food_items (
    id                uuid not null,
    name              varchar(255) not null,
    brand             varchar(255),
    -- Cle de deduplication du cache : un fdcId USDA n'est importe qu'une fois.
    usda_fdc_id       bigint unique,
    data_type         varchar(32),
    source            varchar(255) not null check (source in ('USDA','CUSTOM')),
    -- Valeurs nutritionnelles POUR 100 g (convention USDA).
    calories_per100g  float(53),
    protein_per100g   float(53),
    carbs_per100g     float(53),
    fat_per100g       float(53),
    fiber_per100g     float(53),
    created_at        timestamp(6) with time zone not null,
    primary key (id)
);

-- Recherche par libelle dans le catalogue local (avant d'interroger USDA).
create index idx_food_items_name on food_items (name);

-- ---------------------------------------------------------------------
--  Journal alimentaire : provenance + fibres
-- ---------------------------------------------------------------------
alter table nutrition_entries add column food_item_id uuid;

-- ATTENTION au nom de colonne : la strategie de nommage Hibernate transforme
-- le champ Java `fiberG` en `fiberg` (et NON `fiber_g`) — une majuscule isolee
-- en fin de nom ne genere pas de underscore. C'est deja le cas des colonnes
-- existantes proteing / carbsg / fatg (voir V1). Utiliser `fiber_g` ici ferait
-- echouer le demarrage : « Schema validation: missing column [fiberg] ».
alter table nutrition_entries add column fiberg float(53);

alter table nutrition_entries
    add constraint fk_nutrition_food_item foreign key (food_item_id) references food_items;

create index idx_nutrition_food_item on nutrition_entries (food_item_id);
