package com.fitforge.api.nutrition.i18n;

import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Traducteur culinaire anglais &lt;-&gt; francais du module Nutrition.
 *
 * <p><b>Le probleme resolu.</b> USDA FoodData Central est une base
 * <b>entierement anglophone</b>, alors que FitForge est une application
 * francaise. Sans cette couche, l'adherent qui tape « poulet » obtient zero
 * resultat, et les rares resultats obtenus s'affichent « Chicken, broiler or
 * fryer, breast, meat only, raw ».
 *
 * <p><b>Deux sens, un seul lexique.</b> Le fichier
 * {@code nutrition/lexique-aliments-fr.csv} alimente deux index :
 * <ul>
 *   <li><b>FR -&gt; EN</b> ({@link #toEnglishQuery}) : traduit la saisie avant
 *       l'appel USDA ;</li>
 *   <li><b>EN -&gt; FR</b> ({@link #toFrenchLabel}) : traduit le libelle USDA
 *       avant l'affichage et avant la mise en cache.</li>
 * </ul>
 *
 * <p><b>Pourquoi un lexique plutot qu'une API de traduction ?</b> Les libelles
 * USDA suivent une grammaire tres reguliere (« aliment, variete, partie,
 * preparation ») avec un vocabulaire ferme de quelques centaines de termes. Un
 * lexique donne ici de <b>meilleurs</b> resultats qu'un traducteur generaliste
 * (qui rend « broiler or fryer » par « rotissoire ou friteuse »), sans cle, sans
 * quota, sans latence reseau et de facon parfaitement reproductible.
 *
 * <p><b>Degradation gracieuse.</b> Un terme inconnu traverse tel quel, et un
 * fichier illisible desactive la traduction sans jamais empecher le demarrage :
 * la recherche continue de fonctionner, simplement en anglais.
 *
 * <p>Cette classe est immuable apres construction, donc utilisable sans
 * synchronisation par toutes les requetes.
 */
@Component
@Slf4j
public class FoodLexicon {

    private static final String RESOURCE_PATH = "nutrition/lexique-aliments-fr.csv";

    /**
     * Plafond de securite du nombre de mots d'une expression. Le maximum reel
     * est calcule au chargement ; cette borne evite qu'une ligne aberrante ne
     * rende l'appariement quadratique.
     */
    private static final int MAX_PHRASE_WORDS = 5;

    /**
     * Articles et prepositions francais sans equivalent utile dans une requete
     * USDA. Ils ne sont retires que s'ils n'ont ete <b>absorbes par aucune
     * expression</b> du lexique : « blanc de poulet » est traduit en entier,
     * tandis que le « de » isole de « filet de X » disparait.
     */
    private static final Set<String> ARTICLES_FR =
            Set.of("de", "du", "des", "d", "le", "la", "les", "l", "un", "une", "au", "aux", "a", "en");

    /** Index anglais -> francais, cle normalisee. */
    private final Map<String, String> enToFr;
    /** Index francais -> anglais, cle normalisee (accents neutralises). */
    private final Map<String, String> frToEn;

    /** Longueur reelle de la plus longue expression de chaque index (en mots). */
    private final int longestEn;
    private final int longestFr;

    public FoodLexicon() {
        Map<String, String> en = new HashMap<>();
        Map<String, String> fr = new HashMap<>();
        int maxEn = 1;
        int maxFr = 1;
        int lines = 0;

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                new ClassPathResource(RESOURCE_PATH).getInputStream(), StandardCharsets.UTF_8))) {

            String line;
            while ((line = reader.readLine()) != null) {
                String entry = line.trim();
                if (entry.isEmpty() || entry.startsWith("#")) {
                    continue;
                }

                // Marqueur de direction : « > » affichage seul, « < » recherche seule.
                boolean indexForDisplay = true;   // EN -> FR
                boolean indexForSearch = true;    // FR -> EN
                char marker = entry.charAt(0);
                if (marker == '>') {
                    indexForSearch = false;
                    entry = entry.substring(1).trim();
                } else if (marker == '<') {
                    indexForDisplay = false;
                    entry = entry.substring(1).trim();
                }

                int separator = entry.indexOf(';');
                if (separator <= 0) {
                    log.warn("Lexique nutrition : ligne ignoree (separateur ';' absent) -> {}", entry);
                    continue;
                }
                String english = entry.substring(0, separator).trim();
                String french = entry.substring(separator + 1).trim();
                if (english.isEmpty() || french.isEmpty()) {
                    log.warn("Lexique nutrition : ligne ignoree (traduction vide) -> {}", entry);
                    continue;
                }

                String englishKey = normalize(english);
                String frenchKey = normalize(french);

                // putIfAbsent : en cas de doublon, la PREMIERE ligne du fichier
                // fait foi (regle documentee en tete du lexique).
                if (indexForDisplay) {
                    en.putIfAbsent(englishKey, french);
                    maxEn = Math.max(maxEn, wordCount(englishKey));
                }
                if (indexForSearch) {
                    fr.putIfAbsent(frenchKey, english);
                    maxFr = Math.max(maxFr, wordCount(frenchKey));
                }
                lines++;
            }

            log.info("Lexique nutrition charge : {} entrees ({} EN->FR, {} FR->EN)",
                    lines, en.size(), fr.size());

        } catch (IOException e) {
            // Volontairement non bloquant : mieux vaut une recherche anglophone
            // qu'une application qui refuse de demarrer.
            log.error("Lexique nutrition introuvable ou illisible ({}) : "
                    + "la traduction des aliments est desactivee", RESOURCE_PATH, e);
        }

        this.enToFr = Map.copyOf(en);
        this.frToEn = Map.copyOf(fr);
        this.longestEn = Math.min(maxEn, MAX_PHRASE_WORDS);
        this.longestFr = Math.min(maxFr, MAX_PHRASE_WORDS);
    }

    // ── API publique ──────────────────────────────────────────────────

    /**
     * Traduit une saisie francaise en requete exploitable par USDA.
     *
     * <p>« blanc de poulet » devient « chicken breast », « pomme de terre
     * bouillie » devient « potato boiled ». Les articles residuels sont
     * supprimes : ils ne servent a rien cote USDA et nuisent a la recherche
     * (le client exige que <i>tous</i> les mots soient presents).
     *
     * <p><b>Prudence volontaire :</b> si <b>aucun</b> mot n'a ete reconnu, la
     * saisie est renvoyee <b>telle quelle</b>. C'est ce qui permet a une saisie
     * deja anglaise (« chicken breast ») ou a un nom de marque (« Nutella »)
     * de continuer a fonctionner exactement comme avant.
     *
     * @param query saisie de l'adherent, potentiellement en francais
     * @return la requete a envoyer a USDA (jamais {@code null} si l'entree ne l'est pas)
     */
    public String toEnglishQuery(String query) {
        if (query == null || query.isBlank() || frToEn.isEmpty()) {
            return query;
        }
        Translation result = translateSegment(query.trim(), frToEn, longestFr, true, true);
        return result.changed() ? result.text() : query.trim();
    }

    /**
     * Traduit un libelle USDA en francais affichable.
     *
     * <p>Les libelles USDA sont des listes de descripteurs separes par des
     * virgules (« Chicken, broiler or fryer, breast, meat only, raw »). Chaque
     * segment est traduit independamment, ce qui evite qu'une expression
     * chevauche deux descripteurs sans rapport.
     *
     * @param description libelle USDA
     * @return le libelle francais, premiere lettre en majuscule
     */
    public String toFrenchLabel(String description) {
        if (description == null || description.isBlank() || enToFr.isEmpty()) {
            return description;
        }

        String[] segments = description.split(",");
        List<String> translated = new ArrayList<>(segments.length);
        for (String segment : segments) {
            String trimmed = segment.trim();
            if (trimmed.isEmpty()) {
                continue;
            }
            translated.add(translateSegment(trimmed, enToFr, longestEn, false, false).text());
        }
        return capitalize(String.join(", ", translated));
    }

    // ── Moteur d'appariement ──────────────────────────────────────────

    /** Resultat d'une traduction : le texte, et si quelque chose a ete reconnu. */
    private record Translation(String text, boolean changed) {
    }

    /**
     * Un mot du texte source, decoupe en {@code prefixe + noyau + suffixe}.
     *
     * <p>Separer la ponctuation du noyau permet de retrouver « (raw) » ou
     * « raw; » dans le lexique sous la forme « raw », puis de restituer la
     * ponctuation autour de la traduction.
     */
    private record Token(String prefix, String core, String suffix) {
        String original() {
            return prefix + core + suffix;
        }
    }

    /**
     * Traduit un fragment de texte par appariement <b>glouton du plus long au
     * plus court</b> : a chaque position, on tente d'abord l'expression la plus
     * longue possible. C'est ce qui fait gagner « pomme de terre » contre
     * « pomme », sans dependre de l'ordre des lignes du lexique.
     *
     * @param dropArticles retire les articles francais non absorbes (sens FR -&gt; EN)
     * @param french       les cles cherchees sont francaises (replis d'accord)
     */
    private Translation translateSegment(String text, Map<String, String> dict,
                                         int maxWords, boolean dropArticles,
                                         boolean french) {
        List<Token> tokens = tokenize(text);
        if (tokens.isEmpty()) {
            return new Translation(text, false);
        }

        List<String> output = new ArrayList<>(tokens.size());
        boolean changed = false;
        int index = 0;

        while (index < tokens.size()) {
            int window = Math.min(maxWords, tokens.size() - index);
            boolean matched = false;

            for (int length = window; length >= 1 && !matched; length--) {
                String key = joinCores(tokens, index, length);
                if (key.isEmpty()) {
                    continue;
                }
                String translation = lookup(dict, key, french);
                if (translation != null) {
                    // La ponctuation ouvrante du premier mot et fermante du
                    // dernier encadrent la traduction.
                    output.add(tokens.get(index).prefix()
                            + translation
                            + tokens.get(index + length - 1).suffix());
                    index += length;
                    matched = true;
                    changed = true;
                }
            }

            if (!matched) {
                Token token = tokens.get(index);
                // Article francais qu'aucune expression n'a absorbe : on le
                // supprime plutot que de l'envoyer a USDA.
                if (!(dropArticles && ARTICLES_FR.contains(normalize(token.core())))) {
                    output.add(token.original());
                }
                index++;
            }
        }

        return new Translation(String.join(" ", output), changed);
    }

    /**
     * Recherche une cle, avec repli sur les formes flechies.
     *
     * <p>Evite de dupliquer chaque entree du lexique dans toutes ses formes.
     * Quatre replis, essayes dans cet ordre :
     *
     * <ol>
     *   <li><b>pluriel anglais global</b> : « tomatoes » trouve « tomato »,
     *       « cherries » trouve « cherry » ;</li>
     *   <li><b>pluriel mot a mot</b> : indispensable en francais, ou le pluriel
     *       marque le <i>nom de tete</i> et non le dernier mot —
     *       « pommes de terre » doit trouver « pomme de terre ». Sans ce repli,
     *       l'expression echouait et « pommes » seul etait traduit par
     *       « apple » : un contresens complet ;</li>
     *   <li><b>feminin francais</b> : « salade verte » trouve « vert »,
     *       « viande grillee » trouve « grille » ;</li>
     *   <li><b>feminin pluriel</b> : « pommes de terre cuites ».</li>
     * </ol>
     *
     * <p>Ces replis ne sont tentes qu'apres echec de la cle exacte, et ne sont
     * retenus que si la forme reduite existe reellement dans le lexique : une
     * troncature qui ne correspond a rien est simplement ignoree.
     *
     * @param french active les replis propres au francais (accord en genre)
     */
    private String lookup(Map<String, String> dict, String key, boolean french) {
        String exact = dict.get(key);
        if (exact != null) {
            return exact;
        }

        // 1. Pluriel anglais sur la cle entiere.
        if (key.endsWith("ies") && key.length() > 4) {
            String hit = dict.get(key.substring(0, key.length() - 3) + "y");
            if (hit != null) {
                return hit;
            }
        }
        if (key.endsWith("es") && key.length() > 3) {
            String hit = dict.get(key.substring(0, key.length() - 2));
            if (hit != null) {
                return hit;
            }
        }
        if (key.endsWith("s") && key.length() > 3) {
            String hit = dict.get(key.substring(0, key.length() - 1));
            if (hit != null) {
                return hit;
            }
        }

        // 2. Pluriel mot a mot.
        String singular = mapWords(key, FoodLexicon::singularize);
        if (!singular.equals(key)) {
            String hit = dict.get(singular);
            if (hit != null) {
                return hit;
            }
        }

        if (!french) {
            return null;
        }

        // 3. Feminin, puis 4. feminin pluriel.
        String masculine = mapWords(key, FoodLexicon::masculinize);
        if (!masculine.equals(key)) {
            String hit = dict.get(masculine);
            if (hit != null) {
                return hit;
            }
        }
        String both = mapWords(singular, FoodLexicon::masculinize);
        if (!both.equals(key) && !both.equals(masculine)) {
            return dict.get(both);
        }
        return null;
    }

    /** Applique une transformation a chaque mot d'une cle. */
    private static String mapWords(String key, java.util.function.UnaryOperator<String> op) {
        if (key.indexOf(' ') < 0) {
            return op.apply(key);
        }
        StringBuilder out = new StringBuilder(key.length());
        for (String word : key.split(" ")) {
            if (out.length() > 0) {
                out.append(' ');
            }
            out.append(op.apply(word));
        }
        return out.toString();
    }

    /** « pommes » -> « pomme ». Les mots courts sont laisses tels quels. */
    private static String singularize(String word) {
        return (word.length() > 3 && word.endsWith("s"))
                ? word.substring(0, word.length() - 1)
                : word;
    }

    /** « verte » -> « vert », « grillee » -> « grille » (accents deja neutralises). */
    private static String masculinize(String word) {
        return (word.length() > 3 && word.endsWith("e"))
                ? word.substring(0, word.length() - 1)
                : word;
    }

    /**
     * Cle de recherche formee de {@code length} noyaux consecutifs.
     *
     * <p>Un jeton sans noyau (ponctuation isolee, « / » entre deux mentions)
     * <b>invalide</b> toute la fenetre : il fait barriere. Sans cela, une
     * expression enjamberait le separateur et l'avalerait au passage —
     * « lean meat / 15% fat » perdrait son « / » en devenant
     * « viande maigre 15% gras ».
     *
     * @return la cle, ou une chaine vide si la fenetre n'est pas appariable
     */
    private String joinCores(List<Token> tokens, int from, int length) {
        StringBuilder key = new StringBuilder();
        for (int i = from; i < from + length; i++) {
            String core = normalize(tokens.get(i).core());
            if (core.isEmpty()) {
                return "";
            }
            if (key.length() > 0) {
                key.append(' ');
            }
            key.append(core);
        }
        return key.toString();
    }

    /** Decoupe en mots, ponctuation de bordure isolee du noyau. */
    private List<Token> tokenize(String text) {
        List<Token> tokens = new ArrayList<>();
        for (String word : text.split("\\s+")) {
            if (word.isEmpty()) {
                continue;
            }
            int start = 0;
            int end = word.length();
            while (start < end && !Character.isLetterOrDigit(word.charAt(start))) {
                start++;
            }
            while (end > start && !Character.isLetterOrDigit(word.charAt(end - 1))) {
                end--;
            }
            tokens.add(new Token(word.substring(0, start), word.substring(start, end), word.substring(end)));
        }
        return tokens;
    }

    /**
     * Forme canonique d'une cle : minuscules, <b>accents neutralises</b>,
     * ligatures developpees, apostrophe typographique unifiee.
     *
     * <p>Neutraliser les accents rend la recherche tolerante : « cereales »
     * trouve « céréales », « boeuf » trouve « bœuf ». Seules les <b>cles</b>
     * sont normalisees ; le texte affiche conserve ses accents.
     */
    private static String normalize(String value) {
        String unified = value
                .replace('’', '\'')   // apostrophe typographique -> droite
                .replace("œ", "oe").replace("Œ", "OE")
                .replace("æ", "ae").replace("Æ", "AE");
        String decomposed = Normalizer.normalize(unified, Normalizer.Form.NFD);
        return decomposed.replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.FRENCH)
                .trim();
    }

    private static int wordCount(String normalizedKey) {
        return normalizedKey.isEmpty() ? 0 : normalizedKey.split(" ").length;
    }

    private static String capitalize(String text) {
        if (text.isEmpty()) {
            return text;
        }
        return Character.toUpperCase(text.charAt(0)) + text.substring(1);
    }
}
