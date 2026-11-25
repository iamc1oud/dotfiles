# Domain Reference — Enterprise Auth Platform

## Table of Contents
1. [Identity & Authentication](#1-identity--authentication)
2. [Session Management](#2-session-management)
3. [Organizations & Multi-tenancy](#3-organizations--multi-tenancy)
4. [RBAC & Permissions](#4-rbac--permissions)
5. [Billing & Plans](#5-billing--plans)
6. [API Keys & Tokens](#6-api-keys--tokens)
7. [Security & Audit](#7-security--audit)
8. [Developer Platform](#8-developer-platform)

---

## 1. Identity & Authentication

### Auth Methods (implement in this priority order)
| Method | When to add | Notes |
|---|---|---|
| Email + Password | Day 1 | bcrypt, breach detection via HaveIBeenPwned |
| Social OAuth | Day 1 | Google, GitHub, Microsoft minimum |
| Magic Links | Day 1 | Passwordless, high conversion |
| OTP (Email/SMS) | Day 1 | One-time codes |
| Passkeys/WebAuthn | Phase 2 | Phishing-resistant, biometrics |
| TOTP (Authenticator apps) | Phase 2 | Google Authenticator, Authy |
| Enterprise SSO (SAML/OIDC) | Phase 2 | Required for enterprise sales |
| Web3/Wallet | Optional | MetaMask, Coinbase Wallet |

### User Profile Model
```typescript
interface User {
  id: string;                    // user_xxxxx
  primary_email: string;
  email_verified: boolean;
  primary_phone?: string;
  phone_verified?: boolean;

  // Linked identities (OAuth accounts)
  external_accounts: ExternalAccount[];

  // Metadata
  public_metadata: Record<string, unknown>;   // readable client-side
  private_metadata: Record<string, unknown>;  // server-only
  unsafe_metadata: Record<string, unknown>;   // user-writable

  // Security
  password_enabled: boolean;
  two_factor_enabled: boolean;
  mfa_methods: MFAMethod[];

  // Timestamps
  created_at: Date;
  last_sign_in_at: Date;
  last_active_at: Date;
}
```

### MFA Implementation
```
Sign-in Flow with MFA:
  1. User provides first factor (password / OAuth / passkey)
  2. System returns partial session (status: "needs_second_factor")
  3. User provides second factor (TOTP code / SMS OTP / backup code)
  4. System upgrades session to active
  5. JWT claims include fva (factor verification age): [first_factor_age, second_factor_age]
```

Required MFA methods: TOTP authenticator app, SMS OTP, email OTP, backup codes.

### Bot & Fraud Protection
- ML-based bot detection on sign-up (block disposable emails, suspicious patterns)
- Rate limiting on auth endpoints (exponential backoff)
- CAPTCHA integration (Cloudflare Turnstile recommended)
- Brute force prevention with lockout after N failures
- Breached password detection

---

## 2. Session Management

### Session Architecture
Sessions are short-lived JWTs (60s–5min) backed by long-lived refresh tokens stored server-side.

```
┌─────────────────────────────────────────────────────────┐
│ Active Session                                          │
│  ├── session_id (tracks this device/browser)            │
│  ├── user_id                                            │
│  ├── JWT (short-lived, embedded claims)                 │
│  ├── refresh_token (long-lived, httpOnly cookie)        │
│  ├── device fingerprint                                 │
│  ├── ip_address (last known)                            │
│  └── last_active_at                                     │
└─────────────────────────────────────────────────────────┘
```

### Session Lifecycle
```
Create → Active → [Idle timeout] → Expired
                → [Absolute timeout] → Expired
                → [User revoke] → Revoked
                → [Admin revoke] → Revoked
                → [Password change] → All sessions revoked
                → [Privilege change] → Token refreshed with new claims
```

### Multi-Device Handling
- Each browser/device gets its own session with a unique `session_id`
- Users can see all active sessions and revoke any from their profile
- Admins can revoke all sessions for a user
- New org role changes propagate at next JWT refresh (max delay = JWT TTL)

### Token Refresh Strategy
```typescript
// Client SDK refresh logic
async function getActiveToken(): Promise<string> {
  const token = getCurrentJWT();

  if (isExpiredOrExpiringSoon(token, THRESHOLD_SECONDS=30)) {
    // Silently refresh in background
    const newToken = await refreshSession(refresh_token);
    cacheToken(newToken);
    return newToken;
  }

  return token;
}
```

---

## 3. Organizations & Multi-tenancy

### Data Model
```typescript
interface Organization {
  id: string;                    // org_xxxxx
  name: string;
  slug: string;                  // URL-safe, unique
  image_url?: string;

  // Membership
  members_count: number;
  max_allowed_memberships: number;  // plan-based limit

  // Settings
  admin_delete_enabled: boolean;
  domains: OrgDomain[];          // verified domains for auto-join

  // Billing
  plan_id: string;
  stripe_customer_id: string;
  subscription_id: string;

  // Metadata (same pattern as users)
  public_metadata: Record<string, unknown>;
  private_metadata: Record<string, unknown>;
}

interface Membership {
  user_id: string;
  org_id: string;
  role: string;               // "org:admin" | "org:member" | custom
  created_at: Date;
  invited_by?: string;
}
```

### Invitation Flow
```
Admin invites email
  → Store invitation with token (24hr expiry)
  → Send email with magic link
  → User clicks link:
      → If existing user: add to org directly
      → If new user: sign-up flow, then add to org
  → Webhook: organization.invitation.accepted
```

### Domain Allowlisting
```typescript
// Org admins can verify domains — users with matching email auto-join
interface OrgDomain {
  domain: string;            // "acme.com"
  verified: boolean;
  enrollment_mode: "automatic_invitation" | "automatic_suggestion" | "manual";
}
```

### SCIM Provisioning (Enterprise)
For Okta/Entra integration: implement SCIM 2.0 endpoints:
- `POST /scim/v2/Users` — provision user
- `PATCH /scim/v2/Users/{id}` — update user
- `DELETE /scim/v2/Users/{id}` — deprovision user
- `GET /scim/v2/Groups` — sync groups → org roles

---

## 4. RBAC & Permissions

### Permission Naming Convention
```
Format: {namespace}:{feature}:{action}

Examples:
  org:billing:manage       — manage org billing
  org:members:invite       — invite new members
  org:members:remove       — remove members
  org:documents:read       — read documents
  org:documents:write      — create/edit documents
  org:documents:delete     — delete documents
  org:analytics:view       — view analytics
  org:api_keys:manage      — manage API keys
```

### Role Architecture
```typescript
interface Role {
  key: string;              // "org:admin" | "org:editor" | custom
  name: string;             // Human readable
  description: string;
  is_default: boolean;      // Assigned to new members
  permissions: string[];    // List of permission keys
}

// Default roles (always present)
const DEFAULT_ROLES = {
  "org:admin": {
    permissions: ["*"]      // All permissions
  },
  "org:member": {
    permissions: [
      "org:documents:read",
      "org:analytics:view"
    ]
  }
}
```

### Role Sets (for billing tiers)
```typescript
// Different subscription plans unlock different role sets
interface RoleSet {
  id: string;
  plan: "free" | "pro" | "enterprise";
  available_roles: Role[];   // Roles orgs on this plan can assign
}

// Free plan: only admin + member
// Pro plan: admin + member + editor + viewer
// Enterprise: fully custom roles
```

### Permission Check Patterns
```typescript
// Frontend — check from session (no network call)
const { has } = useAuth();
const canManageBilling = has({ permission: "org:billing:manage" });

// Backend — same data, from JWT claims
function requirePermission(permission: string) {
  return (req, res, next) => {
    const { sessionClaims } = req.auth;
    const allowed = sessionClaims.org?.permissions.includes(permission);
    if (!allowed) return res.status(403).json({ error: "Forbidden" });
    next();
  };
}

// Decorator approach for services
@RequirePermission("org:documents:delete")
async deleteDocument(docId: string): Promise<void> { ... }
```

---

## 5. Billing & Plans

### Architecture: Auth + Billing Unified
This is the key differentiator. Billing gates features at the **permission layer**, not just the UI.

```typescript
interface Plan {
  id: string;               // "free" | "pro" | "enterprise"
  name: string;
  stripe_price_id: string;

  limits: {
    mau: number;            // Monthly Active Users
    org_members: number;    // Per organization
    api_keys: number;
    storage_gb: number;
  };

  features: string[];       // Feature flags unlocked by this plan
  // e.g., ["analytics", "custom_roles", "saml_sso", "audit_logs"]

  role_set_id: string;      // Which RBAC role set is available
}
```

### Plan-Permission Integration
```typescript
// When billing plan changes → update session claims
async function onPlanUpgrade(orgId: string, newPlan: Plan) {
  await db.organization.update({
    where: { id: orgId },
    data: {
      plan_id: newPlan.id,
      features: newPlan.features
    }
  });

  // Next JWT refresh will include new features in claims
  // org.features: ["analytics", "custom_roles"]
}

// Feature gate check (combines plan + permission)
function canAccessFeature(session: SessionClaims, feature: string): boolean {
  const planIncludesFeature = session.org?.features.includes(feature);
  const hasPermission = session.org?.permissions
    .some(p => p.includes(`:${feature}:`));
  return planIncludesFeature && hasPermission;
}
```

### Stripe Integration Points
```
Customer (= Organization)
  └── Subscription (= Plan)
       └── Stripe Webhooks → your billing service:
            - customer.subscription.updated → update plan in DB
            - customer.subscription.deleted → downgrade to free
            - invoice.payment_failed → grace period logic
            - invoice.payment_succeeded → reset usage counters

// Expose pricing UI
<PricingTable orgId={org.id} currentPlan={org.plan} />
// Handles checkout, trial, upgrade, downgrade
```

### Usage Tracking
```typescript
// Track billable events
interface UsageEvent {
  org_id: string;
  metric: "mau" | "api_calls" | "storage_bytes";
  value: number;
  recorded_at: Date;
}
// Aggregate daily, enforce limits, alert near-threshold
```

---

## 6. API Keys & Tokens

### API Key Model
```typescript
interface APIKey {
  id: string;               // key_xxxxx
  name: string;             // human readable
  key_prefix: string;       // first 8 chars shown in UI: "sk_live_xxxx..."
  key_hash: string;         // bcrypt hash of full key (never store plaintext)

  // Scoping
  owner_type: "user" | "organization";
  owner_id: string;
  scopes: string[];         // ["read:users", "write:documents"]

  // Lifecycle
  expires_at?: Date;
  last_used_at?: Date;
  revoked_at?: Date;
  revoked_by?: string;

  created_at: Date;
  created_by: string;
}
```

### Key Creation Flow
```
1. Generate cryptographically random key (32 bytes → base64url)
2. Format: sk_live_{random} or sk_test_{random}
3. Show full key ONCE to user (never again)
4. Store only: prefix (for display) + bcrypt hash (for verification)
5. On API request: hash incoming key → compare to stored hash
```

### Scope System
```typescript
// Scopes follow same pattern as permissions
const API_KEY_SCOPES = [
  "users:read",
  "users:write",
  "organizations:read",
  "organizations:write",
  "billing:read",
  // etc.
];

// Validate scope on every API request
function validateAPIKeyScope(key: APIKey, requiredScope: string): boolean {
  return key.scopes.includes(requiredScope) || key.scopes.includes("*");
}
```

---

## 7. Security & Audit

### Audit Log Schema
```typescript
interface AuditEvent {
  id: string;
  actor_type: "user" | "api_key" | "system";
  actor_id: string;

  action: string;           // "session.created" | "org.member.removed" | "api_key.revoked"
  target_type?: string;     // "user" | "organization" | "api_key"
  target_id?: string;

  org_id?: string;

  metadata: Record<string, unknown>;  // action-specific details

  ip_address: string;
  user_agent: string;
  country_code?: string;

  created_at: Date;         // immutable, append-only
}

// Key events to always log:
const AUDIT_EVENTS = [
  "user.signed_in", "user.signed_out", "user.created", "user.deleted",
  "user.password_changed", "user.mfa_enabled", "user.mfa_disabled",
  "session.revoked",
  "org.created", "org.member_added", "org.member_removed", "org.role_changed",
  "org.plan_changed",
  "api_key.created", "api_key.revoked",
  "sso.connection_created",
  "permission.updated",
];
```

### Security Requirements
- All tokens stored as hashes (bcrypt for API keys, SHA-256 for refresh tokens)
- Session cookies: httpOnly, Secure, SameSite=Strict
- JWT signed with RS256 (asymmetric) — public key exposed for service verification
- Refresh tokens: single-use with rotation
- Rate limiting: per-IP and per-user, with exponential backoff
- All auth endpoints behind HTTPS only
- PII encrypted at rest (email, phone, IP addresses)

### Webhook System
```typescript
interface Webhook {
  endpoint_url: string;
  signing_secret: string;   // for HMAC verification
  events: string[];         // which events to send
  enabled: boolean;
}

// Payload always includes:
interface WebhookPayload {
  type: string;             // "user.created"
  data: object;             // the resource
  timestamp: number;
  signature: string;        // HMAC-SHA256(body, signing_secret)
}

// Retry logic: exponential backoff, up to 5 attempts over 24hrs
```

---

## 8. Developer Platform

### SDK Architecture
Every framework integration should expose the same conceptual API:

```typescript
// Frontend (React example)
const { isLoaded, isSignedIn, user } = useUser();
const { sessionId, userId, orgId, orgRole, has } = useAuth();
const { organization, membership, members } = useOrganization();

// Pre-built components (drop-in)
<SignIn />               // Full sign-in flow
<SignUp />               // Full sign-up flow
<UserButton />           // Avatar + account menu
<UserProfile />          // Account settings page
<OrganizationProfile />  // Org settings + members
<PricingTable />         // Billing plan selection
<CreateOrganization />   // Org creation flow

// Backend (Node.js example)
import { authMiddleware, requireAuth, requirePermission } from '@your-auth/node';

app.use(authMiddleware());  // Attaches session to req.auth

app.get('/protected', requireAuth(), (req, res) => {
  const { userId, orgId } = req.auth;
});

app.delete('/doc/:id', requirePermission('org:documents:delete'), handler);
```

### Middleware Pattern (per framework)
```typescript
// Next.js
export default authMiddleware({
  publicRoutes: ['/landing', '/pricing', '/api/webhooks/stripe'],
  ignoredRoutes: ['/api/health'],
  afterAuth(auth, req) {
    // Redirect unauthenticated users
    if (!auth.userId && !auth.isPublicRoute) {
      return redirectToSignIn({ returnBackUrl: req.url });
    }
  }
});

// Express
app.use(clerkMiddleware());
app.use('/api/protected', requireAuth());
```

### Dashboard (Admin UI) — Required Pages
1. **Users** — list, search, impersonate, ban, delete, reset MFA
2. **Organizations** — list, view members, manage roles
3. **Sessions** — active sessions, revoke any
4. **Audit Logs** — filterable event stream
5. **API Keys** — list all, revoke
6. **Billing** — current plan, usage, invoice history
7. **SSO Connections** — SAML/OIDC configuration
8. **Webhooks** — configure endpoints, view delivery logs
9. **RBAC** — manage roles and permissions per org
10. **Settings** — auth methods, branding, email templates

### User Impersonation (Support Tool)
```typescript
// Admin can sign in as any user for debugging
async function impersonateUser(adminId: string, targetUserId: string) {
  // 1. Verify admin has impersonation permission
  // 2. Create impersonation session (flagged in JWT: "impersonator_id")
  // 3. Emit audit event: "user.impersonation.started"
  // 4. All actions in impersonated session attributed in audit log
}
```

---

## Implementation Order (Recommended)

### Phase 1 — Core Auth (Weeks 1-4)
1. User model + password auth + OAuth
2. Session management (JWT + refresh tokens)
3. Email/SMS OTP
4. Basic user profile

### Phase 2 — B2B Features (Weeks 5-8)
5. Organizations + membership
6. RBAC (roles + permissions in JWT)
7. Invitations + email flows
8. Admin dashboard (users, orgs, sessions)

### Phase 3 — Enterprise (Weeks 9-14)
9. SAML/OIDC SSO
10. SCIM provisioning
11. API Keys
12. Audit logs
13. Webhooks
14. MFA (TOTP + passkeys)

### Phase 4 — Platform (Weeks 15-20)
15. Billing integration (Stripe)
16. Plan-gated permissions
17. Usage tracking
18. Developer SDKs (per framework)
19. User impersonation
20. Bot/fraud protection
