# GatherSeat

**A distributed restaurant reservation system with group confirmations and waiting lists.**

Course project for *Distributed Systems and Middleware Technologies* (University of Pisa, MSc, a.y. 2026/27).

![Java](https://img.shields.io/badge/Java-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)
![Apache Tomcat](https://img.shields.io/badge/Apache%20Tomcat-F8DC75?style=for-the-badge&logo=apachetomcat&logoColor=black)
![Erlang](https://img.shields.io/badge/Erlang%2FOTP-A90533?style=for-the-badge&logo=erlang&logoColor=white)
![RabbitMQ](https://img.shields.io/badge/RabbitMQ-FF6600?style=for-the-badge&logo=rabbitmq&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)

GatherSeat supports ordinary bookings, group bookings that need confirmation from every member before a deadline, and waiting lists. It guarantees that no table is ever double-booked and that the system recovers safely when a worker crashes.

---

## Table of contents

1. [Goals and scope](#goals-and-scope)
2. [Architecture](#architecture)
3. [Technologies](#technologies)
4. [Components](#components)
5. [Booking flow](#booking-flow)
6. [Reliability and consistency rules](#reliability-and-consistency-rules)
7. [Deployment](#deployment)
8. [Required demonstrations](#required-demonstrations)
9. [Repository structure](#repository-structure)
10. [Getting started](#getting-started)
11. [Team](#team)
12. [Timeline](#timeline)

---

## Goals and scope

**Goal:** build a distributed reservation system that supports ordinary bookings, group confirmations and waiting lists, prevents double bookings, and recovers safely from worker crashes.

**In scope**

- Fixed, non-overlapping dining slots
- One table per reservation (smallest available table that fits the party)
- Fixed group membership during a group hold
- Worker-crash recovery while RabbitMQ and MySQL stay available

**Out of scope**

- Payments
- Joined tables
- Multi-restaurant booking packages
- Full VM or database failover (MySQL and RabbitMQ are shared dependencies)

---

## Architecture

```mermaid
flowchart TB
    subgraph CLIENT["Browser"]
        FE["Frontend<br/>JSP, HTML, CSS, JavaScript"]
    end

    subgraph VM1["VM1"]
        direction TB
        JAVA["Java web layer (Tomcat)<br/>Servlets: auth, roles, validation,<br/>correlation-ID reply matching,<br/>WebSocket endpoint"]
        MQ["RabbitMQ<br/>commands (routed by restaurant ID)<br/>reply queue / events exchange"]
        WA["Erlang worker A<br/>OTP supervisor<br/>restaurant coordinators<br/>outbox publisher"]
    end

    subgraph VM2["VM2"]
        direction TB
        WB["Erlang worker B<br/>OTP supervisor<br/>restaurant coordinators<br/>outbox publisher"]
        DB[("MySQL / InnoDB<br/>authoritative state<br/>reservations, request results, outbox")]
    end

    FE <-->|"HTTP / WebSocket"| JAVA
    JAVA <-->|"JSON commands, replies, events"| MQ
    MQ <-->|"active consumer: A's restaurants<br/>standby: B's restaurants"| WA
    MQ <-->|"active consumer: B's restaurants<br/>standby: A's restaurants"| WB
    WA <-->|"transactions, row locks"| DB
    WB <-->|"transactions, row locks"| DB
    WA -.->|"outbox events"| MQ
    WB -.->|"outbox events"| MQ
```

Active restaurants are distributed across both workers. Each restaurant has its own queue with a single active consumer, and a standby consumer on the other worker takes over if the active one dies.

---

## Technologies

**Frontend**

![JSP](https://img.shields.io/badge/JSP-007396?style=for-the-badge&logo=openjdk&logoColor=white)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![CSS3](https://img.shields.io/badge/CSS3-1572B6?style=for-the-badge&logo=css3&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)
![WebSocket](https://img.shields.io/badge/WebSocket-010101?style=for-the-badge&logo=socketdotio&logoColor=white)

**Backend**

![Java](https://img.shields.io/badge/Java-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)
![Servlets](https://img.shields.io/badge/Java%20Servlets-007396?style=for-the-badge&logo=openjdk&logoColor=white)
![Apache Tomcat](https://img.shields.io/badge/Apache%20Tomcat-F8DC75?style=for-the-badge&logo=apachetomcat&logoColor=black)
![Maven](https://img.shields.io/badge/Maven-C71A36?style=for-the-badge&logo=apachemaven&logoColor=white)
![Erlang](https://img.shields.io/badge/Erlang%2FOTP-A90533?style=for-the-badge&logo=erlang&logoColor=white)

**Middleware and data**

![RabbitMQ](https://img.shields.io/badge/RabbitMQ-FF6600?style=for-the-badge&logo=rabbitmq&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL%20%2F%20InnoDB-4479A1?style=for-the-badge&logo=mysql&logoColor=white)

**Deployment**

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)

| Layer | Technology | Why |
|---|---|---|
| Frontend | JSP, HTML, CSS, JavaScript | Server-rendered pages with live updates over WebSocket |
| Web layer | Java Servlets on Apache Tomcat | Authentication, request validation, request/reply correlation |
| Messaging | RabbitMQ | Routing by restaurant ID, request/reply, pub/sub notifications, acknowledgements and redelivery |
| Reservation service | Erlang/OTP | Supervised, isolated restaurant coordinators; fast restart after failure |
| Database | MySQL (InnoDB) | Transactions, constraints and row locking as the source of truth |
| Deployment | Docker, multi-VM setup | Two VMs, two Erlang workers |

---

## Components

### Frontend (JSP, HTML, CSS, JavaScript)

- Registration, login and restaurant search with availability
- Booking, cancellation and "My bookings"
- Group invitations, member responses and deadline countdown
- Waiting-list offers and in-app notifications
- Manager pages for restaurants, tables, dining slots and reservations
- Status dashboard
- WebSocket updates for changing availability and booking status

### Java web layer (Servlets on Tomcat)

- Authenticates users and checks customer/manager permissions
- Validates requests and sends JSON commands through RabbitMQ
- Matches replies using correlation IDs
- Shows confirmed, rejected or pending/unknown outcomes correctly
- Forwards notification events to browsers

### Messaging (RabbitMQ)

- Routes booking commands by restaurant ID
- One active consumer per restaurant queue, with a standby on the other Erlang worker
- Carries request/reply messages and publishes notification events
- Commands are acknowledged after processing; redelivery is handled safely

### Reservation service (Erlang/OTP)

- Supervised restaurant coordinators across two workers
- Selects the smallest available table that fits the party
- Manages bookings, cancellations, group responses and hold expiry
- Gives released tables to the earliest compatible waiting-list entry
- Recovers persisted pending work after restart

### Database (MySQL/InnoDB)

- Stores users, restaurants, tables, slots, reservations, group members, offers and deadlines
- Uses transactions, constraints and a consistent locking order
- Prevents duplicate table/slot allocations and simultaneous bookings for the same member across restaurants
- Stores processed request results and pending outbox events
- MySQL is authoritative; Erlang memory must always be recoverable from it

---

## Booking flow

```mermaid
sequenceDiagram
    autonumber
    participant B as Browser
    participant J as Java (Tomcat)
    participant Q as RabbitMQ
    participant E as Erlang coordinator
    participant D as MySQL
    participant O as Outbox publisher

    B->>J: Booking request
    J->>Q: JSON command with unique request ID
    Q->>E: Deliver to restaurant queue
    E->>D: Validate and lock affected rows
    E->>D: One transaction: booking change + request result + outbox event
    D-->>E: Commit
    E->>Q: Reply (correlation ID)
    Q->>J: Reply
    J-->>B: Confirmed / rejected / pending
    O->>D: Read pending outbox events
    O->>Q: Publish event
    Q->>J: Event
    J-->>B: WebSocket update
```

1. Browser sends a request to Java.
2. Java sends a command with a unique request ID through RabbitMQ.
3. Erlang validates and locks the affected database records.
4. One transaction saves the booking change, the request result and the outbox event.
5. After commit, the result returns to the customer.
6. An outbox publisher delivers the event; Java updates browsers.

---

## Reliability and consistency rules

- **Idempotency:** repeating a request returns its stored result without repeating the booking.
- **Unknown outcomes:** a timeout means the outcome is unknown; retry or check using the same request ID.
- **Persistent deadlines:** group and waiting-list deadlines are stored, and expired holds are scanned for after restarts.
- **Event integrity:** events are deduplicated, and versions reject stale updates.
- **Database unavailable:** no new bookings are confirmed when MySQL is unreachable.
- **Cross-restaurant guarantee:** one member cannot hold overlapping active bookings across restaurants. This is enforced in MySQL through constraints and a fixed lock order, not in Erlang memory.
- **Authoritative state:** MySQL is the source of truth, and Erlang state is rebuilt from it after a crash.

---

## Deployment

| Machine | Services |
|---|---|
| **VM1** | Tomcat (Java web layer), RabbitMQ, Erlang worker A |
| **VM2** | MySQL, Erlang worker B |

- Active restaurants are distributed across both workers.
- Failure scope is **worker recovery** while RabbitMQ and MySQL remain available. Full VM or database failover is outside this project's scope.

---

## Required demonstrations

| # | Scenario | Expected result |
|---|---|---|
| 1 | 100 requests competing for one table | Exactly one allocation |
| 2 | Concurrent group confirmations | One final reservation |
| 3 | Group confirmation racing with expiry | One valid outcome |
| 4 | One member in competing groups | One active booking |
| 5 | Waiting-list promotion | Released table goes to the earliest compatible entry |
| 6 | Worker crash after commit | Safe retry, no duplicate effect |
| 7 | Outbox publisher restart | Eventual event delivery without duplicate effects |

---

## Repository structure

> Proposed layout. Adjust to match the actual code.

```
gatherseat/
├── web/                 # Java web layer (Servlets, JSP, static assets)
│   └── src/
├── erlang/              # Erlang/OTP reservation service
│   ├── apps/
│   └── config/
├── db/                  # MySQL schema, migrations, seed data
├── messaging/           # RabbitMQ definitions (exchanges, queues, bindings)
├── deploy/              # Docker and multi-VM deployment files
├── tests/               # Concurrency, crash-recovery and outbox tests
├── docs/                # Report, architecture and state diagrams, demo script
└── README.md
```

---

## Getting started

> Fill in the exact versions and commands once the stack is fixed.

### Prerequisites

- JDK and Maven
- Apache Tomcat
- Erlang/OTP and rebar3
- RabbitMQ
- MySQL
- Docker and Docker Compose

### Run locally

```bash
# 1. Start infrastructure (MySQL, RabbitMQ)
docker compose up -d

# 2. Initialise the database
mysql -u <user> -p < db/schema.sql

# 3. Start the Erlang worker(s)
cd erlang && rebar3 shell

# 4. Build and deploy the Java web layer
cd web && mvn clean package
# copy the WAR to Tomcat's webapps/ directory
```

### Run the demonstrations

```bash
# Scripts live in tests/ (see docs/ for the demo script)
```

---

## Team

| Member | GitHub | Area | Responsibilities |
|---|---|---|---|
| **Muhammad Abuzar Thanvi** | [@abuzarthanvi25](https://github.com/abuzarthanvi25) | Java + Interface | Servlets/JSP, login and roles, restaurant search, booking/cancellation screens, group responses, waiting-list screens, status dashboard |
| **Muhammad Haroon Shahzad** | [@HaroonMalik771](https://github.com/HaroonMalik771) | Erlang/OTP | Supervised restaurant coordinators, table allocation, group holds, confirmations and expiry, waiting-list offers, worker restart and deadline recovery |
| **Ouballouk Mohamed** | [@username](https://github.com/username) | Persistence + Messaging | MySQL schema and transaction helpers, RabbitMQ request/reply, request deduplication, outbox publishing, Docker and multi-VM deployment |

All three members review transaction correctness, concurrency tests, integration and the final report.

---

## Course

*Distributed Systems and Middleware Technologies*, MSc, University of Pisa.
