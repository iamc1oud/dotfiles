---
name: fastapi-best-practices
version: 1.0.0
description: |
  Apply Python FastAPI and backend development best practices. Use when writing,
  reviewing, or designing FastAPI routes, services, models, database access,
  authentication, async patterns, or project structure. Trigger phrases include:
  "FastAPI", "API endpoint", "route", "SQLAlchemy", "Alembic", "Pydantic",
  "dependency injection", "async", "JWT", "backend service", "repository pattern",
  "database model", "migration", "middleware", "Dapr", "service mesh".
license: MIT
compatibility: claude-code
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# FastAPI & Python Backend Best Practices

You are an expert Python backend engineer. Apply all guidance below when writing,
reviewing, or designing any FastAPI service, database layer, or related backend code.

---

## Project Structure

Follow a domain-driven layout. Each service is self-contained:

```
services/crm/
├── app/
│   ├── main.py              # FastAPI app factory, lifespan, middleware
│   ├── config.py            # Pydantic Settings
│   ├── database.py          # Engine, session factory, Base
│   ├── dependencies.py      # Shared FastAPI Depends (db, current_user, etc.)
│   ├── models/              # SQLAlchemy ORM models (one file per domain)
│   ├── schemas/             # Pydantic request/response schemas
│   ├── routers/             # APIRouter files, one per resource
│   ├── services/            # Business logic, pure Python, no HTTP concerns
│   ├── repositories/        # DB access layer (one per model/aggregate)
│   └── middleware/          # Custom Starlette middleware
├── tests/
│   ├── conftest.py
│   ├── unit/
│   └── integration/
├── alembic/
│   └── versions/
├── alembic.ini
└── pyproject.toml
```

Never put business logic in routers. Never put DB queries in routers.
Routers → Services → Repositories → Database.

---

## App Factory & Lifespan

```python
# app/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.database import engine
from app.routers import contacts, users

@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    yield
    # shutdown
    await engine.dispose()

def create_app() -> FastAPI:
    app = FastAPI(title="CRM Service", lifespan=lifespan)
    app.include_router(contacts.router, prefix="/api/v1/contacts", tags=["contacts"])
    app.include_router(users.router, prefix="/api/v1/users", tags=["users"])
    return app

app = create_app()
```

Use `lifespan` (not deprecated `on_event`). Register all routers in the factory,
not at module level.

---

## Configuration

```python
# app/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    database_url: str
    secret_key: str
    access_token_expire_minutes: int = 30
    environment: str = "development"

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

from functools import lru_cache

@lru_cache
def get_settings() -> Settings:
    return Settings()
```

- Never hardcode secrets. Always read from env / `.env`.
- Use `lru_cache` so `Settings()` is constructed once per process.
- Use `pydantic-settings` (v2), not `pydantic.BaseSettings`.

---

## Database & Sessions

```python
# app/database.py
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings

engine = create_async_engine(
    get_settings().database_url,
    pool_size=10,
    max_overflow=20,
    echo=get_settings().environment == "development",
)

AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

class Base(DeclarativeBase):
    pass
```

- Always use **async** engine (`asyncpg` driver: `postgresql+asyncpg://...`).
- `expire_on_commit=False` prevents lazy-load errors after commit.
- Never call `Base.metadata.create_all()` in production — use Alembic migrations.

---

## Dependency Injection

```python
# app/dependencies.py
from typing import AsyncGenerator
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import AsyncSessionLocal
from app.config import Settings, get_settings

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token")

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(get_settings),
):
    # decode JWT, load user, raise 401 on failure
    ...
```

- DB sessions are always yielded from an `async with` block — this guarantees close.
- Chain dependencies via `Depends()`; never instantiate them manually in routes.
- One session per request; never share sessions across requests.

---

## Models (SQLAlchemy)

```python
# app/models/contact.py
from datetime import datetime
from sqlalchemy import String, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Contact(Base):
    __tablename__ = "contacts"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)

    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(), onupdate=func.now()
    )

    owner: Mapped["User"] = relationship(back_populates="contacts")
```

- Use `Mapped` + `mapped_column` (SQLAlchemy 2.x style). Never use old `Column()`.
- Add `index=True` on every foreign key and any field used in WHERE clauses.
- Always add `created_at` / `updated_at` with `server_default`.
- `nullable=False` for required fields; don't rely on Python-side validation alone.

---

## Schemas (Pydantic)

