# Documents Module

## Overview

The Document Vault stores files that belong to the active vehicle: registration, insurance papers, invoices, warranties, and similar. It is a named list of files, not an insurance-policy or receipt-OCR product. Insurance **files** live here; insurance **policies** are v1.1.

Source of truth for scope: `product/mvp-scope.md`.

---

# Objectives

Enable users to:

- Keep important vehicle files in one place
- Upload a photo or PDF
- Categorize the document
- Open it later on the device

---

# In Scope

- Per-vehicle document list
- Upload photo or PDF with compression for images
- Categories: insurance, registration, invoice, warranty, receipt, other
- View / open a stored document
- Edit name, category, and notes
- Delete a document (user-confirmed)

---

# Out of Scope

- Insurance policy object (provider, period, renew, previous policies)
- Receipt OCR
- Multiple files per document record (MVP is one primary file per document)
- Sharing a document with another account
- Folder nesting
- Expiry reminders derived from document contents (use Maintenance reminders or v1.1 insurance)

---

# User Personas

- Everyday Owner
- Family Manager (own vehicles only)
- Car Enthusiast

---

# User Stories

### US-DOC-001

As a user,

I want to store my registration and insurance files on the vehicle

So that I can find them without paper.

---

### US-DOC-002

As a user,

I want to photograph or upload a PDF

So that I can capture a document I already have.

---

### US-DOC-003

As a user,

I want to open a stored document

So that I can show it at a workshop or checkpoint.

---

# Functional Requirements

## List

Display for the active vehicle

- Thumbnail or type icon (PDF / image)
- Name
- Category
- Size and date added

Empty state explains that insurance, registration, and invoices belong here.

## Add / upload

Required

- File (camera, photo library, or PDF picker)
- Name (defaults to file name)
- Category

Optional

- Notes

Behavior

- Images are compressed before upload and before local store
- PDFs are stored as-is with a size limit
- Works offline: file stays local and uploads when sync runs
- Category `insurance` does not create a policy record

## View

- Images open in a full-screen viewer
- PDFs open in the platform document viewer
- No in-app annotation in MVP

## Edit

- Name, category, notes
- Replacing the file is allowed (old file is removed after the new file is stored)

## Delete

- Confirm destructive action
- Removes the local file and queues remote delete
- Not the same as archiving a vehicle (vehicle archive keeps documents)

---

# Business Rules

- Every document belongs to exactly one vehicle
- The list always shows the active vehicle's documents
- Categories are a fixed enum in MVP (no user-defined categories)
- Free/premium does not limit document count in MVP
- Maximum file size: 15 MB after image compression; reject with an error if still over

---

# User Flow

Vehicle detail or Documents entry

↓

Document list

↓

Add → pick camera / library / PDF → name + category → save

↓

Tap row → view

---

# Validation Rules

Name

- Required
- Maximum 120 characters

Category

- Required
- One of: insurance, registration, invoice, warranty, receipt, other

File

- Required
- Image (jpeg, png, heic) or PDF
- Size after compression <= 15 MB

---

# Error States

- No active vehicle
- Camera or files permission denied
- Unsupported file type
- File too large
- Image compression failure
- Open/view failure (missing local file before sync download)
- Offline: save locally and show queued state, not a blocking error
- Sync upload failure (retry via `sync.md`)

---

# Non-Functional Requirements

- Offline-first metadata and local file
- Automatic sync of metadata and bytes
- < 2-second list load on a mid-range device
- Accessible list and upload flow
- Secure local storage of files
- Large images compressed before upload

---

# Analytics

Events

document_uploaded

document_opened

document_deleted

---

# Success Metrics

- Documents uploaded per vehicle
- Share of vehicles with at least one document
- Open rate of stored documents

---

# Dependencies

- Authentication
- Garage (active vehicle)
- Local Database
- Sync Engine
- Media Storage

---

# Future Enhancements

- Multiple attachments per document
- Insurance module using these files as attachments
- Expiry date field and reminder
- OCR of registration / plate
- Export / share link
