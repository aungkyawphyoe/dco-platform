# DCO Platform Pricing & Feature Reference

**Version**: 1.0
**Market**: Myanmar
**Currency**: MMK (primary), USD (international)
**Last Updated**: October 2026

---

## Plan Overview

| Plan | Vehicles | Sharing | Storage | AI Tier | Monthly (MMK) | Monthly (USD) | Annual (MMK) | Annual (USD) |
|------|----------|---------|---------|---------|---------------|---------------|--------------|--------------|
| **Free** | 1 | 1 | 50 MB | Base | 0 | 0 | 0 | 0 |
| **Lite** | 3 | 3 | 150 MB | Higher | 3,000 | $1.00 | 30,000 | $10.00 |
| **Standard** | 10 | Unlimited | 500 MB | Highest | 9,000 | $2.99 | 90,000 | $29.99 |
| **Fleet/Pro** | Unlimited | Unlimited | 5 GB+ | Unlimited | 70,000 | $14.99 | 700,000 | $149.99 |

**Annual Discount**: 2 months free (10× monthly price)

---

## Feature Matrix

### Tracking
| Feature | Free | Lite | Standard | Fleet/Pro |
|---------|------|------|----------|-----------|
| Fuel Tracking | ✅ | ✅ | ✅ | ✅ |
| EV Charging Tracking | ✅ | ✅ | ✅ | ✅ |
| Mileage Tracker & Trip Log | ✅ | ✅ | ✅ | ✅ |

### Maintenance
| Feature | Free | Lite | Standard | Fleet/Pro |
|---------|------|------|----------|-----------|
| Maintenance Tracker | ✅ | ✅ | ✅ | ✅ |
| Custom Maintenance Plan | ✅ | ✅ | ✅ | ✅ |
| Reminders (Date/Mileage/Interval) | ✅ | ✅ | ✅ | ✅ |

### Costs & Records
| Feature | Free | Lite | Standard | Fleet/Pro |
|---------|------|------|----------|-----------|
| Vehicle Expense Tracker | ✅ | ✅ | ✅ | ✅ |
| Insurance Tracker | ✅ | ✅ | ✅ | ✅ |
| Digital Vehicle Logbook | ✅ | ✅ | ✅ | ✅ |
| Mileage/Trip Log | ✅ | ✅ | ✅ | ✅ |

### Garage & Sharing
| Feature | Free | Lite | Standard | Fleet/Pro |
|---------|------|------|----------|-----------|
| Multi-Vehicle Garage | ❌ (1 only) | ✅ (3) | ✅ (10) | ✅ (Unlimited) |
| Vehicle Sharing | 1 invite | 3 invites | Unlimited | Unlimited |

### Reports & Intelligence
| Feature | Free | Lite | Standard | Fleet/Pro |
|---------|------|------|----------|-----------|
| PDF Reports | ✅ | ✅ | ✅ | ✅ |
| AI Vehicle Assistant | Base | Higher | Highest | Unlimited |

### Data & Automation
| Feature | Free | Lite | Standard | Fleet/Pro |
|---------|------|------|----------|-----------|
| Data Import/Export | Limited (once) | General | General | General + API |
| Receipt Scanning | ✅ | ✅ | ✅ | ✅ |

### Fleet Features (Fleet/Pro Only)
| Feature | Free | Lite | Standard | Fleet/Pro |
|---------|------|------|----------|-----------|
| Organization/Workspace | ❌ | ❌ | ❌ | ✅ |
| Work Orders | ❌ | ❌ | ❌ | ✅ |
| Inspections | ❌ | ❌ | ❌ | ✅ |
| Driver Assignments | ❌ | ❌ | ❌ | ✅ |
| Workshop Management | ❌ | ❌ | ❌ | ✅ |
| Warranty Templates | ❌ | ❌ | ❌ | ✅ |
| Fleet Reports | ❌ | ❌ | ❌ | ✅ |
| API Access | ❌ | ❌ | ❌ | ✅ |

---

## Key Differentiators by Plan

| Aspect | Free | Lite | Standard | Fleet/Pro |
|--------|------|------|----------|-----------|
| **Vehicles** | 1 | 3 | 10 | Unlimited |
| **Sharing Invites** | 1 | 3 | Unlimited | Unlimited |
| **Storage** | 50 MB | 150 MB | 500 MB | 5 GB+ |
| **AI Assistant** | Base | Higher | Highest | Unlimited |
| **Multi-Vehicle** | ❌ | ✅ | ✅ | ✅ |
| **Vehicle Sharing** | 1 | 3 | Unlimited | Unlimited |
| **Email Reminders** | ✅ | ✅ | ✅ | ✅ |
| **Data Export (Excel/CSV)** | ✅ | ✅ | ✅ | ✅ |
| **PDF Reports** | ✅ | ✅ | ✅ | ✅ |
| **Receipt Scanning** | ✅ | ✅ | ✅ | ✅ |
| **Fleet Features** | ❌ | ❌ | ❌ | ✅ |
| **API Access** | ❌ | ❌ | ❌ | ✅ |
| **Priority Support** | ❌ | ❌ | ✅ | ✅ |

---

## Limit Enforcement Strategy

### Hard Limits (Block + Upsell)
- **Vehicles**: Hard block at limit, show upgrade prompt
- **Sharing Invites**: Hard block at limit, show upgrade prompt
- **Storage**: Hard block on upload when quota exceeded

