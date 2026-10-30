--------------------------------------------------------------------------------
-- vom_workflow : risk-based, sequential approval chain
--   * the chain is generated from VOM_APPROVAL_RULES for the vendor's risk level
--   * step 1 is PENDING, later steps WAITING until the previous step is approved
--   * any rejection rejects the vendor and cancels the remaining steps
--   * the final approval approves the vendor and assigns a vendor number
--------------------------------------------------------------------------------
create or replace package vom_workflow as

  procedure start_approval (p_vendor_id in number);

  procedure decide (
    p_step_id   in number,
    p_decision  in varchar2,          -- 'APPROVED' or 'REJECTED'
    p_comments  in varchar2 default null
  );

end vom_workflow;
/

create or replace package body vom_workflow as

  procedure set_vendor_status (p_vendor_id in number, p_status in varchar2) is
    l_old vom_vendors.status%type;
  begin
    select status into l_old from vom_vendors where vendor_id = p_vendor_id for update;
    update vom_vendors
       set status      = p_status,
           approved_on = case when p_status = 'APPROVED' then sysdate else approved_on end,
           vendor_number = case when p_status = 'APPROVED' and vendor_number is null
                                then 'V' || to_char(sysdate, 'YY') || lpad(p_vendor_id, 6, '0')
                                else vendor_number end,
           updated_by  = vom_util.current_user,
           updated_on  = sysdate
     where vendor_id = p_vendor_id;
    vom_util.audit('VENDOR', p_vendor_id, 'STATUS_CHANGE', l_old, p_status);
  end set_vendor_status;

  procedure start_approval (p_vendor_id in number) is
    l_level  vom_vendors.risk_level%type;
    l_count  pls_integer := 0;
  begin
    l_level := vom_risk_engine.calculate(p_vendor_id);

    -- Cancel any chain left from an earlier submission
    update vom_approval_steps
       set status = 'CANCELLED'
     where vendor_id = p_vendor_id and status in ('PENDING', 'WAITING');

    for r in (select step_seq, approver_role
                from vom_approval_rules
               where risk_level = l_level
               order by step_seq)
    loop
      l_count := l_count + 1;
      insert into vom_approval_steps (vendor_id, step_seq, approver_role, status)
      values (p_vendor_id, r.step_seq, r.approver_role, case when l_count = 1 then 'PENDING' else 'WAITING' end);
    end loop;

    if l_count = 0 then
      raise_application_error(-20200, 'No approval rules configured for risk level ' || l_level || '.');
    end if;

    set_vendor_status(p_vendor_id, 'UNDER_REVIEW');
    vom_notify.notify_approvers(p_vendor_id);
  end start_approval;

  procedure decide (
    p_step_id   in number,
    p_decision  in varchar2,
    p_comments  in varchar2 default null
  ) is
    l_step vom_approval_steps%rowtype;
    l_next number;
  begin
    if p_decision not in ('APPROVED', 'REJECTED') then
      raise_application_error(-20201, 'Decision must be APPROVED or REJECTED.');
    end if;
    if p_decision = 'REJECTED' and p_comments is null then
      raise_application_error(-20202, 'A comment is required when rejecting.');
    end if;

    select * into l_step from vom_approval_steps where step_id = p_step_id for update;

    if l_step.status <> 'PENDING' then
      raise_application_error(-20203, 'This approval step is not awaiting a decision.');
    end if;
    vom_security.assert_role(l_step.approver_role);

    update vom_approval_steps
       set status = p_decision, decided_by = vom_util.current_user, decided_on = sysdate, comments = p_comments
     where step_id = p_step_id;
    vom_util.audit('APPROVAL_STEP', p_step_id, 'DECISION', 'PENDING', p_decision, p_comments);

    if p_decision = 'REJECTED' then
      update vom_approval_steps
         set status = 'CANCELLED'
       where vendor_id = l_step.vendor_id and status = 'WAITING';
      set_vendor_status(l_step.vendor_id, 'REJECTED');
      vom_notify.notify_vendor_outcome(l_step.vendor_id);
      return;
    end if;

    select min(step_id) keep (dense_rank first order by step_seq)
      into l_next
      from vom_approval_steps
     where vendor_id = l_step.vendor_id and status = 'WAITING';

    if l_next is not null then
      update vom_approval_steps set status = 'PENDING', created_on = sysdate where step_id = l_next;
      vom_notify.notify_approvers(l_step.vendor_id);
    else
      set_vendor_status(l_step.vendor_id, 'APPROVED');
      vom_notify.notify_vendor_outcome(l_step.vendor_id);
    end if;
  end decide;

end vom_workflow;
/
