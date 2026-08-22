import type { ButtonHTMLAttributes } from "react";

type Variant = "primary" | "secondary" | "destructive" | "ghost";
type Size = "sm" | "md";

const variantClasses: Record<Variant, string> = {
  primary:
    "bg-btn-primary text-on-gold font-semibold hover:bg-btn-primary-hover active:bg-btn-primary-pressed disabled:bg-btn-primary-disabled disabled:text-ink-muted",
  secondary:
    "bg-card text-ink border border-line-strong hover:bg-skeleton active:bg-field disabled:opacity-50",
  destructive:
    "bg-transparent border border-danger text-danger hover:bg-[#3A2424] disabled:opacity-50",
  ghost: "bg-transparent text-gold hover:bg-panel disabled:opacity-50",
};

const sizeClasses: Record<Size, string> = {
  sm: "h-8 px-3 text-sm rounded-sm",
  md: "h-11 px-5 rounded-md",
};

export function Button({
  variant = "primary",
  size = "md",
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant;
  size?: Size;
}) {
  return (
    <button
      className={`inline-flex items-center justify-center gap-2 font-display transition-colors duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus disabled:cursor-not-allowed ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
      {...props}
    />
  );
}
