import { apiFetchSafe } from "@/lib/api";
import { Badge, Card, EmptyState, ErrorState, SectionTitle, TableWrap, Td, Th } from "@/components/ui";
import { AiProbe } from "@/components/ai-probe";
import { failureTone, formatLatency, formatNumber, timeAgo } from "@/lib/format";
import type { AiHealth } from "@/lib/types";

export const metadata = { title: "Sante de l'IA — FitForge Admin" };

/**
 * Supervision des fonctions d'intelligence artificielle.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Cinq fonctions, UNE SEULE cle
 * ═══════════════════════════════════════════════════════════════════
 * Le coach IA, l'analyse de photo, l'ajout vocal, l'ajout ecrit et la
 * generation de programme partagent la meme cle Gemini. Quand le quota
 * tombe ou que le service repond 503, tout s'arrete en meme temps.
 *
 * D'ou le decoupage par fonction : un compteur global dirait « l'IA est
 * en panne » sans permettre de savoir laquelle a consomme le quota des
 * autres. C'est exactement l'information qui manque quand ca casse.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Deux fenetres, parce qu'un taux seul ne veut rien dire
 * ═══════════════════════════════════════════════════════════════════
 * « 8 % d'echec » n'est ni bon ni mauvais dans l'absolu. Compare a une
 * semaine a 1 %, c'est une degradation ; compare a une semaine a 9 %,
 * c'est le regime normal de ce service.
 */
