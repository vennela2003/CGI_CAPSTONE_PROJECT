
-- Insert sample PO_LINE_ITEMS
INSERT INTO po_line_items (line_id, po_number, product_id, quantity, unit_price)
VALUES ('LINE-00001', 'PO-2025-001', 'QUA-FEE-117', 328, 1896.63);

INSERT INTO po_line_items (line_id, po_number, product_id, quantity, unit_price)
VALUES ('LINE-00002', 'PO-2025-002', 'BRA-BRA-081', 248, 3503.59);

INSERT INTO po_line_items (line_id, po_number, product_id, quantity, unit_price)
VALUES ('LINE-00003', 'PO-2025-003', 'QUA-IMP-035', 100, 2626.90);

INSERT INTO po_line_items (line_id, po_number, product_id, quantity, unit_price)
VALUES ('LINE-00004', 'PO-2025-004', 'CAB-STE-018', 13, 2272.16);

INSERT INTO po_line_items (line_id, po_number, product_id, quantity, unit_price)
VALUES ('LINE-00005', 'PO-2025-005', 'TOO-CLA-078', 136, 3206.77);

INSERT INTO po_line_items (line_id, po_number, product_id, quantity, unit_price)
VALUES ('LINE-00006', 'PO-2025-006', 'PLA-DOO-052', 84, 1007.95);

INSERT INTO po_line_items (line_id, po_number, product_id, quantity, unit_price)
VALUES ('LINE-00007', 'PO-2025-007', 'LIG-GLO-068', 272, 3562.14);

--Package for supplier performance calculations

CREATE OR REPLACE PACKAGE supplier_rating_pkg AS
    PROCEDURE rate_suppliers(p_supplier_id IN VARCHAR2 DEFAULT NULL);
END supplier_rating_pkg;
/

CREATE OR REPLACE PACKAGE BODY supplier_rating_pkg AS

    PROCEDURE rate_suppliers(p_supplier_id IN VARCHAR2 DEFAULT NULL) IS
        CURSOR cur_suppliers IS
            SELECT sp.supplier_id,
                   s.supplier_name,
                   ROUND(AVG(
                         ((sp.quality_rating / 5) * 100) * 0.4
                       + (CASE
                            WHEN sp.delivery_date <= sp.promised_date THEN 100
                            WHEN sp.delivery_date <= sp.promised_date + 2 THEN 80
                            WHEN sp.delivery_date <= sp.promised_date + 5 THEN 50
                            ELSE 0
                          END) * 0.3
                       + (((sp.qty_delivered - sp.qty_rejected) / NULLIF(sp.qty_delivered, 0)) * 100) * 0.3
                   ), 2) AS avg_score
            FROM supplier_performance sp
            JOIN suppliers s
              ON sp.supplier_id = s.supplier_id
            WHERE p_supplier_id IS NULL OR sp.supplier_id = p_supplier_id
            GROUP BY sp.supplier_id, s.supplier_name
            ORDER BY avg_score DESC;

        v_score     NUMBER(5,2);
        v_category  VARCHAR2(100);
    BEGIN
        FOR rec IN cur_suppliers LOOP
            v_score := rec.avg_score;

            IF v_score BETWEEN 90 AND 100 THEN
                v_category := 'Excellent supplier, priority for future orders';
            ELSIF v_score BETWEEN 75 AND 89 THEN
                v_category := 'Good supplier, occasional checks needed';
            ELSIF v_score BETWEEN 60 AND 74 THEN
                v_category := 'Average performance, needs improvement plan';
            ELSE
                v_category := 'Poor performance, review supplier relationship';
            END IF;

            DBMS_OUTPUT.PUT_LINE(
                'Supplier: ' || rec.supplier_name ||
                ' | Score: ' || v_score ||
                ' | Category: ' || v_category
            );
        END LOOP;
    END rate_suppliers;

END supplier_rating_pkg;
/

SET SERVEROUTPUT ON;
ACCEPT supp_id CHAR PROMPT 'Enter Supplier ID: '
BEGIN
    supplier_rating_pkg.rate_suppliers('&supp_id');
END;
/

BEGIN
    supplier_rating_pkg.rate_suppliers('SUP-009');
END;
/
rollback;
--------------------------------------------------------------------------------------------------------
-- Automated reorder point calculations

-- Only if you want a table to capture each time an item drops below its ROP
CREATE TABLE REORDER_ALERTS (
  ALERT_ID        VARCHAR2(30) PRIMARY KEY,
  PRODUCT_ID      VARCHAR2(20) NOT NULL,
  LOCATION_ID     VARCHAR2(20) NOT NULL,
  CURRENT_STOCK   NUMBER(10)   NOT NULL,
  REORDER_LEVEL   NUMBER(10)   NOT NULL,
  ALERTED_ON      DATE         DEFAULT SYSDATE NOT NULL,
  CREATED_BY      VARCHAR2(50) DEFAULT SYS_CONTEXT('USERENV','SESSION_USER')
);

