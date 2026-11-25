CREATE TABLE app_user (
    id BIGINT UNSIGNED PRIMARY KEY
) ENGINE=InnoDB;

CREATE TABLE restaurant (
    id BIGINT UNSIGNED PRIMARY KEY,
    name VARCHAR(160) NOT NULL
) ENGINE=InnoDB;

-- A slot ID represents the same time window across all restaurants.
-- The catalog must provision fixed, non-overlapping windows.
CREATE TABLE dining_slot (
    id BIGINT UNSIGNED PRIMARY KEY,
    starts_at DATETIME(6) NOT NULL UNIQUE,
    ends_at DATETIME(6) NOT NULL,
    CHECK (starts_at < ends_at)
) ENGINE=InnoDB;

CREATE TABLE restaurant_slot (
    restaurant_id BIGINT UNSIGNED NOT NULL,
    slot_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (restaurant_id, slot_id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(id),
    FOREIGN KEY (slot_id) REFERENCES dining_slot(id)
) ENGINE=InnoDB;

CREATE TABLE dining_table (
    restaurant_id BIGINT UNSIGNED NOT NULL,
    table_id BIGINT UNSIGNED NOT NULL,
    capacity SMALLINT UNSIGNED NOT NULL CHECK (capacity > 0),
    PRIMARY KEY (restaurant_id, table_id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(id)
) ENGINE=InnoDB;

CREATE TABLE reservation (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    restaurant_id BIGINT UNSIGNED NOT NULL,
    slot_id BIGINT UNSIGNED NOT NULL,
    table_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    party_size SMALLINT UNSIGNED NOT NULL CHECK (party_size > 0),
    status ENUM('confirmed', 'cancelled') NOT NULL,
    version INT UNSIGNED NOT NULL DEFAULT 1,
    active_marker TINYINT AS (IF(status = 'confirmed', 1, NULL)) STORED,
    UNIQUE (restaurant_id, slot_id, table_id, active_marker),
    UNIQUE (user_id, slot_id, active_marker),
    FOREIGN KEY (restaurant_id, slot_id) REFERENCES restaurant_slot(restaurant_id, slot_id),
    FOREIGN KEY (restaurant_id, table_id) REFERENCES dining_table(restaurant_id, table_id),
    FOREIGN KEY (user_id) REFERENCES app_user(id)
) ENGINE=InnoDB;

CREATE TABLE command_result (
    user_id BIGINT UNSIGNED NOT NULL,
    request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    fingerprint CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    result JSON,
    PRIMARY KEY (user_id, request_id),
    FOREIGN KEY (user_id) REFERENCES app_user(id)
) ENGINE=InnoDB;

CREATE TABLE reservation_outbox (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    reservation_id BIGINT UNSIGNED NOT NULL,
    aggregate_version INT UNSIGNED NOT NULL,
    payload JSON NOT NULL,
    published_at DATETIME(6),
    UNIQUE (reservation_id, aggregate_version),
    INDEX (published_at, id),
    FOREIGN KEY (reservation_id) REFERENCES reservation(id)
) ENGINE=InnoDB;
