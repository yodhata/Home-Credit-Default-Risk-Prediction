SELECT "SK_ID_CURR"
FROM application_train;


SELECT *
FROM appication_all;


SELECT *
FROM bureau_balance where "SK_ID_BUREAU" = '5795694';


-- Cek Orphan
SELECT COUNT(*) AS orphan_rows
FROM public.bureau_balance bb
LEFT JOIN public.bureau b
  ON b."SK_ID_BUREAU" = bb."SK_ID_BUREAU"
WHERE b."SK_ID_BUREAU" IS NULL;


--hapus orphan
DELETE FROM public.bureau_balance bb
WHERE NOT EXISTS (
  SELECT 1
  FROM public.bureau b
  WHERE b."SK_ID_BUREAU" = bb."SK_ID_BUREAU"
);

--Foreign key bureau balance

ALTER TABLE public.bureau_balance
ADD CONSTRAINT fk_bureau_balance__bureau
FOREIGN KEY ("SK_ID_BUREAU")
REFERENCES public.bureau ("SK_ID_BUREAU");


select *
from bureau b
join bureau_balance bb on bb."SK_ID_BUREAU" = b."SK_ID_BUREAU";

--cek orphan
SELECT COUNT(*) AS orphan_rows
FROM public.pos_cash_balance p
LEFT JOIN public.previous_application pr
  ON pr."SK_ID_PREV" = p."SK_ID_PREV"
WHERE pr."SK_ID_PREV" IS NULL;

--hapus orphan
DELETE FROM public.pos_cash_balance p
WHERE NOT EXISTS (
  SELECT 1
  FROM public.previous_application pr
  WHERE pr."SK_ID_PREV" = p."SK_ID_PREV");

--foreign key posh cash balance
ALTER TABLE public.pos_cash_balance
ADD CONSTRAINT fk_pos_cash_balance
FOREIGN KEY ("SK_ID_PREV")
REFERENCES public.previous_application ("SK_ID_PREV");


--cek orphan installments_payments
SELECT COUNT(*) AS orphan_rows
FROM public.installments_payments ip
LEFT JOIN public.previous_application pr
  ON pr."SK_ID_PREV" = ip."SK_ID_PREV"
WHERE pr."SK_ID_PREV" IS NULL;

--hapus orphan installments_payments
DELETE FROM public.installments_payments ip
WHERE NOT EXISTS (
  SELECT 1
  FROM public.previous_application pr
  WHERE pr."SK_ID_PREV" = ip."SK_ID_PREV");

-- foreign key installments_payments
ALTER TABLE public.installments_payments
ADD CONSTRAINT fk_installments_payments
FOREIGN KEY ("SK_ID_PREV")
REFERENCES public.previous_application ("SK_ID_PREV");


--cek orphan credit card balance
SELECT COUNT(*) AS orphan_rows
FROM public.credit_card_balance cc
LEFT JOIN public.previous_application pr
  ON pr."SK_ID_PREV" = cc."SK_ID_PREV"
WHERE pr."SK_ID_PREV" IS NULL;

--hapus orphan cc
DELETE FROM public.credit_card_balance cc
WHERE NOT EXISTS (
  SELECT 1
  FROM public.previous_application pr
  WHERE pr."SK_ID_PREV" = cc."SK_ID_PREV");

-- foreign key installments_payments
ALTER TABLE public.credit_card_balance
ADD CONSTRAINT fk_credit_card_balance
FOREIGN KEY ("SK_ID_PREV")
REFERENCES public.previous_application ("SK_ID_PREV");

-- foreign key 
ALTER TABLE public.credit_card_balance
ADD CONSTRAINT fk_credit_card_app
FOREIGN KEY ("SK_ID_CURR")
REFERENCES public.appication_all ("SK_ID_CURR");

-- foreign key installments_payments
ALTER TABLE public.installments_payments
ADD CONSTRAINT fk_installments_payments_app
FOREIGN KEY ("SK_ID_CURR")
REFERENCES public.appication_all ("SK_ID_CURR");

-- foreign key installments_payments
ALTER TABLE public.pos_cash_balance
ADD CONSTRAINT fk_pos_cash_balance_app
FOREIGN KEY ("SK_ID_CURR")
REFERENCES public.appication_all ("SK_ID_CURR");

