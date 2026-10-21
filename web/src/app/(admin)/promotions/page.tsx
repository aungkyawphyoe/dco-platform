"use client";

import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiGet, apiPatch, apiPost } from "@/lib/api/client";
import { PageHeader } from "@dco/ui/components/page-header";
import { Card } from "@dco/ui/components/card";
import { Button } from "@dco/ui/components/button";
import { Input } from "@dco/ui/components/input";
import { Select } from "@dco/ui/components/select";
import type { components } from "@/lib/api/schema";

type Promotion = components["schemas"]["Promotion"];
type Redemption = components["schemas"]["GiftGrant"] & { email: string | null; user_id: string };

export default function PromotionsPage() {
  const qc = useQueryClient();
  const [name, setName] = useState("");
  const [kind, setKind] = useState("shared");
  const [plan, setPlan] = useState("standard");
  const [days, setDays] = useState("90");
  const [deadline, setDeadline] = useState("");
  const [capacity, setCapacity] = useState("100");
  const [code, setCode] = useState("");
  const [codes, setCodes] = useState<string[]>([]);
  const [selected, setSelected] = useState<Promotion | null>(null);
  const [offset, setOffset] = useState(0);
  const [historyOffset, setHistoryOffset] = useState(0);
  const list = useQuery({ queryKey: ["admin", "promotions", offset], queryFn: () => apiGet<{ items: Promotion[]; next_offset: number | null }>(`/admin/promotions?offset=${offset}`) });
  const history = useQuery({ queryKey: ["admin", "promotions", selected?.id, historyOffset], enabled: !!selected,
    queryFn: () => apiGet<{ items: Redemption[]; next_offset: number | null }>(`/admin/promotions/${selected!.id}/redemptions?offset=${historyOffset}`) });
  const create = useMutation({ mutationFn: () => apiPost<{ promotion: Promotion; codes: string[] }>("/admin/promotions", {
    name, kind, plan, duration_days: Number(days), redeem_by: new Date(deadline).toISOString(), capacity: Number(capacity),
    ...(kind === "shared" && code.trim() ? { code: code.trim() } : {}),
  }), onSuccess: data => { setCodes(data.codes); setName(""); setCode(""); qc.invalidateQueries({ queryKey: ["admin", "promotions"] }); } });
  const disable = useMutation({ mutationFn: (id: string) => apiPatch(`/admin/promotions/${id}`, { enabled: false }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["admin", "promotions"] }) });
  function downloadCodes() {
    const url = URL.createObjectURL(new Blob([codes.join("\n")], { type: "text/plain" }));
    const a = document.createElement("a"); a.href = url; a.download = "autox-gift-codes.txt"; a.click(); URL.revokeObjectURL(url);
  }
  return <div className="space-y-6">
    <PageHeader title="Promotions" description="Give owners time on Lite or Standard. No payment or automatic renewal." />
    <Card className="p-6">
      <h2 className="font-display text-xl mb-4">Create a promotion</h2>
      <form onSubmit={e => { e.preventDefault(); create.mutate(); }} className="space-y-4">
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          <Input label="Promotion name" value={name} onChange={e => setName(e.target.value)} required maxLength={100} />
          <Select label="Code type" value={kind} onChange={setKind} options={[{ value: "shared", label: "Shared campaign code" }, { value: "single_use", label: "Single-use code batch" }]} />
          <Select label="Gift plan" value={plan} onChange={setPlan} options={[{ value: "lite", label: "Lite" }, { value: "standard", label: "Standard" }]} />
          <Input label="Access duration (days)" type="number" min={1} max={3650} value={days} onChange={e => setDays(e.target.value)} required />
          <Input label="Redeem before (your local time)" type="datetime-local" value={deadline} onChange={e => setDeadline(e.target.value)} required hint="Every successful redemption receives the full duration." />
          <Input label={kind === "shared" ? "Maximum redemptions" : "Number of codes"} type="number" min={1} max={kind === "shared" ? 1000000 : 1000} value={capacity} onChange={e => setCapacity(e.target.value)} required />
          {kind === "shared" && <Input label="Campaign code (optional)" value={code} onChange={e => setCode(e.target.value)} minLength={6} maxLength={64} pattern="[A-Za-z0-9-]+" hint="Letters, numbers and hyphens. Leave blank to generate." />}
        </div>
        <p className="text-sm text-ink-caption">Verified Free accounts only. One redemption per account per promotion. One active gift at a time.</p>
        {create.error && <p role="alert" className="text-danger">{create.error.message}</p>}
        <Button disabled={create.isPending || codes.length > 0} type="submit">{create.isPending ? "Creating…" : "Create promotion"}</Button>
      </form>
    </Card>
    {codes.length > 0 && <Card className="p-6 space-y-3">
      <h2 className="font-display text-xl">Save your codes</h2>
      <p className="text-ink-caption">Codes are shown only once. Download them before leaving this page.</p>
      <textarea aria-label="Generated gift codes" readOnly className="w-full h-32 bg-field border border-line-strong rounded-md p-3 font-mono" value={codes.join("\n")} />
      <div className="flex flex-wrap gap-3"><Button onClick={downloadCodes}>Download codes</Button><Button variant="secondary" onClick={() => { if (window.confirm("Have you saved the codes? They cannot be shown again.")) setCodes([]); }}>I have saved these codes</Button></div>
    </Card>}
    <Card className="p-6 space-y-4">
      <h2 className="font-display text-xl">Promotions</h2>
      {list.isLoading && <p>Loading promotions…</p>}
      {list.error && <div role="alert"><p>{list.error.message}</p><Button onClick={() => list.refetch()}>Retry</Button></div>}
      {disable.error && <p role="alert" className="text-danger">{disable.error.message}</p>}
      {list.data?.items.length === 0 && <p className="text-ink-caption">No promotions yet. Create your first giveaway above.</p>}
      <div className="overflow-x-auto"><table className="w-full text-left text-sm">
        <thead><tr className="text-ink-caption border-b border-line-subtle">{["Promotion", "Gift", "Redemptions", "Redeem before", "Status", "Actions"].map(h => <th key={h} className="p-3">{h}</th>)}</tr></thead>
        <tbody>{list.data?.items.map(p => <tr key={p.id} className="border-b border-line-subtle">
          <td className="p-3"><div className="font-medium">{p.name}</div><div className="text-ink-caption">{p.kind === "shared" ? "Shared code" : "Single-use batch"}</div></td>
          <td className="p-3 capitalize">{p.plan} · {p.duration_days} days</td><td className="p-3 font-mono">{p.redeemed} / {p.capacity}</td>
          <td className="p-3">{new Date(p.redeem_by).toLocaleString()}</td>
          <td className="p-3">{!p.enabled ? "Disabled" : new Date(p.redeem_by) <= new Date() ? "Expired" : p.redeemed >= p.capacity ? "Fully redeemed" : "Active"}</td>
          <td className="p-3"><div className="flex gap-2"><Button variant="secondary" onClick={() => { setSelected(p); setHistoryOffset(0); }}>History</Button>
            {p.enabled && <Button variant="ghost" disabled={disable.isPending} onClick={() => { if (window.confirm(`Disable future redemptions for ${p.name}? Existing gifts remain valid.`)) disable.mutate(p.id); }}>Disable</Button>}</div></td>
        </tr>)}</tbody>
      </table></div>
      <div className="flex gap-3"><Button variant="secondary" disabled={offset === 0} onClick={() => setOffset(Math.max(0, offset - 50))}>Previous</Button><Button variant="secondary" disabled={list.data?.next_offset == null} onClick={() => setOffset(list.data!.next_offset!)}>Next</Button></div>
    </Card>
    {selected && <Card className="p-6 space-y-4"><h2 className="font-display text-xl">{selected.name} — redemption history</h2>
      {history.isLoading && <p>Loading history…</p>}
      {history.error && <div role="alert"><p>{history.error.message}</p><Button onClick={() => history.refetch()}>Retry</Button></div>}
      {history.data?.items.length === 0 && <p>No redemptions yet.</p>}
      <ul className="divide-y divide-line-subtle">{history.data?.items.map(g => <li key={g.id} className="py-3"><p>{g.email ?? g.user_id}</p><p className="text-sm text-ink-caption">{new Date(g.starts_at).toLocaleString()} → {new Date(g.ends_at).toLocaleString()}</p></li>)}</ul>
      <div className="flex gap-3"><Button variant="secondary" disabled={!historyOffset} onClick={() => setHistoryOffset(Math.max(0, historyOffset - 50))}>Previous</Button><Button variant="secondary" disabled={history.data?.next_offset == null} onClick={() => setHistoryOffset(history.data!.next_offset!)}>Next</Button></div>
    </Card>}
  </div>;
}