```python
# app/schemas/contact.py
from datetime import datetime
from pydantic import BaseModel, EmailStr, ConfigDict

class ContactBase(BaseModel):
    name: str
    email: EmailStr

class ContactCreate(ContactBase):
    pass

class ContactUpdate(BaseModel):
    name: str | None = None
    email: EmailStr | None = None

class ContactResponse(ContactBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    owner_id: int
    created_at: datetime
```

- Separate `Create`, `Update`, and `Response` schemas — never reuse one schema for all.
- `Update` schemas use `Optional` fields (partial updates).
- `Response` schemas use `model_config = ConfigDict(from_attributes=True)` for ORM compat.
- Never expose internal fields (passwords, internal IDs) in response schemas.

---

## Repository Pattern

```python
# app/repositories/contact.py
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.contact import Contact
from app.schemas.contact import ContactCreate, ContactUpdate

class ContactRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get(self, contact_id: int) -> Contact | None:
        result = await self.db.execute(select(Contact).where(Contact.id == contact_id))
        return result.scalar_one_or_none()

    async def list(self, owner_id: int, skip: int = 0, limit: int = 100) -> list[Contact]:
        result = await self.db.execute(
            select(Contact)
            .where(Contact.owner_id == owner_id)
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def create(self, data: ContactCreate, owner_id: int) -> Contact:
        contact = Contact(**data.model_dump(), owner_id=owner_id)
        self.db.add(contact)
        await self.db.commit()
        await self.db.refresh(contact)
        return contact

    async def update(self, contact: Contact, data: ContactUpdate) -> Contact:
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(contact, field, value)
        await self.db.commit()
        await self.db.refresh(contact)
        return contact

    async def delete(self, contact: Contact) -> None:
        await self.db.delete(contact)
        await self.db.commit()
```

- Repositories receive an injected `AsyncSession`; never call `AsyncSessionLocal()` inside.
- Use `model_dump(exclude_unset=True)` for partial updates.
- Always `refresh()` after commit when the caller needs the updated state.

---

## Service Layer

```python
# app/services/contact.py
from fastapi import HTTPException, status
from app.repositories.contact import ContactRepository
from app.schemas.contact import ContactCreate, ContactUpdate
from app.models.contact import Contact

class ContactService:
    def __init__(self, repo: ContactRepository):
        self.repo = repo

    async def get_or_404(self, contact_id: int, owner_id: int) -> Contact:
        contact = await self.repo.get(contact_id)
        if not contact or contact.owner_id != owner_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Contact not found")
        return contact

    async def create(self, data: ContactCreate, owner_id: int) -> Contact:
        return await self.repo.create(data, owner_id)

    async def update(self, contact_id: int, data: ContactUpdate, owner_id: int) -> Contact:
        contact = await self.get_or_404(contact_id, owner_id)
        return await self.repo.update(contact, data)

    async def delete(self, contact_id: int, owner_id: int) -> None:
        contact = await self.get_or_404(contact_id, owner_id)
        await self.repo.delete(contact)
```

- Services raise `HTTPException` (they are app-layer, not DB-layer).
- Services own authorization logic (e.g., owner check).
- Services never import from `routers/`.

---

## Routers

```python
# app/routers/contacts.py
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, get_current_user
from app.models.user import User
from app.repositories.contact import ContactRepository
from app.schemas.contact import ContactCreate, ContactUpdate, ContactResponse
from app.services.contact import ContactService

router = APIRouter()

def get_contact_service(db: AsyncSession = Depends(get_db)) -> ContactService:
    return ContactService(ContactRepository(db))

@router.get("/", response_model=list[ContactResponse])
async def list_contacts(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_user),
    service: ContactService = Depends(get_contact_service),
):
    return await service.repo.list(owner_id=current_user.id, skip=skip, limit=limit)

@router.post("/", response_model=ContactResponse, status_code=status.HTTP_201_CREATED)
async def create_contact(
    data: ContactCreate,
    current_user: User = Depends(get_current_user),
    service: ContactService = Depends(get_contact_service),
):
    return await service.create(data, owner_id=current_user.id)

@router.patch("/{contact_id}", response_model=ContactResponse)
async def update_contact(
    contact_id: int,
    data: ContactUpdate,
    current_user: User = Depends(get_current_user),
    service: ContactService = Depends(get_contact_service),
):
    return await service.update(contact_id, data, owner_id=current_user.id)

@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_contact(
    contact_id: int,
    current_user: User = Depends(get_current_user),
    service: ContactService = Depends(get_contact_service),
):
    await service.delete(contact_id, owner_id=current_user.id)
```

