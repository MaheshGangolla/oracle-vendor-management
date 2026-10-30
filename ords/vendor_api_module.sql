--------------------------------------------------------------------------------
-- vendor_api_module.sql : read-only REST API for downstream systems (ERP, AP)
--   GET /vendors/            approved vendors (paged collection)
--   GET /vendors/:id         one approved vendor
--   GET /vendors/:id/compliance   document status, no file content
--
-- Protect the module with an ORDS privilege and OAuth client credentials before
-- exposing it outside the database network (see docs/SECURITY.md).
--------------------------------------------------------------------------------
begin
  ords.enable_schema(p_enabled => true, p_url_mapping_type => 'BASE_PATH', p_url_mapping_pattern => 'vom');

  ords.define_module(
    p_module_name    => 'vom.vendor.api.v1',
    p_base_path      => '/v1/',
    p_items_per_page => 25,
    p_status         => 'PUBLISHED',
    p_comments       => 'Vendor Onboarding - approved vendor master data');

  ords.define_template(p_module_name => 'vom.vendor.api.v1', p_pattern => 'vendors/');
  ords.define_handler(
    p_module_name    => 'vom.vendor.api.v1',
    p_pattern        => 'vendors/',
    p_method         => 'GET',
    p_source_type    => ords.source_type_collection_feed,
    p_source         => q'[
      select vendor_number, vendor_name, country_code, category_code, risk_level, approved_on
        from vom_vendors
       where status = 'APPROVED'
       order by vendor_name]');

  ords.define_template(p_module_name => 'vom.vendor.api.v1', p_pattern => 'vendors/:id');
  ords.define_handler(
    p_module_name    => 'vom.vendor.api.v1',
    p_pattern        => 'vendors/:id',
    p_method         => 'GET',
    p_source_type    => ords.source_type_collection_item,
    p_source         => q'[
      select vendor_number, vendor_name, tax_registration_no, country_code, category_code,
             primary_contact_name, primary_email, risk_score, risk_level, approved_on
        from vom_vendors
       where vendor_id = :id
         and status = 'APPROVED']');

  ords.define_template(p_module_name => 'vom.vendor.api.v1', p_pattern => 'vendors/:id/compliance');
  ords.define_handler(
    p_module_name    => 'vom.vendor.api.v1',
    p_pattern        => 'vendors/:id/compliance',
    p_method         => 'GET',
    p_source_type    => ords.source_type_collection_feed,
    p_source         => q'[
      select t.doc_type_name, d.status, d.issued_on, d.expires_on, d.verified_on
        from vom_vendor_documents d
        join vom_document_types t on t.doc_type_code = d.doc_type_code
        join vom_vendors v        on v.vendor_id = d.vendor_id
       where d.vendor_id = :id
         and v.status = 'APPROVED'
       order by t.doc_type_name]');

  commit;
end;
/
