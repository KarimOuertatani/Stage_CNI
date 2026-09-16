import { NextResponse } from "next/server";
import { apiFetch } from "@/lib/api";
import type { ProbeResult } from "@/lib/types";

/**
 * Relais de la sonde IA.
 *
 * Comme le compteur de notifications, la sonde est declenchee depuis un
 * composant client, qui n'a pas acces au jeton (cookie `httpOnly`). Cette
 * route lit le cookie cote serveur et retransmet le resultat.
 *
 * `POST`, parce que l'appel a un effet de bord reel : il consomme le
 * quota Gemini partage par toutes les fonctions IA et ecrit une ligne de
 * journal. Une route `GET` pourrait etre prechargee par le navigateur ou
 * rejouee a chaque rafraichissement.
 */
export async function POST() {
  try {
    const result = await apiFetch<ProbeResult>("/admin/ai-health/probe", {
      method: "POST",
    });
    return NextResponse.json(result, { headers: { "Cache-Control": "no-store" } });
  } catch {
    // Le backend lui-meme est injoignable — a distinguer d'un Gemini en
    // panne, que le backend aurait su rapporter.
    return NextResponse.json(
      { reachable: false, latencyMs: 0, error: "Backend injoignable" } satisfies ProbeResult,
      { status: 200, headers: { "Cache-Control": "no-store" } },
    );
  }
}
