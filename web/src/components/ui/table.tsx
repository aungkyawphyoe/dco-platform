import type { HTMLAttributes, TdHTMLAttributes } from "react";

export interface TableCellProps extends TdHTMLAttributes<HTMLTableCellElement> {
  colSpan?: number;
}

export function Table({
  className = "",
  ...props
}: HTMLAttributes<HTMLTableElement>) {
  return (
    <div className="overflow-x-auto">
      <table
        className={`w-full text-left text-sm ${className}`}
        {...props}
      />
    </div>
  );
}

export function TableHead({
  className = "",
  ...props
}: HTMLAttributes<HTMLTableSectionElement>) {
  return (
    <thead
      className={`border-b border-line-subtle ${className}`}
      {...props}
    />
  );
}

export function TableBody({
  className = "",
  ...props
}: HTMLAttributes<HTMLTableSectionElement>) {
  return <tbody className={className} {...props} />;
}

export function TableRow({
  className = "",
  ...props
}: HTMLAttributes<HTMLTableRowElement>) {
  return (
    <tr
      className={`border-b border-line-subtle transition-colors hover:bg-skeleton/50 ${className}`}
      {...props}
    />
  );
}

export function TableHeadCell({
  className = "",
  ...props
}: HTMLAttributes<HTMLTableCellElement>) {
  return (
    <th
      className={`px-4 py-3 text-xs font-medium uppercase tracking-wider text-ink-caption ${className}`}
      {...props}
    />
  );
}

export function TableCell({
  className = "",
  colSpan,
  ...props
}: TableCellProps) {
  return (
    <td
      className={`px-4 py-3 text-ink ${className}`}
      colSpan={colSpan}
      {...props}
    />
  );
}
