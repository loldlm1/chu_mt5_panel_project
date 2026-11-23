ENUM_ORDER_TYPE PendingOrderType(const bool buy,const double entry,const MqlTick &quote)
{
   if(buy) return entry>quote.ask?ORDER_TYPE_BUY_STOP:ORDER_TYPE_BUY_LIMIT;
   return entry<quote.bid?ORDER_TYPE_SELL_STOP:ORDER_TYPE_SELL_LIMIT;
}

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
   if(pendingOrderMode) type=PendingOrderType(tradeSide>0,csmPlannedEntry,q);
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

bool IsManagedPendingOrder(const ulong ticket)
{
   if(!OrderSelect(ticket)) return false;
   if(OrderGetString(ORDER_SYMBOL)!=_Symbol) return false;
   if(OrderGetInteger(ORDER_MAGIC)!=(long)Magic) return false;
   ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   return type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_LIMIT ||
          type==ORDER_TYPE_SELL_STOP || type==ORDER_TYPE_SELL_LIMIT;
}

void RenderBrokerPendingLines()
{
   // Display the broker's current entry price, not a local simulated order.
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong ticket=OrderGetTicket(i);
      if(!ticket || !IsManagedPendingOrder(ticket)) continue;
      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      string key=StringFormat("Pending_%I64u",ticket);
      bool buy=(type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_LIMIT);
      DrawPriceLevel(key,OrderGetDouble(ORDER_PRICE_OPEN),buy?buyColor:sellColor,true);
      ObjectSetString(0,PanelObjectName(key),OBJPROP_TOOLTIP,
                      StringFormat("#%I64u | %s | arrastra la entrada",ticket,OrderTypeCaption(type)));
   }
   string prefix=PanelObjectName("Pending_");
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string object=ObjectName(0,i);
      if(StringFind(object,prefix)!=0) continue;
      if(chartLineDragging && chartDragKey==StringSubstr(object,StringLen(panelObjectPrefix))) continue;
      ulong ticket=(ulong)StringToInteger(StringSubstr(object,StringLen(prefix)));
      if(ticket==0 || !IsManagedPendingOrder(ticket)) ObjectDelete(0,object);
   }
}

