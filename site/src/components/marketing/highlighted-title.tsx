export function HighlightedTitle({ title, highlight }: { title: string; highlight: string }) {
  const start = title.indexOf(highlight);
  if (start < 0 || !highlight) return title;
  return <>{title.slice(0, start)}<span className="title-highlight">{highlight}</span>{title.slice(start + highlight.length)}</>;
}
