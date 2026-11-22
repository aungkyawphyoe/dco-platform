DO $$
BEGIN
  CREATE TYPE fleet_agreement_kind AS ENUM ('insurance_policy', 'maintenance_agreement');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS fleet_agreements (
  id uuid PRIMARY KEY,
  org_id uuid NOT NULL REFERENCES organizations(id),
  kind fleet_agreement_kind NOT NULL,
  responsible_member_id uuid REFERENCES organization_members(id) ON DELETE SET NULL,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS fleet_agreements_org_idx ON fleet_agreements(org_id);

CREATE TABLE IF NOT EXISTS fleet_agreement_terms (
  id uuid PRIMARY KEY,
  agreement_id uuid NOT NULL REFERENCES fleet_agreements(id),
  term_number integer NOT NULL,
  provider text NOT NULL,
  starts_on date NOT NULL,
  ends_on date NOT NULL,
  reminder_lead_days integer NOT NULL,
  document_id uuid REFERENCES documents(id) ON DELETE SET NULL,
  CONSTRAINT fleet_agreement_term_number_unique UNIQUE (agreement_id, term_number),
  CONSTRAINT fleet_agreement_term_number_positive CHECK (term_number > 0),
  CONSTRAINT fleet_agreement_term_dates CHECK (ends_on >= starts_on),
  CONSTRAINT fleet_agreement_term_lead_positive CHECK (reminder_lead_days > 0)
);

CREATE TABLE IF NOT EXISTS fleet_agreement_term_vehicles (
  term_id uuid NOT NULL REFERENCES fleet_agreement_terms(id),
  vehicle_id uuid NOT NULL REFERENCES vehicles(id),
  CONSTRAINT fleet_agreement_term_vehicles_pk PRIMARY KEY (term_id, vehicle_id)
);
