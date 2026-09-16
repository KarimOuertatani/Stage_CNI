-- =====================================================================
--  Nutrition : libelle francais des aliments
-- ---------------------------------------------------------------------
--  Contexte : USDA FoodData Central est une base entierement anglophone
--  (« Chicken, broiler or fryer, breast, meat only, raw »), alors que
--  FitForge est une application francaise. Le backend traduit desormais
--  ces libelles via le lexique nutrition/lexique-aliments-fr.csv.
--
--  Pourquoi une colonne dediee plutot qu'une traduction a chaque lecture ?
--    * la traduction est faite UNE fois, a l'import de l'aliment ;
--    * le libelle francais devient CHERCHABLE dans le catalogue local,
--      qui sert de repli quand USDA est indisponible ou hors quota ;
--    * le libelle historique anglais reste dans `name`, ce qui permet de
--      regenerer la traduction apres tout enrichissement du lexique.
--
--  Colonne volontairement NULLABLE : les aliments importes avant cette
--  migration sont traduits a la volee puis rattrapes au premier usage
--  (voir FoodCatalogService#resolveOrImport). Aucun backfill bloquant.
--
--  Taille 512 (contre 255 pour `name`) : le francais est plus long que
--  l'anglais, une description USDA proche de la limite deborderait.
-- =====================================================================

alter table food_items add column name_fr varchar(512);

-- Recherche locale par libelle francais (repli hors ligne cote USDA).
create index idx_food_items_name_fr on food_items (name_fr);
