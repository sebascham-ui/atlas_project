# Atlas Domain Standard
Version 1.0

---

# Purpose

This document defines every business entity existing inside Atlas.

Every software component must use these definitions.

Business entities are independent from databases, prompts, workflows and programming languages.

---

# Core Entities

Atlas is composed of the following business entities.

Case

Conversation

Message

Customer

Reservation

Transport Leg

Location

Hotel

Event

Flight

Vehicle Requirement

Question

Quote

Document

Task

---

# Entity Rules

Every entity must have

Identity

Lifecycle

Relationships

Business meaning

No entity may exist without business justification.

---

# Relationships

Case

├── Conversation

├── Customer

├── Reservation

├── Documents

├── Questions

└── Quotes

Reservation

├── Events

├── Flights

├── Hotels

└── Transport Legs

Transport Leg

├── Pickup Location

├── Destination Location

└── Vehicle Requirement

---

# Business Principles

A Case represents a business opportunity.

A Reservation represents transportation services.

A Transport Leg represents one transportation movement.

Locations are reusable.

Hotels are reusable.

Events are reusable.

Questions represent unresolved information.

Documents represent supporting information.

---

# Future Compatibility

New entities may be added.

Existing entities should not change semantics.
