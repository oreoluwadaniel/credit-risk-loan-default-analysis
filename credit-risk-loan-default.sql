/* ================================================================
   CREDIT DECISIONING & PORTFOLIO RISK INTELLIGENCE
   Stratavax Bank | Credit Risk
   Written for SQL Server (T-SQL)
   ================================================================

   Business objective
   ----------------------------------------------------------------
   Evaluate borrower risk, loan portfolio health, and default
   patterns to support better lending decisions and stronger
   credit risk management.

   Tables used
   ----------------------------------------------------------------
   bank_loans      loan_id, customer_id, loan_type, loan_amount,
                    interest_rate, status
   loan_payments   payment_id, loan_id, payment_amount, payment_date
   bank_customers  customer_id, name, age, country, income
   credit_scores   customer_id, credit_score, risk_band

   Corrections made during review (see README for the full writeup)
   ----------------------------------------------------------------
   1. The original script had markdown code fences (triple
      backticks) wrapped around several SELECT lists, left over
      from being copied out of a chat or notes app. That is not
      valid SQL and would throw a syntax error on execution.
      Removed everywhere.
   2. v_credit_master joined loan_payments directly onto bank_loans.
      loan_payments is many-to-one against loans (some loans have
      2+ payment records), so a loan with 2 payments showed up
      twice in the view, and any KPI counting rows from that view
      double counted that loan and its default status. Fixed by
      aggregating payments to one row per loan first, then joining
      that summary onto bank_loans.
   3. KPI 5 used an INNER JOIN to credit_scores, which would drop
      any loan whose customer has no credit score on file from the
      portfolio total. Switched to LEFT JOIN.
   4. KPI 7 grouped by the raw interest_rate value, which is a
      continuous decimal (2.57%, 8.98%, etc), so it produced one
      row per unique rate instead of a usable trend. Bucketed into
      bands instead.
   ================================================================ */


/*-----------------------------------------------------------------
STEP 1: REPAYMENT SUMMARY (LOAN GRAIN)

Aggregate loan_payments down to one row per loan before it touches
anything else. This is what keeps the master view below from
duplicating loans that have multiple payment records.
-----------------------------------------------------------------*/

CREATE VIEW v_loan_payment_summary AS

SELECT
    loan_id,
    COUNT(*) AS num_payments,
    SUM(payment_amount) AS total_paid,
    MAX(payment_date) AS last_payment_date

FROM loan_payments

GROUP BY loan_id;



/*-----------------------------------------------------------------
STEP 2: BUILD THE CREDIT RISK REPORTING VIEW

Joins the pre-aggregated payment summary (one row per loan) rather
than the raw loan_payments table (one row per payment), so this
view stays at loan grain and matches bank_loans row for row.
-----------------------------------------------------------------*/

CREATE VIEW v_credit_master AS

SELECT

    l.loan_id,
    l.customer_id,
    l.loan_type,
    l.loan_amount,
    l.interest_rate,
    l.status,

    ps.num_payments,
    ps.total_paid,
    ps.last_payment_date,

    c.age,
    c.country,
    c.income,

    cs.credit_score,
    cs.risk_band

FROM bank_loans l

LEFT JOIN v_loan_payment_summary ps
    ON l.loan_id = ps.loan_id

LEFT JOIN bank_customers c
    ON l.customer_id = c.customer_id

LEFT JOIN credit_scores cs
    ON l.customer_id = cs.customer_id;



/*-----------------------------------------------------------------
KPI 1: PORTFOLIO DEFAULT RATE

Share of all loans currently in Default status.
-----------------------------------------------------------------*/

SELECT

    COUNT(
        CASE
            WHEN status = 'Default'
            THEN 1
        END
    ) * 1.0 / COUNT(*) AS default_rate

FROM bank_loans;



/*-----------------------------------------------------------------
KPI 2: LOAN PORTFOLIO EXPOSURE

Total and average loan size across the whole portfolio.
-----------------------------------------------------------------*/

SELECT

    SUM(loan_amount) AS total_loans,
    AVG(loan_amount) AS avg_loan

FROM bank_loans;



/*-----------------------------------------------------------------
KPI 3: REPAYMENT BEHAVIOR ANALYSIS

Payment count and total repaid per loan, straight from
loan_payments. This was already correct at loan grain in the
original script and did not need a fix.
-----------------------------------------------------------------*/

SELECT

    loan_id,
    COUNT(*) AS num_payments,
    SUM(payment_amount) AS total_paid

FROM loan_payments

GROUP BY loan_id;



/*-----------------------------------------------------------------
KPI 4: NON-PERFORMING LOAN MONITORING

Loans currently in default, for collections follow up.
-----------------------------------------------------------------*/

SELECT

    loan_id,
    loan_amount,
    status

FROM bank_loans

WHERE status = 'Default';



/*-----------------------------------------------------------------
KPI 5: CREDIT QUALITY ANALYSIS

Default counts by risk band.

Fixed: switched from INNER JOIN to LEFT JOIN on credit_scores so a
loan without a matching credit score record still counts toward
the portfolio instead of quietly dropping out of the total.

Prime Customers      : Lower Risk Borrowers
Mid Tier Customers   : Moderate Risk Borrowers
Subprime Customers   : Higher Risk Borrowers
-----------------------------------------------------------------*/

SELECT

    cs.risk_band,
    COUNT(*) AS total_loans,

    SUM(
        CASE
            WHEN l.status = 'Default'
            THEN 1
            ELSE 0
        END
    ) AS defaults

