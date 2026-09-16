package com.fitforge.api.training.importer;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.training.entity.Exercise;
import com.fitforge.api.training.importer.ExerciseDbDtos.Detail;
import com.fitforge.api.training.importer.ExerciseDbDtos.DetailResponse;
import com.fitforge.api.training.importer.ExerciseDbDtos.ListItem;
import com.fitforge.api.training.importer.ExerciseDbDtos.ListResponse;
import com.fitforge.api.training.repository.ExerciseRepository;
import com.fitforge.api.training.service.ExerciseDifficultyRules;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Importe le referentiel d'exercices depuis l'API EXERCISEDB V2 (AscendAPI via
 * RapidAPI) dans notre propre table {@code exercises}.
 *
 * <p><b>Principe :</b> le client Flutter n'appelle JAMAIS l'API externe. On
 * importe une fois cote serveur (la cle RapidAPI ne quitte jamais le backend),
 * puis l'app consomme notre API habituelle. Cela protege la cle, evite une
 * dependance de disponibilite en production, et permet d'enrichir les donnees.
 *
 * <p><b>Cout :</b> la liste ne renvoie ni video ni instructions ; il faut donc
 * 1 appel liste (25/page) + 1 appel detail PAR exercice. Le plan RapidAPI
 * gratuit plafonne a 200 exercices ({@code meta.total}). Un delai entre chaque
 * appel respecte le rate limit.
 */
@Service
@Slf4j
public class ExerciseImportService {

    private static final int PAGE_SIZE = 25;              // max autorise par l'API
    private static final long THROTTLE_MS = 150L;         // anti rate-limit

    private final ExerciseRepository exerciseRepository;
    private final RestClient restClient;

    public ExerciseImportService(
            ExerciseRepository exerciseRepository,
            @Value("${rapidapi.base-url}") String baseUrl,
            @Value("${rapidapi.key}") String apiKey,
            @Value("${rapidapi.host}") String apiHost) {
        this.exerciseRepository = exerciseRepository;
        this.restClient = RestClient.builder()
                .baseUrl(baseUrl)
                .defaultHeader("X-RapidAPI-Key", apiKey)
                .defaultHeader("X-RapidAPI-Host", apiHost)
                .build();
    }

    /**
     * Import complet avec pagination par curseur. Deduplique via external_id :
     * relancer l'import n'ajoute que les nouveaux exercices.
     *
     * @param maxExercises borne de securite (ex : 200) — utile pour un test avant
     *                     un import complet, et pour rester sous le quota du plan.
     * @return nombre d'exercices reellement ajoutes.
     */
    public int importAll(int maxExercises) {
        int imported = 0;
        int skipped = 0;
        String cursor = null;
        boolean hasNext = true;

        log.info("Import ExerciseDB : demarrage (max={})", maxExercises);

        while (hasNext && imported < maxExercises) {
            ListResponse page = fetchPage(cursor);
            if (page == null || page.data() == null || page.data().isEmpty()) {
                break;
            }

            for (ListItem item : page.data()) {
                if (imported >= maxExercises) {
                    break;
                }
                if (item.exerciseId() == null
                        || exerciseRepository.existsByExternalId(item.exerciseId())) {
                    skipped++;
                    continue;
                }
                if (importSingle(item.exerciseId())) {
                    imported++;
                }
                sleep();
            }

            hasNext = page.meta() != null && Boolean.TRUE.equals(page.meta().hasNextPage());
            cursor = page.meta() != null ? page.meta().nextCursor() : null;
            if (cursor == null) {
                hasNext = false;
            }
        }

        log.info("Import ExerciseDB : termine — {} ajoutes, {} ignores (deja presents)",
                imported, skipped);
        return imported;
    }

