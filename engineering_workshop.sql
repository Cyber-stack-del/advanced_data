DROP TABLE IF EXISTS tool_loans;
DROP TABLE IF EXISTS tools;

CREATE TABLE tools (
    tool_id SERIAL PRIMARY KEY,
    tool_name VARCHAR(100) NOT NULL,
    available_quantity INTEGER NOT NULL CHECK (available_quantity >= 0)
);

CREATE TABLE tool_loans (
    loan_id SERIAL PRIMARY KEY,
    tool_id INTEGER REFERENCES tools(tool_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

INSERT INTO tools (tool_name, available_quantity) VALUES
('Hammer', 10),
('Screwdriver', 3),
('Drill', 5);

-- IF ELSIF ELSE
DO $$
DECLARE
    amount INTEGER;
BEGIN
    SELECT available_quantity INTO amount
    FROM tools WHERE tool_id = 1;

    IF amount = 0 THEN
        RAISE NOTICE 'Tool unavailable';
    ELSIF amount <= 3 THEN
        RAISE NOTICE 'Tool low on stock';
    ELSE
        RAISE NOTICE 'Tool readily available';
    END IF;
END $$;

-- WHILE
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Workshop safety reminder %', i;
        i := i + 1;
    END LOOP;
END $$;

-- FOR
DO $$
DECLARE
    i INTEGER;
BEGIN
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Tool inspection %', i;
    END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE issue_tool(
    p_tool_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    stock INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero';
    END IF;

    SELECT available_quantity INTO stock
    FROM tools
    WHERE tool_id = p_tool_id
    FOR UPDATE;

    IF stock IS NULL THEN
        RAISE EXCEPTION 'Tool does not exist';
    END IF;

    IF stock < p_quantity THEN
        RAISE NOTICE 'Not enough tools available';
        RETURN;
    END IF;

    UPDATE tools
    SET available_quantity = available_quantity - p_quantity
    WHERE tool_id = p_tool_id;

    INSERT INTO tool_loans(tool_id, student_number, quantity)
    VALUES (p_tool_id, p_student_number, p_quantity);
END;
$$;

CALL issue_tool(1, 'STU001', 2);
CALL issue_tool(2, 'STU002', 1);
CALL issue_tool(2, 'STU003', 10);

SELECT * FROM tools;
SELECT * FROM tool_loans;

CREATE OR REPLACE PROCEDURE return_tool(p_loan_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    selected_tool INTEGER;
    amount INTEGER;
BEGIN
    SELECT tool_id, quantity INTO selected_tool, amount
    FROM tool_loans
    WHERE loan_id = p_loan_id AND status = 'ACTIVE';

    IF selected_tool IS NULL THEN
        RAISE NOTICE 'Loan already returned or does not exist';
        RETURN;
    END IF;

    UPDATE tools
    SET available_quantity = available_quantity + amount
    WHERE tool_id = selected_tool;

    UPDATE tool_loans
    SET status = 'RETURNED'
    WHERE loan_id = p_loan_id;
END;
$$;

CALL return_tool(1);
CALL return_tool(1);

-- Cursor
DO $$
DECLARE
    tool_cursor CURSOR FOR
        SELECT tool_name, available_quantity
        FROM tools
        WHERE available_quantity <= 3;
    r RECORD;
BEGIN
    OPEN tool_cursor;

    LOOP
        FETCH tool_cursor INTO r;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE 'Low availability: %, Quantity: %',
            r.tool_name, r.available_quantity;
    END LOOP;

    CLOSE tool_cursor;
END $$;

-- Exception
DO $$
BEGIN
    BEGIN
        CALL issue_tool(1, 'STU004', 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

SELECT * FROM tools ORDER BY tool_id;
SELECT * FROM tool_loans ORDER BY loan_id;