### Enforcement Layers
1. **JWT (Passport)** — Fast gatekeeper with plan claims (15min TTL)
2. **Redis Cache (Shield)** — High-throughput limit checks (5min TTL)
3. **PostgreSQL (Source of Truth)** — Final settlement, audit trail, billing reconciliation

### Sharing Quota Model
- Owner initiates share → consumes 1 slot from **owner's quota**
- Recipient accepts → no quota impact on recipient
- Recipient can be on Free plan — gets read access to shared vehicle
- Owner revokes share → slot returned to owner's quota

---

## Payment & Billing

### Currency Strategy
- **Display**: MMK for all Myanmar users
- **Local Payments**: 2C2P / MyanmarPay / KBZPay / AYA Pay / Wave Money (MMK direct)
- **International**: Stripe (USD) for non-Myanmar cards
- **No Stripe MMK** (unsupported by Stripe)

### Billing Cycles
- Monthly: Charged on subscription date
- Annual: 10× monthly (2 months free), charged upfront
- Auto-renewal default, cancel anytime
- 30-day money-back guarantee

### Plan Changes
- **Upgrade**: Immediate, prorated charge, new limits effective instantly
- **Downgrade**: Effective at period end, current limits remain until then
- **Cancellation**: Access until period end, then reverts to Free

---

## Target Audiences

1. **Individual Owners** (Free/Lite/Standard) — Personal vehicles, family sharing
2. **EV Owners** — Charging costs, energy consumption, efficiency tracking
3. **Petrol/Diesel Drivers** — Fuel efficiency, service history, maintenance
4. **Families** — Multiple vehicles, shared records, shared reminders
5. **Fleet Operators** (Fleet/Pro) — Organization workspace, work orders, driver management, workshops, warranty, API

---

## Platform Availability
- Mobile App (Flutter): iOS, Android — **Owner plans only** (Free/Lite/Standard)
- Fleet Portal (Next.js 15): Web — **Fleet/Pro only** (separate product, `dco-fleet` JWT audience)
- Sync: Instant across devices for same account

---

## Privacy & Data Ownership
- User controls data at all times
- Export data anytime (CSV/Excel/PDF)
- Delete account permanently option
- Data stored in Azure (Myanmar region preferred)
- 30-day refund policy, no questions asked

---

## Implementation Reference

### Database Schema
```sql
-- plans (static reference)
CREATE TABLE plans (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  vehicle_limit INT,
  sharing_limit INT,
  storage_bytes BIGINT,
  ai_tier TEXT,
  price_monthly_mmk INT,
  price_annual_mmk INT,
  stripe_price_id TEXT,
  local_gateway_plan_id TEXT
);

-- subscriptions
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  plan_id TEXT NOT NULL REFERENCES plans(id),
  status TEXT NOT NULL,
  current_period_start TIMESTAMPTZ NOT NULL,
  current_period_end TIMESTAMPTZ NOT NULL,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  payment_method TEXT,
  external_subscription_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id) WHERE status IN ('active', 'trialing')
);

-- usage_counters
CREATE TABLE usage_counters (
  user_id UUID NOT NULL REFERENCES users(id),
  metric TEXT NOT NULL,
  count BIGINT NOT NULL DEFAULT 0,
  period_start DATE NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, metric, period_start)
);
```

### JWT Entitlement Claims
```json
{
  "sub": "user_id",
  "plan_id": "lite",
  "vehicle_limit": 3,
  "sharing_limit": 3,
  "storage_bytes": 157286400,
  "ai_tier": "higher",
  "period_end": "2026-11-01T00:00:00Z",
  "exp": 1730419200
}
```

### Limit Check Response (403)
Wrapped in the platform error envelope (`architecture/openapi.yaml` → `ErrorBody`);
the pricing fields live in `details`.

```json
{
  "error": {
    "code": "LIMIT_EXCEEDED",
    "message": "Free plan allows 1 vehicle. Upgrade to Lite for 3 vehicles.",
    "details": {
      "metric": "vehicles",
      "current": 1,
      "limit": 1,
      "upgrade_url": "/pricing"
    }
  }
}
```

---

## Feature Parity Checklist

| Feature | DCO Current | Status |
|---------|-------------|--------|
| Fuel Tracking | ✅ | Done |
| EV Charging Tracking | ✅ | Done |
| Maintenance Tracker | ✅ | Done |
| Custom Maintenance Plan | ✅ | Done |
| Reminders (Date/Mileage/Interval) | ✅ | Done |
| Vehicle Expense Tracker | ✅ | Done |
| Insurance Tracker | ❌ | Planned |
| Digital Vehicle Logbook | ✅ | Done |
| Mileage/Trip Log | ❌ | Planned |
| Multi-Vehicle Garage | ❌ | Planned (plan-gated) |
| Vehicle Sharing | ✅ | Done |
| PDF Reports | ❌ | Planned |
| AI Vehicle Assistant | ❌ | Planned |
| Data Import/Export | Partial | Improve |
| Receipt Scanning | ❌ | Planned |
| Fleet Features | ❌ | Fleet Portal (separate) |

---

## References
- Architecture: `architecture/system.md`
- Data Model: `architecture/data-model.md`
- IAM: `architecture/iam.md`
- OpenAPI: `architecture/openapi.yaml`
- Mobile AGENTS: `mobile/AGENTS.md`
- Web Stack: `docs/adr/web-stack.md`
- Fleet Portal: `fleet-portal/`