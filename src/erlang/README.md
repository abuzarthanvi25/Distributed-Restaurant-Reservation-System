# GatherSeat Erlang scaffold

Install Erlang/OTP and make sure `escript` is available on your PATH.
Run these commands from the repository root.

Start the supervisor and worker:

```text
escript erlang/booking.escript start
```

The process stays up until you stop it with Ctrl+C.

Run the restart demo:

```text
escript erlang/booking.escript test
```

The demo checks request 101, kills the worker, waits for a replacement with a
different PID, and checks request 102. A supervisor report with reason
`killed` is expected. Success ends with `PASS`.

The worker receives `{book, Caller, RequestId}` and replies to `Caller`
with `{booking_reply, RequestId, test_only}`. The reply is for the local
demo. RabbitMQ and MySQL integration are still pending.
