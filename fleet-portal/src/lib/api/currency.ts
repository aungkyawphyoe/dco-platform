"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiGet, apiPut } from "./client";
import type { components } from "./schema";

export type Currency = components["schemas"]["OperationalCurrency"];
export type CurrencyState = components["schemas"]["CurrencyState"];
export const currencyKey = (id: string | null) => ["fleet", "currency", id];
export function useFleetCurrency(id: string | null) {
  return useQuery({ queryKey: currencyKey(id), enabled: Boolean(id),
    queryFn: () => apiGet<CurrencyState>(`/organizations/${id}/currency`) });
}
export function useSaveFleetCurrency(id: string | null) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: { currency: Currency; expected_currency: Currency | null }) =>
      apiPut<CurrencyState>(`/organizations/${id}/currency`, body),
    onSuccess: (state) => { qc.setQueryData(currencyKey(id), state); void qc.invalidateQueries({ queryKey: ["analytics-settings", id] }); void qc.invalidateQueries({ queryKey: ["analytics", id] }); },
    onError: () => { void qc.invalidateQueries({ queryKey: currencyKey(id) }); },
  });
}
