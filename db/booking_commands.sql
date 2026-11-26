
DELIMITER $$

DROP PROCEDURE IF EXISTS book_table$$

CREATE PROCEDURE book_table(
    IN p_request_id VARCHAR(100),
    IN p_customer_id BIGINT,
    IN p_restaurant_id BIGINT,
    IN p_slot_id BIGINT,
    IN p_guests INT
)
BEGIN
    DECLARE v_table_id BIGINT DEFAULT NULL;
    DECLARE v_reservation_id BIGINT DEFAULT NULL;
    DECLARE v_existing_customer BIGINT DEFAULT NULL;
    DECLARE v_existing_fingerprint CHAR(64);
    DECLARE v_existing_result VARCHAR(40);
    DECLARE v_existing_payload JSON;
    DECLARE v_fingerprint CHAR(64);
    DECLARE v_slot_exists INT DEFAULT 0;
    DECLARE v_customer_exists INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_fingerprint = SHA2(
        JSON_ARRAY(p_customer_id, p_restaurant_id, p_slot_id, p_guests),
        256
    );

    IF p_request_id IS NULL OR p_request_id = ''
       OR p_customer_id IS NULL
       OR p_restaurant_id IS NULL
       OR p_slot_id IS NULL
       OR p_guests IS NULL OR p_guests <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid booking parameters';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_customer_exists
    FROM app_user
    WHERE id = p_customer_id AND role = 'CUSTOMER';

    IF v_customer_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Customer does not exist';
    END IF;

    INSERT INTO command_result (
        request_id, customer_id, operation,
        request_fingerprint, result_code
    )
    VALUES (
        p_request_id, p_customer_id, 'book',
        v_fingerprint, NULL
    )
    ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id);

    SELECT customer_id, request_fingerprint,
           result_code, result_payload
    INTO v_existing_customer, v_existing_fingerprint,
         v_existing_result, v_existing_payload
    FROM command_result
    WHERE request_id = p_request_id
    FOR UPDATE;

    IF v_existing_customer <> p_customer_id
       OR v_existing_fingerprint <> v_fingerprint THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Request ID reused with different parameters';
    END IF;

    IF v_existing_result IS NOT NULL THEN
        COMMIT;
        SELECT v_existing_payload AS result;
    ELSE
        SELECT COUNT(*) INTO v_slot_exists
        FROM restaurant_slot
        WHERE restaurant_id = p_restaurant_id
          AND slot_id = p_slot_id;

        IF v_slot_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Restaurant slot unavailable';
        END IF;

        SELECT MIN(id) INTO v_table_id
        FROM dining_table
        WHERE restaurant_id = p_restaurant_id
          AND capacity >= p_guests
          AND NOT EXISTS (
              SELECT 1 FROM table_allocation a
              WHERE a.table_id = dining_table.id
                AND a.slot_id = p_slot_id
          );

        IF v_table_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No available table';
        END IF;

        INSERT INTO reservation (
            request_id, customer_id, table_id,
            slot_id, guests, status
        )
        VALUES (
            p_request_id, p_customer_id, v_table_id,
            p_slot_id, p_guests, 'CONFIRMED'
        );

        SET v_reservation_id = LAST_INSERT_ID();

        INSERT INTO table_allocation (
            reservation_id, table_id, slot_id
        )
        VALUES (
            v_reservation_id, v_table_id, p_slot_id
        );

        UPDATE command_result
        SET result_code = 'CONFIRMED',
            reservation_id = v_reservation_id,
            result_payload = JSON_OBJECT(
                'code', 'CONFIRMED',
                'reservation_id', v_reservation_id,
                'table_id', v_table_id
            )
        WHERE request_id = p_request_id;

        COMMIT;

        SELECT JSON_OBJECT(
            'code', 'CONFIRMED',
            'reservation_id', v_reservation_id,
            'table_id', v_table_id
        ) AS result;
    END IF;
END$$

DELIMITER ;


DELIMITER $$

DROP PROCEDURE IF EXISTS cancel_booking$$

CREATE PROCEDURE cancel_booking(
    IN p_reservation_id BIGINT,
    IN p_customer_id BIGINT
)
BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_reservation BIGINT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_reservation_id IS NULL
       OR p_customer_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid cancellation parameters';
    END IF;

    START TRANSACTION;

    SELECT id, status
    INTO v_reservation, v_status
    FROM reservation
    WHERE id = p_reservation_id
      AND customer_id = p_customer_id
    FOR UPDATE;

    IF v_reservation IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reservation not found or access denied';
    END IF;

    IF v_status = 'CANCELLED' THEN
        COMMIT;
        SELECT 'ALREADY_CANCELLED' AS result;
    ELSE
        UPDATE reservation
        SET status = 'CANCELLED'
        WHERE id = p_reservation_id;

        DELETE FROM table_allocation
        WHERE reservation_id = p_reservation_id;

        COMMIT;
        SELECT 'CANCELLED' AS result;
    END IF;
END$$

DELIMITER ;
