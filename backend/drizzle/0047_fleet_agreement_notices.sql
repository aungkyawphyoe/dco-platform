CREATE TABLE IF NOT EXISTS fleet_agreement_notices (
  term_id uuid NOT NULL REFERENCES fleet_agreement_terms(id),
  ends_on date NOT NULL,
  attempted_at timestamptz NOT NULL,
  sent_at timestamptz,
  CONSTRAINT fleet_agreement_notices_pk PRIMARY KEY (term_id, ends_on)
);
