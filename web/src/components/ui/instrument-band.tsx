/// The recessed panel that carries a fleet's live numbers and condition.
export function InstrumentBand({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section className={`rounded-lg border border-line-subtle bg-panel ${className}`}>
      {children}
    </section>
  );
}
