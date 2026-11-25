# Spec: Email/Password Login

Ported from PostHog's implementation (`posthog/api/authentication.py`,
`posthog/models/user.py`, `posthog/models/organization.py`). Scope: session-based
email/password authentication only, plus the minimum org-membership shape needed
because this platform is multi-tenant (see [architecture.md](architecture.md)'s
tenant-scoping pattern). Signup, password reset, 2FA, social auth, SSO domain
enforcement, and WebAuthn/passkeys are explicitly out of scope — called out at the
end as extension points, not requirements.

## 1. Data model

### User

| Field | Type | Notes |
|---|---|---|
| `email` | unique, indexed | `USERNAME_FIELD` — login identifier, not `username` |
| `password` | Django's standard hashed password field (from `AbstractUser`) | never store/compare plaintext |
| `is_active` | bool, default `True` | account-level kill switch; inactive users fail login |
| `is_email_verified` | bool, default `False` (or nullable if you need a "legacy/unset" state) | gates login if you require verified email |
| `last_login` | timestamp, nullable | stdlib Django field, auto-updated by `login()` |

Decision to make: PostHog's `is_email_verified` is a nullable tri-state (`None` =
legacy user, grandfathered in). Unless migrating existing unverified users, a plain
`bool` defaulting `False` is simpler — pick that unless you have a reason not to.

### Organization membership

Required because org/tenant scoping already exists on this platform (see
`backend/core/scoping/` in the project scaffold). Model shape:

```python
class OrganizationMembership(models.Model):
    class Level(models.IntegerChoices):
        MEMBER = 1, "member"
        ADMIN = 8, "administrator"
        OWNER = 15, "owner"

    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="organization_memberships")
    level = models.PositiveSmallIntegerField(default=Level.MEMBER, choices=Level.choices)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["organization", "user"], name="unique_org_membership")]
```

`level` is the access-scope hook: it's a role field on the membership row, not on the
user — a user can hold different levels in different orgs. This spec only requires the
field to exist and be populated at membership-creation time (out of scope here); login
itself doesn't write to it.

### Active org/tenant selection

`User.current_organization` (nullable FK) tracks which org a multi-org user is
currently "in." Resolve it **lazily, on read, not during login**:

```python
@property
def organization(self) -> Organization | None:
    if self.current_organization_id is None:
        first_membership = self.organization_memberships.first()
        if first_membership is None:
            return None
        self.current_organization = first_membership.organization
        self.save(update_fields=["current_organization"])
    return self.current_organization
```

Login does not need to know about orgs at all — it authenticates a `User`. The very
next request that needs tenant context resolves `request.user.organization` via this
property (or your `tenant_scope(...)` context manager reads `request.user.organization_id`
directly at the same point `TenantScopedViewSetMixin.initial()` enters scope).

## 2. Auth configuration

```python
AUTH_USER_MODEL = "yourapp.User"

AUTHENTICATION_BACKENDS = [
    "django.contrib.auth.backends.ModelBackend",
]

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 8}},
]
```

- `USERNAME_FIELD = "email"` on the `User` model is what makes stock `ModelBackend`
  accept `authenticate(request, email=..., password=...)` — `ModelBackend` falls back
  to `kwargs.get(UserModel.USERNAME_FIELD)` when no `username=` kwarg is passed. No
  custom backend is required for plain email/password.
- `PASSWORD_HASHERS`: don't override — Django's default hasher chain (Argon2 if
  installed, else PBKDF2) is correct out of the box. Only override in `TEST` settings
  to a faster hasher (`MD5PasswordHasher`) if test suite login-heavy tests are slow.
- Password strength: `MinimumLengthValidator` is the floor. PostHog additionally
  scores with zxcvbn (rejects below strength 3/4) — worth adding once this is beyond a
  throwaway prototype, not required for a first pass.

## 3. API surface

### `POST /api/login/`

Request:
```json
{ "email": "user@example.com", "password": "..." }
```

Success — `200`:
```json
{ "success": true }
```

Failure — `400`:
```json
{ "type": "validation_error", "code": "invalid_credentials", "detail": "Invalid email or password." }
```

Failure — `403` (lockout, see §4):
```json
{ "type": "authentication_error", "code": "too_many_failed_attempts", "detail": "..." }
```

Use one generic message (`"Invalid email or password."`) for both "no such user" and
"wrong password" — never reveal which, to avoid user enumeration.

### Serializer logic, in order

1. Check rate-limit/lockout state for this identifier before attempting auth (§4).
2. Call `authenticate(request, email=<email>, password=<password>)`.
3. If `None` returned: record the failed attempt, re-check lockout (a failure may
   itself trigger a lockout), raise `invalid_credentials`.
4. If `is_active` is `False`: `ModelBackend` already filters this out (returns `None`
   from step 2) — no separate check needed.
