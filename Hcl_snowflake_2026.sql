
-- Vaibhav,kritagya
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE MYDB;
USE SCHEMA MY_SCHEMA;

CREATE OR REPLACE STORAGE INTEGRATION s3_int
TYPE = EXTERNAL_STAGE
STORAGE_PROVIDER = S3
ENABLED = TRUE
STORAGE_ALLOWED_LOCATIONS = ('s3://anant-snowflake-bucket/')
STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::768396678972:role/AnantSnowflakeRole';

CREATE OR REPLACE TABLE stg_patients_clean (
    patient_id        STRING,
    full_name         STRING,
    dob               STRING,
    gender            STRING,
    phone             STRING,
    email             STRING,
    city              STRING,
    state             STRING,
    registration_date STRING
);

CREATE OR REPLACE TABLE stg_patients_dirty (
    patient_id        STRING,
    full_name         STRING,
    dob               STRING,
    gender            STRING,
    phone             STRING,
    email             STRING,
    city              STRING,
    state             STRING,
    registration_date STRING
);

CREATE OR REPLACE TABLE stg_appointments_clean (
    appt_id     STRING,
    appt_date   STRING,
    patient_id  STRING,
    doctor_id   STRING,
    doctor_name STRING,
    department  STRING,
    slot        STRING,
    status      STRING
);

CREATE OR REPLACE TABLE stg_billing_clean (
    bill_id          STRING,
    bill_date        STRING,
    patient_id       STRING,
    service_code     STRING,
    service_desc     STRING,
    department       STRING,
    gross_amount     STRING,
    discount_amount  STRING,
    tax_amount       STRING,
    net_amount       STRING,
    payment_mode     STRING,
    insurer_name     STRING
);

CREATE OR REPLACE TABLE stg_billing_dirty (
    bill_id          STRING,
    bill_date        STRING,
    patient_id       STRING,
    service_code     STRING,
    service_desc     STRING,
    department       STRING,
    gross_amount     STRING,
    discount_amount  STRING,
    tax_amount       STRING,
    net_amount       STRING,
    payment_mode     STRING,
    insurer_name     STRING
);

DESC INTEGRATION s3_int;

CREATE OR REPLACE STAGE ext_stage
URL = 's3://anant-snowflake-bucket/'
STORAGE_INTEGRATION = s3_int
FILE_FORMAT = csv_format;

LIST @ext_stage;

COPY INTO stg_patients_clean
FROM @ext_stage/patients_master_clean.csv
FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
ON_ERROR = 'CONTINUE';

select * from stg_patients_clean;

COPY INTO stg_patients_dirty
FROM @ext_stage/patients_master_dirty.csv
FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
ON_ERROR = 'CONTINUE';

select * from stg_patients_dirty;

COPY INTO stg_appointments_clean
FROM @ext_stage/appointments_clean.csv
FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
ON_ERROR = 'CONTINUE';

select * from stg_appointments_clean;

COPY INTO stg_billing_clean
FROM @ext_stage/billing_clean.csv
FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
ON_ERROR = 'CONTINUE';

select * from stg_billing_clean;

COPY INTO stg_billing_dirty
FROM @ext_stage/billing_dirty.csv
FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
ON_ERROR = 'CONTINUE';

select * from stg_billing_dirty;
--vaibhav kritagya code ends here

--Rishi,Anant code starts here

--cleanning logic patients_dirty

