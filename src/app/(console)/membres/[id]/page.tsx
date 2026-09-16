import Link from "next/link";
import { notFound } from "next/navigation";
import { apiFetchSafe } from "@/lib/api";
import { Avatar, Badge, Card, Field, SectionTitle, StatTile } from "@/components/ui";
import { AccountActions } from "@/components/account-actions";
import { COACH_STATUS, ROLE, formatDate, formatDateTime, formatNumber, timeAgo } from "@/lib/format";
import type { UserDetail } from "@/lib/types";

/**
 * Fiche d'un membre.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Des COMPTEURS d'activite, jamais de contenu
 * ═══════════════════════════════════════════════════════════════════
 * Cette page dit combien de seances, de repas et de nuits une personne a
 * enregistres. Elle ne dit pas lesquels, et n'ouvre aucune conversation.
 *
 * L'administration a besoin de savoir SI un compte est actif et A QUEL
 * POINT — pour trancher un litige, comprendre un signalement, ou verifier
 * qu'un compte n'est pas un faux. Elle n'a pas besoin de lire ce que les
 * gens mangent ni ce qu'ils ecrivent a leur coach.
 *
 * C'est la meme ligne que celle tenue ailleurs dans le projet : le coach
 * IA recoit l'objectif et les blessures mais jamais le nom ni les notes
 * medicales libres ; le journal des appels IA enregistre la latence mais
 * jamais la question. On transmet ce qui sert, pas ce qui est disponible.
 */
export default async function MemberDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const user = await apiFetchSafe<UserDetail>(`/admin/users/${id}`);

  if (!user) notFound();

  return (
    <div className="flex flex-col gap-6">
      <Link href="/membres" className="text-sm text-ink-faint transition-colors hover:text-ink">
        ← Membres
      </Link>

      {/* ══ En-tete ══════════════════════════════════════════════ */}
      <header className="flex flex-wrap items-start gap-5">
        <Avatar name={user.fullName} url={user.avatarUrl} size={64} />

        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2.5">
            <h1 className="text-2xl font-bold tracking-tight">{user.fullName}</h1>
            <Badge tone={ROLE[user.role].tone}>{ROLE[user.role].label}</Badge>
            {!user.emailVerified ? (
              <Badge tone="warn">Email non verifie</Badge>
            ) : user.enabled ? (
              <Badge tone="ok">Actif</Badge>
            ) : (
              <Badge tone="danger">Suspendu</Badge>
            )}
          </div>

          <p className="mt-1 text-sm text-ink-muted">
            {user.email}
            {user.phoneNumber && ` · ${user.phoneNumber}`}
          </p>
          <p className="mt-1 text-xs text-ink-faint">
            Inscrit {timeAgo(user.createdAt)} · Derniere connexion{" "}
            {user.lastLoginAt ? timeAgo(user.lastLoginAt) : "jamais"}
          </p>
        </div>

        {/* Renvoi vers le dossier de candidature, quand il y en a un :
            depuis une fiche de coach, la question suivante est presque
            toujours « qu'a-t-il fourni ? ». */}
        {user.coachProfileId && (
          <Link
            href={`/coachs/${user.coachProfileId}`}
            className="rounded-xl border border-line px-3.5 py-2 text-sm text-ink-muted transition-colors hover:border-violet/40 hover:text-ink"
          >
            Voir son dossier coach →
          </Link>
        )}
      </header>

      <div className="grid gap-5 xl:grid-cols-[1fr_20rem]">
        <div className="flex min-w-0 flex-col gap-5">
          {/* ══ Activite ═══════════════════════════════════════ */}
          <section>
            <h2 className="mb-3 text-xs font-semibold tracking-[0.16em] text-ink-faint uppercase">
              Activite
            </h2>
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              <StatTile
                label="Seances"
                value={formatNumber(user.workoutLogCount)}
                hint={
                  user.lastWorkoutDate
                    ? `derniere le ${formatDate(user.lastWorkoutDate)}`
                    : "aucune"
                }
                tone="violet"
              />
              <StatTile
                label="Repas notes"
                value={formatNumber(user.nutritionEntryCount)}
                tone="info"
              />
              <StatTile
                label="Nuits saisies"
                value={formatNumber(user.sleepEntryCount)}
                tone="ok"
              />
              <StatTile
                label="Programmes"
                value={formatNumber(user.programCount)}
                tone="neutral"
              />
            </div>
          </section>

          {/* ══ Profil sportif ═════════════════════════════════ */}
          {user.role === "ADHERENT" && (
            <Card>
              <SectionTitle>Profil sportif</SectionTitle>

              {!user.onboardingCompleted && (
                <p className="mb-4 rounded-xl border border-warn/25 bg-warn/8 px-3.5 py-2.5 text-sm text-warn">
                  Onboarding non termine : ce compte n&apos;a pas renseigne sa taille et
                  son poids, donc ni IMC ni objectif calorique ne sont calcules.
                </p>
              )}

              <dl className="grid gap-4 sm:grid-cols-3">
                <Field label="Sexe">{user.gender ?? "—"}</Field>
                <Field label="Age">{user.age !== null ? `${user.age} ans` : "—"}</Field>
                <Field label="Naissance">{formatDate(user.birthDate)}</Field>
                <Field label="Taille">
                  {user.heightCm !== null ? `${user.heightCm} cm` : "—"}
                </Field>
                <Field label="Poids">
                  {user.currentWeightKg !== null ? `${user.currentWeightKg} kg` : "—"}
                </Field>
                <Field label="Objectif">
                  {user.goal ? user.goal.toLowerCase().replace(/_/g, " ") : "—"}
                </Field>
              </dl>
            </Card>
          )}

          {/* ══ Compte ═════════════════════════════════════════ */}
          <Card>
            <SectionTitle>Compte</SectionTitle>
            <dl className="grid gap-4 sm:grid-cols-3">
              <Field label="Inscrit le">{formatDateTime(user.createdAt)}</Field>
              <Field label="Derniere connexion">{formatDateTime(user.lastLoginAt)}</Field>
              <Field label="Vu en ligne">{formatDateTime(user.lastSeenAt)}</Field>
              {user.coachStatus && (
                <Field label="Statut coach">
                  <Badge tone={COACH_STATUS[user.coachStatus].tone}>
                    {COACH_STATUS[user.coachStatus].label}
                  </Badge>
                </Field>
              )}
            </dl>
            <p className="mt-4 text-xs text-ink-faint">
              « Vu en ligne » vient de la presence temps reel (WebSocket) et ne bouge que
              sur les ecrans de conversation : un adherent qui logue ses seances sans
              jamais ouvrir un chat garde une valeur ancienne. C&apos;est « derniere
              connexion » qui dit l&apos;activite reelle.
            </p>
          </Card>
        </div>

        {/* ══ Actions ══════════════════════════════════════════ */}
        <div className="xl:sticky xl:top-20 xl:self-start">
          <Card>
            <SectionTitle>Actions</SectionTitle>
            <AccountActions
              userId={user.id}
              enabled={user.enabled}
              emailVerified={user.emailVerified}
              isAdmin={user.role === "ADMIN"}
              name={user.fullName.split(" ")[0] ?? user.fullName}
            />
          </Card>
        </div>
      </div>
    </div>
  );
}