- Routers are thin: validate input, call service, return response schema.
- Use `status.HTTP_*` constants, never magic numbers.
- `DELETE` returns 204 No Content, no body.
- Use `PATCH` for partial updates, `PUT` only for full replacements.

---

## Authentication (JWT)

```python
# app/auth.py
from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import HTTPException, status

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_access_token(subject: str, settings) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    return jwt.encode({"sub": subject, "exp": expire}, settings.secret_key, algorithm="HS256")

def decode_access_token(token: str, settings) -> str:
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=["HS256"])
        sub = payload.get("sub")
        if sub is None:
            raise ValueError
        return sub
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
```

- Use `python-jose[cryptography]` for JWT, `passlib[bcrypt]` for passwords.
- Always use `timezone.utc` for expiry — never naive datetimes.
- Store only the user identifier (sub) in the token; load the full user from DB.
- Never log tokens or passwords, even at DEBUG level.

---

## Error Handling

```python
# app/main.py (add to create_app)
from fastapi import Request
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError

@app.exception_handler(IntegrityError)
async def integrity_error_handler(request: Request, exc: IntegrityError):
    return JSONResponse(
        status_code=409,
        content={"detail": "Resource already exists or constraint violated"},
    )
```

- Register global exception handlers for DB-level errors so they surface as clean HTTP responses.
- Never let SQLAlchemy exceptions propagate to the client.
- Use 422 for validation errors (FastAPI does this automatically via Pydantic).
- Use 404 for missing resources, 409 for conflicts, 403 for authorization failures.

---

## Migrations (Alembic)

```ini
# alembic.ini
sqlalchemy.url = %(DATABASE_URL)s
```

```python
# alembic/env.py — key parts
from app.database import Base
from app.models import contact, user  # import all models so Alembic sees them

target_metadata = Base.metadata
```

Rules:
- Import **all** models in `env.py` — Alembic only detects tables it can see.
- Never use `autogenerate` alone in production: always review the generated migration.
- One migration per logical change; never squash in-production migrations.
- Test migrations both forward and backward (`alembic downgrade -1`).
- Set `compare_type=True` in `context.configure()` to detect column type changes.

---

## Async Patterns

```python
# Correct: awaitable DB calls
contacts = await repo.list(owner_id=user.id)

# Correct: run blocking I/O in executor
import asyncio
result = await asyncio.get_event_loop().run_in_executor(None, blocking_function, arg)

# Wrong: never call sync SQLAlchemy in an async route
# session.execute(...)  ← blocks the event loop
```

- Every route, service, and repository method that touches the DB must be `async def`.
- Never mix sync and async SQLAlchemy sessions.
- Use `asyncio.gather()` for truly independent concurrent operations.
- Background tasks that need DB access should get their own session (not share the request session).

---

## Background Tasks

```python
from fastapi import BackgroundTasks

@router.post("/contacts/", ...)
async def create_contact(
    data: ContactCreate,
    background_tasks: BackgroundTasks,
    ...
):
    contact = await service.create(data, owner_id=current_user.id)
    background_tasks.add_task(send_welcome_email, contact.email)
    return contact
```

- Use `BackgroundTasks` for fire-and-forget work that doesn't need the response.
- For reliable async jobs (retries, persistence), use a task queue (Dapr pub/sub or Celery).
- Background tasks share the process but not the request DB session — open a new session inside.

---

## Middleware

```python
# app/middleware/request_id.py
import uuid
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response
```

Add to app:
```python
app.add_middleware(RequestIDMiddleware)
app.add_middleware(CORSMiddleware, allow_origins=["*"])  # tighten in production
```

- Middleware order matters: added last, runs first.
- CORS middleware must be added before any auth middleware.
- Always propagate request IDs through logs for traceability.

---

## Logging

```python
# app/logging_config.py
import logging
import sys

def configure_logging(level: str = "INFO") -> None:
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
        stream=sys.stdout,
    )

# In routes/services: use module-level logger
import logging
logger = logging.getLogger(__name__)

logger.info("contact_created contact_id=%s owner_id=%s", contact.id, owner_id)
```

- Log in key=value or JSON format so logs are parseable by log aggregators.
- Log at `INFO` for normal operations, `WARNING` for recoverable issues, `ERROR` for failures.
- Never log PII (emails, passwords, tokens) at any level.
- Include request ID and user ID in log context when available.

---

## Testing

