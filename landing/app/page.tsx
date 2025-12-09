import { CTAButton } from "../components/CTAButton";
import { Section } from "../components/Section";
import { FeatureCard } from "../components/FeatureCard";
import { PricingCard } from "../components/PricingCard";
import { FAQ } from "../components/FAQ";
import { TestimonialPlaceholder } from "../components/TestimonialPlaceholder";
import { ScreenshotPlaceholder } from "../components/ScreenshotPlaceholder";

export default function Page() {
  const faqItems = [
    {
      q: "Berapa harga PocketBizz?",
      a: "Pro RM39/bulan. Early Adopter RM29/bulan untuk 100 pengguna pertama. Ada pakej 1/3/6/12 bulan dengan diskaun 8% (6 bln) dan 15% (12 bln).",
    },
    {
      q: "Ada free trial?",
      a: "Ya, 7 hari akses penuh semua fungsi. Tiada kad kredit diperlukan untuk bermula.",
    },
    {
      q: "Boleh batalkan bila-bila masa?",
      a: "Boleh. Tiada kontrak panjang. Langganan tamat mengikut tempoh yang dibayar.",
    },
    {
      q: "Sokongan macam mana?",
      a: "Sokongan chat/email. Boleh juga minta sesi onboarding ringkas.",
    },
  ];

  const features = [
    {
      title: "Inventori & Stok",
      description:
        "Kawal stok, variasi, kos, dan alert low-stock supaya tak oversell.",
    },
    {
      title: "Konsainan & Vendor",
      description:
        "Jejak konsainan, komisen, dan status bayaran vendor dengan telus.",
    },
    {
      title: "Claims & Belian",
      description:
        "Urus claim pembekal, bil, dan pembayaran dengan rekod yang kemas.",
    },
    {
      title: "Laporan & Insight",
      description:
        "Laporan untung-rugi ringkas, jualan produk teratas, dan prestasi vendor.",
    },
    {
      title: "Multi-channel",
      description:
        "Sedia untuk web. Boleh kembangkan ke mobile (iOS/Android) jika diperlukan.",
    },
    {
      title: "Kawalan Akses",
      description: "Role-based access untuk staf; data lebih selamat.",
    },
  ];

  const painPoints = [
    "Operasi manual: stok, pesanan, rekod claim berselerak (Excel/WhatsApp).",
    "Human error dan lambat rekonsiliasi — tak pasti untung-rugi sebenar.",
    "Susah pantau konsainan/vendor; payout lewat dan menimbulkan konflik.",
    "Tiada amaran stok rendah atau tarikh luput — risiko kehilangan jualan.",
  ];

  const flowSteps = [
    "Tambah produk & kos, tetapkan variasi.",
    "Log jualan & terimaan, track konsainan/claim.",
    "Lihat dashboard & laporan ringkas, buat keputusan cepat.",
  ];

  return (
    <main className="min-h-screen bg-gradient-to-b from-slate-50 to-white">
      <div className="bg-grid relative overflow-hidden">
        <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-white via-white/60 to-white" />
        <div className="mx-auto flex max-w-6xl flex-col gap-12 px-4 pb-20 pt-16 md:flex-row md:items-center md:pt-20">
          <div className="md:w-3/5">
            <div className="inline-flex rounded-full bg-primary-50 px-3 py-1 text-xs font-semibold text-primary-700">
              Operasi lebih laju, rekod lebih jelas
            </div>
            <h1 className="mt-4 text-4xl font-bold text-slate-900 md:text-5xl">
              Urus stok, konsainan, claim, dan laporan dalam satu tempat.
            </h1>
            <p className="mt-4 text-lg text-slate-700">
              PocketBizz membantu SME & F&B kecil/ sederhana kawal inventori,
              jualan, konsainan, dan pembayaran vendor dengan pantas — tanpa
              tumpang Excel yang serabut.
            </p>
            <div className="mt-6 flex flex-wrap items-center gap-3">
              <CTAButton href="https://app.pocketbizz.my">Mula Free Trial 7 Hari</CTAButton>
              <CTAButton href="#features" variant="ghost">
                Lihat Fungsi
              </CTAButton>
            </div>
            <p className="mt-3 text-sm text-slate-500">
              Trial penuh, tiada kad kredit diperlukan. Early Adopter: RM29/bulan
              untuk 100 pengguna pertama.
            </p>
          </div>
          <div className="md:w-2/5">
            <ScreenshotPlaceholder />
          </div>
        </div>
      </div>

      <Section
        id="pain"
        title="Masalah biasa yang kami selesaikan"
        subtitle="Kurangkan kerja manual, elak silap kira, dan percepat keputusan."
        background="muted"
      >
        <div className="grid gap-4 md:grid-cols-2">
          {painPoints.map((p) => (
            <div
              key={p}
              className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
            >
              <p className="text-sm text-slate-700">{p}</p>
            </div>
          ))}
        </div>
      </Section>

      <Section
        id="features"
        title="Semua yang perlu untuk operasi SME & F&B"
        subtitle="Daripada stok hingga laporan, semuanya terhubung."
      >
        <div className="grid gap-4 md:grid-cols-3">
          {features.map((f) => (
            <FeatureCard key={f.title} title={f.title} description={f.description} />
          ))}
        </div>
      </Section>

      <Section
        id="flow"
        title="Aliran kerja ringkas"
        subtitle="3 langkah untuk kawal operasi harian tanpa serabut."
        background="muted"
      >
        <div className="grid gap-4 md:grid-cols-3">
          {flowSteps.map((step, idx) => (
            <div
              key={step}
              className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
            >
              <div className="mb-2 inline-flex h-8 w-8 items-center justify-center rounded-full bg-primary-50 text-sm font-semibold text-primary-700">
                {idx + 1}
              </div>
              <p className="text-sm text-slate-700">{step}</p>
            </div>
          ))}
        </div>
      </Section>

      <Section
        id="pricing"
        title="Harga telus, tiada caj tersembunyi"
        subtitle="Pilih tempoh langganan; jimat lebih untuk komitmen lebih panjang."
      >
        <div className="grid gap-4 md:grid-cols-3">
          <PricingCard
            title="Early Adopter"
            subtitle="100 pengguna pertama"
            price="RM29/bulan"
            description="Akses penuh. Kekal harga ini seumur hidup selagi aktif."
            highlight
            badge="Terhad"
            perks={[
              "Semua fungsi Pro",
              "Support chat/email",
              "Harga kekal selagi langganan aktif",
            ]}
            ctaLabel="Tebus Early Adopter"
            ctaHref="https://app.pocketbizz.my"
          />
          <PricingCard
            title="Pro Bulanan"
            price="RM39/bulan"
            description="Fleksibel tanpa kontrak panjang."
            perks={["Semua fungsi Pro", "Support chat/email"]}
            ctaLabel="Mula Free Trial"
            ctaHref="https://app.pocketbizz.my"
          />
          <PricingCard
            title="Pakej 12 Bulan"
            price="RM397.80 /tahun"
            subtitle="Jimatan 15%"
            description="Bayar sekali, jimat lebih."
            badge="Paling Popular"
            perks={[
              "Penjimatan 15%",
              "Semua fungsi Pro",
              "Support chat/email",
            ]}
            ctaLabel="Langgan 12 Bulan"
            ctaHref="https://app.pocketbizz.my"
          />
        </div>
        <p className="mt-4 text-center text-xs text-slate-500">
          Nota: 6 bulan jimat 8%, 12 bulan jimat 15%. Harga Early Adopter RM29/bulan
          hanya untuk 100 pengguna pertama.
        </p>
      </Section>

      <Section
        id="testimoni"
        title="Apa kata pelanggan?"
        subtitle="Gantikan dengan testimoni sebenar bila sedia."
        background="muted"
      >
        <TestimonialPlaceholder />
      </Section>

      <Section
        id="faq"
        title="Soalan Lazim"
        subtitle="Jika ada soalan lain, hubungi kami."
      >
        <FAQ items={faqItems} />
      </Section>

      <Section background="muted">
        <div className="rounded-3xl bg-gradient-to-r from-primary-600 to-primary-700 px-6 py-10 text-center text-white shadow-card md:px-12 md:py-14">
          <h2 className="text-3xl font-bold md:text-4xl">
            Sedia untuk operasi yang lebih teratur?
          </h2>
          <p className="mt-3 text-base text-white/80">
            Mulakan free trial 7 hari dan lihat sendiri perbezaannya.
          </p>
          <div className="mt-6 flex flex-wrap items-center justify-center gap-3">
            <a
              href="https://app.pocketbizz.my"
              className="rounded-full bg-white px-5 py-3 text-sm font-semibold text-primary-700 shadow hover:bg-slate-100"
            >
              Mula Free Trial 7 Hari
            </a>
            <a
              href="#features"
              className="rounded-full border border-white/40 px-5 py-3 text-sm font-semibold text-white hover:bg-white/10"
            >
              Lihat Fungsi
            </a>
          </div>
        </div>
      </Section>
    </main>
  );
}

