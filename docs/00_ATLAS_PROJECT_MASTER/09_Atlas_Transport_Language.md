# Atlas Transport Language (ATL)
Version: 1.0
Status: Draft
Owner: Atlas Project

---

# 1. Purpose

Atlas Transport Language (ATL) is the official business language of Atlas.

It defines how transportation operations are represented independently of any programming language, database engine, artificial intelligence model, workflow platform or external integration.

ATL exists to ensure that every Atlas component speaks the same language.

This includes:

- AI Parsers
- AI Validators
- PostgreSQL
- n8n Workflows
- CRM Interfaces
- Reply Generators
- Future APIs
- Mobile Applications

ATL is the canonical representation of transportation operations inside Atlas.

---

# 2. Mission

Convert unstructured transportation information into deterministic business objects.

Every email, PDF, spreadsheet or document entering Atlas must eventually become ATL.

No business component should consume raw emails directly.

Raw communication is temporary.

ATL is permanent.

---

# 3. Philosophy

Atlas does not understand emails.

Atlas understands transportation operations.

Emails are only one possible source of information.

The parser translates communication into ATL.

Every other component works exclusively with ATL.

---

# 4. Principles

ATL follows the following principles.

## 4.1 Deterministic

The same input must always produce the same business representation.

---

## 4.2 Technology Independent

ATL does not depend on

- PostgreSQL
- n8n
- OpenAI
- Anthropic
- Outlook
- Microsoft
- JSON
- REST

These technologies may change.

ATL remains stable.

---

## 4.3 Business First

ATL models transportation operations.

It does not model emails.

It does not model prompts.

It does not model databases.

Business concepts always have priority.

---

## 4.4 Explicit Information

ATL stores explicit facts.

Unknown values remain unknown.

Missing information is represented explicitly.

Atlas never invents data.

---

## 4.5 Immutable Contracts

Every ATL version defines an immutable contract.

Breaking changes require a new version.

Minor additions create a minor version.

Examples

ATL v1.0

ATL v1.1

ATL v2.0

---

# 5. Canonical Flow

Every communication follows the same lifecycle.

Communication

↓

Parser

↓

ATL

↓

Validation

↓

Business Rules

↓

Persistence

↓

Operations

↓

Customer Communication

ATL is the center of the architecture.

---

# 6. Versioning

ATL follows semantic versioning.

Major

Breaking changes.

Minor

Backward compatible additions.

Patch

Documentation improvements or corrections.

Examples

ATL v1.0

ATL v1.1

ATL v1.2

ATL v2.0

---

# 7. Responsibilities

ATL IS responsible for

- Business representation
- Canonical data exchange
- Stable contracts
- AI interoperability
- Long-term compatibility

ATL IS NOT responsible for

- SQL
- Prompt engineering
- Workflow execution
- Email rendering
- User interfaces

---

# 8. Long-Term Vision

Atlas should be able to replace any technology without changing ATL.

Future AI models may change.

Databases may change.

Workflow engines may change.

Programming languages may change.

ATL should not.

ATL is the permanent language of Atlas.

---

# 9. Summary

Everything entering Atlas eventually becomes ATL.

Everything leaving Atlas is generated from ATL.

ATL is the single source of truth for transportation operations.
