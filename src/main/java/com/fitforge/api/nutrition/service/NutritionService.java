package com.fitforge.api.nutrition.service;

import com.fitforge.api.common.enums.MealType;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.nutrition.dto.AddFoodEntryRequest;
import com.fitforge.api.nutrition.dto.CreateNutritionEntryRequest;
import com.fitforge.api.nutrition.dto.MealMacrosDto;
import com.fitforge.api.nutrition.dto.NutritionEntryResponse;
import com.fitforge.api.nutrition.dto.NutritionSummaryResponse;
import com.fitforge.api.nutrition.entity.FoodItem;
import com.fitforge.api.nutrition.entity.NutritionEntry;
import com.fitforge.api.nutrition.mapper.NutritionMapper;
import com.fitforge.api.nutrition.repository.NutritionEntryRepository;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Logique metier du journal alimentaire : CRUD des entrees, ajout depuis le
 * catalogue d'aliments (macros calculees automatiquement), resume quotidien et
 * totaux par repas.
 */
@Service
@RequiredArgsConstructor
public class NutritionService {

    private final NutritionEntryRepository nutritionRepo;
    private final UserRepository userRepo;
    private final NutritionMapper mapper;
    private final FoodCatalogService foodCatalog;

    /** Journal d'un jour donne. */
    @Transactional(readOnly = true)
    public List<NutritionEntryResponse> getByDate(UUID userId, LocalDate date) {
        return nutritionRepo.findByUserIdAndConsumedOnOrderByMealType(userId, date).stream()
                .map(mapper::toResponse)
                .toList();
    }

    /** Ajoute un aliment/repas au journal. */
    @Transactional
    public NutritionEntryResponse create(UUID userId, CreateNutritionEntryRequest req) {
        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        NutritionEntry entry = NutritionEntry.builder()
                .user(user)
                .consumedOn(req.consumedOn())
                .mealType(req.mealType())
                .foodName(req.foodName())
                .quantityGrams(req.quantityGrams())
                .calories(req.calories())
                .proteinG(req.proteinG())
                .carbsG(req.carbsG())
                .fatG(req.fatG())
                .fiberG(req.fiberG())
                .build();

        return mapper.toResponse(nutritionRepo.save(entry));
    }

    // ── Ajout depuis le catalogue d'aliments ─────────────────────────

    /**
     * Ajoute un aliment du catalogue au journal : l'adherent ne fournit qu'une
     * <b>quantite en grammes</b>, le serveur calcule toutes les macros.
     *
     * <p><b>Formule (prorata) :</b> {@code macro = macroPour100g x grammes / 100}.
     * Les valeurs sont <b>figees</b> dans l'entree : l'historique reste exact
     * meme si l'aliment du catalogue est corrige par la suite.
     *
     * <p><b>Concurrence :</b> {@link FoodCatalogService#resolveOrImport} tourne
     * dans une transaction <i>separee</i> ({@code REQUIRES_NEW}). Si deux
     * adherents ajoutent simultanement le meme aliment encore inconnu, la
     * violation de la contrainte d'unicite ({@code usda_fdc_id} cote USDA,
     * {@code off_code} cote Open Food Facts) ne fait echouer que cette
     * transaction-la : on relit alors la ligne validee par l'autre requete au
     * lieu de renvoyer une erreur.
     */
    @Transactional
    public NutritionEntryResponse addFromFood(UUID userId, AddFoodEntryRequest req) {
        if (!req.hasFoodReference()) {
            throw new BusinessException(
                    "Precisez l'aliment a ajouter (foodItemId, fdcId ou offCode)");
        }

        FoodItem food;
        try {
            food = foodCatalog.resolveOrImport(req.foodItemId(), req.fdcId(), req.offCode());
        } catch (DataIntegrityViolationException e) {
            // L'autre requete a gagne la course : sa ligne est validee, on la relit.
            food = findAfterCollision(req)
                    .orElseThrow(() -> new BusinessException(
                            "Impossible d'importer cet aliment, reessayez"));
        }

        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        double grams = req.quantityGrams();
        double ratio = grams / 100.0;

        NutritionEntry entry = NutritionEntry.builder()
                .user(user)
                .foodItem(food)
                .consumedOn(req.consumedOn())
                .mealType(req.mealType())
                .foodName(displayName(food))
                .quantityGrams(round(grams, 1))
                .calories(scaleToInt(food.getCaloriesPer100g(), ratio))
                .proteinG(scale(food.getProteinPer100g(), ratio))
                .carbsG(scale(food.getCarbsPer100g(), ratio))
                .fatG(scale(food.getFatPer100g(), ratio))
                .fiberG(scale(food.getFiberPer100g(), ratio))
                .build();

        return mapper.toResponse(nutritionRepo.save(entry));
    }

