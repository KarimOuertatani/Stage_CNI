import { redirect } from "next/navigation";
import { currentAccount, logout } from "@/lib/auth";
import { apiFetchSafe } from "@/lib/api";
import { Sidebar } from "@/components/sidebar";
import { NotificationBell } from "@/components/notification-bell";
import { Avatar } from "@/components/ui";
import type { CoachStatus, ProblemStatus } from "@/lib/types";

/**
 * Coquille de la console : barre laterale, en-tete, contenu.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  C'est ICI que la session est verifiee, et une seule fois
 * ═══════════════════════════════════════════════════════════════════
 * Toutes les pages de la console vivent dans ce groupe de routes, donc
 * toutes passent par cette mise en page. Repeter le controle dans chaque
 * page donnerait autant d'endroits ou l'oublier — et un oubli laisserait
 * une page accessible sans qu'aucun test ne s'en apercoive, puisque
 * l'API, elle, repondrait 401.
 *
 * Le controle est volontairement fait ici plutot que dans un middleware :
 * un middleware ne peut que constater la PRESENCE du cookie, pas la
 * validite du jeton ni le role du compte. Il laisserait entrer un cookie
 * expire, et chaque page afficherait une erreur au lieu de renvoyer se
 * reconnecter.
 */

/** Comptes affiches en pastille dans la barre laterale. */
async function navCounts() {
  const [coaches, reports] = await Promise.all([
    apiFetchSafe<Record<CoachStatus, number>>("/admin/coach-applications/counts"),
    apiFetchSafe<Record<ProblemStatus, number>>("/admin/problem-reports/counts"),
  ]);

  return {
    pendingCoaches: coaches?.PENDING ?? 0,
    // Un signalement « en cours » attend encore une reponse : le compter
    // avec les nouveaux evite qu'un dossier pris en charge puis oublie
    // disparaisse silencieusement de la pastille.
    openReports: (reports?.NEW ?? 0) + (reports?.IN_PROGRESS ?? 0),
  };
}

export default async function ConsoleLayout({ children }: { children: React.ReactNode }) {
  const account = await currentAccount();
  if (!account) {
    redirect("/connexion");
  }

  const [counts, unread] = await Promise.all([
    navCounts(),
    apiFetchSafe<{ count: number }>("/admin/notifications/unread-count"),
  ]);

  return (
    <div className="flex min-h-screen">
      {/* ══ Barre laterale ═══════════════════════════════════════
          `hidden lg:flex` : sous 1024 px, elle disparait au profit du
          contenu. Une console d'administration se consulte sur grand
          ecran ; consacrer 16 rem a la navigation sur un portable de
          13 pouces amputerait les tableaux, qui sont l'essentiel. */}
      <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col border-r border-line bg-surface/60 backdrop-blur-xl lg:flex">
        <div className="flex items-center gap-3 border-b border-line px-5 py-5">
          <div
            className="grid size-9 shrink-0 place-items-center rounded-xl text-sm font-black text-white"
            style={{
              background: "linear-gradient(135deg, var(--color-violet), var(--color-cyan))",
            }}
          >
            FF
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm font-bold tracking-tight">
              FIT<span className="font-light">FORGE</span>
            </p>
            <p className="truncate text-[0.65rem] tracking-[0.14em] text-ink-faint uppercase">
              Administration
            </p>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto">
          <Sidebar counts={counts} />
        </div>

        {/* Identite + deconnexion, en pied de barre laterale. */}
        <form
          action={logout}
          className="flex items-center gap-3 border-t border-line px-4 py-4"
        >
          <Avatar name={account.fullName} url={account.avatarUrl} size={34} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium">{account.fullName}</p>
            <p className="truncate text-xs text-ink-faint">{account.email}</p>
          </div>
          <button
            type="submit"
            title="Se deconnecter"
            aria-label="Se deconnecter"
            className="grid size-8 shrink-0 place-items-center rounded-lg border border-line text-ink-faint transition-colors hover:border-danger/40 hover:text-danger"
          >
            ⏻
          </button>
        </form>
      </aside>

      {/* ══ Contenu ══════════════════════════════════════════════ */}
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-20 flex items-center gap-3 border-b border-line bg-ground/80 px-5 py-3.5 backdrop-blur-xl lg:px-8">
          <p className="flex-1 truncate text-sm text-ink-faint lg:hidden">
            FitForge — Administration
          </p>
          <div className="hidden flex-1 lg:block" />
          <NotificationBell initialCount={unread?.count ?? 0} />
        </header>

        <main className="min-w-0 flex-1 px-5 py-6 lg:px-8 lg:py-8">{children}</main>
      </div>
    </div>
  );
}