CREATE OR REPLACE VIEW vw_patients_dirty_cleaned AS
SELECT
    patient_id,
    TRIM(full_name) AS full_name,

    
    CASE
        WHEN dob RLIKE '^\\d{2}/\\d{2}/\\d{4}$'
             AND TRY_TO_DATE(dob, 'DD/MM/YYYY') IS NOT NULL
            THEN TRY_TO_DATE(dob, 'DD/MM/YYYY')
        ELSE TRY_TO_DATE(dob)
    END AS dob,

    
    CASE
        WHEN UPPER(TRIM(gender)) IN ('M','MALE') THEN 'MALE'
        WHEN UPPER(TRIM(gender)) IN ('F','FEMALE') THEN 'FEMALE'
        ELSE 'UNKNOWN'
    END AS gender,


    CASE
        WHEN phone RLIKE '^[6-9]\\d{9}$' THEN phone
        ELSE NULL
    END AS phone,

    REPLACE(LOWER(TRIM(email)), '[at]', '@') AS email,

    INITCAP(TRIM(city)) AS city,
    INITCAP(TRIM(state)) AS state,

    TRY_TO_DATE(registration_date) AS registration_date,

    'dirty_source' AS data_source

FROM stg_patients_dirty
WHERE patient_id IS NOT NULL;

CREATE OR REPLACE TABLE patients_error AS
SELECT *
FROM stg_patients_dirty
WHERE patient_id IS NULL
   OR (
        dob RLIKE '^\\d{2}/\\d{2}/\\d{4}$'
        AND TRY_TO_DATE(dob, 'DD/MM/YYYY') IS NULL
      );



CREATE OR REPLACE VIEW vw_patients_clean AS
SELECT
    patient_id,
    TRIM(full_name) AS full_name,
    TRY_TO_DATE(dob) AS dob,

    CASE
        WHEN UPPER(TRIM(gender)) IN ('M','MALE') THEN 'MALE'
        WHEN UPPER(TRIM(gender)) IN ('F','FEMALE') THEN 'FEMALE'
        ELSE 'UNKNOWN'
    END AS gender,

    phone,
    LOWER(TRIM(email)) AS email,
    INITCAP(TRIM(city)) AS city,
    INITCAP(TRIM(state)) AS state,
    TRY_TO_DATE(registration_date) AS registration_date,

    'clean_source' AS data_source
FROM stg_patients_clean
WHERE patient_id IS NOT NULL;


CREATE OR REPLACE VIEW vw_billing_dirty_cleaned AS
SELECT
    bill_id,
    TRY_TO_DATE(bill_date) AS bill_date,
    patient_id,

    UPPER(TRIM(service_code)) AS service_code,
    TRIM(service_desc) AS service_desc,
    INITCAP(TRIM(department)) AS department,

    
    CASE 
        WHEN TRY_TO_NUMBER(gross_amount) < 0 THEN NULL
        ELSE TRY_TO_NUMBER(gross_amount)
    END AS gross_amount,

    CASE 
        WHEN TRY_TO_NUMBER(discount_amount) < 0 THEN NULL
        ELSE TRY_TO_NUMBER(discount_amount)
    END AS discount_amount,

    CASE 
        WHEN TRY_TO_NUMBER(tax_amount) < 0 THEN NULL
        ELSE TRY_TO_NUMBER(tax_amount)
    END AS tax_amount,

    
    (
        COALESCE(
            CASE WHEN TRY_TO_NUMBER(gross_amount) >= 0 THEN TRY_TO_NUMBER(gross_amount) END, 0
        )
        -
        COALESCE(
            CASE WHEN TRY_TO_NUMBER(discount_amount) >= 0 THEN TRY_TO_NUMBER(discount_amount) END, 0
        )
        +
        COALESCE(
            CASE WHEN TRY_TO_NUMBER(tax_amount) >= 0 THEN TRY_TO_NUMBER(tax_amount) END, 0
        )
    ) AS net_amount,

    CASE
        WHEN UPPER(TRIM(payment_mode)) IN ('CASH','CARD','UPI','INSURANCE')
        THEN UPPER(TRIM(payment_mode))
        ELSE 'UNKNOWN'
    END AS payment_mode,

    TRIM(insurer_name) AS insurer_name,

    'dirty_source' AS data_source
FROM stg_billing_dirty
WHERE bill_id IS NOT NULL;


