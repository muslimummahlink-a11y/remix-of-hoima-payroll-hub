import {describe,it,expect} from 'vitest';
import {operatingTotals,remaining,canApprove,validFx,accountBalance,type FinanceRecord} from './bmp';
const rec=(id:string,kind:FinanceRecord['kind'],data:FinanceRecord['data']):FinanceRecord=>({id,kind,data,created_by:'one',assigned_to:null,created_at:''});
describe('BMP business rules',()=>{
it('requires a documented USD exchange rate',()=>{expect(validFx('USD',0,'','')).toBe(false);expect(validFx('USD',3700,'Bank statement','2026-10-28')).toBe(true);expect(validFx('USD',3700,'','2026-10-28')).toBe(false);});
it('UGX needs no exchange conversion',()=>expect(validFx('UGX',0,'','')).toBe(true));
it('transfers, loans and contributions are not operating revenue',()=>{expect(operatingTotals(['transfer','loan','owner_contribution'].map((type,i)=>rec(String(i),'transactions',{type,ugx_amount:1000})))).toEqual({income:0,expense:0});});
it('partial payment reduces the invoice balance',()=>expect(remaining({amount:1000,paid:250})).toBe(750));
it('requesters cannot approve their own expenses',()=>{expect(canApprove('manager','one','one')).toBe(false);expect(canApprove('manager','two','one')).toBe(true);expect(canApprove('accountant','two','one')).toBe(false);});
it('keeps account balances separate and reversals cancel original movements',()=>{const a=rec('a','accounts',{amount:100,currency:'UGX'});const tx=rec('tx','transactions',{type:'income',amount:50,account_id:'a'});expect(accountBalance(a,[tx,rec('other','transactions',{type:'income',amount:800,account_id:'usd'})])).toBe(150);expect(accountBalance(a,[tx,rec('r','transactions',{...tx.data,reversal_of:'tx'})])).toBe(100);});
});
