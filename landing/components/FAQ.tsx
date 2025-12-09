interface QA {
  q: string;
  a: string;
}

export function FAQ({ items }: { items: QA[] }) {
  return (
    <div className="grid gap-4 md:grid-cols-2">
      {items.map((item) => (
        <div
          key={item.q}
          className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
        >
          <h3 className="text-base font-semibold text-slate-900">{item.q}</h3>
          <p className="mt-2 text-sm text-slate-600">{item.a}</p>
        </div>
      ))}
    </div>
  );
}

