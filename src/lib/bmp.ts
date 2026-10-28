import { queryOptions } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
export type Kind = 'accounts'|'contacts'|'projects'|'invoices'|'expenses'|'transactions';
export type RecordData = { [key:string]: string | number | null };
export type FinanceRecord = {id:string;kind:Kind;data:RecordData;created_by:string;assigned_to:string|null;created_at:string};
export const financeQuery = queryOptions({queryKey:['finance'],queryFn:async()=>{
 const [records, members, user, audit] = await Promise.all([supabase.from('finance_records').select('*').order('created_at',{ascending:false}),supabase.from('finance_members').select('*'),supabase.auth.getUser(),supabase.from('finance_audit').select('*').order('created_at',{ascending:false}).limit(100)]);
 if(records.error) throw records.error;if(members.error) throw members.error;
 return {records:(records.data??[]) as unknown as FinanceRecord[],members:members.data??[],user:user.data.user,audit:audit.data??[],role:members.data?.find(m=>m.user_id===user.data.user?.id)?.role??null};
}});
export function money(amount:number,currency:string='UGX'){return new Intl.NumberFormat('en-UG',{style:'currency',currency,maximumFractionDigits:currency==='UGX'?0:2}).format(amount);}
export function effect(d:RecordData){const sign=d.reversal_of?-1:1;return sign*(['expense','personal_withdrawal','advance'].includes(String(d.type))?-1:1)*Number(d.amount);}
export function accountBalance(account:FinanceRecord,records:FinanceRecord[]){return Number(account.data.amount||0)+records.filter(r=>r.kind==='transactions').reduce((s,r)=>s+(r.data.account_id===account.id?(r.data.type==='transfer'?-effect(r.data):effect(r.data)):r.data.destination_id===account.id?effect(r.data):0),0);}
export function operatingTotals(records:FinanceRecord[]){return records.filter(r=>r.kind==='transactions').reduce((a,r)=>{const sign=r.data.reversal_of?-1:1;if(r.data.type==='income')a.income+=sign*Number(r.data.ugx_amount);if(r.data.type==='expense')a.expense+=sign*Number(r.data.ugx_amount);return a;},{income:0,expense:0});}
export function remaining(d:RecordData){return Number(d.amount)-Number(d.paid||0);}
export function canApprove(role:string|null,actor:string,requester:string){return role==='manager'&&actor!==requester;}
export function validFx(currency:string,rate:number,source:string,date:string){return currency==='UGX'||(currency==='USD'&&rate>0&&source.trim().length>0&&date.length>0);}
export function bmpHead(name:string){const title=`${name} · BMP Media Production`;const description=`BMP Media Production financial workspace — ${name.toLowerCase()}, UGX and USD.`;return {meta:[{title},{name:'description',content:description},{property:'og:title',content:title},{property:'og:description',content:description},{property:'og:type',content:'website'},{name:'twitter:card',content:'summary_large_image'}]};}
