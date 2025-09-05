SET SERVEROUTPUT ON;

------------------------------------------------------------------
--Trigger to log all inventory changes

-- If you already have rows and want to start after the max numeric part:
-- SELECT NVL(MAX(TO_NUMBER(REGEXP_SUBSTR(audit_id,'\d+$'))),0) + 1 AS next_start FROM audit_trail;

-- Create the sequence (adjust START WITH if needed):
CREATE SEQUENCE audit_trail_seq
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;


CREATE OR REPLACE TRIGGER trg_log_inventory_changes
AFTER INSERT OR UPDATE OR DELETE ON INVENTORY_MASTER
FOR EACH ROW
DECLARE
  v_old_values CLOB;
  v_new_values CLOB;
  v_operation  VARCHAR2(10);
BEGIN
  IF INSERTING THEN
    v_operation := 'INSERT';
  ELSIF UPDATING THEN
    v_operation := 'UPDATE';
  ELSE
    v_operation := 'DELETE';
  END IF;

  IF DELETING OR UPDATING THEN
    v_old_values := 'Product ID=' || :OLD.product_id ||
                    ', Location ID=' || :OLD.location_id ||
                    ', Current Stock=' || :OLD.current_stock ||
                    ', Reorder Level=' || :OLD.reorder_level ||
                    ', Max Stock Level=' || :OLD.max_stock_level ||
                    ', Safety Stock=' || :OLD.safety_stock ||
                    ', Last Movement=' || TO_CHAR(:OLD.last_movement,'YYYY-MM-DD') ||
                    ', Unit Cost=' || :OLD.unit_cost;
  END IF;

  IF INSERTING OR UPDATING THEN
    v_new_values := 'Product ID=' || :NEW.product_id ||
                    ', Location ID=' || :NEW.location_id ||
                    ', Current Stock=' || :NEW.current_stock ||
                    ', Reorder Level=' || :NEW.reorder_level ||
                    ', Max Stock Level=' || :NEW.max_stock_level ||
                    ', Safety Stock=' || :NEW.safety_stock ||
                    ', Last Movement=' || TO_CHAR(:NEW.last_movement,'YYYY-MM-DD') ||
                    ', Unit Cost=' || :NEW.unit_cost;
  END IF;

  INSERT INTO AUDIT_TRAIL (
    AUDIT_ID, TABLE_NAME, OPERATION_TYPE, OLD_VALUES, NEW_VALUES, CHANGED_BY, CHANGE_DATE
  )
  VALUES (
    'AUD-' || LPAD(audit_trail_seq.NEXTVAL, 12, '0'),
    'INVENTORY_MASTER',
    v_operation,
    v_old_values,
    v_new_values,
    SYS_CONTEXT('USERENV','SESSION_USER'),
    SYSDATE
  );
END;
/


--TO CHECK
ALTER TABLE AUDIT_TRAIL
MODIFY AUDIT_ID VARCHAR2(30);

select * from inventory_master;
select * from locations;
SELECT MAX(inventory_id) FROM inventory_master;
SELECT product_id, location_id
FROM INVENTORY_MASTER
WHERE product_id = 'RAW-CER-108';
-------------------------------------------
--INSERTION
INSERT INTO INVENTORY_MASTER (
    inventory_id, product_id, location_id, current_stock,
    reorder_level, max_stock_level, safety_stock,
    last_movement, unit_cost
) VALUES (
    'INV-00500', -- inventory_id
    'RAW-CER-108',
    'DEL-002',
    100,
    50,
    200,
    20,
    SYSDATE,
    10
);
rollback;
-- Check the audit log
SELECT * FROM AUDIT_TRAIL
WHERE TABLE_NAME = 'INVENTORY_MASTER'
ORDER BY CHANGE_DATE DESC;
-------------------------------------------
--UPDATION
UPDATE INVENTORY_MASTER
SET current_stock = current_stock + 10
WHERE product_id = 'RAW-CER-108'
  AND location_id = 'OSA-002';



