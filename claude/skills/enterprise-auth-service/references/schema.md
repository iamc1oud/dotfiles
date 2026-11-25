# Database Schema Reference

## Core Tables

### users
```sql
CREATE TABLE users (
  id              VARCHAR PRIMARY KEY,  -- user_xxxxx
  primary_email   VARCHAR UNIQUE NOT NULL,
  email_verified  BOOLEAN DEFAULT FALSE,
  primary_phone   VARCHAR,
  phone_verified  BOOLEAN DEFAULT FALSE,

  -- Auth
  password_hash   VARCHAR,             -- bcrypt, nullable if social-only
  password_enabled BOOLEAN DEFAULT FALSE,

  -- MFA
  totp_secret     VARCHAR,             -- encrypted at rest
  mfa_enabled     BOOLEAN DEFAULT FALSE,
  backup_codes    JSONB,               -- hashed codes

  -- Metadata
  public_metadata  JSONB DEFAULT '{}',
  private_metadata JSONB DEFAULT '{}',
  unsafe_metadata  JSONB DEFAULT '{}',

  -- Profile
  first_name      VARCHAR,
  last_name       VARCHAR,
  image_url       VARCHAR,
  username        VARCHAR UNIQUE,

  -- Timestamps
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  last_sign_in_at TIMESTAMPTZ,
  last_active_at  TIMESTAMPTZ,
  banned_at       TIMESTAMPTZ
);
```

### sessions
```sql
CREATE TABLE sessions (
  id                VARCHAR PRIMARY KEY,  -- sess_xxxxx
  user_id           VARCHAR REFERENCES users(id) ON DELETE CASCADE,
  org_id            VARCHAR REFERENCES organizations(id),

  -- Token management
  refresh_token_hash VARCHAR NOT NULL,    -- SHA-256 hash
  refresh_token_exp  TIMESTAMPTZ NOT NULL,

  -- Security metadata
  ip_address         INET,
  user_agent         TEXT,
  country_code       CHAR(2),
  device_fingerprint VARCHAR,

  -- MFA tracking
  first_factor_verified_at  TIMESTAMPTZ,
  second_factor_verified_at TIMESTAMPTZ,

  -- Lifecycle
  status      VARCHAR DEFAULT 'active',  -- active | expired | revoked
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  last_active_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked_at  TIMESTAMPTZ,
  revoked_by  VARCHAR
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_status ON sessions(status);
```

### organizations
```sql
CREATE TABLE organizations (
  id           VARCHAR PRIMARY KEY,  -- org_xxxxx
  name         VARCHAR NOT NULL,
  slug         VARCHAR UNIQUE NOT NULL,
  image_url    VARCHAR,

  -- Membership limits
  max_allowed_memberships INTEGER DEFAULT 5,

  -- Billing
  plan_id               VARCHAR REFERENCES plans(id) DEFAULT 'free',
  stripe_customer_id    VARCHAR UNIQUE,
  stripe_subscription_id VARCHAR,
  subscription_status   VARCHAR DEFAULT 'active',
  trial_ends_at         TIMESTAMPTZ,
  features              JSONB DEFAULT '[]',  -- plan-unlocked features

  -- Metadata
  public_metadata  JSONB DEFAULT '{}',
  private_metadata JSONB DEFAULT '{}',

  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);
```

### memberships
```sql
CREATE TABLE memberships (
  id        VARCHAR PRIMARY KEY,
  user_id   VARCHAR REFERENCES users(id) ON DELETE CASCADE,
  org_id    VARCHAR REFERENCES organizations(id) ON DELETE CASCADE,
  role      VARCHAR NOT NULL DEFAULT 'org:member',

  invited_by  VARCHAR REFERENCES users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, org_id)
);

CREATE INDEX idx_memberships_org_id ON memberships(org_id);
CREATE INDEX idx_memberships_user_id ON memberships(user_id);
```

### roles
```sql
CREATE TABLE roles (
  id          VARCHAR PRIMARY KEY,
  org_id      VARCHAR REFERENCES organizations(id) ON DELETE CASCADE,
  key         VARCHAR NOT NULL,   -- "org:admin" | "org:editor" | custom
  name        VARCHAR NOT NULL,
  description TEXT,
  is_default  BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(org_id, key)
);
```

### permissions
```sql
CREATE TABLE permissions (
  id          VARCHAR PRIMARY KEY,
  key         VARCHAR NOT NULL,   -- "org:documents:delete"
  name        VARCHAR NOT NULL,
  description TEXT,
  category    VARCHAR,            -- "documents" | "billing" | "members"
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE role_permissions (
  role_id       VARCHAR REFERENCES roles(id) ON DELETE CASCADE,
  permission_id VARCHAR REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);
```

### external_accounts (OAuth)
```sql
CREATE TABLE external_accounts (
  id              VARCHAR PRIMARY KEY,
  user_id         VARCHAR REFERENCES users(id) ON DELETE CASCADE,
  provider        VARCHAR NOT NULL,     -- "google" | "github" | "microsoft"
  provider_user_id VARCHAR NOT NULL,
  email           VARCHAR,
  access_token    TEXT,                 -- encrypted at rest
  refresh_token   TEXT,                 -- encrypted at rest
  token_expires_at TIMESTAMPTZ,
  raw_profile     JSONB,               -- full provider response
  created_at      TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(provider, provider_user_id)
);
```

