CREATE TABLE IF NOT EXISTS app_user (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    role ENUM('CUSTOMER', 'MANAGER') NOT NULL DEFAULT 'CUSTOMER'
);

CREATE TABLE IF NOT EXISTS restaurant (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(150) NOT NULL,
    city VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS dining_table (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    restaurant_id BIGINT NOT NULL,
    table_number INT NOT NULL,
    capacity INT NOT NULL,
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(id),
    UNIQUE KEY uq_restaurant_table (restaurant_id, table_number),
    CHECK (capacity > 0)
);

CREATE TABLE IF NOT EXISTS dining_slot (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NOT NULL,
    CHECK (ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS reservation (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    request_id VARCHAR(100) NOT NULL UNIQUE,
    customer_id BIGINT NOT NULL,
    table_id BIGINT NOT NULL,
    slot_id BIGINT NOT NULL,
    guests INT NOT NULL,
    status ENUM('CONFIRMED', 'CANCELLED') NOT NULL DEFAULT 'CONFIRMED',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES app_user(id),
    FOREIGN KEY (table_id) REFERENCES dining_table(id),
    FOREIGN KEY (slot_id) REFERENCES dining_slot(id),
    CHECK (guests > 0)
);

CREATE TABLE IF NOT EXISTS table_allocation (
    reservation_id BIGINT PRIMARY KEY,
    table_id BIGINT NOT NULL,
    slot_id BIGINT NOT NULL,
    FOREIGN KEY (reservation_id) REFERENCES reservation(id),
    FOREIGN KEY (table_id) REFERENCES dining_table(id),
    FOREIGN KEY (slot_id) REFERENCES dining_slot(id),
    UNIQUE KEY uq_table_slot (table_id, slot_id)
);

CREATE TABLE IF NOT EXISTS restaurant_slot (
    restaurant_id BIGINT NOT NULL,
    slot_id BIGINT NOT NULL,
    PRIMARY KEY (restaurant_id, slot_id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(id),
    FOREIGN KEY (slot_id) REFERENCES dining_slot(id)
);

CREATE TABLE IF NOT EXISTS command_result (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    request_id VARCHAR(100) NOT NULL UNIQUE,
    customer_id BIGINT NOT NULL,
    operation VARCHAR(20) NOT NULL,
    request_fingerprint CHAR(64) NOT NULL,
    result_code VARCHAR(40) NULL,
    result_payload JSON NULL,
    reservation_id BIGINT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES app_user(id),
    FOREIGN KEY (reservation_id) REFERENCES reservation(id)
);