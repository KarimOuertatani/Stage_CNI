import Link from "next/link";
import { apiFetchSafe } from "@/lib/api";
import { Avatar, Badge, EmptyState, ErrorState, TableWrap, Td, Th } from "@/components/ui";
import { PROBLEM_CATEGORY, PROBLEM_STATUS, ROLE, formatNumber, timeAgo } from "@/lib/format";
import type { PageResponse, ProblemReport, ProblemStatus } from "@/lib/types";

export const metadata = { title: "Signalements — FitForge Admin" };

/**
 * File des signalements.
 *
 * Comme pour les candidatures coach, le filtre par defaut est ce qui
 * ATTEND une action — « Nouveaux » — et non l'historique complet. On
 * ouvre cet ecran pour traiter.
 */

const FILTERS: { value: ProblemStatus | "ALL"; label: string }[] = [
  { value: "NEW", label: "Nouveaux" },
  { value: "IN_PROGRESS", label: "En cours" },
  { value: "RESOLVED", label: "Resolus" },
  { value: "CLOSED", label: "Clos" },
  { value: "ALL", label: "Tous" },
];

export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const params = await searchParams;
  const status = (params.status as ProblemStatus | "ALL" | undefined) ?? "NEW";

  const [page, counts] = await Promise.all([
    apiFetchSafe<PageResponse<ProblemReport>>(
      `/admin/problem-reports?size=50${status !== "ALL" ? `&status=${status}` : ""}`,
    ),
    apiFetchSafe<Record<ProblemStatus, number>>("/admin/problem-reports/counts"),
  ]);

  if (!page) {
    return <ErrorState message="Impossible de charger les signalements. Le backend repond-il ?" />;
  }

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-bold tracking-tight">Signalements</h1>
        <p className="mt-1 text-sm text-ink-faint">
          Problemes remontes depuis l&apos;application, par les adherents comme par les
          coachs. La reponse que tu ecris ici s&apos;affiche dans leur ecran
          « Mes signalements ».
        </p>
      </header>

      <div className="flex flex-wrap gap-2">
        {FILTERS.map((filter) => {
          const active = status === filter.value;
          const count =
            filter.value === "ALL" ? undefined : (counts?.[filter.value as ProblemStatus] ?? 0);

          return (
            <Link
              key={filter.value}
              href={`/signalements?status=${filter.value}`}
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

      {page.items.length === 0 ? (
        <div className="edge-lit depth rounded-2xl border border-line bg-surface">
          <EmptyState
            icon={status === "NEW" ? "✓" : "—"}
            title={
              status === "NEW"
                ? "Aucun signalement en attente"
                : "Aucun signalement dans cette vue"
            }
            hint={
              status === "NEW"
                ? "Tout ce qui est arrive a ete ouvert. Les nouveaux signalements apparaitront ici."
                : undefined
            }
          />
        </div>
      ) : (
        <TableWrap>
          <thead>
            <tr>
              <Th>Sujet</Th>
              <Th>Categorie</Th>
              <Th>Auteur</Th>
              <Th>Statut</Th>
              <Th>Recu</Th>
            </tr>
          </thead>
          <tbody>
            {page.items.map((report) => {
              const category = PROBLEM_CATEGORY[report.category];
              const state = PROBLEM_STATUS[report.status];

              return (
                <tr key={report.id} className="transition-colors hover:bg-white/[0.025]">
                  <Td>
                    <Link href={`/signalements/${report.id}`} className="group block max-w-md">
                      <p className="truncate font-medium transition-colors group-hover:text-cyan">
                        {report.subject}
                      </p>
                      <p className="truncate text-xs text-ink-faint">{report.description}</p>
                    </Link>
                  </Td>

                  <Td className="whitespace-nowrap">
                    <span className="text-sm text-ink-muted">
                      {category.icon} {category.label}
                    </span>
                  </Td>

                  <Td>
                    <div className="flex items-center gap-2.5">
                      <Avatar
                        name={report.reporterName}
                        url={report.reporterAvatarUrl}
                        size={28}
                      />
                      <div className="min-w-0">
                        <p className="truncate text-sm">{report.reporterName}</p>
                        <p className="truncate text-xs text-ink-faint">
                          {ROLE[report.reporterRole].label}
                        </p>
                      </div>
                    </div>
                  </Td>

                  <Td>
                    <Badge tone={state.tone}>{state.label}</Badge>
                  </Td>

                  <Td className="whitespace-nowrap text-ink-faint">
                    {timeAgo(report.createdAt)}
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