-- CTE
WITH
feat_bureau AS (
  SELECT
    "SK_ID_CURR",
    COUNT(*) AS bureau_cnt_total,
    SUM(CASE WHEN "CREDIT_ACTIVE" = 'Active' THEN 1 ELSE 0 END) AS bureau_cnt_active,
    SUM(COALESCE("AMT_CREDIT_SUM_DEBT",0)) AS bureau_sum_debt,
    SUM(COALESCE("AMT_CREDIT_SUM_OVERDUE",0)) AS bureau_sum_overdue,
    MAX(COALESCE("CREDIT_DAY_OVERDUE",0)) AS bureau_max_overdue_days
  FROM public.bureau
  GROUP BY "SK_ID_CURR"
),
feat_prev AS (
  SELECT
    "SK_ID_CURR",
    COUNT(*) AS prev_cnt,
    SUM(CASE WHEN "NAME_CONTRACT_STATUS" = 'Approved' THEN 1 ELSE 0 END) AS prev_cnt_approved,
    SUM(CASE WHEN "NAME_CONTRACT_STATUS" = 'Refused'  THEN 1 ELSE 0 END) AS prev_cnt_refused,
    AVG(COALESCE("AMT_CREDIT",0)) AS prev_avg_amt_credit,
    AVG(COALESCE("AMT_ANNUITY",0)) AS prev_avg_amt_annuity,
    MAX(COALESCE("DAYS_DECISION", -999999)) AS prev_last_days_decision
  FROM public.previous_application
  GROUP BY "SK_ID_CURR"
),
feat_inst AS (
  SELECT
    "SK_ID_CURR",
    COUNT(*) AS inst_cnt,
    SUM(CASE WHEN "DAYS_ENTRY_PAYMENT" > "DAYS_INSTALMENT" THEN 1 ELSE 0 END) AS inst_late_cnt,
    AVG(GREATEST(COALESCE("DAYS_ENTRY_PAYMENT" - "DAYS_INSTALMENT",0),0)) AS inst_late_days_avg,
    MAX(GREATEST(COALESCE("DAYS_ENTRY_PAYMENT" - "DAYS_INSTALMENT",0),0)) AS inst_late_days_max,
    SUM(COALESCE("AMT_PAYMENT",0)) / NULLIF(SUM(COALESCE("AMT_INSTALMENT",0)),0) AS inst_paid_ratio
  FROM public.installments_payments
  GROUP BY "SK_ID_CURR"
),
feat_pos AS (
  SELECT
    "SK_ID_CURR",
    COUNT(*) AS pos_rows,
    AVG(COALESCE("SK_DPD",0)) AS pos_dpd_avg,
    MAX(COALESCE("SK_DPD",0)) AS pos_dpd_max
  FROM public.pos_cash_balance
  GROUP BY "SK_ID_CURR"
),
feat_cc AS (
  SELECT
    "SK_ID_CURR",
    COUNT(*) AS cc_rows,
    AVG(COALESCE("AMT_BALANCE",0) / NULLIF(COALESCE("AMT_CREDIT_LIMIT_ACTUAL",0),0)) AS cc_util_avg,
    MAX(COALESCE("SK_DPD",0)) AS cc_dpd_max
  FROM public.credit_card_balance
  GROUP BY "SK_ID_CURR"
)

-- ===== MART TRAIN =====
SELECT
  a."SK_ID_CURR",
  a."TARGET",

  -- core money
  a."AMT_INCOME_TOTAL",
  a."AMT_CREDIT",
  a."AMT_ANNUITY",
  a."AMT_GOODS_PRICE",

  -- external scores
  a."EXT_SOURCE_1",
  a."EXT_SOURCE_2",
  a."EXT_SOURCE_3",

  -- time (nanti kamu ubah ke umur/masa kerja di python)
  a."DAYS_BIRTH",
  a."DAYS_EMPLOYED",

  -- profile
  a."CODE_GENDER",
  a."NAME_INCOME_TYPE",
  a."NAME_EDUCATION_TYPE",
  a."OCCUPATION_TYPE",
  a."CNT_CHILDREN",
  a."CNT_FAM_MEMBERS",

  -- assets
  a."FLAG_OWN_CAR",
  a."FLAG_OWN_REALTY",
  a."OWN_CAR_AGE",

  -- region
  a."REGION_RATING_CLIENT",
  a."REGION_RATING_CLIENT_W_CITY",

  -- bureau enquiries (yang “year”)
  a."AMT_REQ_CREDIT_BUREAU_YEAR",

  -- aggregated features
  b.bureau_cnt_total, b.bureau_cnt_active, b.bureau_sum_debt, b.bureau_sum_overdue, b.bureau_max_overdue_days,
  p.prev_cnt, p.prev_cnt_approved, p.prev_cnt_refused, p.prev_avg_amt_credit, p.prev_avg_amt_annuity, p.prev_last_days_decision,
  i.inst_cnt, i.inst_late_cnt, i.inst_late_days_avg, i.inst_late_days_max, i.inst_paid_ratio,
  pos.pos_rows, pos.pos_dpd_avg, pos.pos_dpd_max,
  cc.cc_rows, cc.cc_util_avg, cc.cc_dpd_max
FROM public.appication_all a
LEFT JOIN feat_bureau b ON b."SK_ID_CURR" = a."SK_ID_CURR"
LEFT JOIN feat_prev   p ON p."SK_ID_CURR" = a."SK_ID_CURR"
LEFT JOIN feat_inst   i ON i."SK_ID_CURR" = a."SK_ID_CURR"
LEFT JOIN feat_pos   pos ON pos."SK_ID_CURR" = a."SK_ID_CURR"
LEFT JOIN feat_cc    cc ON cc."SK_ID_CURR" = a."SK_ID_CURR";