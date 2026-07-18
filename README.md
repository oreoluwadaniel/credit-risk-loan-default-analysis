# Credit decisioning and portfolio risk intelligence

SQL project for a fictional bank, Stratavax. Built in T-SQL (SQL Server). This project stands on its own. It shares a dataset with a second project in this portfolio, a real-time fraud detection analysis, but the two ask different questions and should be read separately.

The full script is in [credit-risk-loan-default.sql](./credit-risk-loan-default.sql).

## Business problem

Lending is a bet on the future. Every loan a bank approves is a bet that the borrower will pay it back, and the bank only finds out if it was right months or years later. The credit risk team's job is to make that bet smarter before the money goes out the door, and to catch it early if a loan already on the books is heading toward trouble.

The problem in practice looks like this: loan data lives in one table, payment history lives in another, and credit scores live in a third. Nobody can answer "which borrowers are actually at risk right now" without pulling all three together, and doing that by hand every time someone asks is not a real process, it is a bottleneck. This script builds that process once, as a repeatable set of queries anyone on the credit team can run.

## Data source

This is a synthetic dataset built to mirror what a bank's lending systems would actually hold, roughly 3,000 records across four related tables:

- **bank_loans**: loan_id, customer_id, loan_type, loan_amount, interest_rate, status
- **loan_payments**: payment_id, loan_id, payment_amount, payment_date
- **bank_customers**: customer_id, name, age, country, income
- **credit_scores**: customer_id, credit_score, risk_band

Loan status is either Active, Closed, or Default. Loan type spans Business, Auto, Personal, and Mortgage products in roughly even numbers. Payments are the one table here that does not map neatly one row per loan. A loan can have zero payments on record, one payment, or several, and that turned out to matter a lot for how this script needed to be built. More on that below.

## Methodology

**Understand the grain of every table before joining anything.** This is the step that got skipped in the original version of this script, and it is the reason most of what follows exists. "Grain" just means what one row in a table actually represents. One row in bank_loans is one loan. One row in loan_payments is one payment, and a single loan can have several. Joining a one-row-per-loan table to a many-rows-per-loan table without aggregating first means your combined result is no longer at loan grain, it is at loan-times-payment grain, and every count you run on it afterward is wrong in a way that is very easy to miss because the query still runs and still returns numbers.

**Aggregate before you join, not after.** Once I confirmed loans and payments do not have a clean one-to-one relationship, I built a payment summary view that collapses loan_payments down to one row per loan (total paid, number of payments, most recent payment date) before joining it onto the loans table. That keeps the master reporting view at loan grain, which is what every downstream KPI assumes.

**Rule based scoring as a first pass, not a final model.** The probability of default logic in this script assigns a fixed score based on credit score bands. That is a reasonable starting point for ranking risk quickly. It is not a real predictive model, and the documentation says so directly rather than dressing it up as more sophisticated than it is.

**Segment before you average.** A single portfolio-wide default rate hides more than it reveals. This script breaks default rates out by risk band, income segment, interest rate band, and loan product, because a lender needs to know which segments are driving the number, not just what the number is.

## Analysis and error check

I went through the original script line by line, and this one needed more work than a quick pass.

**The formatting was broken before the logic was even a question.** The original script had markdown code fences (the triple backtick blocks you see when code is displayed on a webpage) wrapped around several SELECT lists, left over from wherever this was copied out of. That is not valid SQL syntax. Running this script as written would throw a syntax error before it ever got to the interesting part. First fix: stripped every stray code fence out.

**The real bug: loans were getting double counted.** This is the one that matters most, so I want to walk through it plainly. The original `v_credit_master` view joined loan_payments directly onto bank_loans using a LEFT JOIN on loan_id. I checked the actual data: loan_payments has close to 3,000 rows and bank_loans has close to 3,000 rows, but they are not a one-to-one match. Some loans have two payment records, which means those loans have zero. When you join a table with duplicate loan_id values onto bank_loans, every loan with more than one payment shows up more than once in the result. A loan with two payments appears twice.

That does not sound serious until you look at what got built on top of that view. KPI 6 (income segment risk), KPI 9 (the probability of default scores), and KPI 11 (the credit decision engine) all read directly from v_credit_master. Every one of them was silently inflating results for any borrower with more than one payment on file: more loans counted than actually exist, more defaults counted than actually happened, and duplicate decision rows for the same loan_id in the underwriting output. If this had gone live, a portfolio risk report built on this view would have overstated exposure in the segments where borrowers happen to make more frequent payments, which is not a random pattern, it correlates with loan type and repayment behavior.

