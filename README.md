# Home Credit Payment Difficulty Prediction (TARGET=1)

Predict the probability of payment difficulties (TARGET=1) using applicant attributes and aggregated credit-history features. The project builds a customer-level dataset in PostgreSQL using CTE-based aggregations, then performs EDA, model training, evaluation (AUPRC for imbalanced data), and explainability using feature importance.

## Business Context
Home Credit needs a reliable way to identify higher-risk applicants using limited and heterogeneous credit history. This model is designed for early risk screening to support underwriting decisions and manual review prioritization.

## Objective
Develop a machine learning classification model that predicts the probability of payment difficulties (TARGET=1) from application and credit-history data, and identify the most influential risk drivers.

## Dataset
Source tables (entity relationship based on the provided ERD):
- `application_train` (has `TARGET`)
- `application_test` (no `TARGET`, used for final prediction/submission)
- `bureau`
- `previous_application`
- `installments_payments`
- `pos_cash_balance`
- `credit_card_balance`

Key identifier:
- `SK_ID_CURR` = unique customer/application ID (customer-level grain after aggregation)

Important note:
- `application_test` has no `TARGET` because it is intended for **scoring** (producing predicted probabilities), not evaluation.

## End-to-End Workflow
1. **PostgreSQL (CTE)** builds a single customer-level dataset by aggregating credit-history tables into summary features per `SK_ID_CURR`
2. **Python preprocessing** creates two tracks: EDA-ready and ML-ready datasets
3. **EDA** explores imbalance, distributions, and key relationships
4. **Modeling** trains Logistic Regression and XGBoost, tunes hyperparameters with Optuna, evaluates using AUPRC, and explains results via feature importance

## Feature Engineering (SQL CTE Aggregations)
Customer-level summary feature groups:
- Application attributes (income, credit amount, demographics)
- Bureau summary (active counts, debt, overdue)
- Previous applications (approved/refused counts, averages)
- Installments behavior (late counts, late days, paid ratio)
- POS and credit card behavior (rows, DPD, utilization)

Example output: one row per `SK_ID_CURR` with ~45 features.

## Preprocessing
### EDA-ready
- Create `ext_median` from `EXT_SOURCE_1/2/3` using median
- Convert time variables:
  - `DAYS_BIRTH` → `age_years`
  - `DAYS_EMPLOYED` → `employed_years`
- Check duplicates (0 duplicates)
- Handle numeric missing values using median imputation

### ML-ready
- Apply the same transformations as EDA-ready
- Outlier screening using `np.log1p` for skewed numeric features
- One-Hot Encoding (OHE) for categorical variables
- Scaling:
  - Logistic Regression: `StandardScaler` on numeric features
  - XGBoost: no scaling (OHE only) to keep features consistent for explainability
- Reduce redundant correlated features to minimize multicollinearity risk (especially helpful for linear models)

## EDA Highlights
- Class imbalance: TARGET=1 is a minority class (~8%)
- `ext_median` shows clear separation between classes and a statistically significant difference (Mann–Whitney U, p < 0.001)

## Modeling
Models:
- Logistic Regression (baseline)
- XGBoost (main model)

Hyperparameter tuning:
- Optuna for XGBoost
- Metric: **AUPRC** (best suited for imbalanced classification)

Threshold tuning:
- Threshold chosen on validation set using PR-curve and best F1 (can be adjusted for business policy)

## Results
Performance summary (AUPRC):

| Model | Stage | Train AUPRC | Test AUPRC | Notes |
|------|-------|-------------|------------|------|
| Logistic Regression | Before tuning | 0.2260 | 0.2319 | Baseline |
| Logistic Regression | After tuning | 0.2270 | 0.2323 | Small gain |
| XGBoost | Before tuning | 0.4430 | 0.2308 | Overfitting |
| XGBoost | After tuning | 0.2340 | 0.2364 | Best test AUPRC |

Additional evaluation:
- ROC-AUC: Train 0.75 vs Test 0.74 (stable generalization)
- Confusion matrix indicates trade-off between extra reviews (false positives) and missed risky borrowers (false negatives)

## Explainability
Top driver:
- `ext_median` is the strongest feature, where lower values are associated with higher predicted default risk

Other important contributors:
- `employed_years`, installment lateness features, POS activity, bureau debt, previous refusals, and selected demographic signals

## Business Recommendations
- Use the model for underwriting **risk tiering** (low, medium, high risk) rather than auto-rejection
- Apply enhanced verification for high-risk tier, especially when `ext_median` is low
- Choose the operating threshold based on business costs (missed defaults vs review workload)

## Links
- LinkedIn: <https://www.linkedin.com/in/yodha-pranata/>
- GitHub: <https://github.com/yodhata/Home-Credit-Default-Risk-Prediction>
- YouTube walkthrough: <https://youtu.be/2-VzSYtL1Hw>

## Notes
- This model is intended for decision support and prioritization, not automatic rejection
- Evaluation on `application_test` is not possible because it has no labels (TARGET)
