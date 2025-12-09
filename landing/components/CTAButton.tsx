import Link from "next/link";
import clsx from "clsx";

interface CTAButtonProps {
  href: string;
  children: React.ReactNode;
  variant?: "primary" | "ghost";
}

export function CTAButton({
  href,
  children,
  variant = "primary",
}: CTAButtonProps) {
  return (
    <Link
      href={href}
      className={clsx(
        "inline-flex items-center justify-center rounded-full px-5 py-3 text-sm font-semibold transition",
        variant === "primary"
          ? "bg-primary-600 text-white shadow-card hover:bg-primary-700"
          : "text-primary-700 hover:text-primary-900"
      )}
    >
      {children}
    </Link>
  );
}

