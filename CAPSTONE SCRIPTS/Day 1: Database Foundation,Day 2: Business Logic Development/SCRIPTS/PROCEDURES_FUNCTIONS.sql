------------Procedures----------------------------------------------------------
SET SERVEROUTPUT ON;
--Procedure to check reorder levels

--Scheduler for updates on reorder levels(daily)
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'JOB_CHECK_REORDER',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'prc_check_reorder_levels',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=9; BYMINUTE=0; BYSECOND=0', -- runs daily at 9 AM
        enabled         => TRUE,
        comments        => 'Job to check inventory reorder levels and alert'
    );
END;

--To see the scheduled jobs:
SELECT job_name, enabled, state
FROM dba_scheduler_jobs
WHERE job_name = 'JOB_CHECK_REORDER';

--shows the run history of scheduler
SELECT job_name,
       status,
       actual_start_date,
       run_duration,
       log_date
FROM   dba_scheduler_job_run_details
WHERE  job_name = 'JOB_CHECK_REORDER'
ORDER BY actual_start_date DESC;


CREATE OR REPLACE PROCEDURE prc_check_reorder_levels
IS
BEGIN
    FOR rec IN (
        SELECT 
            im.product_id,
            p.product_name,
            im.location_id,
            l.location_name,
            im.current_stock,
            im.reorder_level
        FROM inventory_master im
        JOIN products p ON im.product_id = p.product_id
        JOIN locations l ON im.location_id = l.location_id
        WHERE im.current_stock <= im.reorder_level
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE(
            'Product: ' || rec.product_id || ' - ' || rec.product_name ||
            ' at Location: ' || rec.location_id || ' - ' || rec.location_name ||
            ' needs replenishment. Current stock: ' || rec.current_stock ||
            ', Reorder level: ' || rec.reorder_level
        );

     END LOOP;
END;

exec  prc_check_reorder_levels;
--------------------------------------------------------------------------------

--Procedure to transfer stock between locations
CREATE SEQUENCE seq_transfer_num
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE OR REPLACE PROCEDURE prc_transfer_stock_between_locations(
    p_product_id    IN VARCHAR2,
    p_from_location IN VARCHAR2,
    p_to_location   IN VARCHAR2,
    p_quantity      IN NUMBER,
    p_approved_by   IN VARCHAR2
)
IS
    v_from_stock   NUMBER;
    v_safety_stock NUMBER;
    v_to_stock     NUMBER;
    v_max_stock    NUMBER;
BEGIN
    -- Step 1: Get stock & safety stock for source location
    SELECT current_stock, safety_stock
    INTO v_from_stock, v_safety_stock
    FROM inventory_master
    WHERE product_id = p_product_id
      AND location_id = p_from_location;

    -- Step 2: Ensure enough stock remains after transfer
    IF v_from_stock - p_quantity < v_safety_stock THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'Not enough stock to transfer while maintaining safety stock.');
    END IF;

    -- Step 3: Validate destination location has this product
    BEGIN
        SELECT current_stock, max_stock_level
        INTO v_to_stock, v_max_stock
        FROM inventory_master
        WHERE product_id = p_product_id
          AND location_id = p_to_location;

        -- Step 4: Ensure destination won't exceed max stock level
        IF v_to_stock + p_quantity > v_max_stock THEN
            RAISE_APPLICATION_ERROR(-20004, 
                'Destination location exceeds max stock capacity.');
        END IF;

        -- Step 5: Deduct stock from source location
        UPDATE inventory_master
        SET current_stock = current_stock - p_quantity,
            last_movement = SYSDATE
        WHERE product_id = p_product_id
          AND location_id = p_from_location;

        -- Step 6: Add stock to destination location
        UPDATE inventory_master
        SET current_stock = current_stock + p_quantity,
            last_movement = SYSDATE
        WHERE product_id = p_product_id
          AND location_id = p_to_location;

        -- Step 7: Log transfer in stock_transfers
        INSERT INTO stock_transfers (
            transfer_id, product_id, from_location, to_location, 
            quantity, transfer_date, status, approved_by
        )
        VALUES (
            'TRAN-' || LPAD(seq_transfer_num.NEXTVAL, 3, '0'),
            p_product_id, p_from_location, p_to_location, 
            p_quantity, SYSDATE, 'COMPLETED', p_approved_by
        );

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 
                'Destination location does not have this product.');
    END;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 
            'Source location does not have this product.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;

--TESTING
SELECT * FROM INVENTORY_MASTER;

