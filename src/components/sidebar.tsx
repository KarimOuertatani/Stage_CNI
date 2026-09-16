"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

/**
 * Barre de navigation laterale.
 *
 * ═══════════════════════════════════════════════════════════════════
 *  L'ordre suit la frequence d'usage, pas la logique du modele
 * ═══════════════════════════════════════════════════════════════════
 * Les candidatures coach sont en tete parce que ce sont elles qui
 * demandent une action quotidienne. Ranger les entrees par ordre
 * « logique » (comptes, puis coachs, puis signalements…) mettrait en
 * premier l'ecran qu'on ouvre le moins souvent.
 *
 * Les pastilles de comptage ne sont posees que sur ce qui ATTEND une
 * action. En mettre une sur « Membres » afficherait le nombre total de
 * comptes, qui ne descend jamais a zero et n'appelle aucun geste : une
 * pastille permanente cesse d'etre remarquee, et emporte avec elle
 * l'attention qu'on devrait aux vraies.
 */

export interface NavCounts {
  pendingCoaches: number;
  openReports: number;
}

const SECTIONS: {
  title: string;
  items: { href: string; label: string; icon: string; badge?: keyof NavCounts }[];
}[] = [
  {
    title: "Pilotage",
    items: [{ href: "/", label: "Tableau de bord", icon: "◫" }],
  },
  {
    title: "Moderation",
    items: [
      { href: "/coachs", label: "Candidatures coach", icon: "🎓", badge: "pendingCoaches" },
      { href: "/signalements", label: "Signalements", icon: "🚩", badge: "openReports" },
    ],
  },
  {
    title: "Communaute",
    items: [{ href: "/membres", label: "Membres", icon: "👥" }],
  },
  {
    title: "Systeme",
    items: [
      { href: "/ia", label: "Sante de l'IA", icon: "🧠" },
      { href: "/notifications", label: "Notifications", icon: "🔔" },
    ],
  },
];

export function Sidebar({ counts }: { counts: NavCounts }) {
  const pathname = usePathname();

  return (
    <nav className="flex flex-col gap-6 p-4">
      {SECTIONS.map((section) => (
        <div key={section.title}>
          <p className="mb-2 px-3 text-[0.68rem] font-semibold tracking-[0.16em] text-ink-faint uppercase">
            {section.title}
          </p>

          <ul className="flex flex-col gap-0.5">
            {section.items.map((item) => {
              // Comparaison exacte pour la racine, prefixe sinon : sans
              // ce cas particulier, « / » serait actif sur toutes les pages.
              const active =
                item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
              const count = item.badge ? counts[item.badge] : 0;

              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    aria-current={active ? "page" : undefined}
                    className={`group relative flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition-colors ${
                      active
                        ? "bg-white/6 font-semibold text-ink"
                        : "text-ink-muted hover:bg-white/4 hover:text-ink"
                    }`}
                  >
                    {/* Repere actif : une barre verticale plutot qu'une
                        couleur de fond seule, lisible meme en vision
                        reduite des couleurs. */}
                    <span
                      className={`absolute inset-y-1.5 left-0 w-0.5 rounded-full transition-opacity ${
                        active ? "opacity-100" : "opacity-0"
                      }`}
                      style={{
                        background:
                          "linear-gradient(180deg, var(--color-violet), var(--color-cyan))",
                      }}
                    />
                    <span className="w-5 text-center text-base leading-none">{item.icon}</span>
                    <span className="flex-1 truncate">{item.label}</span>

                    {count > 0 && (
                      <span className="rounded-full bg-warn/15 px-2 py-0.5 text-xs font-semibold text-warn tabular-nums ring-1 ring-warn/25 ring-inset">
                        {count}
                      </span>
                    )}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </nav>
  );
}
