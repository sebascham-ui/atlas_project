# Atlas Validator Architecture

Version 1.0

---

# Purpose

The Validator verifies ATL integrity.

It never extracts information.

It never reads emails.

It validates business consistency.

---

# Validation Layers

```text
ATL

↓

JSON Validation

↓

Schema Validation

↓

Business Validation

↓

Operational Validation

↓

Validated ATL
```

---

# JSON Validation

Checks

✔ valid JSON

✔ required properties

✔ arrays

✔ null handling

---

# Schema Validation

Checks

✔ property names

✔ property types

✔ enumerations

✔ required objects

---

# Business Validation

Checks

Airport transfer requires airport.

Hotel transfer requires hotel.

Event transfer requires event.

Reservation requires customer.

Transport Leg requires locations.

---

# Operational Validation

Checks

Passenger counts

Vehicle requirements

Duplicate transport legs

Missing information

Scheduling conflicts

---

# Validation Result

Possible outcomes

🟢 VALID

🟡 VALID WITH WARNINGS

🔴 INVALID

---

# Design Principle

Validator never modifies business meaning.

Validator only verifies consistency.
