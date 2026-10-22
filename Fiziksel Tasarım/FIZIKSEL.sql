-- =========================================================================
-- VERİTABANI BAŞLATMA BETİĞİ
-- =========================================================================

CREATE DATABASE library_database;

-- Not: Veritabanı oluşturulduktan sonra, aşağıdaki komutları 
-- library_database veritabanına bağlanarak çalıştırmalısınız.

-- =========================================================================
-- 1. TABLOLAR
-- =========================================================================

CREATE TABLE PERSON (
    Person_ID SERIAL PRIMARY KEY,
    First_Name VARCHAR(50) NOT NULL,
    Last_Name VARCHAR(50) NOT NULL,
    Detailed_Address VARCHAR(255) NOT NULL,
    Zip_Code VARCHAR(20),
    Birth_Date DATE NOT NULL,
    Register_Date DATE NOT NULL
);

CREATE TABLE EMAIL (
    Email_ID SERIAL PRIMARY KEY,
    Person_ID INT NOT NULL,
    Email_Address VARCHAR(100) NOT NULL UNIQUE,
    FOREIGN KEY (Person_ID) REFERENCES PERSON(Person_ID) ON DELETE CASCADE
);

CREATE TABLE PHONE (
    Person_ID INT NOT NULL,
    Phone_Number VARCHAR(20) NOT NULL,
    PRIMARY KEY (Person_ID, Phone_Number),
    FOREIGN KEY (Person_ID) REFERENCES PERSON(Person_ID) ON DELETE CASCADE
);

CREATE TABLE MEMBER (
    Member_ID INT PRIMARY KEY,
    TC_ID VARCHAR(11) NOT NULL UNIQUE,
    Status VARCHAR(20) NOT NULL,
    FOREIGN KEY (Member_ID) REFERENCES PERSON(Person_ID) ON DELETE CASCADE
);

CREATE TABLE EMPLOYEE (
    Employee_ID INT PRIMARY KEY,
    TC_ID VARCHAR(11) NOT NULL UNIQUE,
    Hashed_Password VARCHAR(255) NOT NULL,
    Role VARCHAR(50) NOT NULL,
    FOREIGN KEY (Employee_ID) REFERENCES PERSON(Person_ID) ON DELETE CASCADE
);

CREATE TABLE PUBLISHER (
    Publisher_ID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Detailed_Address VARCHAR(255),
    Zip_Code VARCHAR(20),
    Phone VARCHAR(20)
);

CREATE TABLE AUTHOR (
    Author_ID SERIAL PRIMARY KEY,
    First_Name VARCHAR(50) NOT NULL,
    Last_Name VARCHAR(50) NOT NULL,
    Biography TEXT
);

