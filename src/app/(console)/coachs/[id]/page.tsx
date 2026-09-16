import Link from "next/link";
import { notFound } from "next/navigation";
import { apiFetchSafe } from "@/lib/api";
import { Avatar, Badge, Card, Field, SectionTitle } from "@/components/ui";
import { DocumentGallery } from "@/components/document-gallery";
import { ReviewPanel } from "@/components/review-panel";
import { COACH_STATUS, formatDateTime, timeAgo } from "@/lib/format";
import type { CoachApplicationDetail } from "@/lib/types";

/**
 * Fiche d'examen d'une candidature.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  La mise en page EST la methode de verification
 * ═══════════════════════════════════════════════════════════════════
 * A gauche, ce que le coach DECLARE : son identite de compte, ses
 * certifications, ses diplomes, son experience — du texte libre qu'il a
 * saisi lui-meme.
 *
 * A droite (ou en dessous sur ecran etroit), ce qu'il PROUVE : les
 * fichiers deposes.
 *
 * Les deux ensembles restent separes, jamais fusionnes, parce que
 * l'examen consiste precisement a chercher les ecarts entre les deux :
 * un titre revendique sans piece correspondante, une piece qui ne
 * correspond a aucun titre, et surtout un nom sur un diplome qui differe
 * de celui du compte — le signal de fraude le plus courant.
 *
 * C'est pourquoi le nom du compte est repete en tete de la colonne des
 * justificatifs : c'est la valeur a laquelle on compare, elle doit etre
 * sous les yeux au moment ou l'on regarde les pieces.
 */