5. If enforcing email verification: check `user.is_email_verified`, raise a distinct
   `not_verified` error if false (distinct from `invalid_credentials` is fine here —
   it's not a credential-guessing vector).
6. `login(request, user)` — creates the session, rotates the session key (Django does
   this automatically to prevent session fixation).
7. Record the successful attempt against the rate-limiter.
8. Return `{"success": true}`.

## 4. Rate limiting / lockout

Minimum viable version of PostHog's `django-axes` setup:

- Track failed attempts per `(IP, email)` pair (or per-email alone, if you want lockout
  to survive IP rotation — PostHog uses `AxesStandaloneBackend`, which is more
  IP-and-username-aware; a simple cache-backed counter keyed by email is enough to
  start).
- `FAILURE_LIMIT` (e.g. 5-10 for a first pass — PostHog uses 30, tuned for its own
  false-positive tolerance) attempts within a rolling window before lockout.
- `COOLOFF_TIME` (e.g. 10-15 minutes) before the counter resets.
- Lockout response: `403`, not `429` — matches PostHog's convention and avoids leaking
  "this is rate-limited" vs "this account doesn't exist" distinctions through status
  code alone.
- Check lockout **before** calling `authenticate()` (cheap short-circuit) **and**
  again immediately after a failed attempt (the failure itself may cross the
  threshold) — both checks needed, not just one.

## 5. CSRF

If the login form is served by the same Django app rendering HTML (not a fully
decoupled SPA on another origin): the page that renders the login form must set the
CSRF cookie (`@ensure_csrf_cookie` on that view) before the login `POST` fires, and the
`POST` itself must NOT be CSRF-exempt — session-based login is exactly the case CSRF
protection exists for.

If the frontend is a separate origin using only the API (no Django-rendered login
page): either serve a `GET /api/csrf/` endpoint that sets the cookie and returns the
token for the SPA to echo back in a header, or switch to a token-based scheme
(short-lived JWT/session token returned in the login response body instead of a
cookie) — CSRF only matters for cookie-based auth in the first place.

## 6. Post-login: org/tenant context

No middleware sets `current_organization` during login. On the next request that needs
tenant context:

1. A view/viewset mixin reads `request.user.organization` (the lazy property from §1).
2. That resolves (or falls back to) an org id, which becomes the `tenant_id` passed
   into `tenant_scope(tenant_id)` before the fail-closed `TenantScopedManager` is
   touched — same integration point `TenantScopedViewSetMixin.initial()` already uses
   in the scaffold.
3. Separately, verify (don't just trust) that the resolved org is still valid for this
   user on every request — e.g. reject if the org is soft-deleted or the membership
   row was removed since the session was created. A single membership existence check
   per request is enough; don't over-build this into a full audit trail.

## 7. Non-functional requirements

- Passwords are never logged, never included in error messages, never round-tripped
  in any API response.
- `authenticate()`/`check_password()` are constant-time-safe already (Django handles
  this) — don't hand-roll password comparison.
- Log login success and login failure as distinct events (email, timestamp, IP,
  success/failure/lockout reason) for audit purposes — but as a fire-and-forget
  side effect after the response is prepared, not inside the same transaction as the
  auth check.
- Session cookie: `HttpOnly`, `Secure` in production, `SameSite=Lax` at minimum
  (`Strict` if the login form and API share an origin and there's no cross-site
  redirect flow to support).

## 8. Explicitly out of scope (extension points, not requirements)

- **Signup / account creation** — a separate flow; this spec assumes a `User` row
  with a hashed password already exists.
- **Password reset** — separate token-based flow (email a signed, short-lived link).
- **2FA (TOTP/passkeys)** — PostHog gates login behind a second factor when enabled;
  add as a second step after `authenticate()` succeeds, before `login()` is called,
  once needed.
- **Social auth / SSO** — separate backends in `AUTHENTICATION_BACKENDS`; the
  email/password path is independent of these and doesn't need to know they exist.
- **Email verification enforcement** — the `is_email_verified` check in §3 step 5 is
  optional; only enforce it if you're actually sending verification emails.

## 9. Acceptance checklist

- [ ] Wrong password and nonexistent email return the identical error message/code.
- [ ] Inactive user (`is_active=False`) cannot log in, same generic error.
- [ ] N consecutive failures from one email lock out further attempts for the
      cooloff window, returning `403` with a distinct code from `invalid_credentials`.
- [ ] Successful login rotates the session key (verify via Django's session
      cycling — no custom code needed, just confirm it isn't accidentally disabled).
- [ ] `POST /api/login/` without a valid CSRF token/cookie is rejected (if
      cookie-based) or the token-issuance endpoint works (if SPA-token-based).
- [ ] A user with no organization membership logs in successfully; org resolution
      failure surfaces later, at the tenant-scoped endpoint, not at login.
- [ ] A user with memberships in 2+ orgs logs in once and `current_organization`
      resolves to *some* valid org on the first subsequent tenant-scoped request.
