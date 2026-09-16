-- =====================================================================
--  Nutrition : Open Food Facts comme seconde source d'aliments
-- ---------------------------------------------------------------------
--  Pourquoi ? USDA FoodData Central couvre tres bien les aliments
--  GENERIQUES (banane crue, blanc de poulet, riz cuit) mais tres mal les
--  PRODUITS EMBALLES vendus en Europe : yaourts, barres cerealieres,
--  plats prepares, biscuits. Or c'est justement ce que l'adherent mange
--  le plus souvent -- et ce qui echouait le plus a l'ajout.
--
--  Open Food Facts est une base collaborative de plusieurs millions de
--  produits du commerce, indexes par CODE-BARRES. On l'interroge en
--  dernier recours (cache local -> USDA -> OFF) et on met en cache tout
--  produit retenu, exactement comme pour USDA.
--
--  Licence : donnees sous ODbL, la source doit etre creditee dans les
--  mentions legales de l'application.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. Le code-barres : cle de deduplication du cache cote Open Food Facts
-- ---------------------------------------------------------------------
--  Pendant de usda_fdc_id pour les produits emballes. TEXTE et non
--  numerique : un GTIN peut commencer par des zeros significatifs.
--  UNIQUE -> un produit n'est importe qu'une seule fois, quel que soit le
--  nombre d'adherents qui l'ajoutent.
alter table food_items add column off_code varchar(64);

alter table food_items
    add constraint uq_food_items_off_code unique (off_code);

create index idx_food_items_off_code on food_items (off_code);

-- ---------------------------------------------------------------------
--  2. Elargir la contrainte de provenance
-- ---------------------------------------------------------------------
--  V10 posait `check (source in ('USDA','CUSTOM'))` en contrainte de
--  colonne, donc SANS nom explicite : PostgreSQL l'a nommee lui-meme
--  (typiquement food_items_source_check). On la retrouve dynamiquement
--  plutot que de parier sur ce nom -- une base creee autrement pourrait
--  porter un suffixe different.
do $$
declare
    constraint_name text;
begin
    select con.conname into constraint_name
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    where rel.relname = 'food_items'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) like '%source%'
    limit 1;

    if constraint_name is not null then
        execute format('alter table food_items drop constraint %I', constraint_name);
    end if;
end $$;

alter table food_items
    add constraint food_items_source_check
    check (source in ('USDA', 'OPEN_FOOD_FACTS', 'CUSTOM'));

-- ---------------------------------------------------------------------
--  3. Coherence : un aliment porte l'identifiant de SA source
-- ---------------------------------------------------------------------
--  Garde-fou contre une ligne incoherente (un aliment USDA qui porterait
--  un code-barres OFF, ou l'inverse). CUSTOM n'a ni l'un ni l'autre.
alter table food_items
    add constraint food_items_source_identifier_check
    check (
        (source = 'USDA'            and off_code is null)
     or (source = 'OPEN_FOOD_FACTS' and usda_fdc_id is null and off_code is not null)
     or (source = 'CUSTOM'          and usda_fdc_id is null and off_code is null)
    );
