-- 12-queries.sql — Oracle/PL-SQL flavoured, because your settings.json maps
-- *.PACKAGE, *.PACKAGE BODY, *.REP SCREEN, *.REP DTM, *.CODE TAB and friends
-- to the sql language. Those files never land in ~/Dev, but SQL is clearly a
-- daily language at work, so the sample follows that dialect rather than the
-- Postgres one.
--
-- Nothing here is meant to run. It exists so that keywords, built-in
-- functions, string literals, bind variables and comments can be compared.

/* ────────────────────────────────────────────────────────────────────────
   DDL
   ──────────────────────────────────────────────────────────────────────── */

CREATE TABLE preview_records (
    id              NUMBER(19)      GENERATED ALWAYS AS IDENTITY,
    external_id     VARCHAR2(64)    NOT NULL,
    message         VARCHAR2(4000),
    level_code      CHAR(1)         DEFAULT 'I' NOT NULL,
    attempt         NUMBER(5,0)     DEFAULT 0,
    ratio           BINARY_DOUBLE,
    payload         CLOB,
    is_loud         NUMBER(1)       DEFAULT 0 NOT NULL,
    created_at      TIMESTAMP(6) WITH TIME ZONE DEFAULT SYSTIMESTAMP,
    updated_at      DATE,
    CONSTRAINT pk_preview_records PRIMARY KEY (id),
    CONSTRAINT uq_preview_external UNIQUE (external_id),
    CONSTRAINT ck_preview_level CHECK (level_code IN ('D', 'I', 'W', 'F'))
);

CREATE INDEX ix_preview_level_created
    ON preview_records (level_code, created_at DESC);

COMMENT ON TABLE preview_records IS 'Sample table for the Leo Dark parity corpus';
COMMENT ON COLUMN preview_records.ratio IS 'Unbounded double, nullable on purpose';

ALTER TABLE preview_records ADD (
    tags VARCHAR2(512),
    source_id NUMBER(19)
);

/* ────────────────────────────────────────────────────────────────────────
   DML
   ──────────────────────────────────────────────────────────────────────── */

INSERT INTO preview_records (external_id, message, level_code, attempt, ratio)
VALUES ('rec_0a1b2c3d', 'boot sequence started', 'D', 1, 1.618);

INSERT ALL
    INTO preview_records (external_id, message, level_code) VALUES ('rec_1', 'cache warmed', 'I')
    INTO preview_records (external_id, message, level_code) VALUES ('rec_2', 'retry budget low', 'W')
SELECT 1 FROM dual;

UPDATE preview_records
   SET is_loud    = CASE WHEN level_code IN ('W', 'F') THEN 1 ELSE 0 END,
       updated_at = SYSDATE
 WHERE created_at >= TRUNC(SYSDATE) - INTERVAL '7' DAY
   AND external_id LIKE 'rec\_%' ESCAPE '\';

DELETE FROM preview_records
 WHERE level_code = 'D'
   AND created_at < ADD_MONTHS(SYSDATE, -3);

MERGE INTO preview_records tgt
USING (SELECT :external_id AS external_id, :message AS message FROM dual) src
   ON (tgt.external_id = src.external_id)
 WHEN MATCHED THEN
      UPDATE SET tgt.message = src.message, tgt.updated_at = SYSDATE
 WHEN NOT MATCHED THEN
      INSERT (external_id, message) VALUES (src.external_id, src.message);

/* ────────────────────────────────────────────────────────────────────────
   Query with CTE, window functions, joins and a scalar subquery
   ──────────────────────────────────────────────────────────────────────── */

