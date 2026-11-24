DO $$
BEGIN
  CREATE TYPE fleet_incident_category AS ENUM ('accident', 'breakdown', 'damage', 'other');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS fleet_incidents (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  reported_by uuid NOT NULL REFERENCES users(id),
  driver_at_event_id uuid REFERENCES users(id),
  event_at timestamptz NOT NULL DEFAULT now(),
  category fleet_incident_category NOT NULL,
  description text NOT NULL CHECK (length(btrim(description)) > 0),
  closed_by uuid REFERENCES users(id),
  closed_at timestamptz,
  review_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fleet_incidents_closure CHECK (
    (closed_at IS NULL AND closed_by IS NULL AND review_note IS NULL)
    OR (closed_at IS NOT NULL AND closed_by IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS fleet_incidents_link_scope ON fleet_incidents (org_id, vehicle_id, id);
CREATE UNIQUE INDEX IF NOT EXISTS work_orders_incident_link_scope ON work_orders (org_id, vehicle_id, id);

CREATE TABLE IF NOT EXISTS fleet_incident_work_orders (
  incident_id uuid NOT NULL,
  work_order_id uuid NOT NULL,
  org_id uuid NOT NULL,
  vehicle_id uuid NOT NULL,
  CONSTRAINT fleet_incident_work_orders_pk PRIMARY KEY (incident_id, work_order_id),
  CONSTRAINT fleet_incident_work_orders_incident_fk FOREIGN KEY (org_id, vehicle_id, incident_id)
    REFERENCES fleet_incidents (org_id, vehicle_id, id),
  CONSTRAINT fleet_incident_work_orders_work_order_fk FOREIGN KEY (org_id, vehicle_id, work_order_id)
    REFERENCES work_orders (org_id, vehicle_id, id)
);

CREATE INDEX IF NOT EXISTS fleet_incident_work_orders_repair_idx ON fleet_incident_work_orders (work_order_id);

CREATE TABLE IF NOT EXISTS fleet_incident_photos (
  incident_id uuid NOT NULL REFERENCES fleet_incidents(id),
  media_id uuid NOT NULL REFERENCES media_objects(id),
  CONSTRAINT fleet_incident_photos_pk PRIMARY KEY (incident_id, media_id),
  CONSTRAINT fleet_incident_photos_media_unique UNIQUE (media_id)
);

CREATE INDEX IF NOT EXISTS fleet_incidents_org_event_idx ON fleet_incidents (org_id, event_at DESC, id);
