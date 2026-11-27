double NormalizeTradePrice(double p)
{
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return NormalizeDouble(tick>0?MathRound(p/tick)*tick:p,_Digits);
}
double RoundVolumeDown(double v)
{
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   return step>0?NormalizeDouble(MathFloor(v/step+1e-9)*step,8):0;
}
ENUM_ORDER_TYPE SelectedOrderDirection(){return tradeSide>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;}
bool EstimateOrderProfit(double open,double end,double lots,double &result)
{
   return OrderCalcProfit(SelectedOrderDirection(),_Symbol,lots,open,end,result);
}
struct PositionRow {ulong id; double open,vol,stop,target,swap,cost,floatPL; bool costKnown;};
// Only preview/accounting displays reuse fee history; trade actions read it fresh.
struct PositionFeeCache
{
   ulong id,identifier,refreshed;
   double volume,cost;
};
PositionFeeCache uiFeeCache[];
void InvalidatePositionFeeCache(){ArrayResize(uiFeeCache,0);}
// Determine the BE activation side without opening an order or querying history.
// The same symbol/Magic policy as the managed position collector applies.
int ResolveBEActivationSide(const int selected)
{
   bool buys=false,sells=false;
   for(int i=0;i<PositionsTotal();i++)
   {
      if(!PositionGetTicket(i) || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(!IncludeOtherPositions && PositionGetInteger(POSITION_MAGIC)!=(long)Magic) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if(type==POSITION_TYPE_BUY) buys=true;
      else if(type==POSITION_TYPE_SELL) sells=true;
      if(buys && sells) return selected;
   }
   return buys?1:sells?-1:0;
}
int CollectManagedPositionsForSide(PositionRow &rows[],const int direction,bool useUiCache=false)
{
   ArrayResize(rows,0);
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong id=PositionGetTicket(i);
      if(!id || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE)!=(direction>0?POSITION_TYPE_BUY:POSITION_TYPE_SELL)) continue;
      if(!IncludeOtherPositions && PositionGetInteger(POSITION_MAGIC)!=(long)Magic) continue;
      int n=ArraySize(rows);
      ArrayResize(rows,n+1);
      rows[n].id=id;
      rows[n].open=PositionGetDouble(POSITION_PRICE_OPEN);
      rows[n].vol=PositionGetDouble(POSITION_VOLUME);
      rows[n].stop=PositionGetDouble(POSITION_SL);
      rows[n].target=PositionGetDouble(POSITION_TP);
      rows[n].swap=PositionGetDouble(POSITION_SWAP);
      rows[n].cost=0;rows[n].costKnown=false;
      rows[n].floatPL=PositionGetDouble(POSITION_PROFIT)+rows[n].swap;
   }
   for(int i=1;i<ArraySize(rows);i++)
      for(int j=i;j>0 && (groupMode?direction*(rows[j].open-rows[j-1].open)>0:rows[j].id>rows[j-1].id);j--)
      {
         PositionRow tmp=rows[j];
         rows[j]=rows[j-1];
         rows[j-1]=tmp;
      }
   if(!groupMode && ArraySize(rows)>1) ArrayResize(rows,1);
   for(int i=0;i<ArraySize(rows);i++)
   {
      if(!PositionSelectByTicket(rows[i].id)) continue;
      ulong identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      int cached=-1;
      if(useUiCache)
      {
         for(int k=0;k<ArraySize(uiFeeCache);k++) if(uiFeeCache[k].id==rows[i].id){cached=k;break;}
         if(cached>=0 && uiFeeCache[cached].identifier==identifier &&
            MathAbs(uiFeeCache[cached].volume-rows[i].vol)<1e-8 &&
            GetTickCount64()-uiFeeCache[cached].refreshed<5000)
         {
            rows[i].cost=uiFeeCache[cached].cost;rows[i].costKnown=true;
            rows[i].floatPL+=rows[i].cost;
            continue;
         }
      }
      if(!HistorySelectByPosition(identifier)) continue;
      double inVolume=0,fees=0;bool feeKnown=true;
      for(int j=0;j<HistoryDealsTotal();j++)
      {
         ulong deal=HistoryDealGetTicket(j);
         if(!deal){feeKnown=false;continue;}
         if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
         double v=0,commission=0,fee=0;
         if(!HistoryDealGetDouble(deal,DEAL_VOLUME,v) || !HistoryDealGetDouble(deal,DEAL_COMMISSION,commission) ||
            !HistoryDealGetDouble(deal,DEAL_FEE,fee) || !MathIsValidNumber(v) || v<=0 ||
            !MathIsValidNumber(commission) || !MathIsValidNumber(fee)){feeKnown=false;continue;}
         inVolume+=v;fees+=commission+fee;
      }
      rows[i].costKnown=feeKnown && inVolume>0 && inVolume+1e-8>=rows[i].vol;
      if(inVolume>0) rows[i].cost=fees*rows[i].vol/inVolume;
      rows[i].floatPL+=rows[i].cost;
      if(useUiCache && rows[i].costKnown)
      {
         if(cached<0){cached=ArraySize(uiFeeCache);ArrayResize(uiFeeCache,cached+1);}
         uiFeeCache[cached].id=rows[i].id;uiFeeCache[cached].identifier=identifier;
         uiFeeCache[cached].volume=rows[i].vol;uiFeeCache[cached].cost=rows[i].cost;
         uiFeeCache[cached].refreshed=GetTickCount64();
      }
   }
   return ArraySize(rows);
}
int CollectManagedPositions(PositionRow &rows[],bool useUiCache=false)
{
   return CollectManagedPositionsForSide(rows,tradeSide,useUiCache);
}
string BESideCaption(){return breakEvenSide>0?"BUY":"SELL";}
string TPSideCaption(){return takeProfitSide>0?"BUY":"SELL";}
double PositionProfitAtLevel(const PositionRow &row,const double level,const int direction,const bool requireKnownCost=false)
{
   double value=0;
   if((requireKnownCost && !row.costKnown) ||
      !OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,row.vol,row.open,level,value) ||
      !MathIsValidNumber(value+row.swap+row.cost)) return EMPTY_VALUE;
   return value+row.swap+row.cost;
}
double ProfitAtPriceLevel(PositionRow &rows[],double level,const int direction,const bool requireKnownCost=false)
{
   double total=0;
   for(int i=0;i<ArraySize(rows);i++)
   {
      double value=PositionProfitAtLevel(rows[i],level,direction,requireKnownCost);
      if(value==EMPTY_VALUE) return EMPTY_VALUE;
      total+=value;
   }
   return MathIsValidNumber(total)?total:EMPTY_VALUE;
}
double CalculateBreakEvenPrice(PositionRow &rows[],const int direction,const bool requireKnownCost=false)
{
   double sum=0,vol=0;
   for(int i=0;i<ArraySize(rows);i++){sum+=rows[i].open*rows[i].vol;vol+=rows[i].vol;}
   if(vol<=0) return 0;
   double base=sum/vol, move=MathMax(_Point*100,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
   double a=ProfitAtPriceLevel(rows,base,direction,requireKnownCost), b=ProfitAtPriceLevel(rows,base+move,direction,requireKnownCost);
   if(a==EMPTY_VALUE || b==EMPTY_VALUE || MathAbs(a-b)<1e-10)
      return requireKnownCost?0:NormalizeTradePrice(base);
   return NormalizeTradePrice(base-a*move/(b-a));
}
