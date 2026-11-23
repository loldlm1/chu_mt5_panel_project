string OrderTypeCaption(ENUM_ORDER_TYPE t)
{
   switch(t)
   {
      case ORDER_TYPE_BUY_STOP:return "Buy Stop";
      case ORDER_TYPE_BUY_LIMIT:return "Buy Limit";
      case ORDER_TYPE_SELL_STOP:return "Sell Stop";
      case ORDER_TYPE_SELL_LIMIT:return "Sell Limit";
      default:return tradeSide>0?"compra a mercado":"venta a mercado";
   }
}
bool BuildOrderPlan(MqlTick &q, ENUM_ORDER_TYPE &type,double &lot,double &loss)
{
   type=SelectedOrderDirection();
   double quote=tradeSide>0?q.ask:q.bid;
   if(!pendingOrderMode) csmPlannedEntry=NormalizeTradePrice(quote);
   if(fixedStopMode) plannedStopLoss=NormalizeTradePrice(csmPlannedEntry-tradeSide*stopDistancePoints*_Point);
   if(riskRewardMode) plannedTakeProfit=NormalizeTradePrice(csmPlannedEntry+tradeSide*MathAbs(csmPlannedEntry-plannedStopLoss)*rewardRiskRatio);
   double gap=MathMax(_Point,SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point);
   if(pendingOrderMode)
   {
      if(tradeSide>0) type=csmPlannedEntry>quote?ORDER_TYPE_BUY_STOP:ORDER_TYPE_BUY_LIMIT;
      else type=csmPlannedEntry<quote?ORDER_TYPE_SELL_STOP:ORDER_TYPE_SELL_LIMIT;
   }
   double one=0, reference=pendingOrderMode?csmPlannedEntry:(tradeSide>0?q.bid:q.ask);
   if(csmPlannedEntry<=0 || plannedStopLoss<=0 || plannedTakeProfit<=0 || tradeSide*(csmPlannedEntry-plannedStopLoss)<=0 || tradeSide*(reference-plannedStopLoss)<gap-1e-9 ||
      tradeSide*(plannedTakeProfit-csmPlannedEntry)<=0 || tradeSide*(plannedTakeProfit-reference)<gap-1e-9 || (pendingOrderMode && MathAbs(csmPlannedEntry-quote)<gap-1e-9) ||
      !EstimateOrderProfit(csmPlannedEntry,plannedStopLoss,1,one) || one>=0) return false;
   double budget=PanelInputNumber("riskval");
   if(riskMode==0) budget*=AccountInfoDouble(ACCOUNT_BALANCE)/100;
   double max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   lot=riskMode==2?RoundVolumeDown(budget):RoundVolumeDown(MathMin(max,budget/-one));
   loss=-one*lot;
   return lot>=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)-1e-9 && lot<=max+1e-9 && (riskMode!=2 || MathAbs(lot-budget)<1e-8);
}
bool TradeResultCompleted()
{
   uint code=trade.ResultRetcode();
   return code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL || code==TRADE_RETCODE_NO_CHANGES;
}
void PrepareOrder(int dir)
{
   if(tradeSide!=dir){breakEvenShown=false;ObjectDelete(0,PanelObjectName("BE"));}
   tradeSide=dir;
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q)) return;
   double quote=tradeSide>0?q.ask:q.bid;
   csmPlannedEntry=NormalizeTradePrice(quote+(pendingOrderMode?tradeSide*stopDistancePoints*_Point:0));
   plannedStopLoss=NormalizeTradePrice(csmPlannedEntry-tradeSide*stopDistancePoints*_Point);
   plannedTakeProfit=NormalizeTradePrice(csmPlannedEntry+tradeSide*stopDistancePoints*_Point*rewardRiskRatio);
   orderPrepared=true;
   csmPanelStatus="Ajusta las lineas y confirma la orden";
}
void SubmitOrder()
{
   MqlTick q;
   ENUM_ORDER_TYPE type;
   double lot=0,loss=0;
   if(!orderPrepared || !SymbolInfoTick(_Symbol,q) || !BuildOrderPlan(q,type,lot,loss)){csmPanelStatus="Orden invalida: revisa niveles, riesgo y lote";return;}
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      csmPanelStatus="La ejecucion de esta beta requiere cuenta demo hedging";
      return;
   }
   PositionRow rows[];
   if(CollectManagedPositions(rows)>0 && (!groupMode || !averagingEnabled)){csmPanelStatus="Activa Grupo y Promediacion para agregar entradas";return;}
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
   if(ok && (TradeResultCompleted() || trade.ResultRetcode()==TRADE_RETCODE_PLACED))
   {
      orderPrepared=false;
      ObjectDelete(0,PanelObjectName("Entrada"));ObjectDelete(0,PanelObjectName("Stop loss"));ObjectDelete(0,PanelObjectName("Take profit"));
      csmPanelStatus="Orden aceptada: "+OrderTypeCaption(type);
   }
   else csmPanelStatus="Orden: "+trade.ResultRetcodeDescription();
}
