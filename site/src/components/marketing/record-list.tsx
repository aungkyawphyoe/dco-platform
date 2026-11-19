type RecordItem = { title: string; description: string; chips?: readonly string[] };

export function RecordList({ items }: { items: readonly RecordItem[] }) {
  return <dl className="record-list">{items.map(item => (
    <div key={item.title}>
      <dt>{item.title}</dt>
      <dd>{item.description}</dd>
      {item.chips && <dd className="record-chips">{item.chips.join(" / ")}</dd>}
    </div>
  ))}</dl>;
}