```python
# tests/conftest.py
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.main import app
from app.dependencies import get_db
from app.database import Base

TEST_DATABASE_URL = "postgresql+asyncpg://test:test@localhost/test_db"

@pytest.fixture(scope="session")
async def engine():
    eng = create_async_engine(TEST_DATABASE_URL)
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield eng
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await eng.dispose()

@pytest.fixture
async def db(engine) -> AsyncSession:
    async_session = async_sessionmaker(engine, expire_on_commit=False)
    async with async_session() as session:
        yield session
        await session.rollback()

@pytest.fixture
async def client(db: AsyncSession) -> AsyncClient:
    app.dependency_overrides[get_db] = lambda: db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
```

- Use `httpx.AsyncClient` with `ASGITransport` for integration tests (no running server needed).
- Override `get_db` with a real test DB session that rolls back after each test.
- Never mock the database — use a real test DB.
- Test at the router level (integration tests) for happy paths; test services in isolation for edge cases.
- Use `pytest-anyio` or `pytest-asyncio` with `asyncio_mode = "auto"`.

---

## Dapr Integration (Service Mesh / Pub-Sub)

```python
# Invoking another service via Dapr sidecar
import httpx

DAPR_HTTP_PORT = 3500

async def invoke_service(app_id: str, method: str, data: dict) -> dict:
    url = f"http://localhost:{DAPR_HTTP_PORT}/v1.0/invoke/{app_id}/method/{method}"
    async with httpx.AsyncClient() as client:
        response = await client.post(url, json=data)
        response.raise_for_status()
        return response.json()

# Publishing an event
async def publish_event(pubsub_name: str, topic: str, data: dict) -> None:
    url = f"http://localhost:{DAPR_HTTP_PORT}/v1.0/publish/{pubsub_name}/{topic}"
    async with httpx.AsyncClient() as client:
        response = await client.post(url, json=data)
        response.raise_for_status()
```

```python
# Subscribing to a topic (Dapr calls this endpoint)
@router.post("/dapr/subscribe/{topic}")
async def handle_event(topic: str, request: Request):
    event = await request.json()
    # process event
    return {"status": "SUCCESS"}
```

- Never call other services directly by URL in a Dapr setup — always go through the sidecar.
- Use `cloudevents` envelope format for pub/sub messages.
- Return `{"status": "SUCCESS"}` from subscription handlers; `"RETRY"` or `"DROP"` on failure.

---

## Security Checklist

- [ ] Passwords hashed with bcrypt (cost factor >= 12)
- [ ] JWT tokens expire (short-lived access + refresh token pattern)
- [ ] All user input validated via Pydantic before use
- [ ] SQL built with SQLAlchemy expressions only — no f-string SQL
- [ ] CORS origins explicitly whitelisted in production
- [ ] Rate limiting on auth endpoints (use slowapi or nginx upstream)
- [ ] Sensitive config (secrets, DB URLs) in env vars, not committed
- [ ] `DEBUG=False` and `echo=False` in production
- [ ] HTTP headers: set `X-Content-Type-Options`, `X-Frame-Options` via middleware
- [ ] File uploads: validate MIME type and size, never execute uploaded content

---

## Performance Checklist

- [ ] DB queries use indexes on filtered/sorted columns
- [ ] Paginate all list endpoints (never return unbounded lists)
- [ ] Use `select()` with explicit columns for large tables (avoid `SELECT *`)
- [ ] Use `selectinload()` or `joinedload()` to avoid N+1 queries on relationships
- [ ] Connection pool sized to expected concurrency (`pool_size + max_overflow`)
- [ ] Long-running tasks offloaded to background workers, not request handlers
- [ ] Responses compressed with `GZipMiddleware` for payloads > 1KB

---

## Common Anti-Patterns to Avoid

| Anti-pattern | Correct approach |
|---|---|
| Business logic in routers | Move to service layer |
| DB queries in routers | Move to repository layer |
| Sync ORM in async routes | Use async SQLAlchemy |
| `Base.metadata.create_all()` in app startup | Use Alembic migrations |
| Reusing one Pydantic schema for create+response | Separate Create/Response schemas |
| `select(Model)` without pagination | Add `.offset()` + `.limit()` |
| Catching bare `Exception` | Catch specific exceptions |
| Hardcoded secrets in config | Use env vars + pydantic-settings |
| Sharing DB session across requests | One session per request via Depends |
| N+1 queries in loops | Use `selectinload` / batch queries |
