import { NextResponse } from "next/server";
import { apiFetchSafe } from "@/lib/api";

/**
 * Relais du compteur de notifications, pour la cloche.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Pourquoi un relais plutot qu'un appel direct depuis le navigateur
 * ═══════════════════════════════════════════════════════════════════
 * La cloche est un composant client : elle interroge le serveur toutes
 * les minutes. Elle ne peut pas appeler l'API Spring elle-meme, parce
 * qu'elle n'a aucun moyen d'obtenir le jeton — celui-ci vit dans un
 * cookie `httpOnly`, invisible au JavaScript de la page (c'est
 * precisement ce qui protege un jeton d'administrateur d'une faille XSS).
 *
 * Cette route tourne cote serveur, lit le cookie, et ne renvoie au
 * navigateur qu'un nombre. Le jeton ne quitte jamais le serveur.
 *
 * En cas de panne, on renvoie `null` plutot qu'une erreur : la cloche
 * conserve alors sa derniere valeur connue. Afficher zero laisserait
 * croire qu'il n'y a rien a traiter.
 */
export async function GET() {
  const result = await apiFetchSafe<{ count: number }>("/admin/notifications/unread-count");

  return NextResponse.json(
    { count: result?.count ?? null },
    { headers: { "Cache-Control": "no-store" } },
  );
}
