import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "PocketBizz | Uruskan Operasi & Jualan SME dengan Mudah",
  description:
    "PocketBizz memudahkan SME & F&B urus stok, jualan, konsignment, claim vendor, dan laporan dalam satu tempat. Mula free trial 7 hari.",
  openGraph: {
    title: "PocketBizz | Uruskan Operasi & Jualan SME dengan Mudah",
    description:
      "PocketBizz memudahkan SME & F&B urus stok, jualan, konsignment, claim vendor, dan laporan dalam satu tempat.",
    url: "https://pocketbizz.my",
    siteName: "PocketBizz",
    locale: "ms_MY",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ms">
      <body>{children}</body>
    </html>
  );
}

