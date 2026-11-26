
import os
import getpass
import pika

RABBITMQ_HOST = "127.0.0.1"
RABBITMQ_PORT = 5672
RABBITMQ_USER = "gatherseat"

COMMAND_EXCHANGE = "gatherseat.commands.v1"
EVENT_EXCHANGE = "gatherseat.events.v1"

RESTAURANTS = {
    1: "Pisa",
    2: "London",
}


def main():
    password = os.getenv("GATHERSEAT_AMQP_PASSWORD")

    if not password:
        password = getpass.getpass("RabbitMQ password: ")

    credentials = pika.PlainCredentials(
        RABBITMQ_USER, password
    )

    parameters = pika.ConnectionParameters(
        host=RABBITMQ_HOST,
        port=RABBITMQ_PORT,
        credentials=credentials,
        heartbeat=60,
        blocked_connection_timeout=30,
    )

    connection = pika.BlockingConnection(parameters)

    try:
        channel = connection.channel()

        for exchange in (COMMAND_EXCHANGE, EVENT_EXCHANGE):
            channel.exchange_declare(
                exchange=exchange,
                exchange_type="topic",
                durable=True,
            )
            print(f"Exchange ready: {exchange}")

        for restaurant_id, city in RESTAURANTS.items():
            queue_name = f"gatherseat.restaurant.{restaurant_id}"
            routing_key = f"restaurant.{restaurant_id}"

            channel.queue_declare(
                queue=queue_name,
                durable=True,
            )

            channel.queue_bind(
                exchange=COMMAND_EXCHANGE,
                queue=queue_name,
                routing_key=routing_key,
            )

            print(
                f"{city}: {queue_name} "
                f"<- {routing_key}"
            )

        print("\nRabbitMQ setup completed successfully.")

    finally:
        connection.close()


if __name__ == "__main__":
    main()
