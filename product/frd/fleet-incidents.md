# Fleet incident cases

Date: 22 November 2026

Status: PR-3 implemented locally. The organization records policy and a representative customer workflow remain unvalidated.

## Purpose

Record a vehicle event as an independently reviewable case that may have no repair or may link to multiple repair work orders. An incident is not itself a repair, expense, or insurance claim.

## Users and authorization

- Drivers and Fleet Portal managers can submit an incident.
- `org_admin` and `org_manager` can view incidents across their organization, edit submitted incidents, close them, and reopen closed incidents.
- All active drivers assigned to the incident vehicle can view its details and photos.
- A mechanic assigned to any linked work order can view the incident and its photos.
- Drivers cannot edit an incident after submission.
- The API enforces organization membership, vehicle scope, and role authorization. Client visibility does not grant access.

## Report fields

Required fields are vehicle, event time, category, and description. Event time defaults to the current time and can be edited for late reports. Photos are optional. The initial report does not require location or involved people.

Incident categories are `accident`, `breakdown`, `damage`, and `other`. These are separate from repair work-order categories.

When the reporter is a manager or several drivers are assigned, suggest drivers whose assignment history overlaps the event time. A manager may correct the attribution. Later assignment changes must not rewrite the stored event attribution.

## Lifecycle and repairs

An incident has an independent lifecycle. It can be reported, reviewed, and closed while it has zero, one, or multiple linked work orders. Closing an incident does not complete, cancel, or otherwise alter its work orders, and does not require repair completion or cost.

Both `org_admin` and `org_manager` may close after review. Store reviewer identity and closure time; a review note is optional. A closed incident can be reopened only through an explicit action by either role. Reopening records an audit event. Editing a closed incident requires reopening first.

A work order may be linked only when it belongs to the same organization and vehicle as the incident. Prevent duplicate links. Work orders keep their own lifecycle and costs. Any future cross-vehicle correction requires an explicitly approved and audited flow.

## Evidence and retention

Photos and case records stay with the vehicle record after closure. When the vehicle leaves the organization, retain them under the organization's records policy. The applicable policy, retention duration, and any audit-access logging requirement remain to be identified. Do not treat this draft as approval to collect more sensitive evidence than the required fields and optional photos.

## Exclusions

Insurance claims, insurer communication, liability decisions, recovery accounting, mandatory location, and involved-person capture are outside this feature.

## Acceptance scenarios to validate

- A driver submits a report with required fields and optional photos; time defaults to now but can be corrected.
- A manager files for a vehicle with multiple drivers and corrects the suggested event-time attribution.
- Active assigned drivers and mechanics on linked work orders can view details and photos; unrelated members cannot.
- An organization admin or manager links multiple same-vehicle repairs, or closes a case with no repair or repairs still open.
- Closure stores reviewer/time and optional note without changing work-order state.
- Reopening is an explicit audited action; closed-case edits are rejected until reopened.
- Reassignment after the event does not alter event-time driver attribution.

## Application behavior

Fleet Portal staff open Incidents from the Fleet menu. Fleet Admins and Managers report, review, edit, close, reopen, and link or create work orders. Mechanics can read cases linked to their assigned repairs.

Drivers report an accident through **Report Issue → Accident** for the active vehicle. The form asks for the description, event time, and optional photos. Other issue types continue to create work orders and ask for odometer and urgency. **Reports** combines work orders, inspections, and incidents in one list. The **Incidents** filter shows cases for vehicles currently assigned to the driver. Incident operations require a connection. In either client, the initial report can include up to five photos. Photos require case access and use organization storage.

## Validation still open

Confirm a representative customer workflow, the governing retention policy, and attachment access in the deployed environment.

A retry with the original submission ID must use the same incident fields and photo IDs. If a report may already have been accepted, the app directs the driver to Reports. Unlinked photo uploads are eligible for cleanup after 24 hours.
