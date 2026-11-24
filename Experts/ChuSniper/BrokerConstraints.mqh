// Current broker limits. Freeze is a modification constraint, not an entry gap.
struct BrokerRules
{
   double tick,point,stopGap,freezeGap,minVolume,maxVolume,stepVolume,limitVolume;
   long orderModes,tradeMode,execution,filling;
};
bool ReadBrokerRules(BrokerRules &b)
{
   long stops=0,freeze=0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,b.tick) ||
      !SymbolInfoDouble(_Symbol,SYMBOL_POINT,b.point) ||
      !SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL,stops) ||
      !SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL,freeze) ||
      !SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN,b.minVolume) ||
      !SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX,b.maxVolume) ||
      !SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP,b.stepVolume) ||
      !SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT,b.limitVolume) ||
      !SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE,b.orderModes) ||
      !SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE,b.tradeMode) ||
      !SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE,b.execution) ||
      !SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE,b.filling)) return false;
   if(!MathIsValidNumber(b.tick) || !MathIsValidNumber(b.point) ||
      !MathIsValidNumber(b.minVolume) || !MathIsValidNumber(b.maxVolume) ||
      !MathIsValidNumber(b.stepVolume) || !MathIsValidNumber(b.limitVolume) ||
      b.tick<=0 || b.point<=0 || stops<0 || freeze<0 || b.minVolume<=0 ||
      b.maxVolume<b.minVolume || b.stepVolume<=0 || b.limitVolume<0) return false;
   b.stopGap=MathMax(b.tick,stops*b.point);
   b.freezeGap=freeze*b.point;
   return true;
}
bool ValidBrokerQuote(const MqlTick &q)
{
   return MathIsValidNumber(q.bid) && MathIsValidNumber(q.ask) &&
          q.bid>0 && q.ask>=q.bid && q.time_msc>0;
}
double BrokerGrid(const double price,const BrokerRules &b,const int outward)
{
   double units=price/b.tick;
   double grid=outward>0?MathCeil(units-1e-9):MathFloor(units+1e-9);
   return NormalizeDouble(grid*b.tick,_Digits);
}
bool OnBrokerGrid(const double price,const BrokerRules &b)
{
   return MathIsValidNumber(price) && price>0 &&
          MathAbs(price-NormalizeDouble(MathRound(price/b.tick)*b.tick,_Digits))<=b.tick*1e-6;
}
bool PriceChanged(const double a,const double b,const BrokerRules &rules)
{
   return MathAbs(a-b)>rules.tick*1e-6;
}
bool BuyOrderType(const ENUM_ORDER_TYPE type)
{
   return type==ORDER_TYPE_BUY || type==ORDER_TYPE_BUY_LIMIT ||
          type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_STOP_LIMIT;
}
bool PendingEntryType(const ENUM_ORDER_TYPE type)
{
   return type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_BUY_STOP ||
          type==ORDER_TYPE_SELL_LIMIT || type==ORDER_TYPE_SELL_STOP;
}
int PendingOutward(const ENUM_ORDER_TYPE type)
{
   return type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_SELL_LIMIT?1:-1;
}
bool EntryTypeAllowed(const ENUM_ORDER_TYPE type,const BrokerRules &b)
{
   bool buy=BuyOrderType(type);
   if(b.tradeMode!=SYMBOL_TRADE_MODE_FULL &&
      !(buy && b.tradeMode==SYMBOL_TRADE_MODE_LONGONLY) &&
      !(!buy && b.tradeMode==SYMBOL_TRADE_MODE_SHORTONLY)) return false;
   if((b.orderModes&SYMBOL_ORDER_SL)==0 || (b.orderModes&SYMBOL_ORDER_TP)==0) return false;
   long required=SYMBOL_ORDER_MARKET;
   if(type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_SELL_LIMIT) required=SYMBOL_ORDER_LIMIT;
   else if(type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_SELL_STOP) required=SYMBOL_ORDER_STOP;
   return (b.orderModes&required)!=0;
}
// Keep already valid prices locked. Adapt only invalid levels, rounding outward.
bool ConstrainEntryPlan(const int dir,const ENUM_ORDER_TYPE type,const MqlTick &q,
                        const BrokerRules &b,const bool ratioMode,const double ratio,
                        const bool rebuildRatio,double &entry,double &sl,double &tp)
{
   if(!ValidBrokerQuote(q) || !MathIsValidNumber(entry) || !MathIsValidNumber(sl) ||
      !MathIsValidNumber(tp) || entry<=0 || sl<=0 || tp<=0 ||
      (ratioMode && (!MathIsValidNumber(ratio) || ratio<=0))) return false;
   bool pending=PendingEntryType(type);
   double opening=dir>0?q.ask:q.bid;
   if(pending)
   {
      int outward=PendingOutward(type);
      double original=entry;
      if(outward*(entry-opening)<b.stopGap-1e-9)
         entry=opening+outward*(b.stopGap+b.tick);
      entry=BrokerGrid(entry,b,outward);
      sl+=entry-original;tp+=entry-original;
   }
   else entry=NormalizeDouble(MathRound(opening/b.tick)*b.tick,_Digits);
   double reference=pending?entry:(dir>0?q.bid:q.ask);
   double requestedSL=sl;
   if(dir*(reference-sl)<b.stopGap-1e-9 || dir*(entry-sl)<b.tick-1e-9)
      sl=dir>0?MathMin(reference-b.stopGap-b.tick,entry-b.tick):
               MathMax(reference+b.stopGap+b.tick,entry+b.tick);
   sl=BrokerGrid(sl,b,-dir);
   if(ratioMode && (rebuildRatio || PriceChanged(sl,requestedSL,b)))
      tp=entry+dir*MathAbs(entry-sl)*ratio;
   if(dir*(tp-reference)<b.stopGap-1e-9 || dir*(tp-entry)<b.tick-1e-9)
      tp=dir>0?MathMax(reference+b.stopGap+b.tick,entry+b.tick):
               MathMin(reference-b.stopGap-b.tick,entry-b.tick);
   tp=BrokerGrid(tp,b,dir);
   return OnBrokerGrid(entry,b) && OnBrokerGrid(sl,b) && OnBrokerGrid(tp,b) &&
          dir*(entry-sl)>0 && dir*(tp-entry)>0 &&
          dir*(reference-sl)>=b.stopGap-1e-9 && dir*(tp-reference)>=b.stopGap-1e-9 &&
          (!pending || PendingOutward(type)*(entry-opening)>=b.stopGap-1e-9);
}
// Broker directional volume limit includes other EAs' and manual orders.
double RemainingDirectionalVolume(const int dir,const BrokerRules &b)
{
   if(b.limitVolume<=0) return b.maxVolume;
   double used=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      if(!PositionGetTicket(i) || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      if(buy==(dir>0)) used+=PositionGetDouble(POSITION_VOLUME);
   }
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderGetTicket(i) || OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type!=ORDER_TYPE_BUY && type!=ORDER_TYPE_SELL && !PendingEntryType(type) &&
         type!=ORDER_TYPE_BUY_STOP_LIMIT && type!=ORDER_TYPE_SELL_STOP_LIMIT) continue;
      if(BuyOrderType(type)==(dir>0)) used+=OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return MathMax(0,MathMin(b.maxVolume,b.limitVolume-used));
}
bool TradePermissionsAllowed()
{
   return tradeExecutionEnabled && MQLInfoInteger(MQL_TRADE_ALLOWED) &&
          AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT) &&
          (MQLInfoInteger(MQL_TESTER) || TerminalInfoInteger(TERMINAL_TRADE_ALLOWED));
}
bool SelectEntryFilling(const ENUM_ORDER_TYPE type,const BrokerRules &b,ENUM_ORDER_TYPE_FILLING &filling)
{
   if(PendingEntryType(type)){filling=ORDER_FILLING_RETURN;return true;}
   if(b.execution==SYMBOL_TRADE_EXECUTION_INSTANT || b.execution==SYMBOL_TRADE_EXECUTION_REQUEST ||
      (b.filling&SYMBOL_FILLING_FOK)!=0){filling=ORDER_FILLING_FOK;return true;}
   if((b.filling&SYMBOL_FILLING_IOC)!=0){filling=ORDER_FILLING_IOC;return true;}
   if(b.execution!=SYMBOL_TRADE_EXECUTION_MARKET){filling=ORDER_FILLING_RETURN;return true;}
   return false;
}
