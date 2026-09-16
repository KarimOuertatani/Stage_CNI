import Link from "next/link";
import { notFound } from "next/navigation";
import { apiFetchSafe } from "@/lib/api";
import { mediaUrl } from "@/lib/urls";
import { Avatar, Badge, Card, Field, SectionTitle } from "@/components/ui";
import { ReportHandler } from "@/components/report-handler";
import { PROBLEM_CATEGORY, PROBLEM_STATUS, ROLE, formatDateTime, timeAgo } from "@/lib/format";
import type { ProblemReport } from "@/lib/types";

/**
 * Fiche d'un signalement.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  Le contexte technique est affiche AVANT la reponse
 * ═══════════════════════════════════════════════════════════════════
 * Plateforme et version d'application sont renseignees par le client, pas
 * saisies par l'utilisateur. C'est souvent ce qui permet de reproduire un
 * bug — ou de repondre « corrige depuis la version 1.1 » sans rien
 * chercher. Les enfouir en bas de page reviendrait a ne pas les avoir
 * collectees.
 */
export default async function ReportDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const report = await apiFetchSafe<ProblemReport>(`/admin/problem-reports/${id}`);

  if (!report) notFound();

  const category = PROBLEM_CATEGORY[report.category];
  const state = PROBLEM_STATUS[report.status];

  return (
    <div className="flex flex-col gap-6">
      <Link
        href="/signalements"
        className="text-sm text-ink-faint transition-colors hover:text-ink"
      >
        ← Signalements
      </Link>

      <header>
        <div className="flex flex-wrap items-center gap-2.5">
          <Badge tone={state.tone}>{state.label}</Badge>
          <span className="text-sm text-ink-muted">
            {category.icon} {category.label}
          </span>
          <span className="text-sm text-ink-faint">· recu {timeAgo(report.createdAt)}</span>
        </div>
        <h1 className="mt-2 text-2xl font-bold tracking-tight">{report.subject}</h1>
      </header>

      <div className="grid gap-5 xl:grid-cols-[1fr_22rem]">
        <div className="flex min-w-0 flex-col gap-5">
          <Card>
            <SectionTitle>Description</SectionTitle>
            <p className="text-sm leading-relaxed whitespace-pre-line text-ink-muted">
              {report.description}
            </p>

            {report.attachmentUrl && (
              <div className="mt-4">
                <p className="mb-2 text-xs font-medium tracking-wide text-ink-faint uppercase">
                  Capture jointe
                </p>
                <a
                  href={mediaUrl(report.attachmentUrl) ?? "#"}
                  target="_blank"
                  rel="noreferrer"
                  className="block overflow-hidden rounded-xl border border-line transition-colors hover:border-violet/40"
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={mediaUrl(report.attachmentUrl) ?? ""}
                    alt="Capture jointe au signalement"
                    className="max-h-96 w-full object-contain bg-ground"
                  />
                </a>
              </div>
            )}
          </Card>

          <Card>
            <SectionTitle>Contexte</SectionTitle>
            <dl className="grid gap-4 sm:grid-cols-3">
              <Field label="Plateforme">{report.platform ?? "non transmise"}</Field>
              <Field label="Version de l'app">{report.appVersion ?? "non transmise"}</Field>
              <Field label="Recu le">{formatDateTime(report.createdAt)}</Field>
            </dl>
          </Card>

          {/* Historique du traitement, quand il y en a un. */}
          {report.adminResponse && (
            <Card>
              <SectionTitle>Reponse deja envoyee</SectionTitle>
              <p className="text-sm leading-relaxed whitespace-pre-line text-ink-muted">
                {report.adminResponse}
              </p>
              {report.handledByName && (
                <p className="mt-3 text-xs text-ink-faint">
                  Par {report.handledByName} · {formatDateTime(report.handledAt)}
                </p>
              )}
            </Card>
          )}
        </div>

        <div className="flex min-w-0 flex-col gap-5 xl:sticky xl:top-20 xl:self-start">
          <Card>
            <SectionTitle>Auteur</SectionTitle>
            <Link
              href={`/membres/${report.reporterId}`}
              className="group flex items-center gap-3"
            >
              <Avatar name={report.reporterName} url={report.reporterAvatarUrl} size={44} />
              <div className="min-w-0">
                <p className="truncate font-medium transition-colors group-hover:text-cyan">
                  {report.reporterName}
                </p>
                <p className="truncate text-xs text-ink-faint">{report.reporterEmail}</p>
                <p className="mt-1">
                  <Badge tone={ROLE[report.reporterRole].tone}>
                    {ROLE[report.reporterRole].label}
                  </Badge>
                </p>
              </div>
            </Link>
            <p className="mt-3 text-xs text-ink-faint">
              Role au moment du signalement. Il indique depuis quel espace de
              l&apos;application le probleme a ete rencontre.
            </p>
          </Card>

          <Card>
            <SectionTitle>Traitement</SectionTitle>
            <ReportHandler
              reportId={report.id}
              currentStatus={report.status}
              currentResponse={report.adminResponse}
              reporterName={report.reporterName.split(" ")[0] ?? report.reporterName}
            />
          </Card>
        </div>
      </div>
    </div>
  );
}