bool PendingLevelValid(const bool buy,const double entry,const double sl,const double tp,
                       const MqlTick &quote,string &reason)
{
   double gap=MathMax(_Point,(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point);
   double market=buy?quote.ask:quote.bid;
   int direction=buy?1:-1;
   if(entry<=0 || MathAbs(entry-market)<gap-1e-9)
   {
      reason="Entrada demasiado cerca del precio actual";
      return false;
   }
   if((sl>0 && direction*(entry-sl)<gap-1e-9) ||
      (tp>0 && direction*(tp-entry)<gap-1e-9))
   {
      reason="SL/TP incompatible con la nueva entrada";
      return false;
   }
   return true;
}

void AdjustBrokerPendingOrder(const string key,const double wantedPrice)
{
   if(!tradeExecutionEnabled)
   {
      csmPanelStatus="Pendientes: solo cuenta Demo hedging";
      return;
   }
   ulong ticket=(ulong)StringToInteger(StringSubstr(key,StringLen("Pending_")));
   if(ticket==0 || !IsManagedPendingOrder(ticket))
   {
      csmPanelStatus="Pendiente ya no disponible o fuera del alcance";
      return;
   }
   ENUM_ORDER_TYPE oldType=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   bool buy=(oldType==ORDER_TYPE_BUY_STOP || oldType==ORDER_TYPE_BUY_LIMIT);
   double oldPrice=OrderGetDouble(ORDER_PRICE_OPEN);
   double volume=OrderGetDouble(ORDER_VOLUME_CURRENT);
   double stop=OrderGetDouble(ORDER_SL),target=OrderGetDouble(ORDER_TP);
   ENUM_ORDER_TYPE_TIME timeType=(ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   datetime expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   string comment=OrderGetString(ORDER_COMMENT);
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote)){csmPanelStatus="Sin cotizacion para editar pendiente";return;}
   double price=NormalizeTradePrice(wantedPrice);
   ENUM_ORDER_TYPE newType=PendingOrderType(buy,price,quote);
   string reason="";
   if(!PendingLevelValid(buy,price,stop,target,quote,reason))
   {
      csmPanelStatus="Pendiente sin cambios: "+reason;
      return;
   }
   double freeze=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)*_Point;
   if(freeze>0 && MathAbs(oldPrice-(buy?quote.ask:quote.bid))<freeze)
   {
      csmPanelStatus="Pendiente bloqueada por freeze level del broker";
      return;
   }
   if(MathAbs(oldPrice-price)<SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)/2)
   {
      csmPanelStatus="Pendiente sin cambios";
      return;
   }
   if(newType==oldType)
   {
      bool changed=trade.OrderModify(ticket,price,stop,target,timeType,expiration,0);
      csmPanelStatus=(changed && TradeResultCompleted())?
            StringFormat("Pendiente #%I64u modificada",ticket):
            "No se pudo modificar: "+trade.ResultRetcodeDescription();
      return;
   }

   // Stop -> Limit and vice versa cannot be modified in place. Preflight before deletion.
   MqlTradeRequest request={};
   MqlTradeCheckResult check={};
   request.action=TRADE_ACTION_PENDING;
   request.symbol=_Symbol;
   request.magic=Magic;
   request.type=newType;
   request.volume=volume;
   request.price=price;
   request.sl=stop;
   request.tp=target;
   request.type_filling=ORDER_FILLING_RETURN;
   request.type_time=timeType;
   request.expiration=expiration;
   request.comment=comment;
   if(volume<=0 || !OrderCheck(request,check) || check.retcode!=0)
   {
      csmPanelStatus=StringFormat("Pendiente conservada: prevalidacion %u %s",check.retcode,check.comment);
      return;
   }
   // Recheck immediately before cancellation. The operation is explicitly not atomic.
   if(!IsManagedPendingOrder(ticket) ||
      (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)!=oldType ||
      MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-oldPrice)>_Point/2 ||
      MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT)-volume)>1e-8)
   {
      csmPanelStatus="Pendiente cambio en broker: reintenta manualmente";
      return;
   }
   if(!trade.OrderDelete(ticket) || !TradeResultCompleted())
   {
      csmPanelStatus="Pendiente original conservada: "+trade.ResultRetcodeDescription();
      return;
   }
   bool placed=false;
   switch(newType)
   {
      case ORDER_TYPE_BUY_STOP: placed=trade.BuyStop(volume,price,_Symbol,stop,target,timeType,expiration,comment);break;
      case ORDER_TYPE_BUY_LIMIT: placed=trade.BuyLimit(volume,price,_Symbol,stop,target,timeType,expiration,comment);break;
      case ORDER_TYPE_SELL_STOP: placed=trade.SellStop(volume,price,_Symbol,stop,target,timeType,expiration,comment);break;
      case ORDER_TYPE_SELL_LIMIT: placed=trade.SellLimit(volume,price,_Symbol,stop,target,timeType,expiration,comment);break;
   }
   if(placed && (trade.ResultRetcode()==TRADE_RETCODE_PLACED || TradeResultCompleted()))
   {
      ObjectDelete(0,PanelObjectName(key));
      csmPanelStatus=StringFormat("Pendiente #%I64u sustituida por #%I64u",ticket,trade.ResultOrder());
   }
   else
   {
      // Never auto-retry: cancellation succeeded, replacement did not.
      csmPanelStatus=StringFormat("ALERTA: #%I64u eliminada; nueva orden NO creada: %s",
                                   ticket,trade.ResultRetcodeDescription());
      Print("Chu Sniper Manager: ",csmPanelStatus);
   }
}
