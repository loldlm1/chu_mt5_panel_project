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
   // Levels are committed absolute prices, not recomputed by each quote or paint.
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
   if(tradeSide!=dir){breakEvenShown=false;ForgetPriceLevel("BE");}
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
   if(CollectManagedPositions(rows)>0 && !groupMode){csmPanelStatus="Activa Grupo para agregar entradas";return;}
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
      ForgetPriceLevel("Entrada");ForgetPriceLevel("Stop loss");ForgetPriceLevel("Take profit");
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
   for(int i=ArraySize(priceLevels)-1;i>=0;i--)
   {
      string key=priceLevels[i].key;
      if(StringFind(key,"Pending_")!=0) continue;
      if(chartLineDragging && chartDragKey==key) continue;
      ulong ticket=(ulong)StringToInteger(StringSubstr(key,StringLen("Pending_")));
      if(ticket==0 || !IsManagedPendingOrder(ticket)) ForgetPriceLevel(key);
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

void AdjustBrokerPendingOrder(const string key,const double wantedPrice,const double expectedEntry,const double expectedSL,const double expectedTP)
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
   double oldStop=OrderGetDouble(ORDER_SL),oldTarget=OrderGetDouble(ORDER_TP);
   if(MathAbs(oldPrice-expectedEntry)>_Point/2 || MathAbs(oldStop-expectedSL)>_Point/2 ||
      MathAbs(oldTarget-expectedTP)>_Point/2)
   {
      csmPanelStatus="Pendiente cambio en broker; vuelve a arrastrar";
      return;
   }
   ENUM_ORDER_TYPE_TIME timeType=(ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   datetime expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   string comment=OrderGetString(ORDER_COMMENT);
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote)){csmPanelStatus="Sin cotizacion para editar pendiente";return;}
   double price=NormalizeTradePrice(wantedPrice);
   double delta=price-oldPrice;
   double stop=oldStop>0?NormalizeTradePrice(oldStop+delta):0;
   double target=oldTarget>0?NormalizeTradePrice(oldTarget+delta):0;
   if((oldStop>0 && stop<=0) || (oldTarget>0 && target<=0))
   {csmPanelStatus="Pendiente sin cambios: SL/TP no valido";return;}
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
      MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT)-volume)>1e-8 ||
      MathAbs(OrderGetDouble(ORDER_SL)-oldStop)>_Point/2 ||
      MathAbs(OrderGetDouble(ORDER_TP)-oldTarget)>_Point/2 ||
      (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME)!=timeType ||
      (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION)!=expiration)
   {
      csmPanelStatus="Pendiente cambio en broker: reintenta manualmente";
      return;
   }
   if(!trade.OrderDelete(ticket) || trade.ResultRetcode()!=TRADE_RETCODE_DONE)
   {
      csmPanelStatus="Pendiente original no eliminada: "+trade.ResultRetcodeDescription();
      return;
   }
   // Send exactly the request that passed OrderCheck, preserving magic/expiry/comment.
   MqlTradeResult result={};
   bool placed=OrderSend(request,result);
   if(placed && (result.retcode==TRADE_RETCODE_PLACED || result.retcode==TRADE_RETCODE_DONE))
   {
      ForgetPriceLevel(key);
      csmPanelStatus=StringFormat("Pendiente #%I64u sustituida por #%I64u",ticket,result.order);
   }
   else
   {
      // Never auto-retry: cancellation succeeded, replacement did not.
      csmPanelStatus=StringFormat("ALERTA: #%I64u eliminada; nueva orden NO creada (%u): %s",
                                   ticket,result.retcode,result.comment);
      Print("Chu Sniper Manager: ",csmPanelStatus);
   }
}
