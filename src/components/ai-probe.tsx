"use client";

import { useState } from "react";
import { formatLatency } from "@/lib/format";
import type { ProbeResult } from "@/lib/types";

/**
 * Sonde de disponibilite de Gemini.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Ce que la sonde apporte que l'historique ne peut pas apporter
 * ═══════════════════════════════════════════════════════════════════
 * Le journal des appels dit ce qui s'est passe. Il ne dit rien quand il
 * ne s'est rien passe : un dimanche matin sans usage, la page afficherait
 * « 0 echec » pour un service totalement hors ligne — la meilleure des
 * nouvelles et la pire produisent le meme zero.
 *
 * La sonde repond a la seule question a laquelle l'historique ne peut pas
 * repondre : est-ce que ca marche MAINTENANT ?
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Pourquoi elle n'est pas declenchee automatiquement
 * ═══════════════════════════════════════════════════════════════════
 * Elle consomme le quota Gemini, partage par le coach IA, la photo de
 * repas, l'ajout vocal et la generation de programme. Une sonde lancee a
 * chaque ouverture de page — ou pire, toutes les trente secondes —
 * prendrait aux adherents une part du quota pour surveiller un service
 * que personne ne regarde. C'est un geste explicite.
 */
export function AiProbe({ configured }: { configured: boolean }) {
  const [result, setResult] = useState<ProbeResult | null>(null);
  const [running, setRunning] = useState(false);

  async function run() {
    setRunning(true);
    try {
      const res = await fetch("/api/ai-probe", { method: "POST" });
      setResult(await res.json());
    } catch {
      setResult({
        reachable: false,
        latencyMs: 0,
        error: "La console n'a pas pu joindre le backend",
      });
    } finally {
      setRunning(false);
    }
  }

  if (!configured) {
    return (
      <div className="rounded-xl border border-danger/30 bg-danger/8 px-4 py-3.5">
        <p className="text-sm font-medium text-danger">Aucune cle Gemini configuree</p>
        <p className="mt-1.5 text-sm text-ink-muted">
          Les cinq fonctions IA sont hors service. L&apos;application demarre
          normalement et tout le reste fonctionne — c&apos;est voulu : une cle absente
          ne doit pas faire tomber la nutrition ou le coaching.
        </p>
        <p className="mt-2 text-xs text-ink-faint">
          Definis <code className="text-cyan">GEMINI_API_KEY</code> sur le serveur, puis
          redemarre-le.
        </p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-3">
        <button
          type="button"
          onClick={run}
          disabled={running}
          className="rounded-xl border border-cyan/40 bg-cyan/10 px-4 py-2.5 text-sm font-semibold text-cyan transition-colors disabled:opacity-60 not-disabled:hover:bg-cyan/16"
        >
          {running ? "Appel en cours…" : "Tester maintenant"}
        </button>

        <p className="text-xs text-ink-faint">
          Envoie un appel reel au modele. Consomme le quota partage — quelques unites.
        </p>
      </div>

      {result && (
        <div
          role="status"
          className={`rounded-xl border px-4 py-3 ${
            result.reachable
              ? "border-ok/30 bg-ok/8"
              : "border-danger/30 bg-danger/8"
          }`}
        >
          {result.reachable ? (
            <>
              <p className="text-sm font-medium text-ok">
                Le modele repond · {formatLatency(result.latencyMs)}
              </p>
              <p className="mt-1 text-xs text-ink-faint">
                La cle est acceptee et le service est joignable a l&apos;instant.
              </p>
            </>
          ) : (
            <>
              <p className="text-sm font-medium text-danger">
                Le modele ne repond pas{result.error ? ` · ${result.error}` : ""}
              </p>
              <p className="mt-1 text-xs text-ink-muted">
                {result.error?.startsWith("HTTP 429")
                  ? "Quota depasse : les fonctions IA vont echouer jusqu'a la reinitialisation."
                  : result.error?.startsWith("HTTP 5")
                    ? "Panne cote Google. Les clients reessaient trois fois avant d'abandonner ; une saturation passagere est frequente sur ce service."
                    : "Verifie la cle, la connexion sortante du serveur, et le quota."}
              </p>
            </>
          )}
        </div>
      )}
    </div>
  );
}
