import json
import os
import time
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

import pika

from infrastructure import COMMANDS, EVENTS, apply, broker, db, declare, publish_one_outbox_event, valid


def booking(actor, restaurant=1, slot=1):
    return {
        "version": 1, "request_id": str(uuid.uuid4()), "operation": "book",
        "actor_id": actor, "restaurant_id": restaurant, "slot_id": slot, "guests": 4,
    }


class CommandValidation(unittest.TestCase):
    def test_reject_invalid_fields(self):
        sample = booking(1)
        self.assertTrue(valid(sample))
        for change in (
            {"actor_id": True}, {"guest": 1}, {"guests": 65536},
            {"version": 2}, {"request_id": "contains spaces"},
            {"operation": "cancel"}, {"slot_id": 0},
        ):
            self.assertFalse(valid({**sample, **change}), change)


@unittest.skipUnless(os.getenv("GATHERSEAT_INTEGRATION") == "1", "requires a disposable Compose stack")
class Integration(unittest.TestCase):
    def setUp(self):
        # Run only against the isolated, disposable database from compose.yaml.
        with db() as connection, connection.cursor() as cursor:
            for table in ("reservation_outbox", "command_result", "reservation", "dining_table",
                          "restaurant_slot", "dining_slot", "restaurant", "app_user"):
                cursor.execute(f"DELETE FROM {table}")
            cursor.executemany("INSERT INTO app_user VALUES (%s)", [(actor,) for actor in range(1, 101)])
            cursor.execute("INSERT INTO restaurant VALUES (1,'Pisa'), (2,'Lucca')")
            cursor.execute("INSERT INTO dining_slot VALUES (1,'2030-01-01 19:00','2030-01-01 21:00')")
            cursor.execute("INSERT INTO restaurant_slot VALUES (1,1),(2,1)")
            cursor.execute("INSERT INTO dining_table VALUES (1,1,4),(2,1,4)")

    def count(self, sql):
        with db() as connection, connection.cursor() as cursor:
            cursor.execute(sql)
            return cursor.fetchone()[0]

    def test_100_competing_bookings(self):
        start = Barrier(100, timeout=10)

        def compete(actor):
            start.wait()
            return apply(booking(actor))

        with ThreadPoolExecutor(max_workers=100) as pool:
            replies = list(pool.map(compete, range(1, 101)))
        self.assertEqual(1, sum(reply["code"] == "CONFIRMED" for reply in replies))
        self.assertEqual(99, sum(reply["code"] == "NO_TABLE" for reply in replies))
        self.assertEqual(1, self.count("SELECT COUNT(*) FROM reservation WHERE status='confirmed'"))
        self.assertEqual(1, self.count("SELECT COUNT(*) FROM reservation_outbox"))

    def test_cross_restaurant_and_cancel(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            replies = list(pool.map(apply, [booking(1), booking(1, restaurant=2)]))
        self.assertCountEqual(["CONFIRMED", "MEMBER_SLOT_CONFLICT"], [reply["code"] for reply in replies])
        winner = next(index for index, reply in enumerate(replies, 1) if reply["code"] == "CONFIRMED")
        reservation_id = replies[winner - 1]["reservation_id"]
        cancel = booking(1, restaurant=winner)
        del cancel["guests"]
        cancel.update(operation="cancel", reservation_id=reservation_id)
        self.assertEqual("RESERVATION_NOT_FOUND", apply({**cancel, "actor_id": 2})["code"])
        self.assertEqual("CANCELLED", apply(cancel)["code"])
        self.assertEqual("CANCELLED", apply(cancel)["code"])
        self.assertEqual("CONFIRMED", apply(booking(2, restaurant=winner))["code"])
        self.assertEqual(3, self.count("SELECT COUNT(*) FROM reservation_outbox"))

    def test_redelivery_after_commit_and_event(self):
        request = booking(1)
        with broker() as client:
            channel = client.channel()
            key, queue = declare(channel, 1)
            channel.queue_purge(queue)
            replies = channel.queue_declare("", exclusive=True).method.queue
            events = channel.queue_declare("", exclusive=True).method.queue
            channel.queue_bind(events, EVENTS, key)
            channel.confirm_delivery()
            correlation_id = str(uuid.uuid4())
            channel.basic_publish(COMMANDS, key, json.dumps(request).encode(), pika.BasicProperties(
                reply_to=replies, correlation_id=correlation_id, delivery_mode=2,
                content_type="application/json"), mandatory=True)

            with broker() as first_worker:
                worker = first_worker.channel()
                delivery, _, body = self.get(worker, queue)
                self.assertFalse(delivery.redelivered)
                saved = apply(json.loads(body))
                self.assertEqual("CONFIRMED", saved["code"])
                # Disconnect after the commit, before publishing the reply or acking.

            with broker() as replacement:
                worker = replacement.channel()
                worker.confirm_delivery()
                delivery, props, body = self.get(worker, queue)
                self.assertTrue(delivery.redelivered)
                replay = apply(json.loads(body))
                worker.basic_publish("", props.reply_to, json.dumps(replay).encode(),
                                     pika.BasicProperties(correlation_id=props.correlation_id))
                worker.basic_ack(delivery.delivery_tag)
                event_id = publish_one_outbox_event(worker)
                self.assertIsNone(publish_one_outbox_event(worker))

            _, props, body = self.get(channel, replies, auto_ack=True)
            self.assertEqual(correlation_id, props.correlation_id)
            self.assertEqual(saved, json.loads(body))
            _, _, body = self.get(channel, events, auto_ack=True)
            self.assertEqual(event_id, json.loads(body)["event_id"])
            self.assertEqual("REQUEST_ID_CONFLICT", apply({**request, "guests": 2})["code"])
            self.assertEqual(1, self.count("SELECT COUNT(*) FROM reservation"))
            self.assertEqual(1, self.count("SELECT COUNT(*) FROM reservation_outbox WHERE published_at IS NOT NULL"))

    @staticmethod
    def get(channel, queue, auto_ack=False):
        for _ in range(100):
            message = channel.basic_get(queue, auto_ack=auto_ack)
            if message[0] is not None:
                return message
            time.sleep(0.05)
        raise AssertionError(f"No message arrived on {queue}")


if __name__ == "__main__":
    unittest.main()