-- Check the audit log
SELECT * FROM AUDIT_TRAIL
WHERE TABLE_NAME = 'INVENTORY_MASTER'
ORDER BY CHANGE_DATE DESC;
-----------------------------------------
--DELETE
DELETE FROM INVENTORY_MASTER
WHERE product_id = 'RAW-CER-108'
  AND location_id = 'OSA-002';


-- Check the audit log
SELECT * FROM AUDIT_TRAIL
WHERE TABLE_NAME = 'INVENTORY_MASTER'
ORDER BY CHANGE_DATE DESC;

ROLLBACK;

--------------------------------------------------------
-- Trigger to update last movement date
CREATE OR REPLACE TRIGGER trg_update_last_movement
AFTER INSERT OR UPDATE ON INVENTORY_TRANSACTIONS
FOR EACH ROW
BEGIN
    UPDATE INVENTORY_MASTER
    SET last_movement = SYSDATE
    WHERE product_id = :NEW.product_id
      AND location_id = :NEW.location_id;
END;


--CHECKING
-- Update an existing transaction
SELECT * FROM INVENTORY_TRANSACTIONS;
SELECT * FROM INVENTORY_MASTER;

UPDATE INVENTORY_TRANSACTIONS
SET quantity = quantity + 5
WHERE transaction_id = 'TXN-01183'


SELECT product_id, location_id, last_movement
FROM INVENTORY_MASTER
WHERE product_id = 'BRA-BRA-016'
  AND location_id = 'FRA-003';



SELECT im.product_id,
       im.location_id
FROM INVENTORY_MASTER im
INNER JOIN INVENTORY_TRANSACTIONS it
   ON im.product_id = it.product_id
  AND im.location_id = it.location_id
ORDER BY im.product_id, im.location_id;

SELECT transaction_id, product_id, location_id, quantity, transaction_type, transaction_date
FROM INVENTORY_TRANSACTIONS
WHERE product_id = 'BRA-BRA-016'
  AND location_id = 'FRA-003';
  
ROLLBACK;
----------------------------------------------------
-- Trigger to validate stock quantities

-------------------------------------------------

CREATE OR REPLACE TRIGGER trg_validate_stock_quantity
BEFORE INSERT OR UPDATE ON INVENTORY_TRANSACTIONS
FOR EACH ROW
DECLARE
    v_current_stock NUMBER;
    v_new_stock     NUMBER;
    v_max_stock     NUMBER;
    v_safety_stock  NUMBER;
BEGIN
    SELECT current_stock, max_stock_level, safety_stock
    INTO v_current_stock, v_max_stock, v_safety_stock
    FROM INVENTORY_MASTER
    WHERE product_id = :NEW.product_id
      AND location_id = :NEW.location_id;

    -- Calculate new stock based on transaction type
    IF :NEW.transaction_type = 'RECEIPT' THEN
        v_new_stock := v_current_stock + :NEW.quantity;
    ELSIF :NEW.transaction_type = 'ISSUE' THEN
        v_new_stock := v_current_stock - ABS(:NEW.quantity);
    ELSIF :NEW.transaction_type = 'TRANSFER' THEN
        v_new_stock := v_current_stock + :NEW.quantity; -- Negative for OUT, positive for IN
    ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Invalid transaction type.');
    END IF;

    -- Validate negative stock
    IF v_new_stock < 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Insufficient stock: resulting stock would be negative.');
    END IF;

    -- Validate max stock level
    IF v_new_stock > v_max_stock THEN
        RAISE_APPLICATION_ERROR(-20003, 'Stock exceeds maximum allowed level.');
    END IF;

    -- Validate safety stock for outflows
    IF :NEW.transaction_type IN ('ISSUE', 'TRANSFER') AND v_new_stock < v_safety_stock THEN
        RAISE_APPLICATION_ERROR(-20004, 'Transaction would reduce stock below safety stock level.');
    END IF;
END;
/
--------------------------------
--TESTING
-- TXN-TEST-01: BRA-BRA-080 @ FRA-003 (initially TRANSFER -100)
INSERT INTO INVENTORY_TRANSACTIONS (
    transaction_id, product_id, location_id, transaction_type, quantity,
    unit_cost, transaction_date, reference_no,created_by
) VALUES (
    'TXN-TEST-01', 'BRA-BRA-080', 'FRA-003', 'TRANSFER', -100,
    1336.54, TO_DATE('2025-08-01','YYYY-MM-DD'), 'PO-TEST01', 'Vinay Kumarr'
);

