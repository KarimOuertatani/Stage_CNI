import type { ReactNode } from "react";

import { mediaUrl } from "@/lib/urls";

/**
 * Primitives visuelles de la console.
 *
 * Elles transposent les widgets partages de l'application mobile
 * (`GlassCard`, `SolidCard`, `AppDepth`, `NeonBadge`). Le principe qui a
 * guide la refonte visuelle du mobile s'applique tel quel ici : ameliorer
 * les quelques composants que TOUS les ecrans utilisent plutot que
 * peaufiner chaque page, faute de quoi les pages divergent.
 */

// ═══════════════════════════════════════════════════════════════════
//  Carte
// ═══════════════════════════════════════════════════════════════════

/**
 * `tint` projette la couleur du SUJET de la carte dans son ombre.
 *
 * C'est la trouvaille la plus rentable de la refonte mobile, et elle vaut
 * autant ici : sans elle, un meme gabarit repete quinze fois donne quinze
 * rectangles identiques que l'oeil ne distingue plus.
 */
export function Card({
  children,
  className = "",
  tint,
  padded = true,
}: {
  children: ReactNode;
  className?: string;
  tint?: string;
  padded?: boolean;
}) {
  return (
    <div
      className={`edge-lit depth relative overflow-hidden rounded-2xl border border-line bg-surface ${
        padded ? "p-5" : ""
      } ${className}`}
      style={tint ? { boxShadow: `0 1px 2px rgb(0 0 0 / .35), 0 18px 40px -22px ${tint}` } : undefined}
    >
      {children}
    </div>
  );
}