    /**
     * Correspondance des 20 exercices seed (francais) vers un exercice importe
     * equivalent dont on copie le media. La cle est le nom seed EXACT (migration
     * V2) ; la valeur est le nom d'un exercice ExerciseDB present dans la base.
     * Choix : correspondance exacte quand elle existe (Bench Press, Squat,
     * Pull-up...), sinon le plus proche du meme groupe musculaire.
     */
    private static final Map<String, String> SEED_MEDIA_SOURCES = Map.ofEntries(
            Map.entry("Developpe couche barre", "Bench Press"),
            Map.entry("Developpe incline haltere", "Incline Push-up"),
            Map.entry("Pompes", "Push-up"),
            Map.entry("Traction pronation", "Pull-up"),
            Map.entry("Rowing barre", "One Arm Bent-over Row"),
            Map.entry("Tirage vertical poulie", "Sliding Floor Pulldown on Towel"),
            Map.entry("Squat barre", "Squat"),
            Map.entry("Presse a cuisses", "Goblet Squat"),
            Map.entry("Fentes halteres", "Lunge"),
            Map.entry("Developpe militaire", "Seated Shoulder Press"),
            Map.entry("Elevations laterales", "Arnold Press"),
            Map.entry("Curl biceps barre", "Biceps Leg Concentration Curl"),
            Map.entry("Curl marteau", "Hammer Curl"),
            Map.entry("Extension triceps poulie", "Triceps Press"),
            Map.entry("Dips", "Triceps Dip"),
            Map.entry("Crunch", "Crunch Floor"),
            Map.entry("Gainage planche", "Front Plank"),
            Map.entry("Hip thrust", "Sliding Floor Bridge Curl on Towel"),
            Map.entry("Mollets debout", "Bodyweight Standing Calf Raise"),
            Map.entry("Course sur tapis", "Run on Treadmill"));

    /**
     * Donne une video de demonstration (et images / apercu / conseils) aux
     * exercices seed qui n'en avaient pas, en copiant le media d'un exercice
     * importe equivalent. Les programmes/modeles reposant sur ces exercices seed
     * beneficient donc aussi de la video.
     *
     * <p>On CONSERVE le nom francais, le groupe musculaire, l'equipement et les
     * instructions francaises d'origine : seuls les champs media/pedagogiques
     * vides sont remplis. Idempotent (ne cible que les seed sans video).
     *
     * @return nombre d'exercices seed enrichis.
     */
    public int enrichSeedExercises() {
        int enriched = 0;
        List<Exercise> seeds = exerciseRepository.findByExternalIdIsNullAndVideoUrlIsNull();
        for (Exercise seed : seeds) {
            String sourceName = SEED_MEDIA_SOURCES.get(seed.getName());
            if (sourceName == null) {
                continue;
            }
            Optional<Exercise> source =
                    exerciseRepository.findFirstByNameAndExternalIdIsNotNull(sourceName);
            if (source.isEmpty()) {
                log.warn("Enrichissement seed : source '{}' introuvable pour '{}'",
                        sourceName, seed.getName());
                continue;
            }
            copyMedia(source.get(), seed);
            exerciseRepository.save(seed);
            enriched++;
        }
        log.info("Enrichissement seed : {} exercice(s) dote(s) d'une video", enriched);
        return enriched;
    }

    /** Copie le media et le contenu pedagogique de {@code src} vers {@code dest}. */
    private void copyMedia(Exercise src, Exercise dest) {
        dest.setVideoUrl(src.getVideoUrl());
        dest.setImageUrl(src.getImageUrl());
        dest.setImageUrl360p(src.getImageUrl360p());
        dest.setImageUrl480p(src.getImageUrl480p());
        dest.setImageUrl720p(src.getImageUrl720p());
        dest.setImageUrl1080p(src.getImageUrl1080p());
        dest.setOverview(src.getOverview());
        dest.setExerciseTips(src.getExerciseTips());
        dest.setVariations(src.getVariations());
        dest.setTargetMuscles(src.getTargetMuscles());
        dest.setSecondaryMuscles(src.getSecondaryMuscles());
        dest.setBodyPart(src.getBodyPart());
        dest.setExerciseType(src.getExerciseType());
        // On NE touche PAS : name (FR), instructions (FR), primaryMuscle,
        // equipment, externalId (reste null -> l'exercice demeure "seed").
    }

