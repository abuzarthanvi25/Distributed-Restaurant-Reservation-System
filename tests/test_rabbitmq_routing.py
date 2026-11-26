
import os
import json
import uuid
import getpass
import pika

password = os.getenv("GATHERSEAT_AMQP_PASSWORD")
if not password:
    password = getpass.getpass("RabbitMQ password: ")

credentials = pika.PlainCredentials("gatherseat", password)
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host="127.0.0.1",
        port=5672,
        credentials=credentials
    )
)

channel = connection.channel()
channel.confirm_delivery()

test_id = uuid.uuid4().hex

try:
    for restaurant_id in (1, 2):
        queue = f"gatherseat.restaurant.{restaurant_id}"
        routing_key = f"restaurant.{restaurant_id}"

        # Do not consume any messages left by other applications.
        queue_info = channel.queue_declare(
            queue=queue,
            passive=True
        )
        assert queue_info.method.message_count == 0, (
            f"{queue} already has messages; stop to avoid consuming them"
        )

        message = {
            "version": 1,
            "request_id": f"routing-test-{test_id}-{restaurant_id}",
            "operation": "book",
            "actor_id": 1,
            "restaurant_id": restaurant_id,
            "slot_id": 1,
            "guests": 2
        }

        channel.basic_publish(
            exchange="gatherseat.commands.v1",
            routing_key=routing_key,
            body=json.dumps(message).encode("utf-8"),
            mandatory=True,
            properties=pika.BasicProperties(
                content_type="application/json",
                delivery_mode=2
            )
        )

        method, properties, body = channel.basic_get(
            queue=queue,
            auto_ack=False
        )

        assert method is not None, f"No message received from {queue}"

        received = json.loads(body)
        if received != message:
            channel.basic_nack(method.delivery_tag, requeue=True)
            raise AssertionError("Received unexpected message")

        channel.basic_ack(method.delivery_tag)

        print(f"PASS: restaurant.{restaurant_id} -> {queue}")

    print("\nPASS: RabbitMQ routing verified for both restaurants.")

finally:
    connection.close()
