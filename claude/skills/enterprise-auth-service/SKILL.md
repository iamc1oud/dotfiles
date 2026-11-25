---
name: enterprise-auth-service
description: >
  Design and architect an enterprise-grade centralized authentication, authorization, and user management platform — similar to Clerk — that handles auth, RBAC, billing, organizations, sessions, API keys, SSO, MFA, and more from a single service. Use this skill whenever the user asks to: build a Clerk-like platform, design an auth service, create centralized auth/authz infrastructure, architect a user management platform, or build any system handling auth + billing + RBAC together. Also trigger for questions like "how do I centralize auth across all my services?", "build me an IAM platform", "design an identity service like Clerk/Auth0/WorkOS". Always use this skill before writing any auth/identity architecture code — it encodes battle-tested patterns that Claude would otherwise get wrong.
---

# Enterprise Auth Service (Clerk-like Platform)

You are architecting a **centralized auth + identity platform** — not just login flows, but the full stack: authentication, sessions, RBAC, organizations, billing, API keys, SSO, audit logs, and developer SDKs. Think Clerk, Auth0, or WorkOS in architecture.

---

## Step 1 — Understand Scope First

Before drawing any architecture, ask (or infer from context):

| Question | Why it matters |
|---|---|
| B2C or B2B? | B2B needs Organizations, tenancy, SSO |
| Self-hosted or SaaS? | Affects infra choices, data isolation |
| Existing tech stack? | SDK and middleware compatibility |
| Billing required? | Stripe integration, plan enforcement |
| Compliance needs? | SOC2, HIPAA, GDPR changes storage/audit |

---

## Step 2 — Core Domain Map

The platform has **8 core domains**. Read `references/domains.md` for deep dives on each. Here's the overview:

```
┌──────────────────────────────────────────────────────────────────┐
│                    ENTERPRISE AUTH PLATFORM                      │
├──────────────┬──────────────┬──────────────┬────────────────────┤
│  1. Identity │  2. Session  │  3. Org &    │  4. RBAC &         │
│  & AuthN     │  Management  │  Multi-tenant│  Permissions       │
├──────────────┼──────────────┼──────────────┼────────────────────┤
│  5. Billing  │  6. API Keys │  7. Security │  8. Developer      │
│  & Plans     │  & Tokens    │  & Audit     │  Platform          │
└──────────────┴──────────────┴──────────────┴────────────────────┘
```

---

## Step 3 — Architecture Layers

Always present the architecture as **three layers**:

### Layer 1: Control Plane (the platform itself)
```
Dashboard (Admin UI)
    └── Management API  ←── webhooks, SCIM provisioning
         └── Core Services (auth, sessions, orgs, billing, keys)
              └── Policy Store (RBAC rules, permissions)
                   └── Encrypted Data Store (users, sessions, secrets)
```

### Layer 2: Data Plane (per-request path)
```
Client Request
    → API Gateway (token validation, rate limiting)
    → Auth Middleware (verify JWT, hydrate session claims)
    → Service (check permissions from session claims — no network hop)
    → Response
```

Key insight: **permissions are embedded in the JWT session token**, not fetched at request time. This is Clerk's core insight — zero extra latency for auth checks.

### Layer 3: Developer SDK Layer
```
Frontend SDK          Backend SDK           Framework Middleware
useAuth()             verifyToken()         authMiddleware()
useUser()             requireAuth()         requirePermission()
useOrganization()     getUserById()         withSession()
<SignIn />            checkPermission()     clerkClient
<UserProfile />
```

---

## Step 4 — Feature Checklist by Domain

Use `references/domains.md` to architect each domain in detail. Required domains for a production system:

### Must-Have (MVP)
- [ ] **Identity & AuthN** — passwords, OAuth, magic links, OTP, passkeys
- [ ] **Session Management** — JWT with embedded claims, refresh, revocation
- [ ] **User Profiles** — metadata, avatar, linked identities
- [ ] **MFA** — TOTP, SMS, backup codes

### Must-Have (B2B)
- [ ] **Organizations** — multi-tenancy, invitations, membership
- [ ] **RBAC** — roles, permissions, embedded in session
- [ ] **Enterprise SSO** — SAML, OIDC, SCIM provisioning
- [ ] **API Keys** — scoped, revocable, per-org or per-user