CREATE TABLE CATEGORY (
    Category_ID SERIAL PRIMARY KEY,
    Category_Name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE SHELF (
    Shelf_ID SERIAL PRIMARY KEY,
    Shelf_No VARCHAR(20),
    Room_No VARCHAR(20)
);

CREATE TABLE BOOK (
    ISBN VARCHAR(20) PRIMARY KEY,
    Title VARCHAR(255) NOT NULL,
    Publish_Year INT NOT NULL,
    PG_Count INT CHECK (PG_Count > 0),
    Language VARCHAR(50) NOT NULL,
    Min_Allowed_Age INT CHECK (Min_Allowed_Age >= 0),
    Publisher_ID INT,
    FOREIGN KEY (Publisher_ID) REFERENCES PUBLISHER(Publisher_ID)
);

CREATE TABLE BOOK_AUTHORS (
    ISBN VARCHAR(20),
    Author_ID INT,
    PRIMARY KEY (ISBN, Author_ID),
    FOREIGN KEY (ISBN) REFERENCES BOOK(ISBN),
    FOREIGN KEY (Author_ID) REFERENCES AUTHOR(Author_ID)
);

CREATE TABLE BOOK_CATEGORIES (
    ISBN VARCHAR(20),
    Category_ID INT,
    PRIMARY KEY (ISBN, Category_ID),
    FOREIGN KEY (ISBN) REFERENCES BOOK(ISBN),
    FOREIGN KEY (Category_ID) REFERENCES CATEGORY(Category_ID)
);

CREATE TABLE BOOK_INSTANCE (
    Barcode VARCHAR(50) PRIMARY KEY,
    ISBN VARCHAR(20),
    Shelf_ID INT,
    Status VARCHAR(20) NOT NULL,
    FOREIGN KEY (ISBN) REFERENCES BOOK(ISBN),
    FOREIGN KEY (Shelf_ID) REFERENCES SHELF(Shelf_ID)
);

CREATE TABLE LOAN (
    Loan_ID SERIAL PRIMARY KEY,
    Member_ID INT,
    Employee_ID INT,
    Loan_Date DATE NOT NULL,
    Due_Date DATE NOT NULL,
    Daily_Late_Fee DECIMAL(10,2) NOT NULL CHECK (Daily_Late_Fee >= 0),
    CHECK (Due_Date >= Loan_Date),
    FOREIGN KEY (Member_ID) REFERENCES MEMBER(Member_ID),
    FOREIGN KEY (Employee_ID) REFERENCES EMPLOYEE(Employee_ID)
);

CREATE TABLE LOAN_DETAILS (
    Loan_ID INT,
    Barcode VARCHAR(50),
    Return_Date DATE,
    PRIMARY KEY (Loan_ID, Barcode),
    FOREIGN KEY (Loan_ID) REFERENCES LOAN(Loan_ID),
    FOREIGN KEY (Barcode) REFERENCES BOOK_INSTANCE(Barcode)
);

-- =========================================================================
-- 2. GÖRÜNÜMLER (VIEWS)
-- =========================================================================

CREATE VIEW v_active_loans AS
SELECT
    l.Loan_ID AS loan_id,
    l.Loan_Date AS loan_date,
    l.Due_Date AS due_date,
    l.Daily_Late_Fee AS daily_late_fee,
    ld.Barcode AS barcode,
    m.TC_ID AS member_tc,
    p.First_Name || ' ' || p.Last_Name AS member_name,
    (SELECT Email_Address FROM EMAIL e WHERE e.Person_ID = p.Person_ID LIMIT 1) AS member_email,
    m.Status AS member_status,
    b.ISBN AS isbn,
    b.Title AS book_title,
    b.Language AS book_language,
    bi.Status AS instance_status,
    CASE
        WHEN ld.Return_Date IS NOT NULL THEN 'RETURNED'
        WHEN CURRENT_DATE > l.Due_Date THEN 'OVERDUE'
        ELSE 'ACTIVE'
    END AS loan_status,
    CASE
        WHEN ld.Return_Date IS NULL AND CURRENT_DATE > l.Due_Date
        THEN CURRENT_DATE - l.Due_Date
        ELSE 0
    END AS days_overdue,
    CASE
        WHEN ld.Return_Date IS NULL AND CURRENT_DATE > l.Due_Date
        THEN (CURRENT_DATE - l.Due_Date) * l.Daily_Late_Fee
        ELSE 0
    END AS estimated_fine
FROM LOAN l
JOIN LOAN_DETAILS ld ON l.Loan_ID = ld.Loan_ID
JOIN MEMBER m ON l.Member_ID = m.Member_ID
JOIN PERSON p ON m.Member_ID = p.Person_ID
JOIN BOOK_INSTANCE bi ON ld.Barcode = bi.Barcode
JOIN BOOK b ON bi.ISBN = b.ISBN;

CREATE VIEW v_book_statistics AS
SELECT
    b.ISBN,
    b.Title AS title,
    b.Language,
    COUNT(DISTINCT bi.Barcode) AS total_stock,
    COUNT(DISTINCT CASE WHEN bi.Status = 'available' THEN bi.Barcode END) AS available_stock,
    COUNT(DISTINCT l.Loan_ID) AS total_loans,
    COUNT(DISTINCT CASE WHEN ld.Return_Date IS NULL THEN l.Loan_ID END) AS active_loans,
    COUNT(DISTINCT CASE WHEN ld.Return_Date IS NOT NULL THEN l.Loan_ID END) AS returned_loans,
    STRING_AGG(DISTINCT c.Category_Name, ', ') AS categories,
    STRING_AGG(DISTINCT a.First_Name || ' ' || a.Last_Name, ', ') AS authors
FROM BOOK b
LEFT JOIN BOOK_INSTANCE bi ON b.ISBN = bi.ISBN
LEFT JOIN LOAN_DETAILS ld ON bi.Barcode = ld.Barcode
LEFT JOIN LOAN l ON ld.Loan_ID = l.Loan_ID
LEFT JOIN BOOK_CATEGORIES bc ON b.ISBN = bc.ISBN
LEFT JOIN CATEGORY c ON bc.Category_ID = c.Category_ID
LEFT JOIN BOOK_AUTHORS ba ON b.ISBN = ba.ISBN
LEFT JOIN AUTHOR a ON ba.Author_ID = a.Author_ID
GROUP BY b.ISBN, b.Title, b.Language;

CREATE VIEW v_member_statistics AS
SELECT
    m.Member_ID,
    m.TC_ID AS tc_id,
    p.First_Name || ' ' || p.Last_Name AS full_name,
    (SELECT Email_Address FROM EMAIL e WHERE e.Person_ID = p.Person_ID LIMIT 1) AS email,
    m.Status AS status,
    p.Register_Date AS register_date,
    COUNT(l.Loan_ID) AS total_loans,
    COUNT(CASE WHEN ld.Return_Date IS NULL THEN 1 END) AS active_loans,
    COUNT(CASE WHEN ld.Return_Date IS NOT NULL THEN 1 END) AS returned_loans,
    SUM(CASE
        WHEN ld.Return_Date IS NOT NULL AND ld.Return_Date > l.Due_Date
        THEN (ld.Return_Date - l.Due_Date) * l.Daily_Late_Fee
        ELSE 0
    END) AS total_fines_paid
FROM MEMBER m
JOIN PERSON p ON m.Member_ID = p.Person_ID
LEFT JOIN LOAN l ON m.Member_ID = l.Member_ID
LEFT JOIN LOAN_DETAILS ld ON l.Loan_ID = ld.Loan_ID
GROUP BY m.Member_ID, p.Person_ID, m.TC_ID, p.First_Name, p.Last_Name, m.Status, p.Register_Date;

CREATE VIEW v_loan_eligibility AS
WITH MemberStats AS (
    SELECT
        m.Member_ID AS member_id,
        m.TC_ID AS tc_id,
        (p.First_Name || ' ' || p.Last_Name) AS member_name,
        m.Status AS member_status,
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.Birth_Date))::INTEGER AS member_age,
        (SELECT COUNT(*) FROM LOAN l2
         JOIN LOAN_DETAILS ld2 ON l2.Loan_ID = ld2.Loan_ID
         WHERE l2.Member_ID = m.Member_ID AND ld2.Return_Date IS NULL) AS member_active_loans
    FROM MEMBER m
    JOIN PERSON p ON m.Member_ID = p.Person_ID
),
BookStats AS (
    SELECT
        b.ISBN AS book_id,
        b.Title AS book_title,
        b.Min_Allowed_Age AS book_min_age,
        COUNT(DISTINCT bi.Barcode) AS total_stock,
        (SELECT COUNT(*) FROM LOAN l3
         JOIN LOAN_DETAILS ld3 ON l3.Loan_ID = ld3.Loan_ID
         JOIN BOOK_INSTANCE bi3 ON ld3.Barcode = bi3.Barcode
         WHERE bi3.ISBN = b.ISBN AND ld3.Return_Date IS NULL) AS loaned_count
    FROM BOOK b
    LEFT JOIN BOOK_INSTANCE bi ON b.ISBN = bi.ISBN
    GROUP BY b.ISBN, b.Title, b.Min_Allowed_Age
)
SELECT
    ms.member_id,
    ms.tc_id,
    ms.member_name,
    ms.member_status,
    ms.member_age,
    bs.book_id,
    bs.book_title,
    bs.book_min_age,
    bs.total_stock,
    bs.loaned_count,
    (bs.total_stock - bs.loaned_count) AS available_copies,
    ms.member_active_loans,
    CASE
        WHEN ms.member_status IN ('inactive', 'penalty') THEN 0
        WHEN bs.loaned_count >= bs.total_stock THEN 0
        WHEN ms.member_age < bs.book_min_age THEN 0
        WHEN ms.member_active_loans >= 5 THEN 0
        ELSE 1
    END AS is_eligible,
    CASE
        WHEN ms.member_status = 'inactive' THEN 'Üye aktif değil'
        WHEN ms.member_status = 'penalty' THEN 'Üyenin cezası bulunmaktadır'
        WHEN bs.loaned_count >= bs.total_stock THEN 'Kitap stokta bulunmamaktadır'
        WHEN ms.member_age < bs.book_min_age THEN 'Üyenin yaşı bu kitabı almak için yeterli değildir'
        WHEN ms.member_active_loans >= 5 THEN 'Üye maksimum ödünç limitine ulaşmıştır'
        ELSE 'Uygun'
    END AS eligibility_message
