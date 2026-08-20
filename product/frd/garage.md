# Garage Module

## Overview

The Garage is the central feature of the platform. It represents the user's digital collection of vehicles and acts as the entry point to all vehicle-related information.

---

# Objectives

Enable users to:

- Add one or more vehicles
- View all owned vehicles
- Select an active vehicle
- Manage vehicle information
- Access all vehicle-related modules

---

# In Scope

- Vehicle list
- Vehicle details
- Add vehicle
- Edit vehicle
- Archive vehicle
- Vehicle photo
- Active vehicle selection

---

# Out of Scope

- Vehicle buying
- Vehicle selling
- Fleet management
- Vehicle financing
- Fuel tracking *efficiency* (MPG / kWh economy). Refuel / charge logs are a separate module (`fuel.md`).
- Insurance policy management (keep insurance as a document and expense category only)

---

# User Personas

- Individual Owner
- Family Owner
- Car Enthusiast

---

# User Stories

### US-GAR-001

As a user,

I want to add a vehicle

So that I can manage its ownership digitally.

---

### US-GAR-002

As a user,

I want to upload a vehicle photo

So that my garage is easy to identify.

---

### US-GAR-003

As a user,

I want to switch between vehicles

So I can manage multiple cars.

---

# Functional Requirements

## Add Vehicle

Required fields

- Name
- Make
- Model
- Year
- License Plate
- Mileage
- Fuel Type (petrol / electric / hybrid plugin)

Optional

- VIN
- Color
- Nickname
- Purchase Date
- Purchase Price
- Photo

---

## Vehicle List

Display

- Photo
- Nickname
- Make
- Model
- License Plate
- Mileage
- Next Maintenance

---

## Vehicle Detail

Sections

- Overview
- Maintenance
- Expenses
- Documents
- Service History

Do not add Fuel or Insurance as vehicle-detail modules in MVP. Insurance files live in Documents. Fuel spend can be logged as an expense.

---

# Suggested Maintenance by Fuel Type

The maintenance plan shows different suggested items based on the vehicle's fuel type (set when adding the vehicle).

## Petrol
- Oil Change (every 5,000 mi or 6 months)
- Tire Rotation (every 7,500 mi)
- Brake Inspection (every 15,000 mi or 12 months)
- Additional engine-specific items (fuel filter, engine air filter, spark plugs)

## Electric
- Tire Rotation (every 5,000-7,500 mi) — EVs weigh more and deliver instant torque
- Brake Inspection (annual) — Regenerative braking reduces wear, but calipers can stick
- Brake Fluid (every 3-5 years)
- Coolant - Battery Thermal Management & Power Electronics (every 3-5 years)
- Cabin Air Filter (every 15,000-22,500 mi or 2 years)
- 12-Volt Battery (test every 6 months; 4-6 year lifespan)

## Hybrid Plugin
- All petrol items above
- Battery / power-electronics coolant (every 3-5 years)
- 12-Volt Battery (test every 6 months)

---

# Business Rules

- License plate must be unique per account.
- VIN cannot belong to multiple vehicles.
- A user must always have one active vehicle selected.
- Deleting a vehicle archives its records rather than permanently removing them.
- Mileage is required.
- Fuel type is required and must be petrol, electric, or hybrid plugin.
- Premium users may manage unlimited vehicles; free users are limited according to their plan.

---

# User Flow

Dashboard

↓

Garage

↓

Vehicle List

↓

Vehicle Detail

↓

Edit Vehicle

↓

Save

---

# Validation Rules

License Plate

- Required
- Maximum 20 characters

Year

- Required
- Between 1900 and current year + 1

Mileage

- Required
- Cannot decrease unless corrected through an administrator workflow

Fuel Type

- Required
- One of: petrol, electric, hybrid plugin

VIN

- 17 characters when supplied

---

# Error States

- Duplicate VIN
- Duplicate License Plate
- Offline save failure
- Sync conflict
- Image upload failure

---

# Non-Functional Requirements

- Offline-first
- Synchronize automatically
- Less than 2-second load time
- Accessible UI
- Secure local storage
- Support large image uploads with compression

---

# Analytics

Events

garage_opened

vehicle_added

vehicle_deleted

vehicle_switched

vehicle_updated

---

# Success Metrics

- Vehicles created
- Daily active garages
- Multiple vehicle adoption
- Profile completion rate

---

# Dependencies

- Authentication
- User Profile
- Local Database
- Sync Engine
- Notifications
- Media Storage

---

# Future Enhancements

- VIN decoder
- License plate OCR
- Fuel tracking
- Insurance module
- Vehicle valuation
- Connected car integrations
- EV battery health
- Digital ownership transfer