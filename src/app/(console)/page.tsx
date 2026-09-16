import Link from "next/link";
import { apiFetchSafe } from "@/lib/api";
import { Card, CardTitle, EmptyState, ErrorState, StatTile } from "@/components/ui";
import { RegistrationsChart } from "@/components/registrations-chart";
import { formatNumber } from "@/lib/format";
import type { Dashboard } from "@/lib/types";

export const metadata = { title: "Tableau de bord — FitForge Admin" };

/**
 * Tableau de bord.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Deux natures d'information, deux traitements visuels
 * ═══════════════════════════════════════════════════════════════════
 * En haut, ce qui ATTEND UNE ACTION : dossiers a examiner, signalements
 * ouverts. Ces nombres doivent tomber a zero ; tant qu'ils ne le sont
 * pas, quelqu'un attend une reponse. Ils sont cliquables (une statistique
 * sans action est une impasse) et se teintent d'ambre des qu'ils
 * depassent zero.
 *
 * En dessous, ce qui DECRIT L'ACTIVITE : membres, seances, repas. Ces
 * nombres ne se traitent pas, ils se regardent.
 *
 * Les melanger dans une meme rangee de tuiles identiques ferait lire
 * « 3 dossiers en attente » comme « 412 membres » : une statistique de
 * plus, sans urgence. C'est exactement le defaut que la refonte de
 * l'accueil mobile avait corrige en retirant une donnee inventee — un
 * ecran d'accueil doit dire ce qui est vrai ET ce qui compte.
 */
export default async function DashboardPage() {
  const data = await apiFetchSafe<Dashboard>("/admin/dashboard");

  if (!data) {
    return (
      <ErrorState message="Le backend ne repond pas. Verifie qu'il tourne sur le port 8081 et que la base est demarree." />
    );
  }

  const toHandle =
    data.pendingCoachApplications + data.newProblemReports + data.inProgressProblemReports;

  return (
    <div className="flex flex-col gap-8">
      <header>
        <h1 className="text-2xl font-bold tracking-tight">Tableau de bord</h1>
        <p className="mt-1 text-sm text-ink-faint">
          {toHandle === 0
            ? "Rien n'attend de decision. Tout est traite."
            : `${toHandle} element${toHandle > 1 ? "s" : ""} attend${toHandle > 1 ? "ent" : ""} une action de ta part.`}
        </p>
      </header>

      {/* ══ A traiter ═════════════════════════════════════════════ */}
      <section>
        <h2 className="mb-3 text-xs font-semibold tracking-[0.16em] text-ink-faint uppercase">
          A traiter
        </h2>
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <StatTile
            label="Candidatures coach"
            value={formatNumber(data.pendingCoachApplications)}
            hint={
              data.pendingCoachApplications === 0
                ? "Aucun dossier en attente"
                : "Dossiers soumis, en attente d'examen"
            }
            tone={data.pendingCoachApplications > 0 ? "warn" : "ok"}
            urgent={data.pendingCoachApplications > 0}
            href="/coachs?status=PENDING"
          />
          <StatTile
            label="Signalements nouveaux"
            value={formatNumber(data.newProblemReports)}
            hint={
              data.newProblemReports === 0
                ? "Aucun signalement non ouvert"
                : "Jamais ouverts par l'administration"
            }
            tone={data.newProblemReports > 0 ? "warn" : "ok"}
            urgent={data.newProblemReports > 0}
            href="/signalements?status=NEW"
          />
          <StatTile
            label="Signalements en cours"
            value={formatNumber(data.inProgressProblemReports)}
            hint="Pris en charge, pas encore clos"
            tone={data.inProgressProblemReports > 0 ? "violet" : "ok"}
            href="/signalements?status=IN_PROGRESS"
          />
        </div>
      </section>

      {/* ══ Communaute + courbe ═══════════════════════════════════ */}
      <section className="grid gap-4 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <RegistrationsChart data={data.registrationsPerDay} />
        </Card>

        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-1">
          <StatTile
            label="Adherents"
            value={formatNumber(data.totalMembers)}
            hint={`+${formatNumber(data.newAccounts30d)} comptes sur 30 jours`}
            tone="info"
            href="/membres?role=ADHERENT"
          />
          <StatTile
            label="Coachs valides"
            value={formatNumber(data.approvedCoaches)}
            hint={`sur ${formatNumber(data.totalCoaches)} comptes coach`}
            tone="violet"
            href="/membres?role=COACH"
          />
          <StatTile
            label="Actifs (7 jours)"
            value={formatNumber(data.activeAccounts7d)}
            hint="Comptes s'etant connectes"
            tone="ok"
          />
        </div>
      </section>

      {/* ══ Activite ══════════════════════════════════════════════ */}
      <section>
        <h2 className="mb-3 text-xs font-semibold tracking-[0.16em] text-ink-faint uppercase">
          Activite sur 30 jours
        </h2>
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <StatTile
            label="Seances enregistrees"
            value={formatNumber(data.workoutsLogged30d)}
            tone="violet"
          />
          <StatTile label="Repas notes" value={formatNumber(data.mealsLogged30d)} tone="info" />
          <StatTile label="Nuits saisies" value={formatNumber(data.sleepEntries30d)} tone="ok" />
          <StatTile
            label="Comptes inactifs"
            value={formatNumber(data.inactiveAccounts)}
            hint="Suspendus ou email non verifie"
            tone="neutral"
            href="/membres?enabled=false"
          />
        </div>
      </section>

      {/* ══ IA ════════════════════════════════════════════════════ */}
      <section>
        <Card>
          <CardTitle
            action={
              <Link
                href="/ia"
                className="text-xs font-medium text-cyan transition-opacity hover:opacity-75"
              >
                Voir le detail →
              </Link>
            }
          >
            Intelligence artificielle · 24 h
          </CardTitle>

          {data.aiCalls24h === 0 ? (
            <EmptyState
              icon="🧠"
              title="Aucun appel dans les dernieres 24 heures"
              hint="Un service en panne produirait le meme chiffre : ouvre la page dediee et lance la sonde pour trancher."
            />
          ) : (
            <div className="flex flex-wrap items-end gap-x-10 gap-y-4">
              <div>
                <p className="text-xs tracking-wide text-ink-faint uppercase">Appels</p>
                <p className="mt-1 text-3xl font-bold tabular-nums">
                  {formatNumber(data.aiCalls24h)}
                </p>
              </div>
              <div>
                <p className="text-xs tracking-wide text-ink-faint uppercase">Echecs</p>
                <p
                  className="mt-1 text-3xl font-bold tabular-nums"
                  style={{
                    color:
                      data.aiFailures24h > 0 ? "var(--color-warn)" : "var(--color-ok)",
                  }}
                >
                  {formatNumber(data.aiFailures24h)}
                </p>
              </div>
              <p className="max-w-md text-sm text-ink-faint">
                Quelques echecs sont normaux : Gemini repond regulierement 503 sur les
                modeles les plus sollicites, et les clients reessaient trois fois avant
                d&apos;abandonner.
              </p>
            </div>
          )}
        </Card>
      </section>
    </div>
  );
}
