"use client";

import { useState } from "react";
import { Card } from "@dco/ui/components/card";
import { Select } from "@dco/ui/components/select";
import { Button } from "@dco/ui/components/button";
import { useOrgId, useOrgRole } from "@/lib/auth/session-context";
import { useFleetCurrency, useSaveFleetCurrency, type Currency, type CurrencyState } from "@/lib/api/currency";

export function CurrencySettings({ setupOnly = false }: { setupOnly?: boolean }) {
  const id = useOrgId();
  const query = useFleetCurrency(id);
  if (query.isError) return <Card className="mb-6 p-5"><p role="alert">Unable to load fleet currency.</p><Button onClick={() => void query.refetch()}>Retry</Button></Card>;
  if (!query.data) return setupOnly ? null : <p>Loading currency…</p>;
  if (setupOnly && (!query.data.enabled || query.data.currency)) return null;
  return <CurrencyForm key={`${id}:${query.data.currency}`} state={query.data} />;
}
function CurrencyForm({ state }: { state: CurrencyState }) {
  const id = useOrgId();
  const role = useOrgRole();
  const save = useSaveFleetCurrency(id);
  const [choice, setChoice] = useState<Currency>(state.currency ?? "MMK");
  const editable = state.enabled && !state.locked && !state.review_required && role === "org_admin";
  return <Card className="mb-6 p-5">
    <h2 className="font-display font-semibold">Fleet currency</h2>
    <p className="my-3 text-sm">{state.currency ? `Current currency: ${state.currency}.` : "Choose a currency before recording costs."} All fleet drivers use this currency. Amounts are never converted automatically.</p>
    {state.review_required ? <p>Legacy monetary history requires review. Contact support.</p> : state.locked ? <p>Currency is locked because monetary records have been saved, even if those records are later deleted.</p> : editable ? <div className="flex flex-col items-start gap-3">
      <Select label="Currency" value={choice} onChange={v => setChoice(v as Currency)} options={[
        { value: "MMK", label: "Myanmar Kyat (MMK)" }, { value: "USD", label: "US Dollar (USD)" },
        { value: "THB", label: "Thai Baht (THB)" }, { value: "CNY", label: "Chinese Yuan (CNY)" },
      ]} />
      <p className="text-sm">You can correct this choice until the first monetary record is saved.</p>
      <Button disabled={save.isPending || choice === state.currency} onClick={() => save.mutate({ currency: choice, expected_currency: state.currency })}>
        {save.isPending ? "Saving…" : `Confirm ${choice}`}
      </Button>
    </div> : <p>{state.enabled ? "Ask your Fleet Admin to select or correct the fleet currency." : "Currency selection is not available yet. New costs use MMK."}</p>}
    {save.isError && <p role="alert" className="mt-3 text-danger">{save.error.message}</p>}
  </Card>;
}
