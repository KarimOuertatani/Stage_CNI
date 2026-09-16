package com.fitforge.api.nutrition.controller;

import com.fitforge.api.common.enums.MealType;
import com.fitforge.api.nutrition.dto.AddFoodEntryRequest;
import com.fitforge.api.nutrition.dto.CreateNutritionEntryRequest;
import com.fitforge.api.nutrition.dto.FoodSearchResultDto;
import com.fitforge.api.nutrition.dto.MealMacrosDto;
import com.fitforge.api.nutrition.dto.NutritionEntryResponse;
import com.fitforge.api.nutrition.dto.NutritionSummaryResponse;
import com.fitforge.api.nutrition.service.FoodCatalogService;
import com.fitforge.api.nutrition.service.NutritionService;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * API du journal alimentaire (nutrition).
 *
 * <p>Deux facons d'ajouter un aliment :
 * <ul>
 *   <li><b>Recommandee</b> — recherche dans le catalogue
 *       ({@code GET /foods/search}) puis {@code POST /from-food} avec une simple
 *       quantite en grammes : <b>le serveur calcule toutes les macros</b> a
 *       partir des donnees USDA FoodData Central ;</li>
 *   <li><b>Repli</b> — {@code POST /nutrition} en saisissant soi-meme les
 *       valeurs (repas maison, restaurant, produit absent de la base).</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/v1/nutrition")
@RequiredArgsConstructor
@Tag(name = "Nutrition", description = "Journal alimentaire : recherche d'aliments, repas, calories, macros")
public class NutritionController {

    private final NutritionService service;
    private final FoodCatalogService foodCatalog;

    // ── Catalogue d'aliments (USDA FoodData Central) ─────────────────

    @GetMapping("/foods/search")
    @Operation(
            summary = "Rechercher un aliment",
            description = """
                    Recherche dans USDA FoodData Central, enrichie par notre catalogue local.
                    Les valeurs renvoyees sont exprimees POUR 100 g.
                    Un terme sans resultat renvoie une liste vide (jamais une erreur).
                    Si USDA est indisponible, la recherche bascule automatiquement sur
                    les aliments deja connus localement.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Aliments trouves (liste possiblement vide)"),
            @ApiResponse(responseCode = "400", description = "Service nutritionnel indisponible ou quota atteint"),
            @ApiResponse(responseCode = "401", description = "Token JWT absent ou invalide")
    })
    public List<FoodSearchResultDto> searchFoods(
            @RequestParam(name = "query") String query) {
        return foodCatalog.search(query);
    }

    @GetMapping("/foods/recent")
    @Operation(
            summary = "Mes aliments les plus utilises",
            description = "Aliments deja consommes par l'adherent, du plus recent au plus ancien. "
                    + "Permet de re-ajouter un aliment habituel sans aucune recherche.")
    public List<FoodSearchResultDto> recentFoods(@AuthenticationPrincipal UserPrincipal me) {
        return foodCatalog.recentForUser(me.getId());
    }

    @PostMapping("/from-food")
    @Operation(
            summary = "Ajouter un aliment du catalogue au journal",
            description = """
                    L'adherent ne fournit qu'une quantite en grammes : les calories,
                    proteines, glucides, lipides et fibres sont calcules par le serveur
                    au prorata (macro = macroPour100g x grammes / 100).
                    Fournir soit foodItemId (aliment deja en catalogue), soit fdcId
                    (aliment USDA, importe et mis en cache au passage).""")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Entree creee avec ses macros calculees"),
            @ApiResponse(responseCode = "400", description = "Quantite invalide ou aliment non exploitable"),
            @ApiResponse(responseCode = "404", description = "Aliment introuvable")
    })
    public ResponseEntity<NutritionEntryResponse> addFromFood(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody AddFoodEntryRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(service.addFromFood(me.getId(), req));
    }

    // ── Journal alimentaire ──────────────────────────────────────────

    @GetMapping
    @Operation(summary = "Mon journal alimentaire d'un jour")
    public List<NutritionEntryResponse> byDate(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return service.getByDate(me.getId(), date);
    }

    @PostMapping
    @Operation(summary = "Ajouter un aliment/repas en saisie manuelle",
            description = "Repli quand l'aliment n'existe pas dans le catalogue "
                    + "(repas maison, restaurant). Prefererez /from-food sinon.")
    public ResponseEntity<NutritionEntryResponse> create(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody CreateNutritionEntryRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(me.getId(), req));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Modifier une entree du journal")
    public NutritionEntryResponse update(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id,
            @Valid @RequestBody CreateNutritionEntryRequest req) {
        return service.update(me.getId(), id, req);
    }

    @PatchMapping("/{id}/quantity")
    @Operation(
            summary = "Changer la quantite d'une entree issue du catalogue",
            description = "Recalcule automatiquement toutes les macros au prorata. "
                    + "Refuse (400) si l'entree a ete saisie manuellement.")
    public NutritionEntryResponse updateQuantity(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id,
            @RequestParam double grams) {
        return service.updateQuantity(me.getId(), id, grams);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Supprimer une entree du journal")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        service.delete(me.getId(), id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/summary")
    @Operation(summary = "Totaux calories/macros du jour")
    public NutritionSummaryResponse summary(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return service.getSummary(me.getId(), date);
    }

    @GetMapping("/macros")
    @Operation(summary = "Totaux d'un repas precis de la journee",
            description = "Somme des macros des aliments d'un repas "
                    + "(PETIT_DEJ, DEJEUNER, DINER, COLLATION).")
    public MealMacrosDto mealMacros(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam MealType mealType) {
        return service.getMealMacros(me.getId(), date, mealType);
    }
}