CREATE OR REPLACE TABLE billing_error AS
SELECT *
FROM stg_billing_dirty
WHERE bill_id IS NULL
   OR TRY_TO_NUMBER(gross_amount) < 0;

   

CREATE OR REPLACE VIEW vw_billing_clean AS
SELECT
    bill_id,
    TRY_TO_DATE(bill_date) AS bill_date,
    patient_id,
    UPPER(TRIM(service_code)) AS service_code,
    TRIM(service_desc) AS service_desc,
    INITCAP(TRIM(department)) AS department,

    TRY_TO_NUMBER(gross_amount) AS gross_amount,
    TRY_TO_NUMBER(discount_amount) AS discount_amount,
    TRY_TO_NUMBER(tax_amount) AS tax_amount,
    TRY_TO_NUMBER(net_amount) AS net_amount,

    UPPER(TRIM(payment_mode)) AS payment_mode,
    TRIM(insurer_name) AS insurer_name,

    'clean_source' AS data_source
FROM stg_billing_clean
WHERE bill_id IS NOT NULL;


CREATE OR REPLACE TABLE patients_master AS
WITH combined AS (
    SELECT *, 1 AS priority FROM vw_patients_clean
    UNION ALL
    SELECT *, 2 AS priority FROM vw_patients_dirty_cleaned
),
deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY patient_id
               ORDER BY priority ASC
           ) AS rn
    FROM combined
)
SELECT *
FROM deduped
WHERE rn = 1;

select * from patients_master

CREATE OR REPLACE TABLE billing_master AS
WITH combined AS (
    SELECT *, 1 AS priority FROM vw_billing_clean
    UNION ALL
    SELECT *, 2 AS priority FROM vw_billing_dirty_cleaned
),
deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY bill_id
               ORDER BY priority ASC
           ) AS rn
    FROM combined
)
SELECT *
FROM deduped
WHERE rn = 1;

select * from billing_master;

CREATE OR REPLACE TABLE dim_patient AS
SELECT
    ROW_NUMBER() OVER (ORDER BY patient_id) AS patient_key,
    patient_id,
    full_name,
    dob,
    gender,
    phone,
    email,
    city,
    state,
    registration_date
FROM patients_master;



CREATE OR REPLACE TABLE dim_doctor AS
SELECT
    ROW_NUMBER() OVER (ORDER BY doctor_id) AS doctor_key,
    doctor_id,
    doctor_name,
    department,
    NULL AS specialization
FROM (
    SELECT DISTINCT doctor_id, doctor_name, department
    FROM stg_appointments_clean
);


CREATE OR REPLACE TABLE fact_appointment_cleaned AS
SELECT
    appt_id,
    TRY_TO_DATE(appt_date) AS appt_date,
    patient_id,
    doctor_id,
    INITCAP(TRIM(doctor_name)) AS doctor_name,
    INITCAP(TRIM(department)) AS department,
    TRIM(slot) AS slot,

    CASE 
        WHEN UPPER(TRIM(status)) IN ('SCHEDULED','COMPLETED','CANCELLED','NO-SHOW')
        THEN UPPER(TRIM(status))
        ELSE 'UNKNOWN'
    END AS status
FROM stg_appointments_clean
WHERE appt_id IS NOT NULL
  AND patient_id IS NOT NULL;

  

  CREATE OR REPLACE TABLE fact_appointment AS
SELECT
    ROW_NUMBER() OVER (ORDER BY a.appt_id) AS appt_key,   -- PK
    a.appt_id,                                           -- NK

    p.patient_key,                                       -- FK
    d.doctor_key,                                        -- FK

    a.appt_date,
    a.slot,
    a.status

FROM fact_appointment_cleaned a

LEFT JOIN dim_patient p
    ON a.patient_id = p.patient_id

LEFT JOIN dim_doctor d
    ON a.doctor_id = d.doctor_id;



