package com.fitforge.api.training.ai.service;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.FitnessGoal;
import com.fitforge.api.common.enums.MuscleGroup;
import com.fitforge.api.common.enums.WorkoutLocation;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.training.ai.client.GeminiProgramClient;
import com.fitforge.api.training.ai.client.GeneratedProgramDto;
import com.fitforge.api.training.ai.client.ModelUnavailableException;
import com.fitforge.api.training.ai.dto.GenerateProgramRequest;
import com.fitforge.api.training.ai.entity.AiProgramRequest;
import com.fitforge.api.training.ai.repository.AiProgramRequestRepository;
import com.fitforge.api.training.entity.Exercise;
import com.fitforge.api.training.entity.SessionExercise;
import com.fitforge.api.training.entity.WorkoutProgram;
import com.fitforge.api.training.entity.WorkoutSession;
import com.fitforge.api.training.mapper.ProgramMapper;
import com.fitforge.api.training.repository.WorkoutProgramRepository;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Tests du generateur de programme.
 *
 * <p>Ils portent presque tous sur <b>une seule promesse</b> : ce que le modele
 * renvoie n'atteint jamais la base sans avoir ete verifie. Un modele de langage
 * produit toujours quelque chose de plausible — une seance de 40 series, un
 * repos de 3 000 secondes et un exercice numero 812 se lisent tous comme du
 * texte valide. Seul le code peut faire la difference, et c'est lui qu'on
 * exerce ici.
 *
 * <p>Le second axe est le <b>quota</b>, parce qu'il touche a l'equite : une
 * generation qui echoue parce que Gemini est sature ne doit pas etre facturee a
 * l'adherent, alors qu'une generation qui echoue apres que le modele a
 * travaille, si.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AiProgramServiceTest {

    @Mock
    private GeminiProgramClient gemini;
    @Mock
    private AiProgramBriefer briefer;
    @Mock
    private ExerciseCatalogBriefer catalogBriefer;
    @Mock
    private AiProgramRequestRepository requestRepo;
    @Mock
    private WorkoutProgramRepository programRepo;
    @Mock
    private UserRepository userRepo;
    @Mock
    private ProgramMapper mapper;

    private AiProgramService service;
    private UUID userId;

    /** Trois exercices connus : les numeros 1, 2 et 3 du catalogue. */
    private Exercise squat;
    private Exercise bench;
    private Exercise curl;

    @BeforeEach
    void setUp() {
        service = new AiProgramService(gemini, briefer, catalogBriefer,
                requestRepo, programRepo, userRepo, mapper);
        ReflectionTestUtils.setField(service, "maxProgramsPerDay", 5);

        userId = UUID.randomUUID();
        User user = new User();
        user.setId(userId);

        squat = exercise("Squat", MuscleGroup.JAMBES, Equipment.BARRE);
        bench = exercise("Developpe couche", MuscleGroup.PECTORAUX, Equipment.BARRE);
        curl = exercise("Curl", MuscleGroup.BICEPS, Equipment.HALTERE);

        when(gemini.isConfigured()).thenReturn(true);
        when(userRepo.findById(userId)).thenReturn(Optional.of(user));
        when(briefer.brief(eq(userId), any())).thenReturn("brief de test");
        when(catalogBriefer.build(any()))
                .thenReturn(new ExerciseCatalogBriefer.Catalog(List.of(squat, bench, curl)));
        when(requestRepo.countSince(eq(userId), any(Instant.class))).thenReturn(0L);
        when(requestRepo.save(any(AiProgramRequest.class))).thenAnswer(i -> i.getArgument(0));
        // Le programme est renvoye tel quel : on inspecte ce que le service a bati.
        when(programRepo.save(any(WorkoutProgram.class))).thenAnswer(i -> i.getArgument(0));
    }

    // ════════════════════════════════════════════════════════════════
    //  Le catalogue : un numero invalide ne peut pas produire d'exercice
    // ════════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Retraduction des numeros de catalogue")
    class CatalogRefs {

        @Test
        @DisplayName("un numero hors bornes fait tomber la ligne, pas le programme")
        void unknownRefIsDropped() {
            modelReturns(session("Jour 1",
                    placed(1, 3, 10),
                    placed(812, 3, 10),   // n'existe pas
                    placed(2, 3, 10)));

            List<SessionExercise> placed = generatedExercises();

            assertThat(placed).hasSize(2);
            assertThat(placed).extracting(se -> se.getExercise().getName())
                    .containsExactly("Squat", "Developpe couche");
        }

        @Test
        @DisplayName("le numero 0 et les numeros negatifs sont refuses")
        void zeroAndNegativeRefsAreDropped() {
            modelReturns(session("Jour 1",
                    placed(0, 3, 10), placed(-4, 3, 10), placed(3, 3, 10)));

            assertThat(generatedExercises())
                    .extracting(se -> se.getExercise().getName())
                    .containsExactly("Curl");
        }

        @Test
        @DisplayName("un ref nul est ignore sans faire echouer la generation")
        void nullRefIsIgnored() {
            modelReturns(session("Jour 1", placed(null, 3, 10), placed(1, 3, 10)));

            assertThat(generatedExercises()).hasSize(1);
        }

        @Test
        @DisplayName("le meme exercice deux fois dans une seance ne compte qu'une fois")
        void duplicateInSameSessionIsDropped() {
            modelReturns(session("Jour 1",
                    placed(1, 4, 8), placed(2, 3, 10), placed(1, 3, 12)));

            List<SessionExercise> placed = generatedExercises();

            assertThat(placed).hasSize(2);
            // C'est la PREMIERE occurrence qui est gardee : ses objectifs aussi.
            assertThat(placed.get(0).getTargetSets()).isEqualTo(4);
        }

        @Test
        @DisplayName("le meme exercice dans DEUX seances differentes est autorise")
        void sameExerciseInTwoSessionsIsKept() {
            modelReturns(4,
                    session("Jour 1", placed(1, 4, 8)),
                    session("Jour 2", placed(1, 3, 12)));

            WorkoutProgram program = generated();

            assertThat(program.getSessions()).hasSize(2);
            assertThat(program.getSessions().get(1).getExercises().get(0).getExercise())
                    .isSameAs(squat);
        }
    }

    // ════════════════════════════════════════════════════════════════
    //  Les bornes : aucun nombre du modele n'est pris tel quel
    // ════════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Bornes appliquees aux valeurs du modele")
    class Bounds {

        @Test
        @DisplayName("series, repetitions et repos sont ramenes dans le tenable")
        void absurdValuesAreClamped() {
            modelReturns(session("Jour 1",
                    new GeneratedProgramDto.PlacedExercise(1, 40, 0, 3000, null, null)));

            SessionExercise se = generatedExercises().get(0);

            assertThat(se.getTargetSets()).isEqualTo(8);
            assertThat(se.getTargetReps()).isEqualTo(1);
            assertThat(se.getRestSeconds()).isEqualTo(300);
        }

        @Test
        @DisplayName("des valeurs absentes recoivent un defaut utilisable")
        void missingValuesFallBack() {
            modelReturns(session("Jour 1",
                    new GeneratedProgramDto.PlacedExercise(1, null, null, null, null, null)));

            SessionExercise se = generatedExercises().get(0);

            assertThat(se.getTargetSets()).isEqualTo(3);
            assertThat(se.getTargetReps()).isEqualTo(10);
            assertThat(se.getRestSeconds()).isEqualTo(90);
        }

        @Test
        @DisplayName("une charge aberrante devient null plutot qu'un poids faux")
        void absurdWeightBecomesNull() {
            modelReturns(4,
                    session("A", new GeneratedProgramDto.PlacedExercise(
                            1, 3, 10, 90, -5.0, null)),
                    session("B", new GeneratedProgramDto.PlacedExercise(
                            2, 3, 10, 90, 900.0, null)),
                    session("C", new GeneratedProgramDto.PlacedExercise(
                            3, 3, 10, 90, 0.0, null)));

            WorkoutProgram program = generated();

            assertThat(program.getSessions())
                    .allSatisfy(s -> assertThat(s.getExercises().get(0).getTargetWeightKg())
                            .isNull());
        }

        @Test
        @DisplayName("une charge plausible est arrondie au demi-kilo")
        void weightIsRoundedToHalfKilo() {
            modelReturns(session("Jour 1", new GeneratedProgramDto.PlacedExercise(
                    1, 3, 10, 90, 61.3, null)));

            assertThat(generatedExercises().get(0).getTargetWeightKg()).isEqualTo(61.5);
        }

        @Test
        @DisplayName("un jour de semaine hors 1..7 est efface")
        void invalidDayOfWeekBecomesNull() {
            modelReturns(new GeneratedProgramDto("Titre", "Desc", "Pourquoi", 8,
                    List.of(new GeneratedProgramDto.Session("Jour X", 12,
                            List.of(placed(1, 3, 10))))));

            assertThat(generated().getSessions().get(0).getDayOfWeek()).isNull();
        }

        @Test
        @DisplayName("une consigne trop longue est tronquee, pas rejetee")
        void longNotesAreTruncated() {
            String tooLong = "a".repeat(500);
            modelReturns(session("Jour 1", new GeneratedProgramDto.PlacedExercise(
                    1, 3, 10, 90, null, tooLong)));

            assertThat(generatedExercises().get(0).getNotes()).hasSize(300);
        }

        @Test
        @DisplayName("une seance porte au plus 12 exercices")
        void sessionIsCappedAtTwelveExercises() {
            List<GeneratedProgramDto.PlacedExercise> many = new ArrayList<>();
            // 20 exercices, mais seulement 3 distincts au catalogue : le
            // dedoublonnage borne bien avant le plafond, on verifie donc que
            // les deux regles cohabitent sans se contredire.
            for (int i = 0; i < 20; i++) {
                many.add(placed((i % 3) + 1, 3, 10));
            }
            modelReturns(new GeneratedProgramDto("Titre", "Desc", "Pourquoi", 8,
                    List.of(new GeneratedProgramDto.Session("Jour 1", 1, many))));

            assertThat(generatedExercises()).hasSize(3);
        }
    }

    // ════════════════════════════════════════════════════════════════
    //  Le questionnaire fait foi, pas le modele
    // ════════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Ce qui vient du questionnaire et non du modele")
    class QuestionnaireWins {

        @Test
        @DisplayName("objectif et niveau sont ceux saisis par l'adherent")
        void goalAndLevelComeFromTheRequest() {
            modelReturns(session("Jour 1", placed(1, 3, 10)));

            WorkoutProgram program = generate(request(4, FitnessGoal.FORCE,
                    ExperienceLevel.AVANCE));

            assertThat(program.getGoal()).isEqualTo(FitnessGoal.FORCE);
            assertThat(program.getExperienceLevel()).isEqualTo(ExperienceLevel.AVANCE);
        }

        @Test
        @DisplayName("le surplus de seances est ecarte : le nombre demande est un ordre")
        void extraSessionsAreDropped() {
            modelReturns(4,
                    session("A", placed(1, 3, 10)),
                    session("B", placed(2, 3, 10)),
                    session("C", placed(3, 3, 10)),
                    session("D", placed(1, 3, 10)));

            WorkoutProgram program = generate(request(2, FitnessGoal.PRISE_MASSE,
                    ExperienceLevel.DEBUTANT));

            assertThat(program.getSessions()).hasSize(2);
            assertThat(program.getSessions()).extracting(WorkoutSession::getTitle)
                    .containsExactly("A", "B");
        }

        @Test
        @DisplayName("l'ordre d'affichage est renumerote par le serveur")
        void orderIndexesAreServerAssigned() {
            modelReturns(4,
                    session("A", placed(1, 3, 10), placed(2, 3, 10)),
                    session("B", placed(3, 3, 10)));

            WorkoutProgram program = generated();

            assertThat(program.getSessions()).extracting(WorkoutSession::getOrderIndex)
                    .containsExactly(0, 1);
            assertThat(program.getSessions().get(0).getExercises())
                    .extracting(SessionExercise::getOrderIndex)
                    .containsExactly(0, 1);
        }

        @Test
        @DisplayName("le programme est marque comme genere et date")
        void programIsFlaggedAsGenerated() {
            modelReturns(session("Jour 1", placed(1, 3, 10)));

            WorkoutProgram program = generated();

            assertThat(program.isGeneratedByAi()).isTrue();
            assertThat(program.getAiGeneratedAt()).isNotNull();
            assertThat(program.getAiRationale()).isEqualTo("Pourquoi");
            assertThat(program.isTemplate()).isFalse();
            assertThat(program.getCreatedBy()).isNull();
        }
    }

    // ════════════════════════════════════════════════════════════════
    //  Ce qui reste quand la reponse est mauvaise
    // ════════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Reponses inexploitables")
    class UnusableAnswers {

        @Test
        @DisplayName("une seance sans exercice valide est retiree, les autres restent")
        void emptySessionIsRemoved() {
            modelReturns(4,
                    session("Valide", placed(1, 3, 10)),
                    session("Vide", placed(999, 3, 10)),
                    session("Valide aussi", placed(2, 3, 10)));

            WorkoutProgram program = generated();

            assertThat(program.getSessions()).extracting(WorkoutSession::getTitle)
                    .containsExactly("Valide", "Valide aussi");
            // La renumerotation suit le retrait : pas de trou dans l'ordre.
            assertThat(program.getSessions()).extracting(WorkoutSession::getOrderIndex)
                    .containsExactly(0, 1);
        }

        @Test
        @DisplayName("aucune seance exploitable : on echoue plutot que d'enregistrer un programme creux")
        void nothingUsableFailsLoudly() {
            modelReturns(4,
                    session("Vide", placed(999, 3, 10)),
                    session("Vide aussi", placed(1000, 3, 10)));

            assertThatThrownBy(() -> service.generate(userId, request()))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("exploitable");

            verify(programRepo, never()).save(any());
        }

        @Test
        @DisplayName("un titre vide recoit un repli plutot que d'echouer")
        void blankTitleFallsBack() {
            modelReturns(new GeneratedProgramDto("   ", null, null, null,
                    List.of(new GeneratedProgramDto.Session(null, 1,
                            List.of(placed(1, 3, 10))))));

            WorkoutProgram program = generated();

            assertThat(program.getTitle()).isEqualTo("Mon programme IA");
            assertThat(program.getSessions().get(0).getTitle()).isEqualTo("Seance 1");
            assertThat(program.getDurationWeeks()).isEqualTo(8);
        }

        @Test
        @DisplayName("le catalogue vide est une panne serveur, pas une erreur de l'adherent")
        void emptyCatalogFails() {
            when(catalogBriefer.build(any()))
                    .thenReturn(new ExerciseCatalogBriefer.Catalog(List.of()));

            assertThatThrownBy(() -> service.generate(userId, request()))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("catalogue");

            // Rien n'a ete demande au modele : inutile de bruler du quota.
            verify(gemini, never()).generate(anyString(), anyString());
        }
    }

    // ════════════════════════════════════════════════════════════════
    //  Le quota
    // ════════════════════════════════════════════════════════════════

    @Nested
    @DisplayName("Plafond journalier")
    class RateLimit {

        @Test
        @DisplayName("au plafond, la generation est refusee sans appeler le modele")
        void limitBlocksBeforeCallingTheModel() {
            when(requestRepo.countSince(eq(userId), any(Instant.class))).thenReturn(5L);

            assertThatThrownBy(() -> service.generate(userId, request()))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("aujourd'hui");

            verify(gemini, never()).generate(anyString(), anyString());
        }

        @Test
        @DisplayName("un echec APRES le travail du modele reste decompte")
        void failureAfterModelWorkedIsStillCounted() {
            when(gemini.generate(anyString(), anyString()))
                    .thenThrow(new BusinessException("reponse illisible"));

            assertThatThrownBy(() -> service.generate(userId, request()))
                    .isInstanceOf(BusinessException.class);

            // La demande reste au journal, avec la raison de l'echec.
            ArgumentCaptor<AiProgramRequest> captor =
                    ArgumentCaptor.forClass(AiProgramRequest.class);
            verify(requestRepo, org.mockito.Mockito.atLeastOnce()).save(captor.capture());
            assertThat(captor.getValue().getErrorMessage()).isEqualTo("reponse illisible");
            verify(requestRepo, never()).delete(any());
        }

        @Test
        @DisplayName("un modele injoignable n'est PAS decompte : il n'a rien traite")
        void unavailableModelDoesNotConsumeQuota() {
            when(gemini.generate(anyString(), anyString()))
                    .thenThrow(new ModelUnavailableException("saturee"));

            assertThatThrownBy(() -> service.generate(userId, request()))
                    .isInstanceOf(ModelUnavailableException.class);

            // La ligne est retiree du journal : sinon quelqu'un qui insiste
            // pendant une saturation serait bloque 24 h sans rien obtenir.
            verify(requestRepo).delete(any(AiProgramRequest.class));
        }

        @Test
        @DisplayName("la generation est refusee si aucune cle n'est configuree")
        void notConfiguredIsRefused() {
            when(gemini.isConfigured()).thenReturn(false);

            assertThatThrownBy(() -> service.generate(userId, request()))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("disponible");

            assertThat(service.isAvailable()).isFalse();
        }
    }

    // ════════════════════════════════════════════════════════════════
    //  Outillage
    // ════════════════════════════════════════════════════════════════

    private Exercise exercise(String name, MuscleGroup muscle, Equipment equipment) {
        return Exercise.builder()
                .id(UUID.randomUUID())
                .name(name)
                .primaryMuscle(muscle)
                .equipment(equipment)
                .build();
    }

    private GeneratedProgramDto.PlacedExercise placed(Integer ref, int sets, int reps) {
        return new GeneratedProgramDto.PlacedExercise(ref, sets, reps, 90, null, null);
    }

    private GeneratedProgramDto.Session session(
            String title, GeneratedProgramDto.PlacedExercise... exercises) {
        return new GeneratedProgramDto.Session(title, 1, List.of(exercises));
    }

    /** Le modele renvoie une seule seance (cas le plus courant des tests). */
    private void modelReturns(GeneratedProgramDto.Session session) {
        modelReturns(4, session);
    }

    private void modelReturns(int durationWeeks, GeneratedProgramDto.Session... sessions) {
        modelReturns(new GeneratedProgramDto(
                "Titre", "Desc", "Pourquoi", durationWeeks, List.of(sessions)));
    }

    private void modelReturns(GeneratedProgramDto dto) {
        when(gemini.generate(anyString(), anyString())).thenReturn(dto);
    }

    private GenerateProgramRequest request() {
        return request(4, FitnessGoal.PRISE_MASSE, ExperienceLevel.INTERMEDIAIRE);
    }

    private GenerateProgramRequest request(int daysPerWeek, FitnessGoal goal,
                                           ExperienceLevel level) {
        return new GenerateProgramRequest(goal, level, daysPerWeek, 60, 8,
                WorkoutLocation.SALLE, List.of(Equipment.BARRE), List.of(), List.of(),
                false, null, null, null, null, null);
    }

    /** Lance la generation et rend le programme reellement enregistre. */
    private WorkoutProgram generate(GenerateProgramRequest request) {
        service.generate(userId, request);
        ArgumentCaptor<WorkoutProgram> captor = ArgumentCaptor.forClass(WorkoutProgram.class);
        verify(programRepo).save(captor.capture());
        return captor.getValue();
    }

    private WorkoutProgram generated() {
        return generate(request());
    }

    private List<SessionExercise> generatedExercises() {
        return generated().getSessions().get(0).getExercises();
    }
}