### invitations
```sql
CREATE TABLE invitations (
  id          VARCHAR PRIMARY KEY,
  org_id      VARCHAR REFERENCES organizations(id) ON DELETE CASCADE,
  email       VARCHAR NOT NULL,
  role        VARCHAR NOT NULL DEFAULT 'org:member',
  token_hash  VARCHAR NOT NULL,         -- SHA-256 of invite token
  invited_by  VARCHAR REFERENCES users(id),
  status      VARCHAR DEFAULT 'pending', -- pending | accepted | revoked | expired
  expires_at  TIMESTAMPTZ NOT NULL,
  accepted_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(org_id, email)
);
```

### api_keys
```sql
CREATE TABLE api_keys (
  id          VARCHAR PRIMARY KEY,  -- key_xxxxx
  name        VARCHAR NOT NULL,
  key_prefix  VARCHAR NOT NULL,     -- first 12 chars for display
  key_hash    VARCHAR NOT NULL,     -- bcrypt hash

  owner_type  VARCHAR NOT NULL,     -- "user" | "organization"
  owner_id    VARCHAR NOT NULL,

  scopes      JSONB DEFAULT '[]',   -- ["users:read", "orgs:write"]

  last_used_at  TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ,
  revoked_at    TIMESTAMPTZ,
  revoked_by    VARCHAR,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  created_by    VARCHAR REFERENCES users(id)
);

CREATE INDEX idx_api_keys_owner ON api_keys(owner_type, owner_id);
```

### plans
```sql
CREATE TABLE plans (
  id          VARCHAR PRIMARY KEY,  -- "free" | "pro" | "enterprise"
  name        VARCHAR NOT NULL,
  stripe_price_id VARCHAR,

  -- Limits
  max_mau           INTEGER,
  max_org_members   INTEGER,
  max_api_keys      INTEGER,
  max_orgs          INTEGER,

  -- Feature flags
  features          JSONB DEFAULT '[]',
  role_set          JSONB DEFAULT '[]',  -- available role keys

  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### audit_logs
```sql
CREATE TABLE audit_logs (
  id          VARCHAR PRIMARY KEY,
  actor_type  VARCHAR NOT NULL,   -- "user" | "api_key" | "system"
  actor_id    VARCHAR NOT NULL,

  action      VARCHAR NOT NULL,   -- "session.created"
  target_type VARCHAR,
  target_id   VARCHAR,

  org_id      VARCHAR,
  metadata    JSONB DEFAULT '{}',

  ip_address  INET,
  user_agent  TEXT,
  country_code CHAR(2),

  created_at  TIMESTAMPTZ DEFAULT NOW()  -- never updated, append-only
) PARTITION BY RANGE (created_at);       -- partition by month for scale

CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_id, created_at DESC);
CREATE INDEX idx_audit_logs_org ON audit_logs(org_id, created_at DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs(action, created_at DESC);
```

### sso_connections
```sql
CREATE TABLE sso_connections (
  id          VARCHAR PRIMARY KEY,
  org_id      VARCHAR REFERENCES organizations(id) ON DELETE CASCADE,
  name        VARCHAR NOT NULL,
  protocol    VARCHAR NOT NULL,   -- "saml" | "oidc"

  -- SAML config
  idp_entity_id     VARCHAR,
  idp_sso_url       VARCHAR,
  idp_certificate   TEXT,        -- encrypted

  -- OIDC config
  discovery_url     VARCHAR,
  client_id         VARCHAR,
  client_secret     TEXT,        -- encrypted

  -- Domain enforcement
  domains           JSONB DEFAULT '[]',  -- ["acme.com"]
  active            BOOLEAN DEFAULT TRUE,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
```

### webhooks
```sql
CREATE TABLE webhooks (
  id              VARCHAR PRIMARY KEY,
  org_id          VARCHAR REFERENCES organizations(id),
  endpoint_url    VARCHAR NOT NULL,
  signing_secret  VARCHAR NOT NULL,   -- for HMAC verification
  events          JSONB DEFAULT '[]', -- subscribed events
  enabled         BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE webhook_deliveries (
  id            VARCHAR PRIMARY KEY,
  webhook_id    VARCHAR REFERENCES webhooks(id) ON DELETE CASCADE,
  event_type    VARCHAR NOT NULL,
  payload       JSONB NOT NULL,
  response_code INTEGER,
  response_body TEXT,
  attempt       INTEGER DEFAULT 1,
  next_retry_at TIMESTAMPTZ,
  delivered_at  TIMESTAMPTZ,
  status        VARCHAR DEFAULT 'pending',  -- pending | delivered | failed
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Indexing Strategy

Critical indexes for auth hot paths:
```sql
-- Session lookup (every authenticated request)
CREATE UNIQUE INDEX idx_sessions_refresh_token ON sessions(refresh_token_hash)
  WHERE status = 'active';

-- API key lookup (every API request)
CREATE INDEX idx_api_keys_prefix ON api_keys(key_prefix)
  WHERE revoked_at IS NULL;

-- User lookup by email (sign-in)
CREATE UNIQUE INDEX idx_users_email ON users(LOWER(primary_email));

-- Active org membership (permission check)
CREATE INDEX idx_memberships_active ON memberships(user_id, org_id);
```

---

## Encryption

Fields encrypted at rest (use AES-256-GCM with per-field keys):
- `users.totp_secret`
- `external_accounts.access_token`
- `external_accounts.refresh_token`
- `sso_connections.idp_certificate`
- `sso_connections.client_secret`
- `api_keys.key_hash` (bcrypt, not AES)
