# Credit Decisioning & Portfolio Risk Intelligence

## Project Overview

Financial institutions make thousands of lending decisions every day, and every loan approved introduces a level of credit risk. The challenge is determining which borrowers are likely to default, identifying high-risk segments within the loan portfolio, and supporting underwriting decisions with reliable data.

This project builds a credit risk analysis framework that combines loan information, payment histories, customer demographics, and credit scores to provide portfolio-level insights and support lending decisions.

> **Business Questions**
>
> - Which borrowers are most likely to default?
> - What is the portfolio's overall default rate?
> - Which customer segments contribute most to portfolio risk?
> - How can credit decisions be standardized using risk scores?
> - How can data quality issues impact credit risk reporting?

---

## Dataset

This project uses a synthetic banking dataset consisting of approximately 3,000 records across four related tables.

| Table | Description |
|-------|------------|
| bank_loans | Loan information including amount, type, interest rate and status |
| loan_payments | Loan repayment transactions |
| bank_customers | Customer demographic and income information |
| credit_scores | Customer credit scores and risk classifications |

### Loan Status

- Active
- Closed
- Default

### Loan Products

- Personal Loans
- Business Loans
- Auto Loans
- Mortgage Loans

---

## Project Architecture

```
                 BANK CUSTOMERS
                        |
                        |
                        |
                 CREDIT SCORES
                        |
                        |
                        |
                   BANK LOANS
                        |
                        |
                        |
                 LOAN PAYMENTS
                        |
                        |
                        ↓
         v_loan_payment_summary (Aggregation Layer)
                        |
                        |
                        ↓
                v_credit_master (Master View)
                        |
                        |
                        ↓
                  Portfolio KPIs
                        |
                        |
       ----------------------------------------
       |                  |                   |
       ↓                  ↓                   ↓
  Default Rate        PD Scoring       Credit Decisions
    Analysis           Analysis       (Approve/Review/Reject)
       |                  |                   |
       ----------------------------------------
                        |
                        ↓
                Business Recommendations

```

---

## Technologies Used

- SQL Server (T-SQL)
- SQL Views
- CASE Statements
- Aggregate Functions
- Window Functions
- Risk Segmentation Techniques
- Portfolio Risk Analysis
- Data Validation & Quality Checks

---

## Methodology

The project was developed using a layered reporting approach.

### Data Preparation

- Aggregated payment transactions into loan-level summaries.
- Created reusable SQL views for reporting.
- Validated data grain across all relationships.
- Corrected duplicate records caused by one-to-many joins.

### Portfolio Analysis

The analysis includes:

- Portfolio default rate analysis
- Risk segmentation analysis
- Income segment analysis
- Interest rate impact analysis
- Credit quality analysis
- Loan product analysis
- Country-level portfolio analysis

### Credit Decision Framework

Borrowers are classified using a simplified rule-based scoring model into:

- Approve
- Review
- Reject

This provides a standardized first-pass lending recommendation for underwriting teams.

---

## Data Quality Challenges Solved

During development, several data quality issues were identified and resolved.

### Duplicate Loan Records

The original implementation joined payment transactions directly to the loan table, causing loans with multiple payments to be counted multiple times.

#### Solution

- Created `v_loan_payment_summary`.
- Aggregated payments before joining.
- Guaranteed one row per loan in the master view.

### Missing Portfolio Records

An INNER JOIN used during credit analysis excluded borrowers without matching credit score records.

#### Solution

- Replaced INNER JOIN operations with LEFT JOINs where appropriate.
- Ensured complete portfolio visibility during analysis.

### Poor Risk Segmentation

Grouping interest rates by their raw decimal values produced fragmented and unreadable results.

#### Solution

Interest rates were segmented into business-friendly ranges:

- Under 5%
- 5% – 8%
- 8% – 11%
- Above 11%

---

## Key Insights

The analysis revealed:

- Portfolio default rates vary significantly across borrower segments.
- Data grain issues can materially impact portfolio KPIs.
- Risk segmentation provides more valuable insights than portfolio-wide averages.
- Loan products and borrower characteristics influence default behaviour differently.
- Accurate reporting depends heavily on properly designed aggregation layers.

---

## Business Recommendations

- Use `v_credit_master` as the single source of truth for portfolio reporting.
- Incorporate segment-level default rates into underwriting policies.
- Monitor portfolio performance continuously across risk bands.
- Use PD scores as decision-support tools rather than standalone approval mechanisms.
- Perform regular data quality validation before portfolio-level reporting.

---

## Skills Demonstrated

This project demonstrates proficiency in:

- Advanced SQL
- Data Modeling
- Portfolio Risk Analysis
- Credit Risk Analytics
- Data Validation
- Business Intelligence Reporting
- Risk Segmentation
- Data Quality Management
- Financial Analytics
- Decision Support Systems
- Problem Solving

---

## Project Deliverables

- Credit Risk Analysis
- Portfolio Default Rate Analysis
- Probability of Default (PD) Scoring
- Credit Decision Engine
- Risk Segmentation Analysis
- Loan Portfolio Monitoring
- SQL Reporting Views
- Business Recommendations
- Data Quality Improvements

---

## Results

The final solution provides a reusable and reliable framework for credit portfolio analysis and lending decision support.

By correcting data integrity issues and implementing standardized risk analyses, the project delivers:

- Accurate portfolio reporting.
- Reliable borrower risk assessments.
- Improved lending intelligence.
- Better visibility into portfolio performance.
- A scalable foundation for future predictive credit risk models.

---

> **Note:** The Probability of Default (PD) model implemented in this project is a simplified rule-based scoring framework designed for analytical and educational purposes. It is intended to support business decision-making and should not be considered a production-grade machine learning model.
