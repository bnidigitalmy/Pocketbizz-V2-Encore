import clsx from "clsx";

interface PricingCardProps {
  title: string;
  price: string;
  subtitle?: string;
  highlight?: boolean;
  description?: string;
  perks: string[];
  ctaLabel: string;
  ctaHref: string;
  badge?: string;
}

export function PricingCard({
  title,
  price,
  subtitle,
  highlight,
  description,
  perks,
  ctaLabel,
  ctaHref,
  badge,
}: PricingCardProps) {
  return (
    <div
      className={clsx(
        "flex h-full flex-col rounded-2xl border bg-white p-6 shadow-sm transition hover:-translate-y-1 hover:shadow-card",
        highlight ? "border-primary-200 ring-2 ring-primary-100" : "border-slate-200"
      )}
    >
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-semibold text-primary-700">{title}</p>
          {subtitle && <p className="text-xs text-slate-500">{subtitle}</p>}
        </div>
        {badge && (
          <div className="rounded-full bg-accent-500 px-3 py-1 text-xs font-bold text-white shadow">
            {badge}
          </div>
        )}
      </div>
      <div className="mt-4">
        <div className="text-3xl font-bold text-slate-900">{price}</div>
        {description && <p className="mt-2 text-sm text-slate-600">{description}</p>}
      </div>
      <ul className="mt-4 space-y-2 text-sm text-slate-700">
        {perks.map((perk) => (
          <li key={perk} className="flex items-start gap-2">
            <span className="mt-1 h-2 w-2 rounded-full bg-primary-500" />
            <span>{perk}</span>
          </li>
        ))}
      </ul>
      <div className="mt-auto pt-6">
        <a
          href={ctaHref}
          className={clsx(
            "flex w-full items-center justify-center rounded-full px-4 py-3 text-sm font-semibold transition",
            highlight
              ? "bg-primary-600 text-white hover:bg-primary-700"
              : "border border-slate-200 text-primary-700 hover:border-primary-200 hover:bg-primary-50"
          )}
        >
          {ctaLabel}
        </a>
      </div>
    </div>
  );
}