CREATE OR REPLACE TABLE fact_billing AS
SELECT
    ROW_NUMBER() OVER (ORDER BY b.bill_id) AS bill_key,   -- PK
    b.bill_id,                                           -- NK

    p.patient_key,                                       -- FK

    b.bill_date,
    b.net_amount,
    b.payment_mode

FROM billing_master b

LEFT JOIN dim_patient p
    ON b.patient_id = p.patient_id;


select * from dim_patient;
select * from dim_doctor;
select * from fact_billing; 
select * from fact_appointment;

SELECT * FROM fact_appointment WHERE patient_key IS NULL;
SELECT * FROM fact_appointment WHERE doctor_key IS NULL;
SELECT * FROM fact_billing WHERE patient_key IS NULL;

--Rishi, Anant code ends here

--Adarsh code starts here

CREATE OR REPLACE STREAM stream_appointment
ON TABLE fact_appointment_cleaned
APPEND_ONLY = FALSE;

CREATE OR REPLACE STREAM stream_billing
ON TABLE billing_master
APPEND_ONLY = FALSE;

CREATE OR REPLACE PROCEDURE sp_merge_appointment()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN

MERGE INTO fact_appointment f
USING (
    SELECT *
    FROM stream_appointment
    WHERE METADATA$ACTION = 'INSERT'
) s
ON f.appt_id = s.appt_id

WHEN MATCHED THEN
    UPDATE SET
        f.appt_date = s.appt_date,
        f.status = s.status,
        f.slot = s.slot

WHEN NOT MATCHED THEN
    INSERT (
        appt_key,
        appt_id,
        patient_key,
        doctor_key,
        appt_date,
        slot,
        status
    )
    VALUES (
        ROW_NUMBER() OVER (ORDER BY s.appt_id),
        s.appt_id,
        NULL,
        NULL,
        s.appt_date,
        s.slot,
        s.status
    );

RETURN 'Appointment Merge Done';

END;
$$;

CREATE OR REPLACE PROCEDURE sp_merge_billing()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN

MERGE INTO fact_billing f
USING (
    SELECT *
    FROM stream_billing
    WHERE METADATA$ACTION = 'INSERT'
) s
ON f.bill_id = s.bill_id

WHEN MATCHED THEN
    UPDATE SET
        f.net_amount = s.net_amount,
        f.payment_mode = s.payment_mode,
        f.bill_date = s.bill_date

WHEN NOT MATCHED THEN
    INSERT (
        bill_key,
        bill_id,
        patient_key,
        bill_date,
        net_amount,
        payment_mode
    )
    VALUES (
        ROW_NUMBER() OVER (ORDER BY s.bill_id),   
        s.bill_id,
        NULL,  
        s.bill_date,
        s.net_amount,
        s.payment_mode
    );

RETURN 'Billing Merge Done';

END;
$$;

CREATE OR REPLACE TASK task_billing_merge
WAREHOUSE = COMPUTE_WH
SCHEDULE = '5 MINUTE'
AS
CALL sp_merge_billing();

CREATE OR REPLACE TASK task_billing_merge
WAREHOUSE = COMPUTE_WH
SCHEDULE = '5 MINUTE'
AS
CALL sp_merge_appointment();

CREATE OR REPLACE ROLE analyst_role;
CREATE OR REPLACE ROLE doctor_role;
CREATE OR REPLACE ROLE admin_role;

GRANT USAGE ON DATABASE MYDB TO ROLE analyst_role;
GRANT USAGE ON SCHEMA MY_SCHEMA TO ROLE analyst_role;

GRANT SELECT ON ALL TABLES IN SCHEMA MY_SCHEMA TO ROLE analyst_role;

GRANT SELECT ON TABLE fact_appointment TO ROLE doctor_role;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA MY_SCHEMA TO ROLE admin_role;


--i have not made the roles but not assigned any role to any user as of now sir 

CREATE OR REPLACE MASKING POLICY mask_phone
AS (val STRING) 
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('ADMIN_ROLE') THEN val
        ELSE 'XXXXXX' || RIGHT(val, 4)
    END;

