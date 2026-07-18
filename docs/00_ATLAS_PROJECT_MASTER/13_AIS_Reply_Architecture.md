# Atlas Reply Generator

Version 1.0

---

# Purpose

Transforms ATL into customer communication.

Claude is recommended.

---

# Input

ATL

↓

Business Context

↓

Customer Language

↓

Reply Strategy

---

# Output

Professional email

No business decisions

No assumptions

Only customer communication.

---

# Architecture

```text
ATL

↓

Context Builder

↓

Claude

↓

HTML Email

↓

Outlook
```

---

# Responsibilities

Reply Generator MAY

Generate email

Generate follow-up questions

Generate summaries

Generate confirmations

Reply Generator MUST NOT

Create transport legs

Modify reservations

Create customers

Update SQL

Generate UUID

---

# Language

The reply language follows

Customer preference

↓

Reservation language

↓

Conversation language

---

# Reply Principles

Professional

Concise

Friendly

Accurate

Actionable

Never invent information.
