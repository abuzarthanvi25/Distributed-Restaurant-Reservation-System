INSERT INTO app_user (id, name, email, role) VALUES
(1, 'Customer One', 'customer1@gatherseat.test', 'CUSTOMER'),
(2, 'Customer Two', 'customer2@gatherseat.test', 'CUSTOMER'),
(3, 'Restaurant Manager', 'manager@gatherseat.test', 'MANAGER');

INSERT INTO restaurant (id, name, city) VALUES
(1, 'GatherSeat Pisa', 'Pisa'),
(2, 'GatherSeat London', 'London');

INSERT INTO dining_table
(id, restaurant_id, table_number, capacity) VALUES
(1, 1, 1, 2),
(2, 1, 2, 4),
(3, 2, 1, 4);

INSERT INTO dining_slot (id, starts_at, ends_at) VALUES
(1, '2026-12-01 19:00:00', '2026-12-01 21:00:00'),
(2, '2026-12-01 21:00:00', '2026-12-01 23:00:00');

INSERT INTO restaurant_slot (restaurant_id, slot_id) VALUES
(1, 1),
(1, 2),
(2, 1);