CREATE SEQUENCE SEQ_REORDER_ALERTS
START WITH 1
INCREMENT BY 1
NOCACHE;


CREATE OR REPLACE PACKAGE PKG_REORDER AS
  /**
   * Recomputes Reorder Level (ROP) for all product-location rows in INVENTORY_MASTER.
   * @param p_days_lookback  How many days of demand history to use (default 90)
   * @param p_service_level  Target service level (e.g., 0.90, 0.95, 0.99)
   * @param p_default_lead   Fallback lead time in days if PO history is missing
   * @param p_cap_ratio      Cap ROP to <= p_cap_ratio * MAX_STOCK_LEVEL (0..1), NULL = no cap
   * @param p_raise_alerts   If 'Y', write to REORDER_ALERTS when current_stock <= new ROP
   */
  PROCEDURE Recalc_All(
    p_days_lookback IN NUMBER  DEFAULT 90,
    p_service_level IN NUMBER  DEFAULT 0.95,
    p_default_lead  IN NUMBER  DEFAULT 14,
    p_cap_ratio     IN NUMBER  DEFAULT 0.90,
    p_raise_alerts  IN CHAR    DEFAULT 'Y'
  );

  /**
   * Same as Recalc_All, but only for one product/location.
   */
  PROCEDURE Recalc_One(
    p_product_id    IN VARCHAR2,
    p_location_id   IN VARCHAR2,
    p_days_lookback IN NUMBER  DEFAULT 90,
    p_service_level IN NUMBER  DEFAULT 0.95,
    p_default_lead  IN NUMBER  DEFAULT 14,
    p_cap_ratio     IN NUMBER  DEFAULT 0.90,
    p_raise_alerts  IN CHAR    DEFAULT 'Y'
  );
END PKG_REORDER;
/