FROM MemberStats ms
CROSS JOIN BookStats bs;

-- =========================================================================
-- 3. TETİKLEYİCİLER (TRIGGERS) VE FONKSİYONLAR
-- =========================================================================

CREATE FUNCTION fn_update_book_status_on_loan()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE BOOK_INSTANCE
    SET Status = 'loaned'
    WHERE Barcode = NEW.Barcode;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_book_status_on_loan
AFTER INSERT ON LOAN_DETAILS
FOR EACH ROW
EXECUTE FUNCTION fn_update_book_status_on_loan();


CREATE FUNCTION fn_update_book_status_on_return()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE BOOK_INSTANCE
    SET Status = 'available'
    WHERE Barcode = NEW.Barcode;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_book_status_on_return
AFTER UPDATE OF Return_Date ON LOAN_DETAILS
FOR EACH ROW
WHEN (NEW.Return_Date IS NOT NULL AND OLD.Return_Date IS NULL)
EXECUTE FUNCTION fn_update_book_status_on_return();


CREATE FUNCTION fn_check_return_date_validity()
RETURNS TRIGGER AS $$
DECLARE
    v_loan_date DATE;
BEGIN
    IF NEW.Return_Date IS NOT NULL THEN
        SELECT Loan_Date INTO v_loan_date
        FROM LOAN
        WHERE Loan_ID = NEW.Loan_ID;

        IF NEW.Return_Date < v_loan_date THEN
            RAISE EXCEPTION 'İade Tarihi (%) Ödünç Alma Tarihinden (%) daha eski olamaz. Ödünç ID: %',
                            NEW.Return_Date, v_loan_date, NEW.Loan_ID;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_return_date_validity