CREATE OR REPLACE MASKING POLICY mask_email
AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('ADMIN_ROLE') THEN val
        ELSE '***@***.com'
    END;

ALTER TABLE dim_patient 
MODIFY COLUMN phone 
SET MASKING POLICY mask_phone;

ALTER TABLE dim_patient 
MODIFY COLUMN email 
SET MASKING POLICY mask_email;

CREATE OR REPLACE SECURE VIEW vw_doctor_patient_view AS
SELECT
    patient_id,
    full_name,
    gender,
    city,
    state
FROM dim_patient;

GRANT SELECT ON VIEW vw_doctor_patient_view TO ROLE doctor_role;


CREATE OR REPLACE VIEW vw_dept_appt_summary AS
SELECT
    d.department,

    COUNT(*) AS total_appointments,

    SUM(CASE WHEN f.status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_visits,

    SUM(CASE WHEN f.status = 'NO-SHOW' THEN 1 ELSE 0 END) AS no_shows,

    ROUND(
        SUM(CASE WHEN f.status = 'COMPLETED' THEN 1 ELSE 0 END) 
        / COUNT(*) * 100, 2
    ) AS completion_rate

FROM fact_appointment f
JOIN dim_doctor d
    ON f.doctor_key = d.doctor_key

GROUP BY d.department;


CREATE OR REPLACE VIEW vw_daily_opd_trend AS
SELECT
    f.appt_date,

    COUNT(*) AS total_visits,

    SUM(CASE WHEN f.status = 'NO-SHOW' THEN 1 ELSE 0 END) AS no_shows,

    ROUND(
        COUNT(*) / COUNT(DISTINCT f.doctor_key), 2
    ) AS avg_appointments_per_doctor

FROM fact_appointment f

GROUP BY f.appt_date
ORDER BY f.appt_date;



CREATE OR REPLACE VIEW vw_revenue_by_dept AS
SELECT
    d.department,

    SUM(b.net_amount) AS net_revenue,

    COUNT(b.bill_id) AS total_bills,

    ROUND(AVG(b.net_amount), 2) AS avg_bill_value

FROM fact_billing b
JOIN dim_patient p
    ON b.patient_key = p.patient_key
JOIN fact_appointment f
    ON p.patient_key = f.patient_key
JOIN dim_doctor d
    ON f.doctor_key = d.doctor_key

GROUP BY d.department;


CREATE OR REPLACE VIEW vw_patient_utilization AS
SELECT
    p.patient_id,
    p.full_name,

    COUNT(a.appt_id) AS total_visits,

    MAX(a.appt_date) AS last_visit_date,

    SUM(b.net_amount) AS lifetime_revenue

FROM dim_patient p

LEFT JOIN fact_appointment a
    ON p.patient_key = a.patient_key

LEFT JOIN fact_billing b
    ON p.patient_key = b.patient_key

GROUP BY p.patient_id, p.full_name;


CREATE OR REPLACE VIEW vw_insurance_mix AS
SELECT
    CASE
        WHEN payment_mode = 'INSURANCE' THEN 'INSURANCE'
        ELSE 'SELF_PAY'
    END AS payment_type,

    COUNT(*) AS total_transactions,

    SUM(net_amount) AS total_revenue,

    ROUND(
        SUM(net_amount) * 100.0 / SUM(SUM(net_amount)) OVER (), 2
    ) AS revenue_percentage

FROM fact_billing

GROUP BY payment_type;

select * from VW_DEPT_APPT_SUMMARY;
select * from VW_DAILY_OPD_TREND;
select * from VW_REVENUE_BY_DEPT;
select * from VW_PATIENT_UTILIZATION;
select * from VW_INSURANCE_MIX;

ALTER TABLE fact_appointment
CLUSTER BY (appt_date);

ALTER TABLE fact_billing
CLUSTER BY (bill_date);

--Adarsh code ends here 