--------------------------------------------------------------------------------
-- vom_document_mgr : compliance document rules
--   * expiry date derived from document type validity
--   * status maintenance (VALID / EXPIRING / EXPIRED)
--   * mandatory document completeness check
--------------------------------------------------------------------------------
create or replace package vom_document_mgr as

  c_expiring_days constant pls_integer := 30;

  procedure verify_document (p_doc_id in number);

  procedure reject_document (p_doc_id in number, p_reason in varchar2);

  -- Recalculates the status of one vendor's documents (or all, when null)
  procedure refresh_statuses (p_vendor_id in number default null);

  -- Comma-separated names of mandatory documents that are missing or not usable
  function missing_mandatory_docs (p_vendor_id in number) return varchar2;

  function is_complete (p_vendor_id in number) return boolean;

end vom_document_mgr;
/

create or replace package body vom_document_mgr as

  function status_for (p_expires_on in date) return varchar2 is
  begin
    return case
             when p_expires_on is null                        then 'VALID'
             when p_expires_on < trunc(sysdate)               then 'EXPIRED'
             when p_expires_on <= sysdate + c_expiring_days   then 'EXPIRING'
             else 'VALID'
           end;
  end status_for;

  procedure verify_document (p_doc_id in number) is
    l_doc vom_vendor_documents%rowtype;
    l_validity vom_document_types.validity_months%type;
  begin
    vom_security.assert_role('COMPLIANCE');

    select * into l_doc from vom_vendor_documents where doc_id = p_doc_id for update;
    select validity_months into l_validity from vom_document_types where doc_type_code = l_doc.doc_type_code;

    -- Derive expiry from the issue date when the uploader did not provide one
    if l_doc.expires_on is null and l_doc.issued_on is not null and l_validity is not null then
      l_doc.expires_on := add_months(l_doc.issued_on, l_validity);
    end if;

    update vom_vendor_documents
       set status      = status_for(l_doc.expires_on),
           expires_on  = l_doc.expires_on,
           verified_by = vom_util.current_user,
           verified_on = sysdate
     where doc_id = p_doc_id;

    vom_util.audit('DOCUMENT', p_doc_id, 'VERIFY', l_doc.status, status_for(l_doc.expires_on));
  end verify_document;

  procedure reject_document (p_doc_id in number, p_reason in varchar2) is
    l_old vom_vendor_documents.status%type;
  begin
    vom_security.assert_role('COMPLIANCE');
    select status into l_old from vom_vendor_documents where doc_id = p_doc_id for update;
    update vom_vendor_documents
       set status = 'REJECTED', verified_by = vom_util.current_user, verified_on = sysdate
     where doc_id = p_doc_id;
    vom_util.audit('DOCUMENT', p_doc_id, 'REJECT', l_old, 'REJECTED', p_reason);
  end reject_document;

  procedure refresh_statuses (p_vendor_id in number default null) is
  begin
    for d in (select doc_id, status, expires_on
                from vom_vendor_documents
               where (p_vendor_id is null or vendor_id = p_vendor_id)
                 and status in ('VALID', 'EXPIRING', 'EXPIRED')
                 for update)
    loop
      if status_for(d.expires_on) <> d.status then
        update vom_vendor_documents set status = status_for(d.expires_on) where doc_id = d.doc_id;
        vom_util.audit('DOCUMENT', d.doc_id, 'STATUS_REFRESH', d.status, status_for(d.expires_on));
      end if;
    end loop;
  end refresh_statuses;

  function missing_mandatory_docs (p_vendor_id in number) return varchar2 is
    l_missing varchar2(4000);
  begin
    select listagg(t.doc_type_name, ', ') within group (order by t.doc_type_name)
      into l_missing
      from vom_document_types t
      join vom_vendors v on v.vendor_id = p_vendor_id
     where t.mandatory_yn = 'Y'
       and (t.category_code is null or t.category_code = v.category_code)
       and not exists (select 1
                         from vom_vendor_documents d
                        where d.vendor_id = p_vendor_id
                          and d.doc_type_code = t.doc_type_code
                          and d.status in ('PENDING', 'VALID', 'EXPIRING'));
    return l_missing;
  end missing_mandatory_docs;

  function is_complete (p_vendor_id in number) return boolean is
  begin
    return missing_mandatory_docs(p_vendor_id) is null;
  end is_complete;

end vom_document_mgr;
/
