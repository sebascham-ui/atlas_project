# ATL JSON Standard

Version 1.0

---

# Purpose

Defines the official JSON contract used inside Atlas.

Every AI model must produce this structure.

Every Atlas component consumes this structure.

---

# Principles

Stable

Versioned

Deterministic

Technology independent

---

# Required Root Objects

conversation

customer

case

reservation

locations

events

transport_legs

questions

documents

metadata

---

# Null Handling

Unknown values

null

Missing collections

[]

Never omit properties.

---

# Enumerations

Case Status

new

quoted

confirmed

operating

completed

cancelled

Reservation Type

quote

reservation

Transport Leg Type

airport_transfer

hotel_transfer

event_transfer

city_transfer

private_transfer

charter

other

Vehicle Type

sedan

suv

van

sprinter

minibus

bus

other

---

# Dates

ISO-8601

YYYY-MM-DD

---

# Time

24-hour

HH:mm

---

# Language

ISO-639-1

Examples

en

es

fr

de

pt

---

# Versioning

Every payload contains

metadata.version

Future versions must remain backward compatible whenever possible.
