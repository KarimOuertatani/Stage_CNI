import Link from "next/link";
import { apiFetchSafe } from "@/lib/api";
import { Avatar, Badge, EmptyState, ErrorState, TableWrap, Td, Th } from "@/components/ui";
import { COACH_STATUS, ROLE, formatNumber, timeAgo } from "@/lib/format";
import type { PageResponse, UserSummary } from "@/lib/types";

export const metadata = { title: "Membres — FitForge Admin" };

/**
 * Tableau des membres.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Les filtres passent par l'URL, pas par un etat local
 * ═══════════════════════════════════════════════════════════════════
 * Une vue filtree est donc partageable, marquable, et survit au bouton
 * « precedent ». C'est ce qui permet au tableau de bord de pointer
 * directement vers `/membres?role=COACH` ou `/membres?enabled=false` : une
 * statistique cliquable qui n'ouvrirait qu'une liste non filtree serait
 * une impasse deguisee.
 *
 * La recherche est un formulaire GET, sans JavaScript. Un champ a
 * declenchement immediat enverrait une requete par frappe, et l'ecran
 * n'en a pas besoin : on cherche une personne precise, on tape son nom,
 * on valide.
 */

const ROLE_FILTERS = [
  { value: "", label: "Tous" },
  { value: "ADHERENT", label: "Adherents" },
  { value: "COACH", label: "Coachs" },
  { value: "ADMIN", label: "Admins" },
];

export default async function MembersPage({
  searchParams,
}: {
  searchParams: Promise<{ role?: string; enabled?: string; query?: string }>;
}) {
  const params = await searchParams;
  const role = params.role ?? "";
  const enabled = params.enabled ?? "";
  const query = params.query ?? "";

  const search = new URLSearchParams({ size: "50" });
  if (role) search.set("role", role);
  if (enabled) search.set("enabled", enabled);
  if (query) search.set("query", query);

  const page = await apiFetchSafe<PageResponse<UserSummary>>(`/admin/users?${search}`);

  if (!page) {
    return <ErrorState message="Impossible de charger les membres. Le backend repond-il ?" />;
  }

  /** Conserve les filtres courants en changeant une seule cle. */
  function hrefWith(patch: Record<string, string>): string {
    const next = new URLSearchParams();
    const merged = { role, enabled, query, ...patch };
    for (const [key, value] of Object.entries(merged)) {
      if (value) next.set(key, value);
    }
    const qs = next.toString();
    return qs ? `/membres?${qs}` : "/membres";
  }

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-bold tracking-tight">Membres</h1>
        <p className="mt-1 text-sm text-ink-faint">
          {formatNumber(page.totalElements)} compte
          {page.totalElements > 1 ? "s" : ""}
          {query && ` correspondant a « ${query} »`}
        </p>
      </header>

      {/* ══ Filtres, en une seule rangee au-dessus du tableau ════ */}
      <div className="flex flex-wrap items-center gap-2">
        {ROLE_FILTERS.map((filter) => (
          <Link
            key={filter.value || "all"}
            href={hrefWith({ role: filter.value })}
            className={`rounded-xl border px-3.5 py-2 text-sm transition-colors ${
              role === filter.value
                ? "border-violet/50 bg-violet/12 font-medium text-ink"
                : "border-line text-ink-muted hover:border-white/20 hover:text-ink"
            }`}
          >
            {filter.label}
          </Link>
        ))}

        <span className="mx-1 h-6 w-px bg-line" />

        <Link
          href={hrefWith({ enabled: enabled === "false" ? "" : "false" })}
          className={`rounded-xl border px-3.5 py-2 text-sm transition-colors ${
            enabled === "false"
              ? "border-warn/50 bg-warn/12 font-medium text-warn"
              : "border-line text-ink-muted hover:border-white/20 hover:text-ink"
          }`}
        >
          Inactifs seulement
        </Link>

        <form method="get" action="/membres" className="ml-auto flex gap-2">
          {role && <input type="hidden" name="role" value={role} />}
          {enabled && <input type="hidden" name="enabled" value={enabled} />}
          <input
            name="query"
            defaultValue={query}
            placeholder="Nom ou email…"
            className="w-56 rounded-xl border border-line bg-surface-2 px-3.5 py-2 text-sm outline-none placeholder:text-ink-faint/70 focus:border-violet/60"
          />
          <button
            type="submit"
            className="rounded-xl border border-line px-3.5 py-2 text-sm text-ink-muted transition-colors hover:border-white/25 hover:text-ink"
          >
            Chercher
          </button>
        </form>
      </div>

      {/* ══ Tableau ══════════════════════════════════════════════ */}
      {page.items.length === 0 ? (
        <div className="edge-lit depth rounded-2xl border border-line bg-surface">
          <EmptyState
            icon="🔍"
            title="Aucun compte ne correspond"
            hint="Essaie un autre terme, ou retire les filtres."
          />
        </div>
      ) : (
        <TableWrap>
          <thead>
            <tr>
              <Th>Membre</Th>
              <Th>Role</Th>
              <Th>Etat</Th>
              <Th>Inscrit</Th>
              <Th>Derniere connexion</Th>
            </tr>
          </thead>
          <tbody>
            {page.items.map((user) => (
              <tr key={user.id} className="transition-colors hover:bg-white/[0.025]">
                <Td>
                  <Link href={`/membres/${user.id}`} className="group flex items-center gap-3">
                    <Avatar name={user.fullName} url={user.avatarUrl} />
                    <div className="min-w-0">
                      <p className="truncate font-medium transition-colors group-hover:text-cyan">
                        {user.fullName}
                      </p>
                      <p className="truncate text-xs text-ink-faint">{user.email}</p>
                    </div>
                  </Link>
                </Td>

                <Td>
                  <div className="flex flex-wrap items-center gap-1.5">
                    <Badge tone={ROLE[user.role].tone}>{ROLE[user.role].label}</Badge>
                    {user.coachStatus && user.coachStatus !== "APPROVED" && (
                      <Badge tone={COACH_STATUS[user.coachStatus].tone}>
                        {COACH_STATUS[user.coachStatus].label}
                      </Badge>
                    )}
                  </div>
                </Td>

                <Td>
                  {/*
                    Trois etats distincts, jamais fusionnes : un compte
                    suspendu et un compte qui n'a jamais confirme son
                    email sont tous deux « inactifs », mais l'un est une
                    sanction et l'autre une inscription inachevee.
                  */}
                  {!user.emailVerified ? (
                    <Badge tone="warn">Email non verifie</Badge>
                  ) : user.enabled ? (
                    <Badge tone="ok">Actif</Badge>
                  ) : (
                    <Badge tone="danger">Suspendu</Badge>
                  )}
                </Td>

                <Td className="whitespace-nowrap text-ink-faint">{timeAgo(user.createdAt)}</Td>
                <Td className="whitespace-nowrap text-ink-faint">
                  {user.lastLoginAt ? timeAgo(user.lastLoginAt) : "jamais"}
                </Td>
              </tr>
            ))}
          </tbody>
        </TableWrap>
      )}

      {page.totalPages > 1 && (
        <p className="text-center text-xs text-ink-faint">
          {formatNumber(page.items.length)} affiches sur {formatNumber(page.totalElements)}
        </p>
      )}
    </div>
  );
}
