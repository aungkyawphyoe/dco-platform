# Parts Module

## Overview

Parts is a per-vehicle catalog of components the owner cares about (filters, pads, batteries). Parts are added and edited from Quick Actions. They can be assigned when logging a service or an expense.

Source of truth for scope: `product/mvp-scope.md`.

---

# Objectives

- Keep a named list of parts for the active vehicle
- Attach those parts to a service or an expense without retyping

---

# In Scope

- List parts for the active vehicle
- Add and edit a part (name required; brand, part number, notes optional)
- Assign parts when registering a service
- Assign parts when logging an expense
- Show assigned parts on service detail and the expense form

# Out of Scope

- Inventory quantity / stock
- Marketplace or vendor catalog
- Deleting parts in this slice

---

# User Stories

### US-PRT-001

As a car owner, I want to add a new part so that I can reuse it on services and expenses.

### US-PRT-002

As a car owner, I want to see the parts I added so that I know what is on this vehicle.

### US-PRT-003

As a car owner, I want to edit a part so that the name and fitment stay accurate.

---

# Functional Requirements

## List

- Active vehicle only, name A–Z
- Row: name; subtitle brand · part number when present
- Tap → edit
- Empty: add CTA

## Add / edit

Required: name (unique per vehicle, case-insensitive).  
Optional: brand, part number, notes.

## Assign on service

- Register Service has a Parts section
- Owner picks from the catalog or adds a new part then returns
- Assigned names are snapshotted on the service so later catalog edits do not rewrite history

## Assign on expense

- Add / edit expense has a Parts section
- Owner picks from the catalog or adds a new part then returns
- Assigned names are snapshotted on the expense so later catalog edits do not rewrite history

---

# Business Rules

- Every part belongs to one vehicle
- Duplicate names on the same vehicle are rejected
- Assignment is optional
- The same part cannot be assigned twice on one service or expense

---

# Validation Rules

- Name required, max 80
- Brand max 40, part number max 40, notes max 500

---

# Analytics

`part_added`, `part_updated`

---

# Dependencies

Garage (active vehicle), Maintenance (register service), Expenses (add/edit form)
