"use client";

import { useState } from "react";
import type { DailyCount } from "@/lib/types";

/**
 * Inscriptions jour par jour, sur 30 jours.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Pourquoi des barres et non une courbe
 * ═══════════════════════════════════════════════════════════════════
 * Les valeurs sont des comptages ENTIERS et DISCRETS : trois inscriptions
 * mardi, zero mercredi. Une courbe relie les points par des segments, et
 * ces segments affirment quelque chose de faux — qu'il a existe un
 * instant, entre mardi et mercredi, ou le nombre valait 1,5. Sur des
 * petits entiers, cette interpolation est visuellement dominante.
 *
 * Les barres disent aussi les zeros correctement : un jour creux est une
 * colonne absente sur une base visible, pas un creux dans un trace.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Une seule serie, donc AUCUNE legende
 * ═══════════════════════════════════════════════════════════════════
 * Le titre nomme la donnee. Une legende a une entree est une boite qui
 * repete le titre.
 */

/** Marge haute : sans elle, la barre maximale touche le bord du cadre. */
const HEAD_ROOM = 1.15;

export function RegistrationsChart({ data }: { data: DailyCount[] }) {
  const [hover, setHover] = useState<number | null>(null);

  const total = data.reduce((sum, d) => sum + d.count, 0);
  const peak = Math.max(...data.map((d) => d.count), 0);

  /*
   * Plancher d'echelle a 4.
   *
   * Sans lui, une periode ou le maximum journalier est 1 afficherait des
   * barres pleine hauteur : trois inscriptions dans le mois ressembleraient
   * graphiquement a un mois record. C'est le meme raisonnement que le
   * plancher de 10 h de l'histogramme de sommeil de l'application mobile.
   */
  const scaleMax = Math.max(peak * HEAD_ROOM, 4);

  const active = hover !== null ? data[hover] : null;

  return (
    <div>
      {/* ── En-tete : le chiffre d'abord, le detail ensuite ────── */}
      <div className="mb-5 flex flex-wrap items-baseline justify-between gap-3">
        <div>
          <h2 className="text-sm font-semibold tracking-wide text-ink-muted uppercase">
            Inscriptions
          </h2>
          <p className="mt-1 text-xs text-ink-faint">30 derniers jours</p>
        </div>

        {/*
          Le survol remplace le total par la valeur du jour, AU MEME
          ENDROIT. Un second emplacement obligerait l'oeil a changer de
          point de fixation a chaque deplacement de la souris.
        */}
        <div className="text-right tabular-nums">
          {active ? (
            <>
              <p className="text-2xl font-bold text-violet">{active.count}</p>
              <p className="text-xs text-ink-faint">
                {new Date(active.date).toLocaleDateString("fr-FR", {
                  weekday: "long",
                  day: "numeric",
                  month: "long",
                })}
              </p>
            </>
          ) : (
            <>
              <p className="text-2xl font-bold text-ink">{total}</p>
              <p className="text-xs text-ink-faint">nouveaux comptes</p>
            </>
          )}
        </div>
      </div>

      {/* ── Les barres ──────────────────────────────────────────
          Construites en flexbox plutot qu'en SVG : 31 rectangles a
          hauteur proportionnelle n'ont besoin d'aucun systeme de
          coordonnees, et le survol se gere par element sans calcul de
          position. */}
      <div
        className="flex h-40 items-end gap-[3px]"
        onMouseLeave={() => setHover(null)}
        role="img"
        aria-label={`Inscriptions des 30 derniers jours : ${total} au total, maximum ${peak} en une journee.`}
      >
        {data.map((day, index) => {
          const ratio = day.count / scaleMax;
          const isHovered = hover === index;

          return (
            <div
              key={day.date}
              className="group relative flex h-full flex-1 cursor-default items-end"
              onMouseEnter={() => setHover(index)}
            >
              {/* Piste de fond : donne a chaque jour sa colonne, y compris
                  les jours a zero. Sans elle, une semaine creuse serait un
                  vide sans repere. */}
              <div className="absolute inset-x-0 bottom-0 h-full rounded-[3px] bg-white/[0.025]" />

              <div
                className="relative w-full rounded-t-[3px] transition-all duration-150"
                style={{
                  height: `${Math.max(ratio * 100, day.count > 0 ? 3 : 0)}%`,
                  background: isHovered
                    ? "linear-gradient(180deg, var(--color-cyan), var(--color-violet))"
                    : "linear-gradient(180deg, color-mix(in oklab, var(--color-violet) 85%, white), var(--color-violet))",
                  opacity: hover === null || isHovered ? 1 : 0.45,
                }}
              />
            </div>
          );
        })}
      </div>

      {/* ── Axe temporel : trois reperes, pas trente ────────────
          Trente etiquettes de date se chevaucheraient et formeraient une
          bouillie grise. Les extremites et le milieu suffisent a situer
          la periode ; le detail d'un jour precis vient du survol. */}
      <div className="mt-2 flex justify-between text-[0.68rem] text-ink-faint">
        <span>{shortDate(data[0]?.date)}</span>
        <span>{shortDate(data[Math.floor(data.length / 2)]?.date)}</span>
        <span>Aujourd&apos;hui</span>
      </div>
    </div>
  );
}

function shortDate(iso: string | undefined): string {
  if (!iso) return "";
  return new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "short" });
}
