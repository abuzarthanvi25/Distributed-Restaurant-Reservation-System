"""Reference adapter for integration tests. The deployed worker belongs to the Erlang module."""
import json
import os
import re
import time

import pika
import pymysql

COMMANDS = "gatherseat.commands.v1"
EVENTS = "gatherseat.events.v1"


def db():
    return pymysql.connect(
        host=os.getenv("GATHERSEAT_DB_HOST", "127.0.0.1"),
        port=int(os.getenv("GATHERSEAT_DB_PORT", "3307")),
        user="gatherseat", password=os.environ["GATHERSEAT_DB_PASSWORD"],
        database="gatherseat", autocommit=True, connect_timeout=5,
        read_timeout=10, write_timeout=10,
    )


def broker():
    return pika.BlockingConnection(pika.ConnectionParameters(
        host=os.getenv("GATHERSEAT_AMQP_HOST", "127.0.0.1"),
        credentials=pika.PlainCredentials("gatherseat", os.environ["GATHERSEAT_AMQP_PASSWORD"]),
        socket_timeout=5, stack_timeout=10, blocked_connection_timeout=5,
    ))


def valid(command):
    if not isinstance(command, dict) or type(command.get("version")) is not int or command["version"] != 1:
        return False
    fields = {"version", "request_id", "actor_id", "operation", "restaurant_id", "slot_id"}
    operation = command.get("operation")
    if operation == "book":
        field, limit = "guests", 65535
    elif operation == "cancel":
        field, limit = "reservation_id", 2**64 - 1
    else:
        return False
    request_id = command.get("request_id")
    return (
        command.keys() == fields | {field}
        and isinstance(request_id, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,64}", request_id) is not None
        and all(
            type(command[key]) is int and 0 < command[key] <= maximum
            for key, maximum in (
                ("actor_id", 2**64 - 1), ("restaurant_id", 2**64 - 1),
                ("slot_id", 2**64 - 1), (field, limit),
            )
        )
    )


def apply(command):
    if not valid(command):
        return {"code": "INVALID_COMMAND"}
    args = (
        command["actor_id"], command["request_id"], command["operation"],
        command["restaurant_id"], command["slot_id"], command.get("guests"),
        command.get("reservation_id"),
    )
    for attempt in range(3):
        try:
            with db() as connection, connection.cursor() as cursor:
                cursor.execute("CALL apply_reservation_command(%s,%s,%s,%s,%s,%s,%s)", args)
                result = json.loads(cursor.fetchone()[0])
                while cursor.nextset():
                    pass
                return {"request_id": command["request_id"], **result}
        except pymysql.OperationalError as error:
            if error.args[0] not in (1205, 1213) or attempt == 2:
                raise
            time.sleep(0.025 * (2**attempt))


def declare(channel, restaurant_id):
    key = f"restaurant.{restaurant_id}"
    queue = f"gatherseat.{key}"
    channel.exchange_declare(COMMANDS, "direct", durable=True)
    channel.exchange_declare(EVENTS, "topic", durable=True)
    channel.queue_declare(queue, durable=True, arguments={"x-single-active-consumer": True})
    channel.queue_bind(queue, COMMANDS, key)
    return key, queue


def publish_one_outbox_event(channel):
    # Caller enables publisher confirms. Losing the connection before the UPDATE
    # leaves the event pending. A retry may therefore publish the same event ID.
    with db() as connection, connection.cursor() as cursor:
        connection.begin()
        cursor.execute("""
            SELECT id, payload FROM reservation_outbox
            WHERE published_at IS NULL ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED
        """)
        row = cursor.fetchone()
        if row is None:
            connection.rollback()
            return None
        event_id, payload = row
        event = {"event_id": event_id, **json.loads(payload)}
        channel.basic_publish(
            EVENTS, f"restaurant.{event['restaurant_id']}", json.dumps(event).encode(),
            pika.BasicProperties(content_type="application/json", delivery_mode=2,
                                 message_id=str(event_id)), mandatory=True,
        )
        cursor.execute("UPDATE reservation_outbox SET published_at = UTC_TIMESTAMP(6) WHERE id = %s", (event_id,))
        connection.commit()
        return event_id
