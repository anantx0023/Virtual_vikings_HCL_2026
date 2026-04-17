# 🏥 Snowflake Hospital Data Pipeline

## 📌 Project Overview

This project implements an **end-to-end data engineering pipeline** using Snowflake for a hospital management system.

It covers:

* Data ingestion from AWS S3
* Data cleaning & validation
* Data modeling (Star Schema)
* Incremental processing (Streams & Tasks)
* Security (RBAC, Masking Policies, Secure Views)
* Analytical reporting (KPI Views)
* Performance optimization

---

## ⚙️ Tech Stack

* ❄️ Snowflake
* ☁️ AWS S3
* 🧾 SQL
* 🔄 Streams & Tasks (CDC)
* 🔐 RBAC & Data Masking

---

## 🏗️ Architecture

```
S3 → STAGING → CLEANING → MASTER TABLES → DIMENSIONS → FACT TABLES → ANALYTICS
                                      ↑
                                STREAMS + TASKS
```

---

## 📥 Data Ingestion

* External stage created using S3 integration
* Data loaded into staging tables using `COPY INTO`

Tables:

* stg_patients_clean / dirty
* stg_appointments_clean
* stg_billing_clean / dirty

---

## 🧹 Data Cleaning & Validation

* Standardized formats (DOB, Gender, Email)
* Removed invalid records
* Handled nulls and incorrect values
* Created error tables:

  * `patients_error`
  * `billing_error`

---

## 🧱 Data Modeling (Star Schema)

### Dimension Tables

* `DIM_PATIENT`
* `DIM_DOCTOR`

### Fact Tables

* `FACT_APPOINTMENT`
* `FACT_BILLING`

✔ Surrogate Keys (PK)
✔ Natural Keys (NK)
✔ Foreign Key relationships

---

## 🔄 Incremental Processing

### Streams

* `stream_appointment`
* `stream_billing`

### Stored Procedures

* `sp_merge_appointment`
* `sp_merge_billing`

### Tasks

* Automated execution every 5 minutes

✔ Ensures **idempotent data loading**
✔ Supports real-time updates

---

## 🔐 Security Implementation

### RBAC (Roles)

* `analyst_role`
* `doctor_role`
* `admin_role`

### Masking Policies

* Phone masking
* Email masking

### Secure View

* `vw_doctor_patient_view` (restricted patient data)

---

## 📊 Analytical Use Cases

### 1. Department-wise Appointment Summary

* Total Appointments
* Completed Visits
* No-Shows
* Completion Rate

### 2. Daily OPD Trend

* Daily Visits
* No-Shows
* Avg Appointments per Doctor

### 3. Revenue by Department

* Net Revenue
* Avg Bill Value

### 4. Patient Utilization

* Total Visits
* Last Visit Date
* Lifetime Revenue

### 5. Insurance vs Self-Pay Mix

* Revenue split

---

## 📈 Output Views

* `VW_DEPT_APPT_SUMMARY`
* `VW_DAILY_OPD_TREND`
* `VW_REVENUE_BY_DEPT`
* `VW_PATIENT_UTILIZATION`
* `VW_INSURANCE_MIX`

---

## ⚡ Performance Optimization

* Clustering on:

  * `APPT_DATE`
  * `BILL_DATE`
* Separate warehouses for ETL & Analytics
* Result caching leveraged

---

## 👨‍💻 Team Contributions

### 🔹 Vaibhav & Kritagya

* S3 Integration setup
* External Stage creation
* Data ingestion using `COPY INTO`
* Staging table design

---

### 🔹 Rishi & Anant

* Data cleaning logic (patients & billing)
* Error handling tables
* Master table creation (deduplication)
* Dimension & Fact table modeling
* Star schema implementation

---

### 🔹 Adarsh

* Streams implementation (CDC)
* Stored procedures (MERGE logic)
* Task automation
* RBAC & Security implementation
* Analytical views (KPI layer)
* Performance optimization (Clustering)

---

## 🚀 Key Highlights

✔ End-to-end ETL pipeline
✔ Real-time incremental processing
✔ Production-level data modeling
✔ Secure & governed data access
✔ Business-ready analytics layer

---

## 📌 How to Run

1. Create database & schema
2. Run staging + ingestion scripts
3. Execute cleaning & master logic
4. Create dimension & fact tables
5. Enable streams & tasks
6. Query analytical views

---

## 📎 Author

Team Virtual Vikings 🚀
