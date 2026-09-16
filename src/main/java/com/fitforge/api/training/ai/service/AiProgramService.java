package com.fitforge.api.training.ai.service;

import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.training.ai.client.GeneratedProgramDto;
import com.fitforge.api.training.ai.client.GeminiProgramClient;
import com.fitforge.api.training.ai.client.ModelUnavailableException;
import com.fitforge.api.training.ai.dto.GenerateProgramRequest;
import com.fitforge.api.training.ai.entity.AiProgramRequest;
import com.fitforge.api.training.ai.repository.AiProgramRequestRepository;
import com.fitforge.api.training.dto.ProgramResponse;
import com.fitforge.api.training.entity.Exercise;
import com.fitforge.api.training.entity.SessionExercise;
import com.fitforge.api.training.entity.WorkoutProgram;
import com.fitforge.api.training.entity.WorkoutSession;
import com.fitforge.api.training.mapper.ProgramMapper;
import com.fitforge.api.training.repository.WorkoutProgramRepository;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

/**
 * La generation d'un programme par l'IA FitForge, de bout en bout.
 *
 * <h2>Le principe : rien de ce que dit le modele n'est ecrit tel quel</h2>
 *
 * <p>Un modele de langage produit toujours quelque chose de plausible. Une
 * seance de 40 series, un repos de 3 000 secondes et un exercice numero 812 sont
 * tous plausibles a la lecture. Ce service part donc du principe que la reponse
 * est une <b>proposition a verifier</b>, pas un resultat :
 *
 * <ul>
 *   <li>chaque numero d'exercice est retraduit via le catalogue exact qui a ete
 *       soumis ; un numero inconnu fait tomber la ligne, pas la generation ;</li>
 *   <li>chaque nombre est ramene dans une plage tenable (series, repetitions,
 *       repos, charge) ;</li>
 *   <li>l'objectif, le niveau et le nombre de seances viennent du
 *       <b>questionnaire</b>, jamais de la reponse : ce sont des donnees que
 *       l'adherent a saisies, le modele n'a pas a les reinterpreter ;</li>
 *   <li>une seance vide apres nettoyage est retiree ; s'il ne reste rien, la
 *       generation echoue franchement plutot que de creer un programme creux.</li>
 * </ul>
 *
 * <h2>Le resultat est un programme ordinaire</h2>
 *
 * <p>Il est ecrit dans les memes tables que les autres, avec le drapeau
 * {@code generatedByAi}. Consequence voulue : l'adherent l'ouvre, le modifie,
 * lui ajoute une seance, y logue ses series — exactement comme un programme
 * compose par son coach. Seule l'origine change, pas la nature.
 *
 * <h2>Pourquoi l'appel au modele est hors transaction</h2>
 *
 * <p>Il dure des dizaines de secondes. Le tenir dans une transaction
 * immobiliserait une connexion a la base pendant tout ce temps ; quelques
 * generations simultanees suffiraient a assecher le pool et a bloquer le reste
 * de l'application. La demande est donc journalisee, l'appel est fait hors
 * transaction, puis le programme est ecrit en une seule sauvegarde en cascade.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AiProgramService {

    /** Fenetre du plafond de generations. */
    private static final Duration RATE_WINDOW = Duration.ofHours(24);

    // ── Bornes de securite appliquees a la reponse du modele ─────────
    private static final int MAX_SESSIONS = 7;
    private static final int MAX_EXERCISES_PER_SESSION = 12;
    private static final int MIN_SETS = 1;
    private static final int MAX_SETS = 8;
    private static final int MIN_REPS = 1;
    private static final int MAX_REPS = 50;
    private static final int MIN_REST_SECONDS = 20;
    private static final int MAX_REST_SECONDS = 300;
    private static final double MAX_WEIGHT_KG = 500;
    private static final int MAX_TITLE_LENGTH = 120;
    private static final int MAX_SESSION_TITLE_LENGTH = 200;
    private static final int MAX_DESCRIPTION_LENGTH = 500;
    private static final int MAX_RATIONALE_LENGTH = 4000;
    private static final int MAX_NOTES_LENGTH = 300;
    private static final int DEFAULT_DURATION_WEEKS = 8;
    private static final int MAX_DURATION_WEEKS = 52;

    private final GeminiProgramClient gemini;
    private final AiProgramBriefer briefer;
    private final ExerciseCatalogBriefer catalogBriefer;
    private final AiProgramRequestRepository requestRepo;
    private final WorkoutProgramRepository programRepo;
    private final UserRepository userRepo;
    private final ProgramMapper mapper;

    /**
     * Plafond de generations par adherent et par 24 heures.
     *
     * <p>Une generation est de loin l'appel Gemini le plus lourd de
     * l'application : elle embarque tout le catalogue d'exercices eligibles et
     * produit plusieurs milliers de jetons. Sans borne, quelques appuis repetes
     * videraient le quota <b>partage</b> avec le coach IA, l'analyse de photo et
     * l'ajout vocal — trois fonctionnalites qui tomberaient sans rapport
     * apparent avec ce qui vient de se passer.
     */
    @Value("${gemini.api.program-max-per-day:5}")
    private int maxProgramsPerDay;

    /** Vrai si la generation est utilisable sur ce serveur (cle configuree). */
    public boolean isAvailable() {
        return gemini.isConfigured();
    }

    // ── Generation ───────────────────────────────────────────────────

    /**
     * Compose un programme pour l'adherent et l'enregistre.
     *
     * @return le programme cree, deja complet (seances + exercices)
     * @throws BusinessException service non configure, plafond atteint, ou
     *                           reponse inexploitable
     */
    public ProgramResponse generate(UUID userId, GenerateProgramRequest req) {
        if (!gemini.isConfigured()) {
            throw new BusinessException(
                    "La generation de programme par l'IA n'est pas disponible sur ce "
                            + "serveur pour le moment.");
        }
        enforceRateLimit(userId);

        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        String brief = briefer.brief(userId, req);
        ExerciseCatalogBriefer.Catalog catalog = catalogBriefer.build(req.equipmentOrEmpty());
        if (catalog.isEmpty()) {
            // Le referentiel est vide : c'est un probleme de serveur, pas une
            // erreur de l'adherent. On le dit sans lui faire recommencer.
            log.error("Generation de programme impossible : le referentiel d'exercices est vide");
            throw new BusinessException(
                    "Le catalogue d'exercices est indisponible sur ce serveur.");
        }

        // La demande est journalisee AVANT l'appel : un echec (reseau, delai
        // depasse, reponse illisible) consomme du quota Gemini exactement comme
        // un succes. Ne le compter qu'en cas de reussite rendrait le plafond
        // contournable en enchainant les generations qui echouent.
        AiProgramRequest journal = requestRepo.save(AiProgramRequest.builder()
                .user(user)
                .brief(brief)
                .build());

        GeneratedProgramDto generated;
        try {
            generated = gemini.generate(brief, catalog.asPrompt());

        } catch (ModelUnavailableException e) {
            // Gemini n'a rien traite : aucun jeton consomme, donc rien a
            // decompter. On retire la ligne du journal plutot que de la
            // laisser peser sur le plafond — sinon quelqu'un qui insiste
            // pendant une saturation se retrouve bloque vingt-quatre heures
            // sans avoir obtenu un seul programme. L'incident reste trace
            // dans les logs applicatifs.
            requestRepo.delete(journal);
            throw e;

        } catch (RuntimeException e) {
            journal.setErrorMessage(truncate(e.getMessage(), 500));
            requestRepo.save(journal);
            throw e;
        }

        WorkoutProgram program;
        try {
            program = programRepo.save(materialize(user, req, generated, catalog));
        } catch (RuntimeException e) {
            journal.setErrorMessage(truncate(e.getMessage(), 500));
            requestRepo.save(journal);
            throw e;
        }

        journal.setProgram(program);
        requestRepo.save(journal);

        log.debug("Programme IA genere : {} seance(s), {} exercice(s)",
                program.getSessions().size(),
                program.getSessions().stream().mapToInt(s -> s.getExercises().size()).sum());

        return mapper.toResponse(program);
    }

    // ── De la reponse du modele au programme reel ────────────────────

    /**
     * Construit le programme a partir de la proposition, en verifiant tout.
     *
     * <p>Les champs que l'adherent a saisis ({@code goal}, {@code experienceLevel})
     * sont repris du <b>questionnaire</b> et non de la reponse : le modele n'a
     * pas a reinterpreter une donnee qu'on lui a fournie.
     */
    private WorkoutProgram materialize(User user, GenerateProgramRequest req,
                                       GeneratedProgramDto dto,
                                       ExerciseCatalogBriefer.Catalog catalog) {

        WorkoutProgram program = WorkoutProgram.builder()
                .user(user)
                .title(text(dto.title(), MAX_TITLE_LENGTH, "Mon programme IA"))
                .description(text(dto.description(), MAX_DESCRIPTION_LENGTH, null))
                .goal(req.goal())
                .experienceLevel(req.experienceLevel())
                .durationWeeks(durationWeeks(req, dto))
                .isTemplate(false)
                .generatedByAi(true)
                .aiRationale(text(dto.rationale(), MAX_RATIONALE_LENGTH, null))
                .aiGeneratedAt(Instant.now())
                .build();

        // Le nombre de seances est celui que l'adherent a demande. Si le modele
        // en a produit davantage, le surplus est ecarte : la reponse au
        // questionnaire fait foi, pas l'inspiration du modele.
        int maxSessions = Math.min(req.daysPerWeek() == null ? MAX_SESSIONS : req.daysPerWeek(),
                MAX_SESSIONS);

        int sessionIndex = 0;
        for (GeneratedProgramDto.Session proposed : dto.sessions()) {
            if (proposed == null || sessionIndex >= maxSessions) {
                break;
            }
            WorkoutSession session = buildSession(program, proposed, sessionIndex, catalog);
            // Une seance sans exercice exploitable n'a aucun interet : elle
            // s'afficherait comme une carte vide que l'adherent devrait remplir
            // lui-meme, ce qui est exactement ce qu'il voulait eviter.
            if (session.getExercises().isEmpty()) {
                log.debug("Generation de programme : seance « {} » ecartee, aucun exercice valide",
                        proposed.title());
                continue;
            }
            program.getSessions().add(session);
            sessionIndex++;
        }

        if (program.getSessions().isEmpty()) {
            throw new BusinessException(
                    "L'IA n'a pas reussi a composer un programme exploitable. Reessaie, "
                            + "ou elargis le materiel disponible.");
        }
        return program;
    }

    private WorkoutSession buildSession(WorkoutProgram program,
                                        GeneratedProgramDto.Session proposed,
                                        int index,
                                        ExerciseCatalogBriefer.Catalog catalog) {

        WorkoutSession session = WorkoutSession.builder()
                .program(program)
                .title(text(proposed.title(), MAX_SESSION_TITLE_LENGTH, "Seance " + (index + 1)))
                .dayOfWeek(dayOfWeek(proposed.dayOfWeek()))
                .orderIndex(index)
                .build();

        if (proposed.exercises() == null) {
            return session;
        }

        // Un meme exercice deux fois dans la seance est une faute de
        // composition, pas une variation : on ne garde que la premiere
        // occurrence.
        Set<UUID> alreadyPlaced = new HashSet<>();
        int order = 0;

        for (GeneratedProgramDto.PlacedExercise proposedExercise : proposed.exercises()) {
            if (proposedExercise == null || order >= MAX_EXERCISES_PER_SESSION) {
                break;
            }
            if (proposedExercise.ref() == null) {
                continue;
            }
            Exercise exercise = catalog.at(proposedExercise.ref());
            if (exercise == null) {
                // Numero hors catalogue : cas attendu, pas une panne. On perd
                // une ligne, pas le programme.
                log.debug("Generation de programme : numero d'exercice {} hors catalogue, ignore",
                        proposedExercise.ref());
                continue;
            }
            if (!alreadyPlaced.add(exercise.getId())) {
                continue;
            }

            session.getExercises().add(SessionExercise.builder()
                    .session(session)
                    .exercise(exercise)
                    .targetSets(clamp(proposedExercise.sets(), MIN_SETS, MAX_SETS, 3))
                    .targetReps(clamp(proposedExercise.reps(), MIN_REPS, MAX_REPS, 10))
                    .restSeconds(clamp(proposedExercise.restSeconds(),
                            MIN_REST_SECONDS, MAX_REST_SECONDS, 90))
                    .targetWeightKg(weight(proposedExercise.weightKg()))
                    .notes(text(proposedExercise.notes(), MAX_NOTES_LENGTH, null))
                    .orderIndex(order)
                    .build());
            order++;
        }
        return session;
    }

    // ── Bornes ───────────────────────────────────────────────────────

    /**
     * La duree conseillee par le modele, sinon celle demandee, sinon 8 semaines.
     *
     * <p>Le modele est ecoute en premier ici — contrairement a l'objectif ou au
     * nombre de seances — parce que la duree est une <b>conclusion de
     * programmation</b> (un cycle de force ne tient pas en trois semaines), pas
     * une contrainte de l'adherent. Le questionnaire ne la rend d'ailleurs pas
     * obligatoire.
     */
    private Integer durationWeeks(GenerateProgramRequest req, GeneratedProgramDto dto) {
        Integer proposed = dto.durationWeeks() != null ? dto.durationWeeks() : req.durationWeeks();
        return clamp(proposed, 1, MAX_DURATION_WEEKS, DEFAULT_DURATION_WEEKS);
    }

    private Integer dayOfWeek(Integer value) {
        return value != null && value >= 1 && value <= 7 ? value : null;
    }

    /**
     * Charge cible, arrondie au demi-kilo.
     *
     * <p>{@code null} est une valeur legitime et frequente : au poids de corps,
     * ou quand l'adherent n'a communique aucune charge de reference. L'ecran de
     * detail affiche alors simplement series x repetitions.
     */
    private Double weight(Double value) {
        if (value == null || value <= 0 || value > MAX_WEIGHT_KG) {
            return null;
        }
        return Math.round(value * 2) / 2.0;
    }

    private Integer clamp(Integer value, int min, int max, int fallback) {
        if (value == null) {
            return fallback;
        }
        return Math.max(min, Math.min(max, value));
    }

    /** Texte nettoye et borne, ou {@code fallback} si rien d'exploitable. */
    private String text(String value, int maxLength, String fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        return truncate(value.trim(), maxLength);
    }

    private String truncate(String value, int maxLength) {
        if (value == null) {
            return null;
        }
        return value.length() <= maxLength ? value : value.substring(0, maxLength);
    }

    // ── Garde-fou de quota ───────────────────────────────────────────

    private void enforceRateLimit(UUID userId) {
        long recent = requestRepo.countSince(userId, Instant.now().minus(RATE_WINDOW));
        if (recent >= maxProgramsPerDay) {
            throw new BusinessException(
                    "Tu as deja genere " + maxProgramsPerDay + " programmes aujourd'hui. "
                            + "Reprends demain, ou ajuste un programme existant.");
        }
    }
}