export default async function CoachApplicationDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const app = await apiFetchSafe<CoachApplicationDetail>(`/admin/coach-applications/${id}`);

  if (!app) notFound();

  const meta = COACH_STATUS[app.status];

  return (
    <div className="flex flex-col gap-6">
      {/* ══ Fil d'Ariane ═════════════════════════════════════════ */}
      <Link
        href="/coachs"
        className="text-sm text-ink-faint transition-colors hover:text-ink"
      >
        ← Candidatures
      </Link>

      {/* ══ En-tete ══════════════════════════════════════════════ */}
      <header className="flex flex-wrap items-start gap-5">
        <Avatar name={app.fullName} url={app.avatarUrl} size={64} />

        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-3">
            <h1 className="text-2xl font-bold tracking-tight">{app.fullName}</h1>
            <Badge tone={meta.tone}>{meta.label}</Badge>
          </div>
          <p className="mt-1 text-sm text-ink-muted">{app.headline ?? "Sans accroche"}</p>
          <p className="mt-1 text-xs text-ink-faint">
            {app.email}
            {app.phoneNumber && ` · ${app.phoneNumber}`}
            {app.city && ` · ${app.city}`}
          </p>
        </div>
      </header>

      {/* Bandeau d'etat : dit ce que le statut IMPLIQUE, pas seulement
          son nom. « En attente » ne dit pas ce qui est attendu. */}
      <div
        className={`rounded-2xl border px-4 py-3 text-sm ${
          app.status === "PENDING"
            ? "border-warn/30 bg-warn/8 text-warn"
            : "border-line bg-surface-2 text-ink-muted"
        }`}
      >
        {meta.hint}
        {app.submittedAt && (
          <span className="opacity-80"> · Soumis {timeAgo(app.submittedAt)}</span>
        )}
      </div>

      {/* Motif du dernier refus / de la suspension. */}
      {app.rejectionReason && (
        <div className="rounded-2xl border border-danger/30 bg-danger/8 px-4 py-3">
          <p className="text-xs font-semibold tracking-wide text-danger uppercase">
            Motif communique au coach
          </p>
          <p className="mt-1.5 text-sm whitespace-pre-line text-ink-muted">
            {app.rejectionReason}
          </p>
          {app.reviewedByName && (
            <p className="mt-2 text-xs text-ink-faint">
              Par {app.reviewedByName} · {formatDateTime(app.reviewedAt)}
            </p>
          )}
        </div>
      )}

      <div className="grid gap-5 xl:grid-cols-[1fr_22rem]">
        {/* ══ Colonne gauche : ce qui est DECLARE ═══════════════ */}
        <div className="flex min-w-0 flex-col gap-5">
          <Card>
            <SectionTitle>Compte</SectionTitle>
            <dl className="grid gap-4 sm:grid-cols-3">
              <Field label="Inscrit le">{formatDateTime(app.registeredAt)}</Field>
              <Field label="Email verifie">
                {app.emailVerified ? (
                  <Badge tone="ok">Oui</Badge>
                ) : (
                  <Badge tone="danger">Non</Badge>
                )}
              </Field>
              <Field label="Experience">
                {app.yearsExperience !== null ? `${app.yearsExperience} ans` : "—"}
              </Field>
              <Field label="Tarif horaire">
                {app.hourlyRate !== null ? `${app.hourlyRate} DT` : "—"}
              </Field>
              <Field label="Ville">{app.city ?? "—"}</Field>
              <Field label="Specialites">
                {app.specialties.length > 0 ? (
                  <span className="flex flex-wrap gap-1.5">
                    {app.specialties.map((s) => (
                      <Badge key={s} tone="violet">
                        {s.toLowerCase().replace(/_/g, " ")}
                      </Badge>
                    ))}
                  </span>
                ) : (
                  "—"
                )}
              </Field>
            </dl>
          </Card>

          {app.bio && (
            <Card>
              <SectionTitle>Presentation</SectionTitle>
              <p className="text-sm leading-relaxed whitespace-pre-line text-ink-muted">
                {app.bio}
              </p>
            </Card>
          )}

          <Card>
            <SectionTitle count={app.certifications.length}>
              Certifications declarees
            </SectionTitle>
            {app.certifications.length === 0 ? (
              <p className="text-sm text-ink-faint">Aucune certification declaree.</p>
            ) : (
              <ul className="flex flex-col gap-2.5">
                {app.certifications.map((c) => (
                  <li
                    key={c.id}
                    className="rounded-xl border border-line bg-surface-2 px-3.5 py-3"
                  >
                    <p className="text-sm font-medium">{c.title}</p>
                    <p className="mt-0.5 text-xs text-ink-faint">
                      {[c.organization, c.year].filter(Boolean).join(" · ") || "—"}
                    </p>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <Card>
            <SectionTitle count={app.educations.length}>Diplomes declares</SectionTitle>
            {app.educations.length === 0 ? (
              <p className="text-sm text-ink-faint">Aucun diplome declare.</p>
            ) : (
              <ul className="flex flex-col gap-2.5">
                {app.educations.map((e) => (
                  <li
                    key={e.id}
                    className="rounded-xl border border-line bg-surface-2 px-3.5 py-3"
                  >
                    <p className="text-sm font-medium">{e.degree}</p>
                    <p className="mt-0.5 text-xs text-ink-faint">
                      {[e.institution, e.fieldOfStudy, e.year].filter(Boolean).join(" · ") ||
                        "—"}
                    </p>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          {app.experiences.length > 0 && (
            <Card>
              <SectionTitle count={app.experiences.length}>Experiences</SectionTitle>
              <ul className="flex flex-col gap-2.5">
                {app.experiences.map((x) => (
                  <li
                    key={x.id}
                    className="rounded-xl border border-line bg-surface-2 px-3.5 py-3"
                  >
                    <p className="text-sm font-medium">{x.title}</p>
                    <p className="mt-0.5 text-xs text-ink-faint">
                      {[x.organization, [x.startYear, x.endYear].filter(Boolean).join(" – ")]
                        .filter(Boolean)
                        .join(" · ") || "—"}
                    </p>
                    {x.description && (
                      <p className="mt-1.5 text-sm text-ink-muted">{x.description}</p>
                    )}
                  </li>
                ))}
              </ul>
            </Card>
          )}
        </div>

        {/* ══ Colonne droite : PREUVES + decision ═══════════════ */}
        <div className="flex min-w-0 flex-col gap-5 xl:sticky xl:top-20 xl:self-start">
          <Card>
            <SectionTitle count={app.documents.length}>Justificatifs</SectionTitle>

            {/* Le nom du compte, repete ICI : c'est la valeur a laquelle
                on compare ce que portent les documents. */}
            <div className="mb-4 rounded-xl border border-violet/25 bg-violet/8 px-3.5 py-2.5">
              <p className="text-[0.68rem] font-semibold tracking-wide text-violet uppercase">
                Le nom a verifier
              </p>
              <p className="mt-0.5 text-sm font-medium">{app.fullName}</p>
              <p className="mt-1 text-xs text-ink-faint">
                Il doit correspondre a celui porte par la piece d&apos;identite et les
                diplomes.
              </p>
            </div>

            <DocumentGallery documents={app.documents} />
          </Card>

          <Card>
            <SectionTitle>Decision</SectionTitle>
            <ReviewPanel
              profileId={app.profileId}
              status={app.status}
              coachName={app.fullName.split(" ")[0] ?? app.fullName}
            />
          </Card>
        </div>
      </div>
    </div>
  );
}