export default async function AiHealthPage() {
  const health = await apiFetchSafe<AiHealth>("/admin/ai-health");

  if (!health) {
    return <ErrorState message="Impossible de charger l'etat de l'IA. Le backend repond-il ?" />;
  }

  const totalCalls = health.features.reduce((sum, f) => sum + f.calls24h, 0);

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-bold tracking-tight">Sante de l&apos;IA</h1>
        <p className="mt-1 text-sm text-ink-faint">
          Cinq fonctions partagent une seule cle Gemini. Ce decoupage montre laquelle
          consomme, laquelle echoue, et a quelle vitesse chacune repond.
        </p>
      </header>

      {/* ══ Sonde ════════════════════════════════════════════════ */}
      <Card>
        <SectionTitle>Disponibilite maintenant</SectionTitle>
        <AiProbe configured={health.configured} />

        {health.configured && (
          <dl className="mt-5 grid gap-4 border-t border-line-soft pt-4 sm:grid-cols-2">
            <div>
              <dt className="text-xs font-medium tracking-wide text-ink-faint uppercase">
                Modele general
              </dt>
              <dd className="mt-1 font-mono text-sm text-ink">{health.model ?? "—"}</dd>
            </div>
            <div>
              <dt className="text-xs font-medium tracking-wide text-ink-faint uppercase">
                Modele des programmes
              </dt>
              <dd className="mt-1 font-mono text-sm text-ink">{health.programModel ?? "—"}</dd>
              <p className="mt-1 text-xs text-ink-faint">
                Plus capable : composer un programme coherent demande du raisonnement,
                pas seulement de la redaction.
              </p>
            </div>
          </dl>
        )}
      </Card>

      {/* ══ Par fonction ═════════════════════════════════════════ */}
      <section>
        <h2 className="mb-3 text-xs font-semibold tracking-[0.16em] text-ink-faint uppercase">
          Par fonction · 24 h et 7 jours
        </h2>

        {totalCalls === 0 ? (
          <div className="edge-lit depth rounded-2xl border border-line bg-surface">
            <EmptyState
              icon="🧠"
              title="Aucun appel dans les dernieres 24 heures"
              hint="Un service en panne produirait exactement le meme resultat : lance la sonde ci-dessus pour distinguer « personne n'a rien demande » de « rien ne repond »."
            />
          </div>
        ) : (
          <TableWrap>
            <thead>
              <tr>
                <Th>Fonction</Th>
                <Th className="text-right">Appels 24 h</Th>
                <Th className="text-right">Echecs 24 h</Th>
                <Th className="text-right">Taux 24 h</Th>
                <Th className="text-right">Taux 7 j</Th>
                <Th className="text-right">Latence moy.</Th>
                <Th className="text-right">Max</Th>
              </tr>
            </thead>
            <tbody>
              {health.features.map((f) => {
                const tone = failureTone(f.failureRate24h);
                // La reference sur 7 jours n'est affichee que si elle
                // existe : « 0 % » sur zero appel serait un faux repere.
                const hasWeek = f.calls7d > 0;

                return (
                  <tr key={f.feature} className="transition-colors hover:bg-white/[0.025]">
                    <Td className="font-medium">{f.label}</Td>
                    <Td className="text-right tabular-nums">{formatNumber(f.calls24h)}</Td>
                    <Td className="text-right tabular-nums">
                      <span className={f.failures24h > 0 ? "text-warn" : "text-ink-faint"}>
                        {formatNumber(f.failures24h)}
                      </span>
                    </Td>
                    <Td className="text-right">
                      {f.calls24h > 0 ? (
                        <Badge tone={tone}>{f.failureRate24h.toFixed(1)} %</Badge>
                      ) : (
                        <span className="text-ink-faint">—</span>
                      )}
                    </Td>
                    <Td className="text-right text-ink-faint tabular-nums">
                      {hasWeek ? `${f.failureRate7d.toFixed(1)} %` : "—"}
                    </Td>
                    <Td className="text-right tabular-nums">{formatLatency(f.avgLatencyMs24h)}</Td>
                    <Td className="text-right text-ink-faint tabular-nums">
                      {formatLatency(f.maxLatencyMs24h)}
                    </Td>
                  </tr>
                );
              })}
            </tbody>
          </TableWrap>
        )}

        <p className="mt-3 text-xs text-ink-faint">
          La latence moyenne ne compte que les appels <strong>reussis</strong> : un echec
          reseau rend la main en quelques millisecondes et ferait baisser la moyenne au
          moment precis ou le service se degrade.
        </p>
      </section>

      {/* ══ Dernieres erreurs ════════════════════════════════════ */}
      <Card>
        <SectionTitle count={health.recentFailures.length}>Dernieres erreurs</SectionTitle>

        {health.recentFailures.length === 0 ? (
          <EmptyState icon="✓" title="Aucun echec enregistre" />
        ) : (
          <>
            <ul className="flex flex-col gap-2">
              {health.recentFailures.map((failure, index) => (
                <li
                  key={`${failure.occurredAt}-${index}`}
                  className="flex flex-wrap items-center gap-3 rounded-xl border border-line bg-surface-2 px-3.5 py-2.5"
                >
                  <Badge tone="danger">{failure.errorType ?? "inconnu"}</Badge>
                  <span className="text-sm text-ink-muted">{labelOf(failure.feature)}</span>
                  <span className="text-xs text-ink-faint tabular-nums">
                    {formatLatency(failure.latencyMs)}
                  </span>
                  <span className="ml-auto text-xs text-ink-faint">
                    {timeAgo(failure.occurredAt)}
                  </span>
                </li>
              ))}
            </ul>

            <p className="mt-4 text-xs leading-relaxed text-ink-faint">
              <strong className="text-ink-muted">Lire ces codes :</strong> un{" "}
              <code className="text-warn">HTTP_503</code> est une saturation cote Google —
              frequente sur les modeles les plus sollicites, et deja rattrapee par trois
              tentatives cote client. Un <code className="text-danger">HTTP_429</code> est
              un quota depasse : toutes les fonctions IA vont echouer jusqu&apos;a la
              reinitialisation. Un <code className="text-danger">HTTP_400</code> vient de
              nous, pas de Google.
            </p>
          </>
        )}
      </Card>
    </div>
  );
}

/** Repli si une fonction apparait dans les erreurs sans etre dans le tableau. */
function labelOf(feature: string): string {
  const labels: Record<string, string> = {
    COACH_CHAT: "Coach IA",
    MEAL_PHOTO: "Photo de repas",
    MEAL_VOICE: "Ajout vocal",
    MEAL_TEXT: "Ajout ecrit",
    PROGRAM_GENERATION: "Generation de programme",
    HEALTH_PROBE: "Sonde de controle",
  };
  return labels[feature] ?? feature;
}
