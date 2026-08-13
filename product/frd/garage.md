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
- Delete vehicle
- Vehicle photo
- Active vehicle selection

---

# Out of Scope

- Vehicle buying
- Vehicle selling
- Fleet management
- Vehicle financing

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

- Make
- Model
- Year
- License Plate

Optional

- VIN
- Color
- Nickname
- Purchase Date
- Purchase Price
- Odometer
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
- Fuel
- Insurance
- Documents
- Service History

---

# Business Rules

- License plate must be unique per account.
- VIN cannot belong to multiple vehicles.
- A user must always have one active vehicle selected.
- Deleting a vehicle archives its records rather than permanently removing them.
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

- Between 1900 and current year + 1

VIN

- 17 characters when supplied

Mileage

- Cannot decrease unless corrected through an administrator workflow

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
- Vehicle valuation
- Connected car integrations
- EV battery health
- Digital ownership transfer