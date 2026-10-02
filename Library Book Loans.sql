-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 1: University Library Book Loans

DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;

-- 1. Create tables and add at least three books

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    available_copies INTEGER NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INTEGER REFERENCES books(book_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL,
    loan_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

INSERT INTO books (title, available_copies) VALUES
('Database Systems', 5),
('Computer Networks', 2),
('Software Engineering', 10);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    copies INTEGER;
BEGIN
    SELECT available_copies INTO copies
    FROM books
    WHERE book_id = 1;

    IF copies = 0 THEN
        RAISE NOTICE 'Book is unavailable';
    ELSIF copies <= 2 THEN
        RAISE NOTICE 'Book is low on copies';
    ELSE
        RAISE NOTICE 'Book is sufficiently stocked';
    END IF;
END $$;

-- 3. WHILE loop: overdue reminders
DO $$
DECLARE
    counter INTEGER := 1;
BEGIN
    WHILE counter <= 3 LOOP
        RAISE NOTICE 'Overdue reminder number %', counter;
        counter := counter + 1;
    END LOOP;
END $$;

-- Numeric FOR loop: library shelf numbers
DO $$
DECLARE
    shelf INTEGER;
BEGIN
    FOR shelf IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number: %', shelf;
    END LOOP;
END $$;

-- 4. borrow_book procedure
CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    copies INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero';
    END IF;

    SELECT available_copies
    INTO copies
    FROM books
    WHERE book_id = p_book_id
    FOR UPDATE;

    IF copies IS NULL THEN
        RAISE EXCEPTION 'Book does not exist';
    END IF;

    IF copies < p_quantity THEN
        RAISE NOTICE 'Not enough copies available';
        RETURN;
    END IF;

    UPDATE books
    SET available_copies = available_copies - p_quantity
    WHERE book_id = p_book_id;

    INSERT INTO book_loans(book_id, student_number, quantity, loan_status)
    VALUES (p_book_id, p_student_number, p_quantity, 'ACTIVE');

    RAISE NOTICE 'Book borrowed successfully';
END;
$$;

-- 5. Two valid loans + one exceeding available copies

CALL borrow_book(1, 'STU001', 2);
CALL borrow_book(2, 'STU002', 1);
CALL borrow_book(2, 'STU003', 5);

SELECT * FROM books;
SELECT * FROM book_loans;

-- 6. return_book procedure
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    returned_quantity INTEGER;
    selected_book INTEGER;
BEGIN
    SELECT book_id, quantity
    INTO selected_book, returned_quantity
    FROM book_loans
    WHERE loan_id = p_loan_id
      AND loan_status = 'ACTIVE';

    IF selected_book IS NULL THEN
        RAISE NOTICE 'Loan already returned or does not exist';
        RETURN;
    END IF;

    UPDATE books
    SET available_copies = available_copies + returned_quantity
    WHERE book_id = selected_book;

    UPDATE book_loans
    SET loan_status = 'RETURNED'
    WHERE loan_id = p_loan_id;

    RAISE NOTICE 'Book returned successfully';
END;
$$;

-- Call twice for the same loan
CALL return_book(1);
CALL return_book(1);

-- 7. Explicit cursor: books with few copies
DO $$
DECLARE
    book_cursor CURSOR FOR
        SELECT title, available_copies
        FROM books
        WHERE available_copies <= 2;

    book_record RECORD;
BEGIN
    OPEN book_cursor;

    LOOP
        FETCH book_cursor INTO book_record;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE 'Low stock book: %, Copies: %',
            book_record.title,
            book_record.available_copies;
    END LOOP;

    CLOSE book_cursor;
END $$;

-- 8. Try to borrow zero copies and handle exception
DO $$
BEGIN
    BEGIN
        CALL borrow_book(1, 'STU004', 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

-- 9. Final queries
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;