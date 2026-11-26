# GatherSeat â€” Infrastructure Guide

**Infrastructure branch:** `haroon/rabbitmq-sql`
**Owner:** Haroon
**Last verified:** 26 November 2026

## 1. Architecture

```text
Java web app (Abuzar) â†’ RabbitMQ â†’ Erlang worker (Mohammad) â†’ MySQL (Haroon)
```

Java handles login, the customer/manager interface, availability and booking requests. RabbitMQ routes restaurant commands; Erlang processes them through MySQL procedures and returns results. Haroon maintains the database, messaging topology and Docker configuration. End-to-end integration is ongoing.

## 2. Infrastructure files

```text
compose.yaml
.env.example
requirements.txt
db/
  gatherseat_schema.sql
  booking_commands.sql
  sample_data.sql
messaging/
  contract.json
  setup_rabbitmq.py
tests/
  test_concurrent_booking.py
  test_rabbitmq_routing.py
documentation/
  INFRASTRUCTURE.md
```

Everyone is already working in the GatherSeat project. Run commands from the existing project root. **Docker Desktop with Docker Compose is required; standalone MySQL Server and RabbitMQ Server are not.** Python 3 is used for the supplied RabbitMQ setup and tests. Continue using the existing Java and Erlang toolchains.

## 3. Passwords and Docker

If `.env` does not already exist, copy `.env.example` and enter local passwords. **Do not overwrite a working `.env` or commit passwords.**

**Windows PowerShell:**

```powershell
if (!(Test-Path .env)) { Copy-Item .env.example .env }
notepad .env
```

**macOS Terminal (Abuzar):**

```bash
[ -f .env ] || cp .env.example .env
open -e .env
```

Required settings:

```dotenv
GATHERSEAT_DB_PASSWORD=your_mysql_application_password
GATHERSEAT_DB_ROOT_PASSWORD=your_mysql_root_password
GATHERSEAT_AMQP_PASSWORD=your_rabbitmq_password
```

With Docker Desktop running, use this on either system **if the ports are available and this project is not already running**:

```bash
docker compose up -d
docker compose ps
```

MySQL is exposed on `3307`; RabbitMQ AMQP on `5672`; its management dashboard on `http://localhost:15672`. On a **fresh MySQL volume**, Compose runs the SQL schema, procedures and seed scripts automatically. It does not rerun these scripts for a populated volume. Changing passwords in `.env` does not reset existing container accounts.

**Do not run `docker compose down -v` on data you want to keep.** Haroon's currently running original containers were created separately from Compose; do not start a conflicting stack on their ports.

## 4. Connections

| Service | Application on Windows/macOS host | Application in same Compose network |
|---|---|---|
| MySQL | `127.0.0.1:3307` | `mysql:3306` |
| RabbitMQ | `127.0.0.1:5672` | `rabbitmq:5672` |
| RabbitMQ management | `http://localhost:15672` | `http://rabbitmq:15672` |

- MySQL database and application username: `gatherseat`; application password: `GATHERSEAT_DB_PASSWORD`.
- RabbitMQ username: use the value configured in `compose.yaml`; password: `GATHERSEAT_AMQP_PASSWORD`.
- Docker service names resolve only inside their Compose network.

## 5. RabbitMQ setup

Docker starts the broker, but the project-specific exchanges, queues and bindings are created with the setup script.

**Windows PowerShell:**

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python .\messaging\setup_rabbitmq.py
```

**macOS Terminal:**

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python messaging/setup_rabbitmq.py
```

Enter the RabbitMQ password when prompted, unless it is already set in the shell environment. The Python script does not automatically inherit `.env` variables merely because Docker Compose reads that file.

| Exchange | Queue | Routing key |
|---|---|---|
| `gatherseat.commands.v1` | `gatherseat.restaurant.1` (Pisa) | `restaurant.1` |
| `gatherseat.commands.v1` | `gatherseat.restaurant.2` (London) | `restaurant.2` |

Both command queues are durable. `gatherseat.commands.v1` and `gatherseat.events.v1` are durable topic exchanges. Publishing/consuming application events has not yet been integrated.

## 6. MySQL procedures

The database creates eight tables: `app_user`, `restaurant`, `dining_table`, `dining_slot`, `restaurant_slot`, `reservation`, `table_allocation` and `command_result`.

Fresh seed data contains three users, two restaurants (Pisa `1`, London `2`), three dining tables, two dining slots and three restaurant-slot associations.

```sql
CALL book_table(request_id, customer_id, restaurant_id, slot_id, guests);
CALL cancel_booking(reservation_id, customer_id);
```

