-- Backfill full vehicle grants for vehicles already shared with a family.
-- Clients previously never created grants (the access model required them
-- but no flow wrote them), so member reads/writes and sync propagation were
-- dead for pre-existing shares. One grant per shared vehicle x non-owner
-- family member, idempotent.
INSERT INTO vehicle_grants (id, vehicle_id, user_id, granted_by, permission)
SELECT
  gen_random_uuid(),
  fv.vehicle_id,
  fm.user_id,
  fv.added_by,
  'full'
FROM family_vehicles fv
JOIN families f ON f.id = fv.family_id
JOIN family_memberships fm ON fm.family_id = fv.family_id
JOIN vehicles v ON v.id = fv.vehicle_id
WHERE fm.user_id <> v.user_id
ON CONFLICT (vehicle_id, user_id) DO NOTHING;
