# Atlas System Flow

---

# Complete Architecture

```text
                    OUTLOOK
                        │
                        ▼
             Email Reception Layer
                        │
                        ▼
               Email Cleaning Layer
                        │
                        ▼
               Atlas Parser (GPT)
                        │
                        ▼
                ATL Document v1
                        │
          ┌─────────────┼──────────────┐
          ▼             ▼              ▼
 JSON Validator   Business Rules   AI Validator
          └─────────────┼──────────────┘
                        ▼
                 Atlas Engine
                        │
        ┌───────────────┼─────────────────┐
        ▼               ▼                 ▼
 PostgreSQL        CRM Dashboard     Analytics
        │
        ▼
Reply Generator (Claude)
        │
        ▼
Outlook
```

---

# Processing Stages

🟦 Reception

Receive communication.

🟦 Understanding

Convert communication into ATL.

🟦 Validation

Verify consistency.

🟦 Persistence

Store structured information.

🟦 Communication

Generate customer response.

---

# Golden Rule

Everything entering Atlas

↓

becomes ATL

↓

Everything leaving Atlas

↓

is generated from ATL
