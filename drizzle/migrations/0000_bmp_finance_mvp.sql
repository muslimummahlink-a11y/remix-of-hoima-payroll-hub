CREATE TABLE public.finance_members (user_id uuid PRIMARY KEY, role text NOT NULL DEFAULT 'team' CHECK (role IN ('manager','accountant','team','system')), email text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now());
GRANT SELECT ON public.finance_members TO authenticated;
GRANT ALL ON public.finance_members TO service_role;
ALTER TABLE public.finance_members ENABLE ROW LEVEL SECURITY;
INSERT INTO public.finance_members(user_id,role,email) SELECT r.user_id, CASE WHEN bool_or(r.role::text='admin') THEN 'manager' ELSE 'accountant' END, coalesce(u.email,'') FROM public.user_roles r JOIN auth.users u ON u.id=r.user_id GROUP BY r.user_id,u.email;
CREATE FUNCTION public.finance_role() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$ SELECT role FROM public.finance_members WHERE user_id=auth.uid() $$;
REVOKE ALL ON FUNCTION public.finance_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.finance_role() TO authenticated;
CREATE POLICY finance_member_read ON public.finance_members FOR SELECT TO authenticated USING(user_id=auth.uid() OR public.finance_role()='manager');
CREATE TABLE public.finance_records (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), kind text NOT NULL CHECK(kind IN ('accounts','contacts','projects','invoices','expenses','transactions')), data jsonb NOT NULL DEFAULT '{}'::jsonb, created_by uuid NOT NULL DEFAULT auth.uid(), assigned_to uuid, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
GRANT SELECT ON public.finance_records TO authenticated;
GRANT ALL ON public.finance_records TO service_role;
ALTER TABLE public.finance_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY finance_record_read ON public.finance_records FOR SELECT TO authenticated USING(public.finance_role() IN ('manager','accountant') OR (public.finance_role()='team' AND kind IN ('projects','expenses') AND (created_by=auth.uid() OR assigned_to=auth.uid())));
CREATE INDEX finance_kind_idx ON public.finance_records(kind);
CREATE TABLE public.finance_audit (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), record_id uuid, actor uuid NOT NULL, action text NOT NULL, reason text NOT NULL, old_value jsonb, new_value jsonb, created_at timestamptz NOT NULL DEFAULT now());
GRANT SELECT ON public.finance_audit TO authenticated;
GRANT ALL ON public.finance_audit TO service_role;
ALTER TABLE public.finance_audit ENABLE ROW LEVEL SECURITY;
CREATE POLICY finance_audit_read ON public.finance_audit FOR SELECT TO authenticated USING(public.finance_role() IN ('manager','accountant'));
CREATE FUNCTION public.finance_validate() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE cur text; amount numeric; rate numeric; account_record public.finance_records; dest public.finance_records; inv public.finance_records;
BEGIN
IF NEW.kind IN ('accounts','projects','invoices','expenses','transactions') THEN
cur:=NEW.data->>'currency'; IF cur NOT IN ('UGX','USD') OR cur IS NULL THEN RAISE EXCEPTION 'Choose UGX or USD'; END IF;
amount:=coalesce((NEW.data->>'amount')::numeric,0); IF amount<0 THEN RAISE EXCEPTION 'Amount cannot be negative'; END IF;
IF NEW.kind IN ('invoices','expenses','transactions') AND amount<=0 THEN RAISE EXCEPTION 'Amount must be greater than zero'; END IF;
END IF;
IF NEW.kind IN ('expenses','transactions') THEN
IF cur='USD' THEN rate:=(NEW.data->>'rate')::numeric; IF rate IS NULL OR rate<=0 OR coalesce(NEW.data->>'rate_source','')='' OR coalesce(NEW.data->>'rate_date','')='' THEN RAISE EXCEPTION 'USD requires an actual exchange rate, source and date'; END IF; ELSE rate:=1; END IF;
NEW.data:=NEW.data || jsonb_build_object('rate',rate,'ugx_amount',round(amount*rate,2));
END IF;
IF NEW.kind='transactions' THEN
SELECT * INTO account_record FROM public.finance_records WHERE id=(NEW.data->>'account_id')::uuid AND kind='accounts';
IF account_record.id IS NULL OR account_record.data->>'currency'<>cur THEN RAISE EXCEPTION 'Account currency must match the transaction'; END IF;
IF NEW.data->>'type' NOT IN ('income','expense','transfer','owner_contribution','loan','personal_withdrawal','refund','advance') THEN RAISE EXCEPTION 'Invalid transaction type'; END IF;
IF NEW.data->>'type'='transfer' THEN
SELECT * INTO dest FROM public.finance_records WHERE id=(NEW.data->>'destination_id')::uuid AND kind='accounts';
IF dest.id IS NULL OR dest.id=account_record.id OR dest.data->>'currency'<>cur THEN RAISE EXCEPTION 'Transfers require different accounts in the same currency'; END IF;
END IF;
END IF;
IF NEW.kind='invoices' AND coalesce((NEW.data->>'paid')::numeric,0)>amount THEN RAISE EXCEPTION 'Payment exceeds invoice value'; END IF;
IF TG_OP='UPDATE' AND OLD.kind='transactions' THEN RAISE EXCEPTION 'Posted transactions are immutable; create a reversal'; END IF;
NEW.updated_at:=now(); RETURN NEW;
END $$;
CREATE TRIGGER finance_validate BEFORE INSERT OR UPDATE ON public.finance_records FOR EACH ROW EXECUTE FUNCTION public.finance_validate();
CREATE FUNCTION public.finance_save(p_kind text,p_data jsonb,p_id uuid DEFAULT NULL,p_reason text DEFAULT 'Created') RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r text:=public.finance_role(); old_record public.finance_records; result uuid; assignee uuid;
BEGIN
IF auth.uid() IS NULL OR r IS NULL THEN RAISE EXCEPTION 'Access not granted'; END IF;
IF p_kind NOT IN ('accounts','contacts','projects','invoices','expenses','transactions') THEN RAISE EXCEPTION 'Invalid record'; END IF;
IF r NOT IN ('manager','accountant') AND NOT(r='team' AND p_kind='expenses' AND p_id IS NULL) THEN RAISE EXCEPTION 'Not authorized'; END IF;
IF coalesce(trim(p_reason),'')='' THEN RAISE EXCEPTION 'A reason is required'; END IF;
IF coalesce(trim(p_data->>'name'),'')='' THEN RAISE EXCEPTION 'Name is required'; END IF;
IF p_id IS NOT NULL THEN
SELECT * INTO old_record FROM public.finance_records WHERE id=p_id FOR UPDATE;
IF old_record.id IS NULL OR old_record.kind<>p_kind THEN RAISE EXCEPTION 'Record not found'; END IF;
IF p_kind IN ('expenses','transactions') OR (p_kind='invoices' AND coalesce((old_record.data->>'paid')::numeric,0)>0) THEN RAISE EXCEPTION 'Use the dedicated financial action'; END IF;
END IF;
IF p_kind='expenses' THEN p_data:=p_data || jsonb_build_object('status','pending'); END IF;
IF p_kind='transactions' THEN p_data:=p_data || jsonb_build_object('status','posted'); p_data:=p_data-'reversal_of'; END IF;
IF p_kind='invoices' THEN p_data:=p_data || jsonb_build_object('paid',0,'status','issued'); END IF;
assignee:=nullif(p_data->>'assigned_to','')::uuid;
IF p_id IS NULL THEN INSERT INTO public.finance_records(kind,data,assigned_to) VALUES(p_kind,p_data,assignee) RETURNING id INTO result;
ELSE UPDATE public.finance_records SET data=p_data,assigned_to=assignee WHERE id=p_id RETURNING id INTO result; END IF;
INSERT INTO public.finance_audit(record_id,actor,action,reason,old_value,new_value) VALUES(result,auth.uid(),CASE WHEN p_id IS NULL THEN 'create' ELSE 'update' END,p_reason,old_record.data,p_data);
RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.finance_save(text,jsonb,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.finance_save(text,jsonb,uuid,text) TO authenticated;
CREATE FUNCTION public.finance_action(p_id uuid,p_action text,p_reason text,p_account uuid DEFAULT NULL,p_amount numeric DEFAULT NULL,p_rate numeric DEFAULT NULL,p_source text DEFAULT NULL,p_rate_date date DEFAULT NULL,p_reference text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r text:=public.finance_role(); rec public.finance_records; a public.finance_records; next_data jsonb; tx jsonb; newid uuid;
BEGIN
IF auth.uid() IS NULL OR r NOT IN ('manager','accountant') OR r IS NULL THEN RAISE EXCEPTION 'Not authorized'; END IF;
IF coalesce(trim(p_reason),'')='' THEN RAISE EXCEPTION 'A reason is required'; END IF;
SELECT * INTO rec FROM public.finance_records WHERE id=p_id FOR UPDATE;
IF rec.id IS NULL THEN RAISE EXCEPTION 'Record not found'; END IF;
next_data:=rec.data;
IF p_action IN ('approve','reject') THEN
IF r<>'manager' OR rec.kind<>'expenses' OR rec.data->>'status'<>'pending' THEN RAISE EXCEPTION 'Only a manager can decide pending expenses'; END IF;
IF rec.created_by=auth.uid() THEN RAISE EXCEPTION 'You cannot approve or reject your own expense'; END IF;
next_data:=next_data || jsonb_build_object('status',CASE WHEN p_action='approve' THEN 'approved' ELSE 'rejected' END,'approved_by',auth.uid());
ELSIF p_action IN ('payment','pay_expense') THEN
IF (p_action='payment' AND rec.kind<>'invoices') OR (p_action='pay_expense' AND (rec.kind<>'expenses' OR rec.data->>'status'<>'approved')) THEN RAISE EXCEPTION 'Record is not eligible for payment'; END IF;
IF p_amount IS NULL OR p_amount<=0 THEN RAISE EXCEPTION 'Payment must be positive'; END IF;
IF p_action='payment' AND p_amount> (rec.data->>'amount')::numeric-coalesce((rec.data->>'paid')::numeric,0) THEN RAISE EXCEPTION 'Payment exceeds invoice balance'; END IF;
IF p_action='pay_expense' AND p_amount<>(rec.data->>'amount')::numeric THEN RAISE EXCEPTION 'Expense payment must equal approved amount'; END IF;
SELECT * INTO a FROM public.finance_records WHERE id=p_account AND kind='accounts';
IF a.id IS NULL OR a.data->>'currency'<>rec.data->>'currency' THEN RAISE EXCEPTION 'Choose an account in the same currency'; END IF;
IF coalesce(trim(p_reference),'')='' THEN RAISE EXCEPTION 'Payment reference required'; END IF;
tx:=jsonb_build_object('name',rec.data->>'name','currency',rec.data->>'currency','amount',p_amount,'rate',p_rate,'rate_source',p_source,'rate_date',p_rate_date,'account_id',p_account,'date',current_date,'type',CASE WHEN p_action='payment' THEN 'income' ELSE 'expense' END,'status','posted','linked_id',p_id,'project_id',rec.data->>'project_id','reference',p_reference);
INSERT INTO public.finance_records(kind,data) VALUES('transactions',tx) RETURNING id INTO newid;
INSERT INTO public.finance_audit(record_id,actor,action,reason,new_value) VALUES(newid,auth.uid(),'payment_transaction',p_reason,tx);
IF p_action='payment' THEN next_data:=next_data || jsonb_build_object('paid',coalesce((rec.data->>'paid')::numeric,0)+p_amount,'status',CASE WHEN coalesce((rec.data->>'paid')::numeric,0)+p_amount=(rec.data->>'amount')::numeric THEN 'paid' ELSE 'partial' END);
ELSE next_data:=next_data || jsonb_build_object('status','paid','payment_reference',p_reference); END IF;
ELSIF p_action='reverse' THEN
IF r<>'manager' OR rec.kind<>'transactions' THEN RAISE EXCEPTION 'Only a manager can reverse transactions'; END IF;
IF rec.data ? 'linked_id' OR rec.data ? 'reversal_of' THEN RAISE EXCEPTION 'Linked payments require accountant review; reversal is unavailable in this MVP'; END IF;
IF EXISTS(SELECT 1 FROM public.finance_records WHERE data->>'reversal_of'=p_id::text) THEN RAISE EXCEPTION 'Already reversed'; END IF;
tx:=rec.data || jsonb_build_object('reversal_of',p_id,'name','Reversal: ' || (rec.data->>'name'),'date',current_date);
INSERT INTO public.finance_records(kind,data) VALUES('transactions',tx) RETURNING id INTO newid;
INSERT INTO public.finance_audit(record_id,actor,action,reason,new_value) VALUES(newid,auth.uid(),'reverse',p_reason,tx);
RETURN;
ELSE RAISE EXCEPTION 'Invalid action'; END IF;
UPDATE public.finance_records SET data=next_data WHERE id=p_id;
INSERT INTO public.finance_audit(record_id,actor,action,reason,old_value,new_value) VALUES(p_id,auth.uid(),p_action,p_reason,rec.data,next_data);
END $$;
REVOKE ALL ON FUNCTION public.finance_action(uuid,text,text,uuid,numeric,numeric,text,date,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.finance_action(uuid,text,text,uuid,numeric,numeric,text,date,text) TO authenticated;
CREATE FUNCTION public.finance_grant(p_email text,p_role text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE target uuid; previous jsonb;
BEGIN
IF public.finance_role()<>'manager' OR public.finance_role() IS NULL THEN RAISE EXCEPTION 'Only managers can manage access'; END IF;
IF p_role NOT IN ('manager','accountant','team','system') THEN RAISE EXCEPTION 'Invalid role'; END IF;
SELECT id INTO target FROM auth.users WHERE lower(email)=lower(trim(p_email));
IF target IS NULL THEN RAISE EXCEPTION 'This person must create an account first'; END IF;
IF target=auth.uid() THEN RAISE EXCEPTION 'You cannot change your own role'; END IF;
SELECT to_jsonb(m) INTO previous FROM public.finance_members m WHERE user_id=target;
INSERT INTO public.finance_members(user_id,role,email) VALUES(target,p_role,lower(trim(p_email))) ON CONFLICT(user_id) DO UPDATE SET role=excluded.role,email=excluded.email;
INSERT INTO public.finance_audit(record_id,actor,action,reason,old_value,new_value) VALUES(target,auth.uid(),'access','Manager assigned role',previous,jsonb_build_object('role',p_role));
END $$;
REVOKE ALL ON FUNCTION public.finance_grant(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.finance_grant(text,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$ SELECT EXISTS(SELECT 1 FROM public.finance_members WHERE user_id=_user_id AND role IN ('manager','accountant')) $$;
CREATE OR REPLACE FUNCTION public.handle_new_user_role() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN RETURN new; END $$;
COMMENT ON TABLE public.user_roles IS 'DEPRECATED: finance access is managed through finance_members; legacy roles no longer grant payroll access';