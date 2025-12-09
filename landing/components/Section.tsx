import { ReactNode } from "react";
import clsx from "clsx";

interface SectionProps {
  id?: string;
  title?: string;
  eyebrow?: string;
  subtitle?: string;
  children: ReactNode;
  background?: "default" | "muted";
  className?: string;
}

export function Section({
  id,
  title,
  eyebrow,
  subtitle,
  children,
  background = "default",
  className,
}: SectionProps) {
  return (
    <section
      id={id}
      className={clsx(
        background === "muted" ? "bg-white" : "bg-transparent",
        "w-full"
      )}
    >
      <div className={clsx("mx-auto max-w-6xl px-4 py-16 md:py-20", className)}>
        {(eyebrow || title || subtitle) && (
          <div className="mb-10 space-y-3 text-center">
            {eyebrow && (
              <div className="inline-flex rounded-full bg-primary-50 px-3 py-1 text-xs font-semibold text-primary-700">
                {eyebrow}
              </div>
            )}
            {title && (
              <h2 className="text-3xl font-bold text-slate-900 md:text-4xl">
                {title}
              </h2>
            )}
            {subtitle && (
              <p className="text-base text-slate-600 md:text-lg">{subtitle}</p>
            )}
          </div>
        )}
        {children}
      </div>
    </section>
  );
}

