import Link from "next/link";
import { revalidatePath } from "next/cache";
import { apiFetch, apiFetchSafe } from "@/lib/api";
import { Card, EmptyState, ErrorState } from "@/components/ui";
import { timeAgo } from "@/lib/format";
import type { AdminNotification, AdminNotificationType, PageResponse } from "@/lib/types";

export const metadata = { title: "Notifications — FitForge Admin" };

/**
 * Journal des evenements portes a la connaissance de l'administration.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Ce que cette page apporte par rapport aux files de traitement
 * ═══════════════════════════════════════════════════════════════════
 * Les candidatures et les signalements ont deja leur file, calculee sur
 * l'etat present. Cette page-ci raconte ce qui est ARRIVE, dans l'ordre,
 * y compris ce qui n'appelle aucune action (une inscription d'adherent).
 *
 * C'est aussi le seul endroit ou l'on peut marquer quelque chose comme lu
 * — un compteur recalcule ne le permettrait pas.
 */

/**
 * Le type decide de la destination du clic.
 *
 * Deduire la cible en analysant le libelle serait fragile : une simple
 * reformulation casserait les liens. Le type est une donnee, le texte est
 * de la presentation.
 */
function hrefFor(notification: AdminNotification): string | null {
  if (!notification.targetId) return null;

  switch (notification.type) {
    case "COACH_APPLICATION_SUBMITTED":
      return `/coachs/${notification.targetId}`;
    case "MEMBER_REGISTERED":
      return `/membres/${notification.targetId}`;
    case "PROBLEM_REPORTED":
      return `/signalements/${notification.targetId}`;
    default:
      return null;
  }
}

const ICONS: Record<AdminNotificationType, string> = {
  COACH_APPLICATION_SUBMITTED: "🎓",
  MEMBER_REGISTERED: "👤",
  PROBLEM_REPORTED: "🚩",
};

async function markAllRead() {
  "use server";
  await apiFetch("/admin/notifications/read-all", { method: "POST" });
  revalidatePath("/notifications");
  // La cloche vit dans la mise en page de la console : sans cette ligne,
  // elle garderait son ancien compteur jusqu'a la prochaine navigation.
  revalidatePath("/", "layout");
}

export default async function NotificationsPage() {
  const [page, unread] = await Promise.all([
    apiFetchSafe<PageResponse<AdminNotification>>("/admin/notifications?size=60"),
    apiFetchSafe<{ count: number }>("/admin/notifications/unread-count"),
  ]);

  if (!page) {
    return <ErrorState message="Impossible de charger les notifications." />;
  }

  const unreadCount = unread?.count ?? 0;

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Notifications</h1>
          <p className="mt-1 text-sm text-ink-faint">
            {unreadCount === 0
              ? "Tout est lu."
              : `${unreadCount} non lue${unreadCount > 1 ? "s" : ""}.`}
          </p>
        </div>

        {unreadCount > 0 && (
          <form action={markAllRead}>
            <button
              type="submit"
              className="rounded-xl border border-line px-3.5 py-2 text-sm text-ink-muted transition-colors hover:border-white/25 hover:text-ink"
            >
              Tout marquer comme lu
            </button>
          </form>
        )}
      </header>

      {page.items.length === 0 ? (
        <Card padded={false}>
          <EmptyState
            icon="🔔"
            title="Aucune notification"
            hint="Les inscriptions d'adherents, les dossiers de coach soumis et les signalements apparaitront ici."
          />
        </Card>
      ) : (
        <ul className="flex flex-col gap-2">
          {page.items.map((notification) => {
            const href = hrefFor(notification);
            const unreadItem = notification.readAt === null;

            const content = (
              <div
                className={`edge-lit flex items-start gap-3.5 rounded-2xl border px-4 py-3.5 transition-colors ${
                  unreadItem
                    ? "border-violet/25 bg-violet/6"
                    : "border-line bg-surface"
                } ${href ? "hover:border-white/20" : ""}`}
              >
                <span className="mt-0.5 text-lg leading-none">
                  {ICONS[notification.type] ?? "•"}
                </span>

                <div className="min-w-0 flex-1">
                  <p className="flex items-center gap-2 font-medium">
                    {notification.title}
                    {unreadItem && (
                      <span className="inline-block size-1.5 shrink-0 rounded-full bg-violet" />
                    )}
                  </p>
                  {notification.body && (
                    <p className="mt-0.5 text-sm text-ink-muted">{notification.body}</p>
                  )}
                </div>

                <span className="shrink-0 text-xs whitespace-nowrap text-ink-faint">
                  {timeAgo(notification.createdAt)}
                </span>
              </div>
            );

            return (
              <li key={notification.id}>
                {href ? (
                  <Link href={href} className="block">
                    {content}
                  </Link>
                ) : (
                  content
                )}
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