Booking is transactional; a unique table/slot constraint prevents double allocation. Repeating an already successful booking with the same request ID and arguments returns its earlier result. Cancellation checks the customer's ownership and releases the allocation. During simultaneous booking, MySQL can return duplicate-key error `1062`; the worker must turn this into a user-facing conflict result. Cancellation request-ID deduplication is not yet implemented.

For a Compose-managed database:

```bash
docker compose exec mysql mysql -u gatherseat -p gatherseat
```

## 7. Abuzar â€” Java integration (macOS)

- Use Docker Desktop and macOS instructions above; no separate MySQL/RabbitMQ server installation is needed.
- For a locally running Java app, use JDBC URL `jdbc:mysql://127.0.0.1:3307/gatherseat` with user `gatherseat` and the configured password.
- Read restaurants, availability and My Bookings with parameterized queries. Use the logged-in customer's **server-side session** for identity and ownership checks.
- Publish booking/cancel commands to `gatherseat.commands.v1` with routing key `restaurant.<restaurant_id>`; coordinate `reply_to`, correlation IDs and responses with Mohammad.
- Booking/cancel writes should flow through Erlang rather than Java independently calling the same procedures.
- Coordinate the login data model: the current `app_user` schema is not a complete password-authentication implementation.

## 8. Mohammad â€” Erlang integration

- Connect to RabbitMQ at `127.0.0.1:5672` on the host or `rabbitmq:5672` from the Compose network.
- Consume from `gatherseat.restaurant.<restaurant_id>` and follow the proposed `messaging/contract.json` after agreement with Abuzar.
- Connect to MySQL at `127.0.0.1:3307` on the host or `mysql:3306` in Compose. Call `book_table` / `cancel_booking` with the authenticated customer ID.
- Return the matching request ID and agreed correlation metadata; convert conflicts (including MySQL `1062`) to explicit rejection responses.
- Implement reliable acknowledgments, redelivery and crash-after-commit retry handling. The cancellation message contract and request/reply details still need team agreement.

## 9. Testing

**Docker status (Compose-managed services):**

```bash
docker compose ps
docker compose logs --tail 60 mysql
docker compose logs --tail 60 rabbitmq
```

**RabbitMQ topology:**

```bash
docker compose exec rabbitmq rabbitmqctl list_exchanges name type durable
docker compose exec rabbitmq rabbitmqctl list_queues name durable messages consumers
```

**Local Python tests:**

```bash
python tests/test_rabbitmq_routing.py
python tests/test_concurrent_booking.py
```

On macOS, use `python3` if `python` is unavailable. The routing test publishes and consumes messages; run it without active application consumers or pending commands. The concurrency test writes real reservations and requires a prepared, unallocated test slot. **The current test script is not fully self-contained for a fresh database; prepare its test data before running it.** Neither test should be used against data that must remain unchanged.

## 10. Verified status â€” 26 November 2026

- Original local MySQL: schema, booking, cancellation, ownership, successful-booking idempotency, availability rejection and concurrent allocation protection tested.
- Original RabbitMQ: exchanges, queues and Pisa/London routing tested.
- **Fresh isolated Docker Compose deployment:** MySQL and RabbitMQ became healthy; MySQL created all eight tables, both procedures and the expected sample data automatically.
- Fresh database booking succeeded; repeating the identical request returned the same reservation, leaving one reservation and one table allocation.
- Temporary verification containers, volumes and network were removed afterward. Original MySQL and RabbitMQ containers remained running.

**Still pending:** separate fresh-instance RabbitMQ routing verification and complete Java â†’ RabbitMQ â†’ Erlang â†’ MySQL â†’ Java testing, including worker failure/retry handling. This is the verified infrastructure baseline for integration, not a fully finished application.

## 11. Common issues

| Issue | Resolution |
|---|---|
| Docker not running | Start Docker Desktop and retry `docker compose ps` |
| Port conflict | Check existing containers; do not remove working containers or data |
| MySQL authentication error | Use the application credentials established when the database volume was initialized |
| RabbitMQ `403` / `ACCESS_REFUSED` | Verify RabbitMQ username/password, not MySQL credentials |
| Missing RabbitMQ queue | Run `messaging/setup_rabbitmq.py` against the intended broker |
| Missing Python package | Activate `.venv` and install `requirements.txt` |
| Changed SQL not showing up | Initialization scripts run only for new volumes; existing databases need migrations |

Keep `.env` private, preserve existing volumes and coordinate the message contract before integrated testing.