The fix: aggregate loan_payments to one row per loan_id first (I did this in a separate view, `v_loan_payment_summary`), then join that summary onto bank_loans. The master view is now guaranteed to have exactly one row per loan, matching bank_loans row for row.

**A quieter issue: an inner join was silently dropping loans.** KPI 5 (credit quality analysis) used an INNER JOIN to credit_scores. Any loan whose customer somehow lacked a credit score record would vanish from that KPI's totals without any warning. I switched it to a LEFT JOIN, so the portfolio total in that KPI actually reflects the full portfolio.

**A design issue: grouping on a continuous value.** KPI 7 (interest rate impact) grouped directly on the interest_rate column. Since interest rates in this data are precise decimals like 3.32 or 8.98, that produces one row per unique rate value, essentially one row per loan, which is not an analysis anyone can read or act on. I bucketed rates into bands (under 5 percent, 5 to 8, 8 to 11, 11 and above) so the trend is actually visible.

## Insight

Once the grain issue is fixed, the portfolio shows a default rate of about 10.7 percent, 321 defaulted loans out of roughly 3,000. Risk bands, loan products, and countries are all close to evenly distributed in this dataset, which again tells me this is a synthetic set built for practicing analysis rather than a real portfolio (a real book of loans is rarely this evenly split across risk tiers). What is worth taking from this dataset is not "here is the exact default rate," it is the shape of the analysis: which segments carry more default risk than others once you actually segment correctly, and how much that answer would have been distorted by the join bug if it had gone uncorrected.

The credit decision engine (KPI 11) is a genuinely useful pattern even in its simplified form: turning a raw credit score into a Reject, Review, or Approve label is exactly the kind of translation that makes a loan officer's job faster, as long as everyone understands it is a first pass filter and not the final word on an application.

## Recommendation

Treat the corrected v_credit_master view as the one source of truth for loan-level reporting going forward, and retire any other version of this join that might exist elsewhere. Duplicate joins are how this kind of bug creeps back in.

Use the segmented default rates (by risk band, income, interest rate, and loan type) to inform underwriting policy, not just to report on it after the fact. If subprime borrowers in a specific loan product are defaulting at a meaningfully higher rate, that is a pricing or approval criteria conversation, not just a chart for a monthly deck.

Be explicit, every time the PD score or the decision engine output gets shared outside the data team, that both are simplified, rule based tools meant to support a human underwriter's judgment, not replace it. Mislabeling a rough heuristic as a real risk model is how bad lending decisions get made with total confidence.

## Business impact

Fixing the join bug alone protects the business from a very real failure mode: making portfolio decisions based on inflated numbers and not knowing it. Beyond that fix, this framework gives the credit team a repeatable way to spot which borrower segments and loan products are driving default risk, a faster first pass on new loan applications, and one shared definition of portfolio risk that does not depend on whoever happens to be running the query that week.

## What was done

I reviewed both scripts in this dataset's project, but this document covers the credit risk script specifically. I traced the loan_payments to bank_loans relationship in the actual data to confirm the fan out was real, not theoretical, rebuilt the master view to aggregate payments before joining, fixed an inner join that was silently excluding loans, rebucketed a KPI that was grouping on a continuous value, and stripped formatting artifacts that would have broken the script outright. Every change is documented inline in the corrected SQL file.

## Tools used and how they helped

**SQL Server (T-SQL)** for the full build: views, CASE based segmentation and scoring, and aggregate functions across every KPI.

**Views**, specifically a two-layer approach here: one view to aggregate payments to loan grain, and a second view that joins that summary onto loans and customer data. Separating those two steps is what makes the grain of the final view predictable and easy to reason about.

**CASE statements** throughout for turning continuous values (income, interest rate, credit score) into the kind of labeled bands a lending team actually thinks and talks in, like "Subprime" or "5 to 8 percent," instead of raw numbers nobody can act on at a glance.

**Manual grain checking against the raw CSV data**, not just reading the SQL and assuming it was right. This is what caught the double counting bug. A join that looks fine on the page can still be wrong if you have not confirmed what each table's rows actually represent.

## Results

A corrected, working credit risk script with a genuine data integrity bug found, explained, and fixed, not just patched over. The portfolio default rate, segment level risk breakdowns, PD scoring, and credit decision engine now all run on a view that is guaranteed to be one row per loan, which means every number that comes out of this script can be trusted at face value instead of needing a mental asterisk next to it.