BEFORE INSERT OR UPDATE ON LOAN_DETAILS
FOR EACH ROW
EXECUTE FUNCTION fn_check_return_date_validity();

-- =========================================================================
-- 4. SAKLI YORDAMLAR (STORED PROCEDURES) VE İŞLEMLER (TRANSACTIONS)
-- =========================================================================

CREATE PROCEDURE sp_kitap_odunc_ver(
    p_member_id INT,
    p_employee_id INT,
    p_barcode VARCHAR(50),
    p_daily_late_fee DECIMAL(10,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_status VARCHAR(20);
    v_member_status VARCHAR(20);
    v_loan_id INT;
BEGIN
    -- 1. Üyenin durumunu kontrol et
    SELECT Status INTO v_member_status FROM MEMBER WHERE Member_ID = p_member_id;
    
    IF v_member_status = 'penalty' THEN
        RAISE EXCEPTION 'Üye cezalı durumda. Kitap ödünç verilemez.';
    ELSIF v_member_status = 'inactive' THEN
        RAISE EXCEPTION 'Üye aktif değil. Kitap ödünç verilemez.';
    END IF;

    -- 2. Kitabın durumunu kontrol et
    SELECT Status INTO v_book_status FROM BOOK_INSTANCE WHERE Barcode = p_barcode;
    
    IF v_book_status != 'available' THEN
        RAISE EXCEPTION 'Kitap şu anda rafta değil (Durum: %).', v_book_status;
    END IF;

    -- 3. Ana ödünç kaydını oluştur (Transaction Başlıyor)
    INSERT INTO LOAN (Member_ID, Employee_ID, Loan_Date, Due_Date, Daily_Late_Fee)
    VALUES (p_member_id, p_employee_id, CURRENT_DATE, CURRENT_DATE + INTERVAL '14 days', p_daily_late_fee)
    RETURNING Loan_ID INTO v_loan_id;

    -- 4. Ödünç detayını ekle
    INSERT INTO LOAN_DETAILS (Loan_ID, Barcode, Return_Date)
    VALUES (v_loan_id, p_barcode, NULL);

    -- Not: trg_update_book_status_on_loan TRIGGER'ı kitabı otomatik 'loaned' yapacak.
    
    -- 5. İşlemleri onayla
    COMMIT;
END;
$$;