string OrderName(ENUM_ORDER_TYPE t)
{
   switch(t)
   {
      case ORDER_TYPE_BUY_STOP:return "Buy Stop";
      case ORDER_TYPE_BUY_LIMIT:return "Buy Limit";
      case ORDER_TYPE_SELL_STOP:return "Sell Stop";
      case ORDER_TYPE_SELL_LIMIT:return "Sell Limit";
      default:return side>0?"compra a mercado":"venta a mercado";
   }
}
bool Plan(MqlTick &q, ENUM_ORDER_TYPE &type,double &lot,double &loss)
{
   type=Direction();
   double quote=side>0?q.ask:q.bid;
   if(!pending) csmPlannedEntry=Price(quote);
   if(fixedStop) plannedStopLoss=Price(csmPlannedEntry-side*stopPoints*_Point);
   if(ratioMode) plannedTakeProfit=Price(csmPlannedEntry+side*MathAbs(csmPlannedEntry-plannedStopLoss)*rr);
   double gap=MathMax(_Point,SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point);
   if(pending)
   {
      if(side>0) type=csmPlannedEntry>quote?ORDER_TYPE_BUY_STOP:ORDER_TYPE_BUY_LIMIT;
      else type=csmPlannedEntry<quote?ORDER_TYPE_SELL_STOP:ORDER_TYPE_SELL_LIMIT;
   }
   double one=0, reference=pending?csmPlannedEntry:(side>0?q.bid:q.ask);
   if(csmPlannedEntry<=0 || plannedStopLoss<=0 || plannedTakeProfit<=0 || side*(csmPlannedEntry-plannedStopLoss)<=0 || side*(reference-plannedStopLoss)<gap-1e-9 ||
      side*(plannedTakeProfit-csmPlannedEntry)<=0 || side*(plannedTakeProfit-reference)<gap-1e-9 || (pending && MathAbs(csmPlannedEntry-quote)<gap-1e-9) ||
      !Profit(csmPlannedEntry,plannedStopLoss,1,one) || one>=0) return false;
   double budget=V("riskval");
   if(risk==0) budget*=AccountInfoDouble(ACCOUNT_BALANCE)/100;
   double max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   lot=risk==2?Down(budget):Down(MathMin(max,budget/-one));
   loss=-one*lot;
   return lot>=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)-1e-9 && lot<=max+1e-9 && (risk!=2 || MathAbs(lot-budget)<1e-8);
}
bool Done()
{
   uint code=trade.ResultRetcode();
   return code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL || code==TRADE_RETCODE_NO_CHANGES;
}
void Prepare(int dir)
{
   if(side!=dir){be=false;ObjectDelete(0,N("BE"));}
   side=dir;
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q)) return;
   double quote=side>0?q.ask:q.bid;
   csmPlannedEntry=Price(quote+(pending?side*stopPoints*_Point:0));
   plannedStopLoss=Price(csmPlannedEntry-side*stopPoints*_Point);
   plannedTakeProfit=Price(csmPlannedEntry+side*stopPoints*_Point*rr);
   prep=true;
   csmPanelStatus="Ajusta las lineas y confirma la orden";
}
void Submit()
{
   MqlTick q;
   ENUM_ORDER_TYPE type;
   double lot=0,loss=0;
   if(!prep || !SymbolInfoTick(_Symbol,q) || !Plan(q,type,lot,loss)){csmPanelStatus="Orden invalida: revisa niveles, riesgo y lote";return;}
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      csmPanelStatus="La ejecucion de esta beta requiere cuenta demo hedging";
      return;
   }
   PositionRow rows[];
   if(Positions(rows)>0 && (!group || !averaging)){csmPanelStatus="Activa Grupo y Promediacion para agregar entradas";return;}
   bool ok=false;
   switch(type)
   {
      case ORDER_TYPE_BUY:ok=trade.Buy(lot,_Symbol,0,plannedStopLoss,plannedTakeProfit,"Chu Sniper Manager");break;
      case ORDER_TYPE_SELL:ok=trade.Sell(lot,_Symbol,0,plannedStopLoss,plannedTakeProfit,"Chu Sniper Manager");break;
      case ORDER_TYPE_BUY_LIMIT:ok=trade.BuyLimit(lot,csmPlannedEntry,_Symbol,plannedStopLoss,plannedTakeProfit);break;
      case ORDER_TYPE_BUY_STOP:ok=trade.BuyStop(lot,csmPlannedEntry,_Symbol,plannedStopLoss,plannedTakeProfit);break;
      case ORDER_TYPE_SELL_LIMIT:ok=trade.SellLimit(lot,csmPlannedEntry,_Symbol,plannedStopLoss,plannedTakeProfit);break;
      case ORDER_TYPE_SELL_STOP:ok=trade.SellStop(lot,csmPlannedEntry,_Symbol,plannedStopLoss,plannedTakeProfit);break;
   }
   if(ok && (Done() || trade.ResultRetcode()==TRADE_RETCODE_PLACED))
   {
      prep=false;
      ObjectDelete(0,N("Entrada"));ObjectDelete(0,N("Stop loss"));ObjectDelete(0,N("Take profit"));
      csmPanelStatus="Orden aceptada: "+OrderName(type);
   }
   else csmPanelStatus="Orden: "+trade.ResultRetcodeDescription();
}
