-- Read-only preflight. Run after migrations on a restored database before rollout.
-- Each returned source has a possible pre-existing expense and was deliberately
-- not backfilled. Reconcile by confirming the correct expense and setting its
-- source_kind/source_id, or by confirming it is independent before generating a
-- linked expense. Do not match or change authors automatically.
WITH sources AS (
  SELECT 'service_record' AS kind, id, vehicle_id, serviced_on AS incurred_on, total_cost AS amount FROM service_records
  UNION ALL
  SELECT 'fuel_log', id, vehicle_id, logged_on, cost FROM fuel_logs
)
SELECT v.org_id, s.vehicle_id, s.kind, s.id AS source_id, e.id AS candidate_expense_id,
       s.incurred_on, s.amount
FROM sources s JOIN organization_vehicles v ON v.vehicle_id = s.vehicle_id
JOIN expenses e ON e.vehicle_id = s.vehicle_id AND e.incurred_on = s.incurred_on
  AND e.amount = s.amount AND e.source_id IS NULL
  AND e.category::text = CASE WHEN s.kind = 'service_record' THEN 'maintenance' ELSE 'fuel' END
WHERE NOT EXISTS (SELECT 1 FROM expenses linked WHERE linked.source_kind = s.kind AND linked.source_id = s.id)
ORDER BY v.org_id, s.vehicle_id, s.incurred_on;