### Must-Have (SaaS)
- [ ] **Billing** — plan-gated features, Stripe integration, usage tracking
- [ ] **Audit Logs** — every auth event logged, queryable
- [ ] **Webhooks** — real-time events to customer systems
- [ ] **Developer SDK** — framework-specific clients

---

## Step 5 — The Session Token (Most Critical Design Decision)

This is the single most important architectural decision. Always show this:

```typescript
// JWT Session Token Claims (v2 format)
interface SessionClaims {
  // Standard JWT
  sub: string;           // user_id
  iss: string;           // your auth service URL
  exp: number;           // short-lived: 60s - 5min
  iat: number;

  // User Identity
  user_id: string;
  email: string;
  email_verified: boolean;

  // Organization (B2B) — only present if user has active org
  org?: {
    id: string;          // org_id
    slug: string;
    role: string;        // "org:admin" | "org:member" | custom
    permissions: string[]; // ["org:billing:manage", "org:members:invite"]
    plan: string;        // "pro" | "enterprise"
    features: string[];  // plan-gated features
  };

  // Security
  session_id: string;    // for revocation tracking
  fva: [number, number]; // first/second factor verification age
}
```

**Rule**: Never put permissions in a database lookup per-request. Embed them in the token. The token is the auth check.

---

## Step 6 — RBAC Model

```
Organization
  └── Role (org:admin, org:member, custom)
       └── Permission (org:<feature>:<action>)
            └── Example: org:billing:manage
                         org:members:invite
                         org:documents:read

// Server-side check (zero network requests)
function checkPermission(session: SessionClaims, permission: string): boolean {
  return session.org?.permissions.includes(permission) ?? false;
}

// Decorator pattern for services
@RequirePermission("org:documents:delete")
async deleteDocument(userId: string, docId: string) { ... }
```

Read `references/domains.md#rbac` for the full permission system design including role sets for billing tiers.

---

## Step 7 — Billing + Auth Integration (Key Differentiator)

Permissions should be **plan-aware**:

```typescript
// Permission check includes plan feature gating
function canUseFeature(session: SessionClaims, feature: string): boolean {
  // Check both org permission AND plan includes feature
  const hasPlanFeature = session.org?.features.includes(feature) ?? false;
  const hasPermission = session.org?.permissions
    .some(p => p.startsWith(`org:${feature}:`)) ?? false;

  return hasPlanFeature && hasPermission;
}

// Usage
canUseFeature(session, "analytics")  // false on free plan, true on pro
```

Read `references/domains.md#billing` for the full Stripe + plan enforcement design.

---

## Step 8 — API Gateway Integration Pattern

For multi-service architectures (the Google-like scenario):

```
                    ┌─────────────────┐
                    │   API Gateway   │
                    │  Validates JWT  │  ← Rejects expired/invalid tokens
                    │  Rate limits    │    Adds X-Auth-* headers
                    └────────┬────────┘
                             │ Forwards with headers:
                             │ X-User-Id, X-Org-Id, X-Session-Id
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
          ┌───────┐      ┌───────┐      ┌───────┐
          │  SVC  │      │  SVC  │      │  SVC  │
          │  A    │      │  B    │      │  C    │
          └───┬───┘      └───┬───┘      └───┬───┘
              │              │              │
              └──── All import shared SDK ──┘
                    checkPermission(session, "org:x:y")
                    // reads from JWT, never hits auth service
```

---

## Output Format

Always produce:

1. **Architecture diagram** (ASCII or described for visualization)
2. **Domain breakdown** with what each service owns
3. **Session token schema** (TypeScript interface)
4. **RBAC model** (roles → permissions table)
5. **SDK interface** (what calling services see)
6. **Implementation order** (what to build first)

For code generation, always generate:
- Token validation middleware first
- Then permission check helpers
- Then organization/tenant middleware
- Then billing gate decorators

---

## Reference Files

- `references/domains.md` — Deep dive on all 8 domains with implementation patterns
- `references/schema.md` — Database schemas for users, orgs, sessions, roles, plans
