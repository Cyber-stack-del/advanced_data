DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INTEGER NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100) NOT NULL,
    workstations INTEGER NOT NULL,
    reservation_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
('Database Practical', 30),
('Programming Practical', 10),
('Networking Practical', 20);

-- IF ELSIF ELSE
DO $$
DECLARE
    seats INTEGER;
BEGIN
    SELECT available_workstations INTO seats
    FROM lab_sessions
    WHERE session_id = 1;

    IF seats = 0 THEN
        RAISE NOTICE 'Session is full';
    ELSIF seats <= 10 THEN
        RAISE NOTICE 'Session is nearly full';
    ELSE
        RAISE NOTICE 'Session has enough workstations';
    END IF;
END $$;

-- WHILE
DO $$
DECLARE
    day INTEGER := 1;
BEGIN
    WHILE day <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder %', day;
        day := day + 1;
    END LOOP;
END $$;

-- FOR
DO $$
DECLARE
    workstation INTEGER;
BEGIN
    FOR workstation IN 1..3 LOOP
        RAISE NOTICE 'Workstation check %', workstation;
    END LOOP;
END $$;

-- Procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INTEGER,
    p_lecturer VARCHAR,
    p_workstations INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    available INTEGER;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Number of workstations must be greater than zero';
    END IF;

    SELECT available_workstations INTO available
    FROM lab_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF available IS NULL THEN
        RAISE EXCEPTION 'Session does not exist';
    END IF;

    IF available < p_workstations THEN
        RAISE NOTICE 'Not enough workstations available';
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations - p_workstations
    WHERE session_id = p_session_id;

    INSERT INTO reservations(session_id, lecturer, workstations)
    VALUES (p_session_id, p_lecturer, p_workstations);

    RAISE NOTICE 'Reservation successful';
END;
$$;

CALL reserve_workstations(1, 'Dr Banda', 10);
CALL reserve_workstations(2, 'Dr Phiri', 5);
CALL reserve_workstations(2, 'Dr Zulu', 20);

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- Cancel procedure
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    selected_session INTEGER;
    reserved_amount INTEGER;
BEGIN
    SELECT session_id, workstations
    INTO selected_session, reserved_amount
    FROM reservations
    WHERE reservation_id = p_reservation_id
      AND reservation_status = 'ACTIVE';

    IF selected_session IS NULL THEN
        RAISE NOTICE 'Reservation already cancelled or does not exist';
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations =
        available_workstations + reserved_amount
    WHERE session_id = selected_session;

    UPDATE reservations
    SET reservation_status = 'CANCELLED'
    WHERE reservation_id = p_reservation_id;
END;
$$;

CALL cancel_reservation(1);
CALL cancel_reservation(1);

-- Cursor
DO $$
DECLARE
    session_cursor CURSOR FOR
        SELECT session_name, available_workstations
        FROM lab_sessions
        WHERE available_workstations <= 10;
    r RECORD;
BEGIN
    OPEN session_cursor;

    LOOP
        FETCH session_cursor INTO r;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE 'Low availability: %, Workstations: %',
            r.session_name, r.available_workstations;
    END LOOP;

    CLOSE session_cursor;
END $$;

-- Exception
DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(1, 'Dr Test', 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid workstation quantity handled: %', SQLERRM;
    END;
END $$;

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;