WITH recent AS (
    SELECT r.id,
           r.external_id,
           r.message,
           r.level_code,
           r.attempt,
           NVL(r.ratio, 0)          AS ratio,
           r.created_at
      FROM preview_records r
     WHERE r.created_at >= SYSTIMESTAMP - INTERVAL '1' HOUR
),
ranked AS (
    SELECT rc.*,
           ROW_NUMBER()  OVER (PARTITION BY rc.level_code ORDER BY rc.created_at DESC) AS rn,
           COUNT(*)      OVER (PARTITION BY rc.level_code)                             AS level_total,
           LAG(rc.attempt, 1, 0) OVER (ORDER BY rc.created_at)                         AS prev_attempt,
           SUM(rc.ratio) OVER (ORDER BY rc.created_at
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)       AS running_ratio
      FROM recent rc
)
SELECT k.external_id,
       UPPER(TRIM(k.message))                       AS message,
       DECODE(k.level_code, 'D', 'debug',
                            'I', 'info',
                            'W', 'warn',
                            'F', 'fatal', 'unknown') AS level_name,
       k.rn,
       k.level_total,
       ROUND(k.running_ratio, 3)                     AS running_ratio,
       TO_CHAR(k.created_at, 'YYYY-MM-DD HH24:MI:SS') AS created_str,
       (SELECT COUNT(*) FROM preview_records p WHERE p.source_id = k.id) AS child_count
  FROM ranked k
  LEFT OUTER JOIN preview_records parent
    ON parent.id = k.id
   AND parent.level_code <> k.level_code
 WHERE k.rn <= 5
   AND EXISTS (SELECT 1 FROM dual)
   AND k.attempt BETWEEN 0 AND 10
 GROUP BY k.external_id, k.message, k.level_code, k.rn,
          k.level_total, k.running_ratio, k.created_at, k.id
HAVING COUNT(*) > 0
 ORDER BY k.level_code ASC, k.created_at DESC NULLS LAST
 FETCH FIRST 50 ROWS ONLY;

/* ────────────────────────────────────────────────────────────────────────
   PL/SQL package — the *.PACKAGE / *.PACKAGE BODY shape
   ──────────────────────────────────────────────────────────────────────── */

CREATE OR REPLACE PACKAGE preview_pkg AS
    g_max_retries CONSTANT PLS_INTEGER := 3;

    TYPE t_record IS RECORD (
        id      preview_records.id%TYPE,
        message preview_records.message%TYPE
    );
    TYPE t_records IS TABLE OF t_record INDEX BY PLS_INTEGER;

    FUNCTION level_name (p_code IN CHAR) RETURN VARCHAR2 DETERMINISTIC;
    PROCEDURE purge_old (p_days IN PLS_INTEGER DEFAULT 90, p_removed OUT NUMBER);
END preview_pkg;
/

CREATE OR REPLACE PACKAGE BODY preview_pkg AS

    FUNCTION level_name (p_code IN CHAR) RETURN VARCHAR2 DETERMINISTIC IS
    BEGIN
        RETURN CASE p_code
                   WHEN 'D' THEN 'debug'
                   WHEN 'I' THEN 'info'
                   WHEN 'W' THEN 'warn'
                   WHEN 'F' THEN 'fatal'
                   ELSE 'unknown'
               END;
    END level_name;

    PROCEDURE purge_old (p_days IN PLS_INTEGER DEFAULT 90, p_removed OUT NUMBER) IS
        CURSOR c_stale IS
            SELECT id, external_id
              FROM preview_records
             WHERE created_at < SYSDATE - p_days
               FOR UPDATE OF is_loud NOWAIT;

        l_count   PLS_INTEGER := 0;
        l_batch   t_records;
        e_locked  EXCEPTION;
        PRAGMA EXCEPTION_INIT(e_locked, -54);
    BEGIN
        FOR rec IN c_stale LOOP
            l_count := l_count + 1;
            l_batch(l_count).id := rec.id;

            IF l_count >= g_max_retries * 100 THEN
                EXIT;
            END IF;
        END LOOP;

        FORALL i IN 1 .. l_batch.COUNT
            DELETE FROM preview_records WHERE id = l_batch(i).id;

        p_removed := SQL%ROWCOUNT;
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('purged ' || p_removed || ' rows older than ' || p_days || ' days');

    EXCEPTION
        WHEN e_locked THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20001, 'rows locked by another session');
        WHEN NO_DATA_FOUND THEN
            p_removed := 0;
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END purge_old;

END preview_pkg;
/

-- A quoted identifier, a string with a doubled quote, and a bind variable.
SELECT "external_id" AS "External Id",
       'it''s escaped by doubling'      AS quoted,
       q'[literal with 'quotes' inside]' AS q_quoted,
       :bind_var                         AS bound
  FROM preview_records
 WHERE ROWNUM <= 1;
