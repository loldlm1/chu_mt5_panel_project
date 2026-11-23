double Price(double p)
{
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return NormalizeDouble(tick>0?MathRound(p/tick)*tick:p,_Digits);
}
double Down(double v)
{
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   return step>0?NormalizeDouble(MathFloor(v/step+1e-9)*step,8):0;
}
ENUM_ORDER_TYPE Direction(){return side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;}
bool Profit(double open,double end,double lots,double &result)
{
   return OrderCalcProfit(Direction(),_Symbol,lots,open,end,result);
}
struct PositionRow {ulong id; double open,vol,stop,target,swap,cost,floatPL;};
int Positions(PositionRow &rows[])
{
   ArrayResize(rows,0);
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong id=PositionGetTicket(i);
      if(!id || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE)!=(side>0?POSITION_TYPE_BUY:POSITION_TYPE_SELL)) continue;
      if(!IncludeOtherPositions && PositionGetInteger(POSITION_MAGIC)!=(long)Magic) continue;
      int n=ArraySize(rows);
      ArrayResize(rows,n+1);
      rows[n].id=id;
      rows[n].open=PositionGetDouble(POSITION_PRICE_OPEN);
      rows[n].vol=PositionGetDouble(POSITION_VOLUME);
      rows[n].stop=PositionGetDouble(POSITION_SL);
      rows[n].target=PositionGetDouble(POSITION_TP);
      rows[n].swap=PositionGetDouble(POSITION_SWAP);
      rows[n].cost=0;
      rows[n].floatPL=PositionGetDouble(POSITION_PROFIT)+rows[n].swap;
   }
   for(int i=1;i<ArraySize(rows);i++)
      for(int j=i;j>0 && (group?side*(rows[j].open-rows[j-1].open)>0:rows[j].id>rows[j-1].id);j--)
      {
         PositionRow tmp=rows[j];
         rows[j]=rows[j-1];
         rows[j-1]=tmp;
      }
   if(!group && ArraySize(rows)>1) ArrayResize(rows,1);
   for(int i=0;i<ArraySize(rows);i++)
   {
      if(!PositionSelectByTicket(rows[i].id)) continue;
      if(!HistorySelectByPosition((ulong)PositionGetInteger(POSITION_IDENTIFIER))) continue;
      double inVolume=0,fees=0;
      for(int j=0;j<HistoryDealsTotal();j++)
      {
         ulong deal=HistoryDealGetTicket(j);
         if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
         inVolume+=HistoryDealGetDouble(deal,DEAL_VOLUME);
         fees+=HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_FEE);
      }
      if(inVolume>0) rows[i].cost=fees*rows[i].vol/inVolume;
      rows[i].floatPL+=rows[i].cost;
   }
   return ArraySize(rows);
}
double AtLevel(PositionRow &rows[],double level)
{
   double total=0;
   for(int i=0;i<ArraySize(rows);i++)
   {
      double value=0;
      if(!Profit(rows[i].open,level,rows[i].vol,value)) return EMPTY_VALUE;
      total+=value+rows[i].swap+rows[i].cost;
   }
   return total;
}
double BreakEven(PositionRow &rows[])
{
   double sum=0,vol=0;
   for(int i=0;i<ArraySize(rows);i++){sum+=rows[i].open*rows[i].vol;vol+=rows[i].vol;}
   if(vol<=0) return 0;
   double base=sum/vol, move=MathMax(_Point*100,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
   double a=AtLevel(rows,base), b=AtLevel(rows,base+move);
   if(a==EMPTY_VALUE || b==EMPTY_VALUE || MathAbs(a-b)<1e-10) return Price(base);
   return Price(base-a*move/(b-a));
}