    private ListResponse fetchPage(String cursor) {
        try {
            return restClient.get()
                    .uri(uriBuilder -> {
                        uriBuilder.path("/api/v1/exercises").queryParam("limit", PAGE_SIZE);
                        if (cursor != null) {
                            uriBuilder.queryParam("after", cursor);
                        }
                        return uriBuilder.build();
                    })
                    .retrieve()
                    .body(ListResponse.class);
        } catch (Exception e) {
            log.error("Import ExerciseDB : echec de recuperation d'une page (cursor={})", cursor, e);
            return null;
        }
    }

    /** Recupere le detail complet (video + instructions) et persiste l'exercice. */
    private boolean importSingle(String exerciseId) {
        try {
            DetailResponse response = restClient.get()
                    .uri("/api/v1/exercises/{id}", exerciseId)
                    .retrieve()
                    .body(DetailResponse.class);

            Detail dto = response != null ? response.data() : null;
            if (dto == null || dto.exerciseId() == null) {
                return false;
            }

            exerciseRepository.save(toEntity(dto));
            return true;
        } catch (Exception e) {
            log.warn("Import ExerciseDB : exercice {} ignore ({})", exerciseId, e.getMessage());
            return false;
        }
    }

    private Exercise toEntity(Detail dto) {
        ExerciseDbDtos.ImageUrls img = dto.imageUrls();
        String name = dto.name() != null ? dto.name().trim() : "Exercice";
        Equipment equipment = ExerciseDbMapping.toEquipment(dto.equipments());
        return Exercise.builder()
                .externalId(dto.exerciseId())
                .name(name)
                .primaryMuscle(ExerciseDbMapping.toMuscleGroup(
                        dto.targetMuscles(), dto.bodyParts(), dto.exerciseType()))
                .equipment(equipment)
                // ExerciseDB ne fournit aucun niveau : on le calcule a l'import,
                // avec la meme regle que le backfill des exercices deja en base.
                .difficulty(ExerciseDifficultyRules.of(name, dto.exerciseType(), equipment))
                .instructions(joinPipe(dto.instructions()))
                .videoUrl(blankToNull(dto.videoUrl()))
                .bodyPart(firstOrNull(dto.bodyParts()))
                .exerciseType(dto.exerciseType())
                .targetMuscles(joinComma(dto.targetMuscles()))
                .secondaryMuscles(joinComma(dto.secondaryMuscles()))
                .keywords(joinComma(dto.keywords()))
                .overview(blankToNull(dto.overview()))
                .exerciseTips(joinPipe(dto.exerciseTips()))
                .variations(joinPipe(dto.variations()))
                .imageUrl(blankToNull(dto.imageUrl()))
                .imageUrl360p(img != null ? img.p360() : null)
                .imageUrl480p(img != null ? img.p480() : null)
                .imageUrl720p(img != null ? img.p720() : null)
                .imageUrl1080p(img != null ? img.p1080() : null)
                .build();
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private static String joinPipe(List<String> list) {
        return join(list, " | ");
    }

    private static String joinComma(List<String> list) {
        return join(list, ", ");
    }

    private static String join(List<String> list, String sep) {
        if (list == null || list.isEmpty()) {
            return null;
        }
        return String.join(sep, list.stream().filter(s -> s != null && !s.isBlank()).toList());
    }

    private static String firstOrNull(List<String> list) {
        return (list == null || list.isEmpty()) ? null : list.get(0);
    }

    private static String blankToNull(String s) {
        return (s == null || s.isBlank()) ? null : s;
    }

    private void sleep() {
        try {
            Thread.sleep(THROTTLE_MS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
