DELIMITER $$

CREATE PROCEDURE apply_reservation_command(
    IN actor_id BIGINT UNSIGNED,
    IN command_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin,
    IN operation VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin,
    IN target_restaurant BIGINT UNSIGNED,
    IN target_slot BIGINT UNSIGNED,
    IN guests SMALLINT UNSIGNED,
    IN target_reservation BIGINT UNSIGNED
)
command: BEGIN
    DECLARE locked_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE selected_table BIGINT UNSIGNED DEFAULT NULL;
    DECLARE booking_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE booking_status VARCHAR(16);
    DECLARE booking_version INT UNSIGNED;
    DECLARE input_hash CHAR(64);
    DECLARE saved_hash CHAR(64);
    DECLARE reply JSON;
    DECLARE event_type VARCHAR(32);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF actor_id IS NULL OR actor_id = 0 OR command_id IS NULL
        OR NOT REGEXP_LIKE(command_id, '^[a-zA-Z0-9_-]{1,64}$', 'c')
        OR target_restaurant IS NULL OR target_restaurant = 0
        OR target_slot IS NULL OR target_slot = 0
        OR operation IS NULL OR operation NOT IN ('book', 'cancel')
        OR (operation = 'book' AND (guests IS NULL OR guests = 0 OR target_reservation IS NOT NULL))
        OR (operation = 'cancel' AND (guests IS NOT NULL OR target_reservation IS NULL OR target_reservation = 0))
    THEN
        SELECT JSON_OBJECT('code', 'INVALID_COMMAND') AS result;
        LEAVE command;
    END IF;

    SET input_hash = SHA2(JSON_ARRAY(operation, target_restaurant, target_slot, guests, target_reservation), 256);
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;

    -- Ordinary commands lock the actor first, then restaurant/slot, then inventory.
    SELECT id INTO locked_id FROM app_user WHERE id = actor_id FOR UPDATE;
    IF locked_id IS NULL THEN
        ROLLBACK;
        SELECT JSON_OBJECT('code', 'UNKNOWN_ACTOR') AS result;
        LEAVE command;
    END IF;

    INSERT INTO command_result (user_id, request_id, fingerprint)
    VALUES (actor_id, command_id, input_hash)
    ON DUPLICATE KEY UPDATE fingerprint = command_result.fingerprint;

    SELECT fingerprint, result INTO saved_hash, reply
    FROM command_result WHERE user_id = actor_id AND request_id = command_id FOR UPDATE;
    IF saved_hash <> input_hash THEN
        ROLLBACK;
        SELECT JSON_OBJECT('code', 'REQUEST_ID_CONFLICT') AS result;
        LEAVE command;
    END IF;

    IF reply IS NULL THEN
        SET locked_id = NULL;
        SELECT restaurant_id INTO locked_id FROM restaurant_slot
        WHERE restaurant_id = target_restaurant AND slot_id = target_slot FOR UPDATE;

        IF locked_id IS NULL THEN
            SET reply = JSON_OBJECT('code', 'UNKNOWN_RESTAURANT_SLOT');
        ELSEIF operation = 'book' THEN
            SELECT id INTO booking_id FROM reservation
            WHERE user_id = actor_id AND slot_id = target_slot AND active_marker = 1 FOR UPDATE;
            IF booking_id IS NOT NULL THEN
                SET reply = JSON_OBJECT('code', 'MEMBER_SLOT_CONFLICT');
            ELSE
                SELECT t.table_id INTO selected_table
                FROM dining_table t
                WHERE t.restaurant_id = target_restaurant AND t.capacity >= guests
                    AND NOT EXISTS (
                        SELECT 1 FROM reservation r
                        WHERE r.restaurant_id = t.restaurant_id AND r.table_id = t.table_id
                            AND r.slot_id = target_slot AND r.active_marker = 1
                    )
                ORDER BY t.capacity, t.table_id LIMIT 1 FOR UPDATE;

                IF selected_table IS NULL THEN
                    SET reply = JSON_OBJECT('code', 'NO_TABLE');
                ELSE
                    INSERT INTO reservation (restaurant_id, slot_id, table_id, user_id, party_size, status)
                    VALUES (target_restaurant, target_slot, selected_table, actor_id, guests, 'confirmed');
                    SET booking_id = LAST_INSERT_ID();
                    SET booking_version = 1;
                    SET event_type = 'reservation.confirmed';
                    SET reply = JSON_OBJECT('code', 'CONFIRMED', 'reservation_id', booking_id, 'table_id', selected_table);
                END IF;
            END IF;
        ELSE
            SELECT id, status, version INTO booking_id, booking_status, booking_version
            FROM reservation WHERE id = target_reservation AND user_id = actor_id
                AND restaurant_id = target_restaurant AND slot_id = target_slot FOR UPDATE;
            IF booking_id IS NULL THEN
                SET reply = JSON_OBJECT('code', 'RESERVATION_NOT_FOUND');
            ELSE
                IF booking_status = 'confirmed' THEN
                    SET booking_version = booking_version + 1;
                    UPDATE reservation SET status = 'cancelled', version = booking_version WHERE id = booking_id;
                    SET event_type = 'reservation.cancelled';
                END IF;
                SET reply = JSON_OBJECT('code', 'CANCELLED', 'reservation_id', booking_id);
            END IF;
        END IF;

        IF event_type IS NOT NULL THEN
            INSERT INTO reservation_outbox (reservation_id, aggregate_version, payload)
            VALUES (booking_id, booking_version, JSON_OBJECT(
                'type', event_type, 'reservation_id', booking_id, 'version', booking_version,
                'restaurant_id', target_restaurant, 'slot_id', target_slot));
        END IF;

        UPDATE command_result SET result = reply
        WHERE user_id = actor_id AND request_id = command_id;
    END IF;

    COMMIT;
    SELECT reply AS result;
END$$

DELIMITER ;
