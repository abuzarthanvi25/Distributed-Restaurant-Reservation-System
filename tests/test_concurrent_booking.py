
import os
import uuid
import threading
from concurrent.futures import ThreadPoolExecutor

import mysql.connector

# --------------------------------------
# Database configuration
# --------------------------------------
DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 3307,
    "user": "gatherseat",
    "password": os.environ["GATHERSEAT_DB_PASSWORD"],
    "database": "gatherseat",
    "connection_timeout": 10,
}

RESTAURANT_ID = 2       # GatherSeat London
TABLE_ID = 3            # London's only table
SLOT_ID = 101           # Fresh concurrency test slot
GUESTS = 4

RUN_ID = uuid.uuid4().hex[:12]
barrier = threading.Barrier(2)


# --------------------------------------
# Execute one booking request
# --------------------------------------
def book(customer_id):
    connection = None
    cursor = None

    request_id = f"concurrency-{RUN_ID}-{customer_id}"

    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        cursor = connection.cursor()

        # Both threads wait here before attempting booking.
        barrier.wait(timeout=15)

        cursor.callproc(
            "book_table",
            (
                request_id,
                customer_id,
                RESTAURANT_ID,
                SLOT_ID,
                GUESTS,
            ),
        )

        rows = []

        for stored_result in cursor.stored_results():
            rows.extend(stored_result.fetchall())

        connection.commit()

        return {
            "customer_id": customer_id,
            "request_id": request_id,
            "status": "SUCCESS",
            "result": rows,
        }

    except Exception as error:
        if connection is not None:
            connection.rollback()

        return {
            "customer_id": customer_id,
            "request_id": request_id,
            "status": "REJECTED",
            "result": str(error),
        }

    finally:
        if cursor is not None:
            cursor.close()

        if connection is not None:
            connection.close()


# --------------------------------------
# Verify slot is unused before testing
# --------------------------------------
def check_slot_is_empty():
    connection = mysql.connector.connect(**DB_CONFIG)
    cursor = connection.cursor()

    try:
        cursor.execute(
            """
            SELECT COUNT(*)
            FROM table_allocation
            WHERE table_id = %s AND slot_id = %s
            """,
            (TABLE_ID, SLOT_ID),
        )

        count = cursor.fetchone()[0]

        if count != 0:
            raise RuntimeError(
                f"Slot {SLOT_ID} already contains "
                f"{count} allocation(s). "
                "Use a fresh test slot."
            )

        print(f"PASS: Slot {SLOT_ID} is initially empty.")

    finally:
        cursor.close()
        connection.close()


# --------------------------------------
# Run two booking requests concurrently
# --------------------------------------
def run_concurrency_test():
    print("\n=== GatherSeat Concurrency Test ===")
    print(f"Restaurant: {RESTAURANT_ID}")
    print(f"Table: {TABLE_ID}")
    print(f"Slot: {SLOT_ID}")
    print(f"Run ID: {RUN_ID}\n")

    check_slot_is_empty()

    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [
            executor.submit(book, 1),
            executor.submit(book, 2),
        ]

        results = [future.result() for future in futures]

    for result in results:
        print(
            f"Customer {result['customer_id']}: "
            f"{result['status']}"
        )
        print(f"  Request: {result['request_id']}")
        print(f"  Result: {result['result']}\n")

    success_count = sum(
        1 for result in results
        if result["status"] == "SUCCESS"
        and any(
            row and '"code": "CONFIRMED"' in str(row)
            for row in result["result"]
        )
    )

    print(f"Successful bookings: {success_count}")

    # --------------------------------------
    # Check final database state
    # --------------------------------------
    connection = mysql.connector.connect(**DB_CONFIG)
    cursor = connection.cursor()

    try:
        cursor.execute(
            """
            SELECT
                r.id,
                r.request_id,
                r.customer_id,
                r.status,
                a.table_id,
                a.slot_id
            FROM reservation r
            JOIN table_allocation a
                ON a.reservation_id = r.id
            WHERE a.table_id = %s
              AND a.slot_id = %s
            """,
            (TABLE_ID, SLOT_ID),
        )

        allocations = cursor.fetchall()

        print("\nFinal allocations:")
        for allocation in allocations:
            print(allocation)

        allocation_count = len(allocations)

        print(f"\nActive allocations: {allocation_count}")

        test_request_ids = [
            result["request_id"] for result in results
        ]

        cursor.execute(
            """
            SELECT request_id, status
            FROM reservation
            WHERE request_id IN (%s, %s)
            """,
            tuple(test_request_ids),
        )

        test_reservations = cursor.fetchall()

        confirmed_count = sum(
            1 for _, status in test_reservations
            if status == "CONFIRMED"
        )

        print(f"Confirmed reservations from this run: {confirmed_count}")

        # --------------------------------------
        # Assertions
        # --------------------------------------
        assert success_count == 1, (
            f"Expected exactly 1 successful request, "
            f"got {success_count}"
        )

        assert confirmed_count == 1, (
            f"Expected exactly 1 confirmed reservation "
            f"from this run, got {confirmed_count}"
        )

        assert allocation_count == 1, (
            f"Expected exactly 1 allocation, "
            f"got {allocation_count}"
        )

        assert allocations[0][1] in test_request_ids, (
            "The allocation belongs to an unexpected request."
        )

        print("\nPASS: Exactly one new booking succeeded.")
        print("PASS: Only one table allocation exists.")
        print("PASS: No double booking occurred.")

    finally:
        cursor.close()
        connection.close()


if __name__ == "__main__":
    run_concurrency_test()