CREATE OR REPLACE PACKAGE BODY PKG_REORDER AS

  /* Map common service levels to Z (Normal quantile).
     You can extend this CASE or plug in a more granular mapping if needed. */
  FUNCTION z_value(p_service_level NUMBER) RETURN NUMBER IS
  BEGIN
    RETURN CASE
             WHEN p_service_level >= 0.999 THEN 3.09
             WHEN p_service_level >= 0.995 THEN 2.58
             WHEN p_service_level >= 0.990 THEN 2.33
             WHEN p_service_level >= 0.975 THEN 1.96
             WHEN p_service_level >= 0.950 THEN 1.65
             WHEN p_service_level >= 0.900 THEN 1.28
             ELSE 1.04  -- ~0.85 svc level
           END;
  END;

  PROCEDURE core_recalc(
    p_product_id    IN VARCHAR2,
    p_location_id   IN VARCHAR2,
    p_days_lookback IN NUMBER,
    p_service_level IN NUMBER,
    p_default_lead  IN NUMBER,
    p_cap_ratio     IN NUMBER,
    p_raise_alerts  IN CHAR
  ) IS
    v_z                NUMBER := z_value(p_service_level);
    v_lead_time        NUMBER;
    v_avg_daily        NUMBER;
    v_sd_daily         NUMBER;
    v_new_rop          NUMBER;
    v_max_level        NUMBER;
    v_current_stock    NUMBER;
  BEGIN
    /* 1) Demand stats per day for this product/location over lookback window */
    WITH day_demand AS (
      SELECT
        TRUNC(t.transaction_date) AS dte,
        SUM(
          CASE
            WHEN t.transaction_type = 'ISSUE' THEN ABS(t.quantity)
            WHEN t.transaction_type = 'TRANSFER' AND t.quantity < 0 THEN ABS(t.quantity) -- out transfer
            ELSE 0
          END
        ) AS qty_out
      FROM inventory_transactions t
      WHERE t.product_id  = p_product_id
        AND t.location_id = p_location_id
        AND t.transaction_date >= TRUNC(SYSDATE) - p_days_lookback
      GROUP BY TRUNC(t.transaction_date)
    )
    SELECT
      NVL(AVG(qty_out), 0),
      NVL(STDDEV(qty_out), 0)
    INTO
      v_avg_daily,
      v_sd_daily
    FROM day_demand;

    /* 2) Lead time (avg) for this product from PO history, delivered orders only */
    SELECT NVL(AVG( (po.actual_date - po.order_date) ), p_default_lead)
    INTO v_lead_time
    FROM purchase_orders po
    JOIN po_line_items  li ON li.po_number = po.po_number
    WHERE li.product_id  = p_product_id
      AND po.order_status = 'DELIVERED'
      AND po.actual_date IS NOT NULL;

    /* 3) Pull max stock + current stock */
    SELECT max_stock_level, current_stock
      INTO v_max_level, v_current_stock
    FROM inventory_master
    WHERE product_id  = p_product_id
      AND location_id = p_location_id;

    /* 4) ROP calculation */
    v_new_rop :=
      CEIL( (v_avg_daily * v_lead_time) + (v_z * v_sd_daily * SQRT(v_lead_time)) );

    /* 5) Optional cap vs max stock level */
    IF p_cap_ratio IS NOT NULL THEN
      v_new_rop := LEAST(v_new_rop, CEIL(NVL(v_max_level, v_new_rop) * p_cap_ratio));
    END IF;

    /* 6) Update INVENTORY_MASTER */
    UPDATE inventory_master
       SET reorder_level = v_new_rop
     WHERE product_id    = p_product_id
       AND location_id   = p_location_id;

    /* 7) Optional alert when stock <= new ROP */
    IF NVL(p_raise_alerts, 'Y') = 'Y' AND v_current_stock <= v_new_rop THEN
      INSERT INTO reorder_alerts (
        ALERT_ID, PRODUCT_ID, LOCATION_ID, CURRENT_STOCK, REORDER_LEVEL, ALERTED_ON, CREATED_BY
      )
      VALUES (
        'ALR-' || LPAD(SEQ_REORDER_ALERTS.NEXTVAL, 8, '0'),
        p_product_id, p_location_id, v_current_stock, v_new_rop, SYSDATE,
        SYS_CONTEXT('USERENV','SESSION_USER')
      );
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- No row in inventory_master for that product/location; ignore gracefully
      NULL;
  END core_recalc;

  PROCEDURE Recalc_All(
    p_days_lookback IN NUMBER  DEFAULT 90,
    p_service_level IN NUMBER  DEFAULT 0.95,
    p_default_lead  IN NUMBER  DEFAULT 14,
    p_cap_ratio     IN NUMBER  DEFAULT 0.90,
    p_raise_alerts  IN CHAR    DEFAULT 'Y'
  ) IS
  BEGIN
    FOR r IN (
      SELECT product_id, location_id
      FROM   inventory_master
    )
    LOOP
      core_recalc(
        p_product_id    => r.product_id,
        p_location_id   => r.location_id,
        p_days_lookback => p_days_lookback,
        p_service_level => p_service_level,
        p_default_lead  => p_default_lead,
        p_cap_ratio     => p_cap_ratio,
        p_raise_alerts  => p_raise_alerts
      );
    END LOOP;
  END Recalc_All;

  PROCEDURE Recalc_One(
    p_product_id    IN VARCHAR2,
    p_location_id   IN VARCHAR2,
    p_days_lookback IN NUMBER  DEFAULT 90,
    p_service_level IN NUMBER  DEFAULT 0.95,
    p_default_lead  IN NUMBER  DEFAULT 14,
    p_cap_ratio     IN NUMBER  DEFAULT 0.90,
    p_raise_alerts  IN CHAR    DEFAULT 'Y'
  ) IS
  BEGIN
    core_recalc(
      p_product_id    => p_product_id,
      p_location_id   => p_location_id,
      p_days_lookback => p_days_lookback,
      p_service_level => p_service_level,
      p_default_lead  => p_default_lead,
      p_cap_ratio     => p_cap_ratio,
      p_raise_alerts  => p_raise_alerts
    );
  END Recalc_One;

END PKG_REORDER;
/

-- Recalculate ROP for everything (90-day lookback, 95% service, cap at 90% of max)
BEGIN
  PKG_REORDER.Recalc_All;
END;
/
SELECT constraint_name, table_name, column_name
FROM all_cons_columns
WHERE constraint_name = 'SYS_C008492';

SELECT * FROM AUDIT_TRAIL;
    TRUNCATE TABLE AUDIT_TRAIL;
-- Spot-check a single item

BEGIN
  PKG_REORDER.Recalc_One(
    p_product_id  => 'PLA-LIG-138',
    p_location_id => 'BAN-001',
    p_days_lookback => 120,
    p_service_level => 0.99  -- stricter service level => higher safety stock
  );
END;
/
SELECT *
FROM reorder_alerts
WHERE product_id = 'PLA-LIG-138' AND location_id = 'BAN-001';
-- See updated reorder levels and any alerts
SELECT product_id, location_id, current_stock, reorder_level, max_stock_level
FROM   inventory_master
ORDER BY product_id, location_id;

SELECT * FROM reorder_alerts ORDER BY alerted_on DESC;
rollback;
-------------------------------------
--SCHEDULER JOB
BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name        => 'JOB_RECALC_ROP_NIGHTLY',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN PKG_REORDER.Recalc_All; END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0;BYSECOND=0',
    enabled         => TRUE,
    comments        => 'Nightly recalculation of ROPs');
END;
/
rollback

SELECT audit_trail_seq.NEXTVAL FROM dual;
SELECT audit_trail_seq.CURRVAL FROM dual;
;