--FROM LOCATION
SELECT * FROM INVENTORY_MASTER WHERE PRODUCT_ID='QUA-THE-076'
AND LOCATION_ID='DAL-003';--INVENTORY_ID=INV-00019

--TO LOCATION
SELECT * FROM INVENTORY_MASTER WHERE PRODUCT_ID='QUA-THE-076'
AND LOCATION_ID='NEW-001';--INVENTORY_ID=INV-00012

--Valid test case

BEGIN
    prc_transfer_stock_between_locations(
        p_product_id    => 'QUA-THE-076',
        p_from_location => 'DAL-003',
        p_to_location   => 'NEW-001',
        p_quantity      => 200,
        p_approved_by   => 'Manager01'
    );
END;
------------------------------------------------------
--Insufficient stock (safety stock breach)
BEGIN
    prc_transfer_stock_between_locations(
        p_product_id    => 'RAW-CER-108',
        p_from_location => 'OSA-002',
        p_to_location   => 'BAN-001',
        p_quantity      => 3600, -- Leaves 244 < safety stock 355
        p_approved_by   => 'Manager01'
    );
END;
--------------------------------------------------------------
--Destination product does not exist
BEGIN
    prc_transfer_stock_between_locations(
        p_product_id    => 'RAW-CER-108',
        p_from_location => 'OSA-002',
        p_to_location   => 'XXX-001', -- Non-existent location
        p_quantity      => 50,
        p_approved_by   => 'Manager03'
    );
END;
--------------------------------------------
-- Check updated stock
SELECT * FROM inventory_master
WHERE product_id = 'QUA-THE-076'
  AND location_id IN ('DAL-003', 'NEW-001');

-- Check transfer log
SELECT * FROM stock_transfers
ORDER BY transfer_date DESC;

ROLLBACK;
----------------------------------------------------------------------------------------------
--Function to calculate stock value
create or replace function calculate_stock_value(p_product_id  varchar2, p_location_id  varchar2) 
return number
is
v_stock_value number := 0;
begin
select current_stock * unit_cost into v_stock_value from inventory_master
where product_id = p_product_id and location_id = p_location_id;
return v_stock_value;
exception
when no_data_found then
return 0;
when others then
return null; -- or raise_application_error with a message
end;
--------------------------------
--TESTING

SELECT calculate_stock_value('RAW-CER-108', 'OSA-002') AS stock_value
FROM dual;


DECLARE
v_value NUMBER;
BEGIN
v_value := calculate_stock_value('RAW-CER-108', 'OSA-002');
DBMS_OUTPUT.PUT_LINE('Stock Value = ' || v_value);
END;
---------------------------------------------------------------------------------------------------------
-- Function to get supplier performance rating
CREATE OR REPLACE FUNCTION get_supplier_performance_rating (
    p_supplier_id   VARCHAR2,
    p_month_year    VARCHAR2 DEFAULT NULL -- format 'Mon-YY' e.g. 'Jun-25'
) RETURN NUMBER
IS
    v_final_rating  NUMBER;
BEGIN
    SELECT 
        ROUND(
            (AVG(quality_rating) * 0.5) +
            (AVG(CASE WHEN delivery_date <= promised_date THEN 100 ELSE 0 END) * 0.3 / 100) +
            (AVG((qty_delivered - qty_rejected) / NULLIF(qty_delivered,0) * 100) * 0.2 / 100)
        , 2) 
    INTO v_final_rating
    FROM supplier_performance
    WHERE supplier_id = p_supplier_id
      AND (p_month_year IS NULL OR performance_month = p_month_year);

    RETURN v_final_rating;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END;
--------------------------------------------------
--TESTING
--The calculation is running correctly based on your weighting logic 
--(50% quality rating, 30% delivery on time, 20% acceptance rate)

UPDATE supplier_performance
SET performance_month = TO_CHAR(TO_DATE(performance_month, 'MM/YYYY'), 'Mon-YY');

DESC SUPPLIER_PERFORMANCE;
SELECT * FROM SUPPLIER_PERFORMANCE;

--Test for a specific supplier & month
SELECT get_supplier_performance_rating('SUP-009', 'Jun-25') AS rating
FROM dual;

--Test for a supplier across all months
SELECT get_supplier_performance_rating('SUP-014') AS rating
FROM dual;

--Multiple suppliers test
SELECT supplier_id,
       get_supplier_performance_rating(supplier_id, 'Jun-25') AS rating
FROM (SELECT DISTINCT supplier_id FROM supplier_performance)
ORDER BY supplier_id;

ROLLBACK;
