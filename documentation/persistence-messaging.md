# Persistence and messaging

This first slice covers ordinary bookings and customer cancellations. Java owns authentication and HTTP. The Erlang worker owns the reservation workflow and calls the database command procedure. The Python adapter under `tests/` exercises the contract with real MySQL and RabbitMQ when the stack is running. It is an integration fixture.

## Run the isolated stack

Install Docker with Compose and Python 3. Copy `.env.example` to `.env` and set all three passwords to distinct local values. On Windows PowerShell, run the following in the repository root.

```powershell
Copy-Item .env.example .env
notepad .env
docker compose up -d --wait
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r tests/requirements.txt
$env:GATHERSEAT_DB_PASSWORD = Read-Host "Database password from .env"
$env:GATHERSEAT_AMQP_PASSWORD = Read-Host "RabbitMQ password from .env"
$env:GATHERSEAT_INTEGRATION = "1"
.venv\Scripts\python.exe -m unittest discover -s tests -v
```

The integration tests clear and seed the local database and purge the restaurant 1 command queue. Use a dedicated stack with no real data. For bash, copy with `cp`, use `.venv/bin/python`, and export the same three test variables. MySQL listens locally on port 3307 and RabbitMQ on 5672. Optional test overrides are `GATHERSEAT_DB_HOST`, `GATHERSEAT_DB_PORT` and `GATHERSEAT_AMQP_HOST`. Compose applies the numbered SQL files on first initialization of an empty MySQL volume.

## Integrate the command path

1. Provision user IDs, restaurants, dining tables, shared dining windows and eligible restaurant/slot pairs. A slot ID must represent the same non-overlapping UTC dining window in every restaurant. Availability reads are advisory. The procedure selects the smallest free table that fits when committing a booking.
2. Java takes the actor ID from the authenticated session and publishes a persistent JSON command to the durable direct exchange in [the contract](../messaging/contract.json). Set AMQP reply-to and correlation ID. Declare the durable restaurant queue and bind the restaurant routing key before publishing. Use publisher confirms and handle unroutable commands. On a reply timeout, retry with the original payload and request ID. Correlation IDs match individual replies.
3. The worker consumes with manual acknowledgement from the restaurant queue. Use the single-active-consumer queue setting and prefetch one for serial processing. Validate the command and routing key before invoking the procedure. On database deadlocks or lock timeouts, retry a bounded number of times with the same command. Only return a business result after the procedure responds. If the database outcome is unknown, preserve the command for retry. Publish the reply before acknowledging the delivery. For expired reply destinations, handle the unroutable reply explicitly and let the client recover the stored result with its original request ID.
4. A publisher reads pending outbox rows and publishes to the durable topic exchange with the same restaurant routing key. Provision a durable event subscription before publishing. Use mandatory publishing and publisher confirms before marking a row published. A crash between publish and mark can repeat an event. Consumers deduplicate by event ID and use aggregate version to handle stale messages and detect gaps. Across concurrent publishers, event delivery can arrive out of version order.

The worker calls the procedure on a connection without an open caller transaction. It returns a single row with one JSON field, `result`.

```sql
CALL apply_reservation_command(1, 'book-1', 'book', 1, 1, 4, NULL);
CALL apply_reservation_command(1, 'cancel-1', 'cancel', 1, 1, NULL, 1);
```

A cancel command replaces `guests` with `reservation_id`. Valid request IDs contain 1–64 ASCII letters, digits, underscores or hyphens. A request ID is scoped to the authenticated actor. Reusing it with different parameters returns `REQUEST_ID_CONFLICT`.

| Result code | Meaning |
|---|---|
| `CONFIRMED`, `CANCELLED` | The booking or cancellation committed |
| `NO_TABLE` | No unallocated table fits the party |
| `MEMBER_SLOT_CONFLICT` | The actor already holds an active reservation in that window |
| `RESERVATION_NOT_FOUND` | No reservation matches the actor and supplied identifiers |
| `UNKNOWN_RESTAURANT_SLOT`, `UNKNOWN_ACTOR`, `INVALID_COMMAND` | Invalid identifiers or command shape |
| `REQUEST_ID_CONFLICT` | The actor reused an ID for different parameters |

## Demonstrate and explain

- **Competing clients.** The SQL integration test releases 100 client tasks against one eligible table. It checks persisted allocations and outbox records. The database locks the actor, then the restaurant/slot row and selected inventory. Unique active keys backstop table and actor consistency.
- **Lost reply.** The broker integration test commits the booking and disconnects before replying or acknowledging. A new connection receives the redelivery and returns the stored answer. It also checks the outbox publication and correlation ID.
- **Two restaurants.** The database shares a slot identity and protects the same actor across restaurant workers. Cancelling the winning reservation frees the table and active slot claim.

**Why put the constraint in MySQL?** Both workers use the same database. The database enforces the invariant while either worker processes a command.

**What if commit succeeds and the client times out?** The result is stored alongside the booking. Retrying the same request ID returns that result.

**What if the publisher sends an event twice?** An event carries a stable ID and reservation version. Consumers can recognize an event they have already applied.

**What remains for integration?** agree user and catalog provisioning with Java and the SQL driver, connection strategy and RabbitMQ adapter with Erlang. Group holds, shared member locking, expiry, waiting-list workflows and two-VM deployment require their own integration work. Test evidence from this slice is scoped to the scenarios above.