    /**
     * Relit l'aliment apres une collision d'unicite, du cote de la source qui
     * a ete designee. Une requete porte l'un ou l'autre identifiant, jamais
     * les deux.
     */
    private java.util.Optional<FoodItem> findAfterCollision(AddFoodEntryRequest req) {
        return req.fdcId() != null
                ? foodCatalog.findCachedByFdcId(req.fdcId())
                : foodCatalog.findCachedByOffCode(req.offCode());
    }

    /**
     * Libelle stocke dans le journal : « Nom (Marque) » si la marque existe.
     *
     * <p>On fige le libelle <b>francais</b> : le journal alimentaire est un
     * historique, il doit rester lisible tel qu'il a ete enregistre.
     */
    private String displayName(FoodItem food) {
        String name = foodCatalog.frenchName(food);
        if (food.getBrand() == null || food.getBrand().isBlank()) {
            return name;
        }
        return name + " (" + food.getBrand() + ")";
    }

    /** Macro au prorata, arrondie a 1 decimale. {@code null} reste {@code null}. */
    private Double scale(Double per100g, double ratio) {
        return per100g == null ? null : round(per100g * ratio, 1);
    }

    /** Calories au prorata, arrondies a l'entier (jamais negatives). */
    private Integer scaleToInt(Double per100g, double ratio) {
        return per100g == null ? null : (int) Math.max(0, Math.round(per100g * ratio));
    }

    private double round(double value, int decimals) {
        return BigDecimal.valueOf(value).setScale(decimals, RoundingMode.HALF_UP).doubleValue();
    }

    /** Modifie une entree existante (verifie la propriete). */
    @Transactional
    public NutritionEntryResponse update(UUID userId, UUID entryId, CreateNutritionEntryRequest req) {
        NutritionEntry entry = loadOwnedEntry(userId, entryId);
        entry.setConsumedOn(req.consumedOn());
        entry.setMealType(req.mealType());
        entry.setFoodName(req.foodName());
        entry.setQuantityGrams(req.quantityGrams());
        entry.setCalories(req.calories());
        entry.setProteinG(req.proteinG());
        entry.setCarbsG(req.carbsG());
        entry.setFatG(req.fatG());
        entry.setFiberG(req.fiberG());
        // Les valeurs sont desormais saisies a la main : l'entree n'est plus
        // rattachee a un aliment du catalogue.
        entry.setFoodItem(null);
        return mapper.toResponse(nutritionRepo.save(entry));
    }

