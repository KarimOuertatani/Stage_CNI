import Link from "next/link";
import { apiFetchSafe } from "@/lib/api";
import {
  Avatar,
  Badge,
  EmptyState,
  ErrorState,
  TableWrap,
  Td,
  Th,
} from "@/components/ui";
import { COACH_STATUS, formatNumber, timeAgo } from "@/lib/format";
import type { CoachApplicationSummary, CoachStatus, PageResponse } from "@/lib/types";

export const metadata = { title: "Candidatures coach — FitForge Admin" };

/**
 * File des candidatures de coach.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Le filtre par defaut est « En attente », pas « Tous »
 * ═══════════════════════════════════════════════════════════════════
 * On ouvre cet ecran pour TRAITER, pas pour consulter un historique.
 * Afficher tout par defaut noierait les trois dossiers a examiner parmi
 * cent coachs deja valides, et obligerait a filtrer a chaque visite.
 *
 * Les autres vues restent a un clic — mais elles sont le cas
 * particulier, pas le cas normal.
 */

const FILTERS: { value: CoachStatus | "ALL"; label: string }[] = [
  { value: "PENDING", label: "En attente" },
  { value: "APPROVED", label: "Valides" },
  { value: "REJECTED", label: "A corriger" },
  { value: "SUSPENDED", label: "Suspendus" },
  { value: "DRAFT", label: "Brouillons" },
  { value: "ALL", label: "Tous" },
];

export default async function CoachApplicationsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const params = await searchParams;
  const status = (params.status as CoachStatus | "ALL" | undefined) ?? "PENDING";

  const [page, counts] = await Promise.all([
    apiFetchSafe<PageResponse<CoachApplicationSummary>>(
      `/admin/coach-applications?size=50${status !== "ALL" ? `&status=${status}` : ""}`,
    ),
    apiFetchSafe<Record<CoachStatus, number>>("/admin/coach-applications/counts"),
  ]);

  if (!page) {
    return <ErrorState message="Impossible de charger les candidatures. Le backend repond-il ?" />;
  }

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-bold tracking-tight">Candidatures coach</h1>
        <p className="mt-1 text-sm text-ink-faint">
          Un coach n&apos;apparait dans l&apos;annuaire qu&apos;une fois son dossier valide
          ici. Compare les titres qu&apos;il declare aux justificatifs qu&apos;il a
          deposes, et verifie que le nom correspond a celui du compte.
        </p>
      </header>

      {/* ══ Filtres ══════════════════════════════════════════════
          Une seule rangee, au-dessus du tableau. Les compteurs sont
          integres aux onglets : afficher « En attente (3) » evite
          d'avoir a cliquer pour decouvrir qu'un onglet est vide. */}
      <div className="flex flex-wrap gap-2">
        {FILTERS.map((filter) => {
          const active = status === filter.value;
          const count =
            filter.value === "ALL"
              ? undefined
              : (counts?.[filter.value as CoachStatus] ?? 0);

          return (
            <Link
              key={filter.value}
              href={`/coachs?status=${filter.value}`}
              className={`rounded-xl border px-3.5 py-2 text-sm transition-colors ${
                active
                  ? "border-violet/50 bg-violet/12 font-medium text-ink"
                  : "border-line text-ink-muted hover:border-white/20 hover:text-ink"
              }`}
            >
              {filter.label}
              {count !== undefined && count > 0 && (
                <span className="ml-2 text-xs text-ink-faint tabular-nums">{count}</span>
              )}
            </Link>
          );
        })}
      </div>

      {/* ══ Tableau ══════════════════════════════════════════════ */}
      {page.items.length === 0 ? (
        <div className="edge-lit depth rounded-2xl border border-line bg-surface">
          <EmptyState
            icon={status === "PENDING" ? "✓" : "—"}
            title={
              status === "PENDING"
                ? "Aucun dossier n'attend de decision"
                : "Aucun dossier dans cette vue"
            }
            hint={
              status === "PENDING"
                ? "Tout est traite. Les nouveaux dossiers apparaitront ici des qu'un coach soumettra sa candidature."
                : undefined
            }
          />
        </div>
      ) : (
        <TableWrap>
          <thead>
            <tr>
              <Th>Coach</Th>
              <Th>Statut</Th>
              <Th>Pieces</Th>
              <Th>Ville</Th>
              <Th>Experience</Th>
              <Th>Soumis</Th>
            </tr>
          </thead>
          <tbody>
            {page.items.map((app) => {
              const meta = COACH_STATUS[app.status];

              return (
                <tr key={app.profileId} className="transition-colors hover:bg-white/[0.025]">
                  <Td>
                    <Link
                      href={`/coachs/${app.profileId}`}
                      className="flex items-center gap-3 group"
                    >
                      <Avatar name={app.fullName} url={app.avatarUrl} />
                      <div className="min-w-0">
                        <p className="truncate font-medium transition-colors group-hover:text-cyan">
                          {app.fullName}
                        </p>
                        <p className="truncate text-xs text-ink-faint">{app.email}</p>
                      </div>
                    </Link>
                  </Td>

                  <Td>
                    {/* Toujours le libelle avec la couleur, jamais la
                        couleur seule : « Valide » et « A corriger » sont
                        proches en deuteranopie. */}
                    <Badge tone={meta.tone}>{meta.label}</Badge>
                  </Td>

                  <Td>
                    <span
                      className={`text-sm tabular-nums ${
                        app.documentCount === 0 ? "text-ink-faint" : "text-ink"
                      }`}
                    >
                      {app.documentCount}
                    </span>
                  </Td>

                  <Td className="text-ink-muted">{app.city ?? "—"}</Td>

                  <Td className="text-ink-muted">
                    {app.yearsExperience !== null ? `${app.yearsExperience} ans` : "—"}
                  </Td>

                  <Td className="whitespace-nowrap text-ink-faint">
                    {app.submittedAt ? timeAgo(app.submittedAt) : "non soumis"}
                  </Td>
                </tr>
              );
            })}
          </tbody>
        </TableWrap>
      )}

      {page.totalElements > page.items.length && (
        <p className="text-center text-xs text-ink-faint">
          {formatNumber(page.items.length)} affiches sur {formatNumber(page.totalElements)}
        </p>
      )}
    </div>
  );
}
