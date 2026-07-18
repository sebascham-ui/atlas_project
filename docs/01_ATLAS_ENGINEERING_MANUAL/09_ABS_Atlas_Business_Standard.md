# Atlas Business Standard

Version 1.0

---

# Purpose

Defines business rules.

Business rules never belong to AI prompts.

Business rules belong to Atlas.

---

# Rule Categories

Validation

Operations

Reservations

Transportation

Communication

Documents

---

# Examples

Airport transfers require an airport.

Hotel transfers require a hotel.

Event transfers require an event.

Transport legs require a pickup and destination.

Reservations may contain multiple transport legs.

A Case may exist before a reservation.

A Quote may exist without confirmation.

Documents belong to Cases.

Questions remain open until answered.

---

# Validation

Unknown values remain null.

Missing information generates Questions.

No information is invented.

---

# Operational Principles

Atlas stores facts.

Atlas derives operations.

Atlas never stores assumptions.

---

# AI Interaction

AI extracts facts.

Atlas validates facts.

Atlas executes business logic.

Claude communicates results.

---

# Future

Business rules evolve.

Business entities remain stable.