export function CardTitle({ children, action }: { children: ReactNode; action?: ReactNode }) {
  return (
    <div className="mb-4 flex items-center justify-between gap-3">
      <h2 className="text-sm font-semibold tracking-wide text-ink-muted uppercase">{children}</h2>
      {action}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════
//  Pastille d'etat
// ═══════════════════════════════════════════════════════════════════

export type Tone = "neutral" | "ok" | "warn" | "danger" | "info" | "violet";

const TONE_CLASS: Record<Tone, string> = {
  neutral: "bg-white/5 text-ink-muted ring-white/10",
  ok: "bg-ok/12 text-ok ring-ok/25",
  warn: "bg-warn/12 text-warn ring-warn/25",
  danger: "bg-danger/12 text-danger ring-danger/25",
  info: "bg-cyan/12 text-cyan ring-cyan/25",
  violet: "bg-violet/15 text-violet ring-violet/30",
};

export function Badge({
  children,
  tone = "neutral",
  className = "",
}: {
  children: ReactNode;
  tone?: Tone;
  className?: string;
}) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset ${TONE_CLASS[tone]} ${className}`}
    >
      {children}
    </span>
  );
}

/** Point colore : dit l'etat sans occuper de place dans un tableau dense. */
export function Dot({ tone = "neutral" }: { tone?: Tone }) {
  const color: Record<Tone, string> = {
    neutral: "bg-ink-faint",
    ok: "bg-ok",
    warn: "bg-warn",
    danger: "bg-danger",
    info: "bg-cyan",
    violet: "bg-violet",
  };
  return <span className={`inline-block size-2 shrink-0 rounded-full ${color[tone]}`} />;
}

// ═══════════════════════════════════════════════════════════════════
//  Tuile de statistique
// ═══════════════════════════════════════════════════════════════════

/**
 * Une tuile porte la couleur de son sujet — meme raison que `tint`.
 *
 * `hint` sert a poser le chiffre dans son echelle. « 412 » ne dit rien ;
 * « 412 · +18 ce mois-ci » dit s'il monte. Un nombre sans reference n'est
 * pas une information, c'est une decoration.
 */
export function StatTile({
  label,
  value,
  hint,
  tone = "violet",
  href,
  urgent = false,
}: {
  label: string;
  value: ReactNode;
  hint?: string;
  tone?: Tone;
  href?: string;
  urgent?: boolean;
}) {
  const accent: Record<Tone, string> = {
    neutral: "var(--color-ink-faint)",
    ok: "var(--color-ok)",
    warn: "var(--color-warn)",
    danger: "var(--color-danger)",
    info: "var(--color-cyan)",
    violet: "var(--color-violet)",
  };

  const inner = (
    <div
      className={`edge-lit depth group relative h-full overflow-hidden rounded-2xl border bg-surface p-5 transition-colors ${
        urgent ? "border-warn/35" : "border-line"
      } ${href ? "hover:border-white/20" : ""}`}
      style={{ boxShadow: `0 1px 2px rgb(0 0 0 / .35), 0 18px 40px -24px ${accent[tone]}` }}
    >
      {/* Liseré haut, teinté par le sujet : la lumière frappe le milieu du bord. */}
      <div
        className="absolute inset-x-0 top-0 h-px"
        style={{
          background: `linear-gradient(90deg, transparent, ${accent[tone]}, transparent)`,
          opacity: 0.55,
        }}
      />
      <p className="text-xs font-medium tracking-wide text-ink-faint uppercase">{label}</p>
      <p className="mt-2 text-3xl font-bold tabular-nums" style={{ color: accent[tone] }}>
        {value}
      </p>
      {hint && <p className="mt-1.5 text-xs text-ink-faint">{hint}</p>}
    </div>
  );

  return href ? (
    <a href={href} className="block h-full">
      {inner}
    </a>
  ) : (
    inner
  );
}

// ═══════════════════════════════════════════════════════════════════
//  Etats vides et d'erreur
// ═══════════════════════════════════════════════════════════════════

/**
 * Un vide n'est pas une erreur.
 *
 * « Aucun dossier en attente » est une BONNE nouvelle sur une file de
 * moderation : la formuler comme un manque (« Aucun resultat ») ferait
 * chercher un probleme la ou tout va bien.
 */
export function EmptyState({
  icon = "✓",
  title,
  hint,
}: {
  icon?: string;
  title: string;
  hint?: string;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-6 py-14 text-center">
      <div className="mb-1 text-3xl opacity-60">{icon}</div>
      <p className="font-medium text-ink">{title}</p>
      {hint && <p className="max-w-sm text-sm text-ink-faint">{hint}</p>}
    </div>
  );
}

export function ErrorState({ message }: { message: string }) {
  return (
    <div className="rounded-2xl border border-danger/30 bg-danger/8 px-5 py-4">
      <p className="text-sm font-medium text-danger">Chargement impossible</p>
      <p className="mt-1 text-sm text-ink-muted">{message}</p>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════
//  Tableau
// ═══════════════════════════════════════════════════════════════════

/**
 * Un tableau large defile DANS son conteneur, jamais la page entiere :
 * un defilement horizontal du body emporterait aussi la barre laterale
 * et l'en-tete, qui doivent rester en place.
 */
export function TableWrap({ children }: { children: ReactNode }) {
  return (
    <div className="edge-lit depth overflow-hidden rounded-2xl border border-line bg-surface">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[52rem] border-collapse text-sm">{children}</table>
      </div>
    </div>
  );
}

export function Th({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <th
      className={`border-b border-line px-4 py-3 text-left text-xs font-semibold tracking-wide whitespace-nowrap text-ink-faint uppercase ${className}`}
    >
      {children}
    </th>
  );
}

export function Td({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <td className={`border-b border-line-soft px-4 py-3 align-middle ${className}`}>{children}</td>;
}

// ═══════════════════════════════════════════════════════════════════
//  Avatar
// ═══════════════════════════════════════════════════════════════════

/**
 * Les initiales servent de repli, jamais d'ornement : elles s'affichent
 * quand le compte n'a pas de photo, ce qui est le cas le plus frequent.
 * Un rond vide donnerait des lignes de tableau indistinctes.
 */
export function Avatar({
  name,
  url,
  size = 36,
}: {
  name: string;
  url?: string | null;
  size?: number;
}) {
  const initials = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? "")
    .join("");

  // La resolution est faite ICI, dans le composant partage, et non dans
  // chaque page : `Avatar` est utilise par les coachs, les membres, les
  // signalements et l'en-tete de la console. Corriger a un seul endroit
  // couvre les cinq — et evite qu'un futur appelant oublie la conversion.
  const resolved = mediaUrl(url);

  if (resolved) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={resolved}
        alt=""
        width={size}
        height={size}
        className="shrink-0 rounded-full object-cover ring-1 ring-white/10"
        style={{ width: size, height: size }}
      />
    );
  }

  return (
    <span
      className="grid shrink-0 place-items-center rounded-full font-semibold text-white ring-1 ring-white/10"
      style={{
        width: size,
        height: size,
        fontSize: size * 0.36,
        background: "linear-gradient(135deg, var(--color-violet), var(--color-cyan))",
      }}
      aria-hidden
    >
      {initials || "?"}
    </span>
  );
}

// ═══════════════════════════════════════════════════════════════════
//  Ligne d'information (fiches)
// ═══════════════════════════════════════════════════════════════════

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="min-w-0">
      <dt className="text-xs font-medium tracking-wide text-ink-faint uppercase">{label}</dt>
      <dd className="mt-1 text-sm break-words text-ink">{children ?? "—"}</dd>
    </div>
  );
}

export function SectionTitle({ children, count }: { children: ReactNode; count?: number }) {
  return (
    <h3 className="mb-3 flex items-center gap-2 text-sm font-semibold text-ink">
      {children}
      {count !== undefined && (
        <span className="rounded-full bg-white/6 px-2 py-0.5 text-xs font-medium text-ink-faint tabular-nums">
          {count}
        </span>
      )}
    </h3>
  );
}
