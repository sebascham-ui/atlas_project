# Atlas Parser Architecture

Version: 1.0

---

# Purpose

The Atlas Parser is responsible for transforming unstructured communication into ATL (Atlas Transport Language).

It does not execute business logic.

It does not make operational decisions.

It only extracts structured facts.

---

# High-Level Architecture

```text
                    EMAIL
                      │
                      ▼
            ┌──────────────────┐
            │ Email Cleaner    │
            └────────┬─────────┘
                     │
                     ▼
            ┌──────────────────┐
            │ Intent Detection │
            └────────┬─────────┘
                     │
                     ▼
            ┌──────────────────┐
            │ Entity Extraction│
            └────────┬─────────┘
                     │
                     ▼
            ┌──────────────────┐
            │ Normalization    │
            └────────┬─────────┘
                     │
                     ▼
            ┌──────────────────┐
            │ Schema Validation│
            └────────┬─────────┘
                     │
                     ▼
                    ATL
```

---

# Responsibilities

🟢 The Parser MUST

- Read customer communications.
- Identify transportation facts.
- Normalize dates.
- Normalize times.
- Normalize languages.
- Normalize locations.
- Produce ATL.

🔴 The Parser MUST NOT

- Generate UUIDs.
- Execute SQL.
- Update PostgreSQL.
- Make pricing decisions.
- Choose vehicles.
- Create workflows.
- Decide logistics.

---

# Internal Pipeline

## Stage 1

Communication Analysis

Input

```
Email
PDF
DOCX
XLSX
```

Output

```
Raw Text
```

---

## Stage 2

Context Separation

Separate

✔ Customer Request

✔ Quoted Emails

✔ Signatures

✔ Legal Disclaimers

✔ Attachments

---

## Stage 3

Intent Detection

Supported intents

Quote

Reservation

Modification

Cancellation

Information

Other

---

## Stage 4

Entity Extraction

Customer

Reservation

Transport Legs

Hotels

Flights

Events

Locations

Questions

Documents

---

## Stage 5

Normalization

Dates

ISO-8601

Times

HH:mm

Language

ISO-639-1

---

## Stage 6

ATL Generation

The Parser generates one ATL document.

Nothing else.

---

# Design Principles

🟢 Deterministic

🟢 Stateless

🟢 Technology Independent

🟢 Business First

---

# Error Strategy

Unknown values

↓

null

Missing information

↓

Question

Contradictory information

↓

Validation Warning

Parser never invents information.

---

# Output

The Parser always produces ATL v1.x
