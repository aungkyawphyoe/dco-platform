export type PlateField = {
  label: string;
  value: React.ReactNode;
  mono?: boolean;
};

/// A hairline label/value band — the "data plate" for identity and specs.
export function DataPlate({
  fields,
  className = "border-y border-line-subtle py-4",
}: {
  fields: PlateField[];
  className?: string;
}) {
  return (
    <dl className={`flex flex-wrap gap-x-10 gap-y-4 ${className}`}>
      {fields.map((field) => (
        <div key={field.label} className="min-w-28">
          <dt className="text-xs text-ink-caption">{field.label}</dt>
          <dd className={`mt-1 text-sm text-ink ${field.mono ? "font-mono" : ""}`}>
            {field.value}
          </dd>
        </div>
      ))}
    </dl>
  );
}
