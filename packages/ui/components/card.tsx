export function Card({
  className = "",
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={`rounded-lg border border-line-subtle bg-card ${className}`}
      {...props}
    >
      {children}
    </div>
  );
}