    /**
     * Change uniquement la quantite d'une entree issue du catalogue : toutes
     * les macros sont recalculees au prorata a partir de l'aliment source.
     */
    @Transactional
    public NutritionEntryResponse updateQuantity(UUID userId, UUID entryId, double grams) {
        if (grams <= 0 || grams > 5000) {
            throw new BusinessException("La quantite doit etre comprise entre 1 et 5000 g");
        }
        NutritionEntry entry = loadOwnedEntry(userId, entryId);
        FoodItem food = entry.getFoodItem();
        if (food == null) {
            throw new BusinessException(
                    "Cette entree a ete saisie manuellement : modifiez directement ses valeurs");
        }

        double ratio = grams / 100.0;
        entry.setQuantityGrams(round(grams, 1));
        entry.setCalories(scaleToInt(food.getCaloriesPer100g(), ratio));
        entry.setProteinG(scale(food.getProteinPer100g(), ratio));
        entry.setCarbsG(scale(food.getCarbsPer100g(), ratio));
        entry.setFatG(scale(food.getFatPer100g(), ratio));
        entry.setFiberG(scale(food.getFiberPer100g(), ratio));

        return mapper.toResponse(nutritionRepo.save(entry));
    }

    /** Supprime une entree du journal. */
    @Transactional
    public void delete(UUID userId, UUID entryId) {
        NutritionEntry entry = loadOwnedEntry(userId, entryId);
        nutritionRepo.delete(entry);
    }

    /**
     * Resume d'une journee : additionne calories et macros de toutes les
     * entrees du jour. Les valeurs nulles sont comptees comme 0.
     */
    @Transactional(readOnly = true)
    public NutritionSummaryResponse getSummary(UUID userId, LocalDate date) {
        List<NutritionEntry> entries = nutritionRepo.findByUserIdAndConsumedOnOrderByMealType(userId, date);

        int totalCalories = 0;
        double totalProtein = 0, totalCarbs = 0, totalFat = 0, totalFiber = 0;
        for (NutritionEntry e : entries) {
            totalCalories += e.getCalories() != null ? e.getCalories() : 0;
            totalProtein  += e.getProteinG() != null ? e.getProteinG() : 0;
            totalCarbs    += e.getCarbsG()   != null ? e.getCarbsG()   : 0;
            totalFat      += e.getFatG()     != null ? e.getFatG()     : 0;
            totalFiber    += e.getFiberG()   != null ? e.getFiberG()   : 0;
        }

        return new NutritionSummaryResponse(date, entries.size(),
                totalCalories,
                round(totalProtein, 1), round(totalCarbs, 1),
                round(totalFat, 1), round(totalFiber, 1));
    }

    /**
     * Totaux d'un <b>repas</b> precis de la journee (petit-dejeuner, dejeuner...).
     *
     * <p>Un repas n'est pas une table dediee : c'est le regroupement naturel
     * {@code (adherent, date, mealType)} des lignes du journal.
     */
    @Transactional(readOnly = true)
    public MealMacrosDto getMealMacros(UUID userId, LocalDate date, MealType mealType) {
        List<NutritionEntry> entries =
                nutritionRepo.findByUserIdAndConsumedOnAndMealType(userId, date, mealType);

        int totalCalories = 0;
        double totalProtein = 0, totalCarbs = 0, totalFat = 0, totalFiber = 0;
        for (NutritionEntry e : entries) {
            totalCalories += e.getCalories() != null ? e.getCalories() : 0;
            totalProtein  += e.getProteinG() != null ? e.getProteinG() : 0;
            totalCarbs    += e.getCarbsG()   != null ? e.getCarbsG()   : 0;
            totalFat      += e.getFatG()     != null ? e.getFatG()     : 0;
            totalFiber    += e.getFiberG()   != null ? e.getFiberG()   : 0;
        }

        return new MealMacrosDto(date, mealType, entries.size(), totalCalories,
                round(totalProtein, 1), round(totalCarbs, 1),
                round(totalFat, 1), round(totalFiber, 1));
    }

    /** Charge une entree en verifiant qu'elle appartient a l'adherent connecte. */
    private NutritionEntry loadOwnedEntry(UUID userId, UUID entryId) {
        NutritionEntry entry = nutritionRepo.findById(entryId)
                .orElseThrow(() -> new ResourceNotFoundException("Entree introuvable"));
        if (!entry.getUser().getId().equals(userId)) {
            throw new ResourceNotFoundException("Entree introuvable");
        }
        return entry;
    }
}
