"use client";
import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiGet, apiPatch } from '@/lib/api/client';
import { Card } from '@dco/ui/components/card';
import { Input } from '@dco/ui/components/input';
import { Button } from '@dco/ui/components/button';
import { PageHeader } from '@dco/ui/components/page-header';
export type Price = {
    id: string;
    name: string;
    priceVersion: number;
    priceMonthlyMmk: number;
    priceAnnualMmk: number;
    priceMonthlyUsd: string;
    priceAnnualUsd: string;
    vehicleLimit: number | null;
    sharingLimit: number | null;
    storageBytes: number;
};
function PriceEditor({ price }: {
    price: Price;
}) {
    const qc = useQueryClient();
    const [values, setValues] = useState([String(price.priceMonthlyMmk), String(price.priceAnnualMmk), price.priceMonthlyUsd, price.priceAnnualUsd]);
    const mutation = useMutation({ mutationFn: () => apiPatch(`/admin/prices/${price.id}`, { version: price.priceVersion, monthly_mmk: Number(values[0]), annual_mmk: Number(values[1]), monthly_usd: Number(values[2]), annual_usd: Number(values[3]) }), onSuccess: () => qc.invalidateQueries({ queryKey: ['prices'] }) });
    return <Card className="p-6 space-y-4"><h2 className="font-display text-xl">{price.name}</h2><p className="text-sm text-ink-caption">{price.vehicleLimit ?? 'Unlimited'} vehicles · {price.sharingLimit ?? 'Unlimited'} shares · {Math.round(price.storageBytes / 1048576)} MB. Benefits are read-only.</p><form className="space-y-4" onSubmit={e => { e.preventDefault(); if (window.confirm(`Publish ${price.name} prices immediately?\nMonthly: ${values[0]} MMK / $${values[2]}\nAnnual: ${values[1]} MMK / $${values[3]}\nExisting purchases and store prices remain unchanged.`))
        mutation.mutate(); }}><div className="grid gap-4 md:grid-cols-4">{['Monthly MMK', 'Annual MMK', 'Monthly USD', 'Annual USD'].map((label, i) => <Input key={label} label={label} type="number" min={0} max={1000000000} step={i < 2 ? 1 : 0.01} required disabled={price.id === 'free'} value={values[i]} onChange={e => setValues(values.map((v, j) => i === j ? e.target.value : v))}/>)}</div>{mutation.error && <p role="alert">{mutation.error.message}</p>}<Button type="submit" disabled={mutation.isPending || price.id === 'free'}>{mutation.isPending ? 'Publishing…' : 'Publish prices'}</Button>{mutation.isSuccess && <p role="status">Prices published.</p>}</form></Card>;
}
export default function PricingPage() { const history = useQuery({ queryKey: ['prices', 'history'], queryFn: () => apiGet<{
        items: {
            id: number;
            at: string;
            adminUserId: string;
            detail: unknown;
        }[];
    }>('/admin/price-history') }); const query = useQuery({ queryKey: ['prices'], queryFn: () => apiGet<{
        items: Price[];
    }>('/admin/prices') }); return <div className="space-y-6"><PageHeader title="Plans & Pricing" description="Catalog prices for direct sales and public plan comparison. Google Play and Apple checkout prices are managed separately."/>{query.isLoading && <p>Loading prices…</p>}{query.error && <p role="alert">{query.error.message}</p>}{query.data?.items.map(p => <PriceEditor key={`${p.id}-${p.priceVersion}`} price={p}/>)}<Card className="p-6 space-y-3"><h2 className="font-display text-xl">Price history</h2>{history.data?.items.map(h => <details key={h.id}><summary>{h.at} · admin {h.adminUserId}</summary><pre className="whitespace-pre-wrap text-sm">{JSON.stringify(h.detail, null, 2)}</pre></details>)}</Card></div>; }
