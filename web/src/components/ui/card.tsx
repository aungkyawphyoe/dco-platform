export function Card({
  className = "",
  children,
}: {
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <div className={`rounded-lg border border-line-subtle bg-card ${className}`}>
      {children}
    </div>
  );
}
