--------------------------------------------------------------------------------
-- 01_reference_data.sql : configuration the application needs to run
--------------------------------------------------------------------------------

-- Vendor categories
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('CATEGORY', 'IT_SERVICES',    'IT Services',              10);
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('CATEGORY', 'RAW_MATERIALS',  'Raw Materials',            20);
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('CATEGORY', 'LOGISTICS',      'Logistics & Freight',      30);
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('CATEGORY', 'FACILITIES',     'Facilities & Maintenance', 40);
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('CATEGORY', 'PROF_SERVICES',  'Professional Services',    50);

-- Categories treated as business-critical by the risk engine
insert into vom_lookups (lookup_type, code, meaning) values ('CRITICAL_CATEGORY', 'RAW_MATERIALS', 'Production depends on supply');
insert into vom_lookups (lookup_type, code, meaning) values ('CRITICAL_CATEGORY', 'LOGISTICS',     'Customer delivery depends on service');

-- Annual spend bands
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('SPEND_BAND', 'LOW',    'Below 50,000',          10);
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('SPEND_BAND', 'MEDIUM', '50,000 to 500,000',     20);
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('SPEND_BAND', 'HIGH',   'Above 500,000',         30);

-- Countries on the organisation's enhanced due-diligence list (placeholder codes; maintain per your policy)
insert into vom_lookups (lookup_type, code, meaning) values ('HIGH_RISK_COUNTRY', 'XA', 'Enhanced due diligence - example A');
insert into vom_lookups (lookup_type, code, meaning) values ('HIGH_RISK_COUNTRY', 'XB', 'Enhanced due diligence - example B');

-- Application roles
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('ROLE', 'ADMIN',       'Administrator',         10);
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('ROLE', 'PROCUREMENT', 'Procurement Officer',   20);
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('ROLE', 'COMPLIANCE',  'Compliance Officer',    30);
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('ROLE', 'FINANCE',     'Finance Controller',    40);
insert into vom_lookups (lookup_type, code, meaning, display_seq) values ('ROLE', 'VIEWER',      'Read-only User',        50);

insert into vom_lookups (lookup_type, code, meaning) values ('MAIL', 'FROM_ADDRESS', 'vendor-onboarding@example.com');

-- Compliance documents
insert into vom_document_types (doc_type_code, doc_type_name, mandatory_yn, validity_months, category_code)
  values ('TRADE_LICENSE',   'Trade / Business License',       'Y', 12, null);
insert into vom_document_types (doc_type_code, doc_type_name, mandatory_yn, validity_months, category_code)
  values ('TAX_CERT',        'Tax Registration Certificate',   'Y', 24, null);
insert into vom_document_types (doc_type_code, doc_type_name, mandatory_yn, validity_months, category_code)
  values ('BANK_LETTER',     'Bank Account Confirmation',      'Y', null, null);
insert into vom_document_types (doc_type_code, doc_type_name, mandatory_yn, validity_months, category_code)
  values ('INSURANCE',       'Liability Insurance Certificate','Y', 12, 'LOGISTICS');
insert into vom_document_types (doc_type_code, doc_type_name, mandatory_yn, validity_months, category_code)
  values ('ISO_CERT',        'ISO Quality Certificate',        'N', 36, null);
insert into vom_document_types (doc_type_code, doc_type_name, mandatory_yn, validity_months, category_code)
  values ('DATA_PROTECTION', 'Data Protection Agreement',      'Y', 24, 'IT_SERVICES');

-- Risk factors and weights (sum does not need to be 100; the engine normalises)
insert into vom_risk_factors (factor_code, description, weight) values ('COUNTRY',   'Country due-diligence level',          25);
insert into vom_risk_factors (factor_code, description, weight) values ('CATEGORY',  'Criticality of the supply category',   20);
insert into vom_risk_factors (factor_code, description, weight) values ('SPEND',     'Annual spend exposure',                20);
insert into vom_risk_factors (factor_code, description, weight) values ('DOCUMENTS', 'Compliance document completeness',     25);
insert into vom_risk_factors (factor_code, description, weight) values ('TAX_ID',    'Tax registration provided',            10);

-- Approval chains: more risk, more approvers
insert into vom_approval_rules (risk_level, step_seq, approver_role) values ('LOW',    1, 'PROCUREMENT');
insert into vom_approval_rules (risk_level, step_seq, approver_role) values ('MEDIUM', 1, 'PROCUREMENT');
insert into vom_approval_rules (risk_level, step_seq, approver_role) values ('MEDIUM', 2, 'COMPLIANCE');
insert into vom_approval_rules (risk_level, step_seq, approver_role) values ('HIGH',   1, 'PROCUREMENT');
insert into vom_approval_rules (risk_level, step_seq, approver_role) values ('HIGH',   2, 'COMPLIANCE');
insert into vom_approval_rules (risk_level, step_seq, approver_role) values ('HIGH',   3, 'FINANCE');

commit;
