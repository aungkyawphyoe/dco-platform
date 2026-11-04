"use client";

import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";
import { apiGet, apiPut } from "@/lib/api/client";
import { useVehicles } from "@/lib/api/hooks";
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
  const [history, setHistory] = useState(false);
  const editable = state.enabled && role === "org_admin";
  return <Card className="mb-6 p-5">
    <h2 className="font-display font-semibold">Fleet currency</h2>
    <p className="my-3 text-sm">{state.currency ? `Current currency: ${state.currency}.` : "Choose a currency before recording costs."} All fleet drivers use this currency. Amounts are never converted automatically.</p>
    {editable ? <div className="flex flex-col items-start gap-3">
      <Select label="Currency" value={choice} onChange={v => setChoice(v as Currency)} options={state.supported.map(code => ({ value: code, label: code + " · " + new Intl.NumberFormat(undefined, {style: "currency", currency: code}).format(100) }))} />
      <p className="text-sm">You can change this preference at any time.</p>
      <label><input type="checkbox" checked={history} onChange={e => setHistory(e.target.checked)} /> Also relabel past fleet logs without changing amounts</label>
      <Button disabled={save.isPending || (!history && choice === state.currency)} onClick={() => save.mutate({ currency: choice, expected_currency: state.currency, relabel_history: history })}>
        {save.isPending ? "Saving…" : `Confirm ${choice}`}
      </Button>
    </div> : <p>{state.enabled ? "Ask your Fleet Admin to select or correct the fleet currency." : "Currency selection is not available yet. New costs use MMK."}</p>}
    {editable && <VehiclePolicy org={id} currencies={state.supported} />}
    {save.isError && <p role="alert" className="mt-3 text-danger">{save.error.message}</p>}
  </Card>;
}

type Policy = {base_currency: string | null; allow_member_currency: boolean};
function VehiclePolicy({org,currencies}:{org:string | null; currencies: string[]}) {
  const vehicles=useVehicles(org);
  const [id,setId]=useState("");
  const url=`/organizations/${org}/vehicles/${id}/currency`;
  const cache=useQueryClient();
  const key=["vehicle-currency",org,id];
  const policy=useQuery({queryKey:key,enabled:Boolean(id),queryFn:()=>apiGet<Policy>(url)});
  const save=useMutation({mutationFn:(body:Policy)=>apiPut<Policy>(url,body),
    onSuccess:(value)=>cache.setQueryData(key,value)});
  return <div className="mt-4 grid gap-3">
    <Select label="Vehicle currency policy" value={id} onChange={setId} options={[
      {value:"",label:"Choose a fleet vehicle"},...(vehicles.data?.items ?? []).map(v=>({value:v.id,label:v.name}))]} />
    {policy.data && <>
      <Select label="Vehicle base currency" value={policy.data.base_currency ?? ""} onChange={value=>save.mutate({...policy.data!,base_currency:value || null})}
        options={[{value:"",label:"Use fleet currency"},...currencies.map(code=>({value:code,label:code}))]} />
      <label><input type="checkbox" disabled={save.isPending} checked={policy.data.allow_member_currency}
        onChange={e=>save.mutate({...policy.data!,allow_member_currency:e.target.checked})} /> Allow each member to choose a display currency</label>
    </>}
    {(policy.isError || save.isError) && <p role="alert">Could not load or save vehicle currency.</p>}
  </div>;
}