---Test 1: Valid TRANSFER (OUT) within limits
-- Should PASS (Stock: 3362 - 100 = 3262 > safety)
UPDATE INVENTORY_TRANSACTIONS
SET quantity = -100
WHERE transaction_id = 'TXN-TEST-01';

--Test 2: TRANSFER (OUT) goes below safety stock
-- Should FAIL (-20004): 3362 - 3050 = 312 < 342
UPDATE INVENTORY_TRANSACTIONS
SET quantity = -3050
WHERE transaction_id = 'TXN-TEST-01';

--Test 3: TRANSFER (OUT) goes negative
-- Should FAIL (-20002): 3362 - 4000 = -638
UPDATE INVENTORY_TRANSACTIONS
SET quantity = -4000
WHERE transaction_id = 'TXN-TEST-01';

-- Test 4: TRANSFER (IN) within max level
-- Should PASS: 3362 + 500 = 3862 < 5224
UPDATE INVENTORY_TRANSACTIONS
SET quantity = 500
WHERE transaction_id = 'TXN-TEST-01';

-- Test 5: TRANSFER (IN) exceeds max stock
-- Should FAIL (-20003): 3362 + 2500 = 5862 > 5224
UPDATE INVENTORY_TRANSACTIONS
SET quantity = 2500
WHERE transaction_id = 'TXN-TEST-01';

--Test 6: Invalid transaction type
-- Should FAIL (-20001)
UPDATE INVENTORY_TRANSACTIONS
SET transaction_type = 'INVALID'
WHERE transaction_id = 'TXN-TEST-01';

-- Test 7: Valid ISSUE
-- Should PASS: 3362 - 500 = 2862 > safety
UPDATE INVENTORY_TRANSACTIONS
SET transaction_type = 'ISSUE',
    quantity = -500
WHERE transaction_id = 'TXN-TEST-01';

-- Test 8: ISSUE below safety
-- Should FAIL (-20004): 3362 - 3100 = 262 < 342
UPDATE INVENTORY_TRANSACTIONS
SET transaction_type = 'ISSUE',
    quantity = -3100
WHERE transaction_id = 'TXN-TEST-01';

--Test 9: ISSUE goes negative

-- Should FAIL (-20002): 3362 - 5000 = -1638
UPDATE INVENTORY_TRANSACTIONS
SET transaction_type = 'ISSUE',
    quantity = -5000
WHERE transaction_id = 'TXN-TEST-01';

--Test 10: Valid RECEIPT within limits
-- Should PASS: 3362 + 1000 = 4362 < 5224
UPDATE INVENTORY_TRANSACTIONS
SET transaction_type = 'RECEIPT',
    quantity = 1000
WHERE transaction_id = 'TXN-TEST-01';

-- Test 11: RECEIPT exceeds max
-- Should FAIL (-20003): 3362 + 3000 = 6362 > 5224
UPDATE INVENTORY_TRANSACTIONS
SET transaction_type = 'RECEIPT',
    quantity = 3000
WHERE transaction_id = 'TXN-TEST-01';



SELECT * FROM  INVENTORY_TRANSACTIONS
DESC INVENTORY_TRANSACTIONS;

-----------------------------------


SELECT im.product_id,
       im.location_id
FROM INVENTORY_MASTER im
INNER JOIN INVENTORY_TRANSACTIONS it
   ON im.product_id = it.product_id
  AND im.location_id = it.location_id
ORDER BY im.product_id, im.location_id;

SELECT transaction_id, product_id, location_id, quantity, transaction_type, transaction_date
FROM INVENTORY_TRANSACTIONS
WHERE product_id = 'BRA-BRA-080'
  AND location_id ='FRA-003';

ROLLBACK;

-----------------------------------------------------


SELECT * FROM  INVENTORY_TRANSACTIONS WHERE TRANSACTION_ID='TXN-01183';
---------------------------------------------