FROM bank_loans l

LEFT JOIN credit_scores cs
    ON l.customer_id = cs.customer_id

GROUP BY cs.risk_band;



/*-----------------------------------------------------------------
KPI 6: INCOME SEGMENT RISK ANALYSIS

Fixed: now reads from the corrected, loan-grain v_credit_master,
so loans are no longer duplicated for borrowers with more than one
payment on file. Before this fix, loan and default counts here
were inflated for any borrower with 2+ payments.
-----------------------------------------------------------------*/

SELECT

    CASE
        WHEN income < 30000 THEN 'Low Income'
        WHEN income < 100000 THEN 'Middle Income'
        ELSE 'High Income'
    END AS income_segment,

    COUNT(*) AS loans,

    SUM(
        CASE
            WHEN status = 'Default'
            THEN 1
            ELSE 0
        END
    ) AS defaults

FROM v_credit_master

GROUP BY

    CASE
        WHEN income < 30000 THEN 'Low Income'
        WHEN income < 100000 THEN 'Middle Income'
        ELSE 'High Income'
    END;



/*-----------------------------------------------------------------
KPI 7: INTEREST RATE IMPACT ANALYSIS

Fixed: interest_rate is a continuous decimal value, so grouping on
the raw column produced one row per unique rate rather than a
trend anyone could read. Bucketed into 3-point bands instead.
-----------------------------------------------------------------*/

SELECT

    CASE
        WHEN interest_rate < 5 THEN 'Under 5%'
        WHEN interest_rate < 8 THEN '5% to 8%'
        WHEN interest_rate < 11 THEN '8% to 11%'
        ELSE '11% and above'
    END AS interest_rate_band,

    COUNT(*) AS loans,

    SUM(
        CASE
            WHEN status = 'Default'
            THEN 1
            ELSE 0
        END
    ) AS defaults

FROM bank_loans

GROUP BY

    CASE
        WHEN interest_rate < 5 THEN 'Under 5%'
        WHEN interest_rate < 8 THEN '5% to 8%'
        WHEN interest_rate < 11 THEN '8% to 11%'
        ELSE '11% and above'
    END

ORDER BY MIN(interest_rate);



/*-----------------------------------------------------------------
KPI 8: LOAN PRODUCT RISK ANALYSIS

Default counts by loan type, to see which products carry the
most portfolio risk.
-----------------------------------------------------------------*/

SELECT

    loan_type,
    COUNT(*) AS total_loans,

    SUM(
        CASE
            WHEN status = 'Default'
            THEN 1
            ELSE 0
        END
    ) AS defaults

FROM bank_loans

GROUP BY loan_type;



/*-----------------------------------------------------------------
KPI 9: PROBABILITY OF DEFAULT MODEL

A simplified, rule based stand in for a real PD model. It assigns
a fixed probability by credit score band. This is useful for
ranking risk quickly, it is not a substitute for a model
calibrated on actual historical default outcomes, and should be
labeled as an estimate wherever it is shown to stakeholders.
-----------------------------------------------------------------*/

SELECT

    loan_id,
    customer_id,
    credit_score,
    income,
    interest_rate,

    CASE
        WHEN credit_score < 500 THEN 0.7
        WHEN credit_score < 650 THEN 0.4
        ELSE 0.1
    END AS pd_score

FROM v_credit_master;



/*-----------------------------------------------------------------
KPI 10: BORROWER RISK CLASSIFICATION

Groups loans into risk categories from the PD score above.

Fixed automatically by the v_credit_master correction: this now
returns one row per loan instead of one row per loan-payment pair.

High Risk      : Elevated default probability.
Medium Risk    : Moderate default probability.
Low Risk       : Lower default probability.
-----------------------------------------------------------------*/

SELECT

    loan_id,
    pd_score,

    CASE
        WHEN pd_score > 0.6
            THEN 'High Risk'

        WHEN pd_score > 0.3
            THEN 'Medium Risk'

        ELSE 'Low Risk'

    END AS risk_category

FROM (

    SELECT

        loan_id,

        CASE
            WHEN credit_score < 500 THEN 0.7
            WHEN credit_score < 650 THEN 0.4
            ELSE 0.1
        END AS pd_score

    FROM v_credit_master

) x;



/*-----------------------------------------------------------------
KPI 11: CREDIT DECISION ENGINE

A simplified lending recommendation based on credit score alone.
In a real underwriting workflow, this would sit alongside income,
existing debt, and loan purpose, not replace them.

Reject Loan      : Elevated portfolio risk.
Review Manually  : Additional assessment required.
Approve Loan     : Acceptable credit profile.
-----------------------------------------------------------------*/

SELECT

    loan_id,
    customer_id,
    loan_amount,
    credit_score,

    CASE

        WHEN credit_score < 500
            THEN 'Reject Loan'

        WHEN credit_score < 650
            THEN 'Review Manually'

        ELSE 'Approve Loan'

    END AS decision

FROM v_credit_master;



/*================================================================

BUSINESS IMPACT

This framework enables the credit risk team to:

- Make faster, more consistent lending decisions.
- Catch portfolio risk building up before it shows up in losses.
- See which borrower segments and loan products carry the most
  default risk.
- Track portfolio health over time using one shared view instead
  of everyone pulling their own numbers.
- Prioritize manual underwriting review where it actually matters.

================================================================*/
