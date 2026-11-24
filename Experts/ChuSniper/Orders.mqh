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
// Shared exact sizing from the effective stop. No group exposure ceiling.
bool CalculateOrderSize(const int direction,const bool pending,const MqlTick &q,
                        const double entry,const double stop,const double target,double &lot,double &loss)
{
   BrokerRules b;
   if(!ReadBrokerRules(b) || !ValidBrokerQuote(q)) return false;
   ENUM_ORDER_TYPE side=direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   ENUM_ORDER_TYPE type=pending?PendingOrderType(direction>0,entry,q):side;
   double opening=direction>0?q.ask:q.bid;
   double reference=pending?entry:(direction>0?q.bid:q.ask);
   if(!EntryTypeAllowed(type,b) || !OnBrokerGrid(entry,b) || !OnBrokerGrid(stop,b) ||
      !OnBrokerGrid(target,b) || direction*(entry-stop)<=0 || direction*(target-entry)<=0 ||
      direction*(reference-stop)<b.stopGap-1e-9 || direction*(target-reference)<b.stopGap-1e-9 ||
      (pending && PendingOutward(type)*(entry-opening)<b.stopGap-1e-9)) return false;
   double one=0;
   if(!OrderCalcProfit(side,_Symbol,1,entry,stop,one) || !MathIsValidNumber(one) || one>=0) return false;
   double budget=PanelInputNumber("riskval");
   if(riskMode==0) budget*=AccountInfoDouble(ACCOUNT_BALANCE)/100;
   if(!MathIsValidNumber(budget) || budget<=0) return false;
   double max=RemainingDirectionalVolume(direction,b);
   double desired=riskMode==2?budget:MathMin(max,budget/-one);
   lot=NormalizeDouble(MathFloor(desired/b.stepVolume+1e-9)*b.stepVolume,8);
   loss=-one*lot;
   return lot>=b.minVolume-1e-9 && lot<=max+1e-9 && MathIsValidNumber(loss) &&
          (riskMode==2?MathAbs(lot-budget)<1e-8:loss<=budget+1e-8);
}
bool BuildOrderPlan(MqlTick &q, ENUM_ORDER_TYPE &type,double &lot,double &loss)
{
   type=SelectedOrderDirection();
   if(!pendingOrderMode) csmPlannedEntry=NormalizeTradePrice(tradeSide>0?q.ask:q.bid);
   if(pendingOrderMode) type=PendingOrderType(tradeSide>0,csmPlannedEntry,q);
   return CalculateOrderSize(tradeSide,pendingOrderMode,q,csmPlannedEntry,plannedStopLoss,plannedTakeProfit,lot,loss);
}
// Explicit preparation/edit/confirm only. Rendering never moves locked SL/TP.
bool AdaptManualPlan(const bool rebuildRatio,bool &adjusted)
{
   adjusted=false;
   if(!orderPrepared) return false;
   BrokerRules b;MqlTick q;
   if(!ReadBrokerRules(b) || !SymbolInfoTick(_Symbol,q) || !ValidBrokerQuote(q))
   {csmPanelStatus="Sin cotizacion o reglas del broker";return false;}
   ENUM_ORDER_TYPE type=pendingOrderMode?PendingOrderType(tradeSide>0,csmPlannedEntry,q):SelectedOrderDirection();
   double entry=csmPlannedEntry,sl=plannedStopLoss,tp=plannedTakeProfit;
   if(!ConstrainEntryPlan(tradeSide,type,q,b,riskRewardMode,rewardRiskRatio,rebuildRatio,entry,sl,tp))
   {csmPanelStatus="No hay niveles validos del broker";return false;}
   adjusted=(pendingOrderMode && PriceChanged(entry,csmPlannedEntry,b)) ||
      PriceChanged(sl,plannedStopLoss,b) || PriceChanged(tp,plannedTakeProfit,b);
   csmPlannedEntry=entry;plannedStopLoss=sl;plannedTakeProfit=tp;
   if(adjusted) csmPanelStatus="Broker ajusto niveles | SL "+PanelNumberText(MathAbs(entry-sl)/_Point)+" pts";
   return true;
}
bool BuildProtectedRequest(const ENUM_ORDER_TYPE type,const double entry,const double sl,
                           const double tp,const double lot,const string comment,MqlTradeRequest &request)
{
   BrokerRules b;
   if(!TradePermissionsAllowed() || !ReadBrokerRules(b) || !EntryTypeAllowed(type,b) ||
      !OnBrokerGrid(entry,b) || !OnBrokerGrid(sl,b) || !OnBrokerGrid(tp,b) || lot<=0)
   {csmPanelStatus="Broker: permisos o niveles invalidos";return false;}
   ENUM_ORDER_TYPE_FILLING fill;
   if(!SelectEntryFilling(type,b,fill)){csmPanelStatus="Broker: filling no soportado";return false;}
   bool pending=PendingEntryType(type);
   request.action=pending?TRADE_ACTION_PENDING:TRADE_ACTION_DEAL;
   request.symbol=_Symbol;request.magic=Magic;request.type=type;request.volume=lot;
   request.price=entry;request.sl=sl;request.tp=tp;request.deviation=10;
   request.type_filling=fill;request.type_time=ORDER_TIME_GTC;request.comment=comment;
   return true;
}
// Match the returned order or deal's position identifier; never guess from last ticket.
int VerifyEntryProtection(const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(result.deal>0 && HistoryDealSelect(result.deal))
   {
      ulong identifier=(ulong)HistoryDealGetInteger(result.deal,DEAL_POSITION_ID);
      if(identifier>0)
         for(int i=0;i<PositionsTotal();i++)
         {
            if(!PositionGetTicket(i) || (ulong)PositionGetInteger(POSITION_IDENTIFIER)!=identifier ||
               PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=(long)Magic) continue;
            return PositionGetDouble(POSITION_SL)>0 && PositionGetDouble(POSITION_TP)>0?1:-1;
         }
      return 0;
   }
   if(PendingEntryType(request.type) && result.order>0 && OrderSelect(result.order) &&
      OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==(long)Magic)
      return OrderGetDouble(ORDER_SL)>0 && OrderGetDouble(ORDER_TP)>0?1:-1;
   return 0;
}
bool SendProtectedEntry(MqlTradeRequest &request,const string caption,const double loss,const bool adjusted)
{
   MqlTradeCheckResult check={};MqlTradeResult result={};
   if(!TradePermissionsAllowed()){csmPanelStatus="Trading no permitido";return false;}
   if(!OrderCheck(request,check) || check.retcode!=0)
   {csmPanelStatus=StringFormat("%s: rechazo previo %u %s",caption,check.retcode,check.comment);return false;}
   bool sent=OrderSend(request,result);
   bool accepted=sent && (result.retcode==TRADE_RETCODE_DONE || result.retcode==TRADE_RETCODE_DONE_PARTIAL ||
                          result.retcode==TRADE_RETCODE_PLACED);
   if(!accepted)
   {
      csmPanelStatus=StringFormat("%s: %u %s; revisa broker",caption,result.retcode,result.comment);
      Print("CSM: ",csmPanelStatus);return false;
   }
   int protection=VerifyEntryProtection(request,result);
   if(protection<0) csmPanelStatus="ALERTA: broker sin SL/TP; revisa posicion!";
   else if(protection==0) csmPanelStatus=caption+": aceptada; SL/TP no verificado";
   else csmPanelStatus=caption+(result.retcode==TRADE_RETCODE_PLACED?": pendiente protegida":
                                  result.retcode==TRADE_RETCODE_DONE_PARTIAL?": parcial protegida":": protegida")+
       " | Riesgo est. "+PanelNumberText(loss);
   if(adjusted) csmPanelStatus+=" | SL "+PanelNumberText(MathAbs(request.price-request.sl)/_Point)+" pts ajust.";
   PrintFormat("CSM: %s order=%I64u deal=%I64u retcode=%u SL=%s TP=%s",
               csmPanelStatus,result.order,result.deal,result.retcode,DoubleToString(request.sl,_Digits),DoubleToString(request.tp,_Digits));
   return true;
}
// One market request per deliberate click; draft and management side stay intact.
void SubmitQuickMarket(const int direction)
{
   string side=direction>0?"BUY":"SELL";
   if(!TradePermissionsAllowed()){csmPanelStatus=side+": trading no permitido";return;}
   BrokerRules b;MqlTick q;
   if(!ReadBrokerRules(b) || !SymbolInfoTick(_Symbol,q) || !ValidBrokerQuote(q) ||
      stopDistancePoints<=0 || rewardRiskRatio<=0)
   {csmPanelStatus=side+": cotizacion o SL/R:B invalido";return;}
   ENUM_ORDER_TYPE type=direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double entry=NormalizeTradePrice(direction>0?q.ask:q.bid);
   double sl=entry-direction*stopDistancePoints*_Point,tp=entry+direction*stopDistancePoints*_Point*rewardRiskRatio;
   double originalSL=sl,originalTP=tp;
   if(!ConstrainEntryPlan(direction,type,q,b,true,rewardRiskRatio,true,entry,sl,tp))
   {csmPanelStatus=side+": no hay niveles validos";return;}
   double lot=0,loss=0;
   if(!CalculateOrderSize(direction,false,q,entry,sl,tp,lot,loss))
   {csmPanelStatus=side+": riesgo/lote o limites invalidos";return;}
   MqlTradeRequest request={};
   if(!BuildProtectedRequest(type,entry,sl,tp,lot,"Chu Sniper Quick",request)) return;
   SendProtectedEntry(request,side,loss,PriceChanged(sl,originalSL,b)||PriceChanged(tp,originalTP,b));
}
bool TradeResultCompleted()
{
   uint code=trade.ResultRetcode();
   return code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL || code==TRADE_RETCODE_NO_CHANGES;
}
void PrepareOrder(int dir)
{
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q) || !ValidBrokerQuote(q)){csmPanelStatus="Sin cotizacion";return;}
   if(tradeSide!=dir){breakEvenShown=false;ForgetPriceLevel("BE");}
   tradeSide=dir;
   double quote=dir>0?q.ask:q.bid;
   csmPlannedEntry=NormalizeTradePrice(quote+(pendingOrderMode?dir*stopDistancePoints*_Point:0));
   plannedStopLoss=NormalizeTradePrice(csmPlannedEntry-dir*stopDistancePoints*_Point);
   plannedTakeProfit=NormalizeTradePrice(csmPlannedEntry+dir*stopDistancePoints*_Point*rewardRiskRatio);
   orderPrepared=true;csmPanelStatus="Ajusta las lineas y confirma la orden";
   bool adjusted=false;
   if(!AdaptManualPlan(riskRewardMode,adjusted)) orderPrepared=false;
}
void SubmitOrder()
{
   if(!TradePermissionsAllowed()){csmPanelStatus="Trading no permitido";return;}
   if(!orderPrepared){csmPanelStatus="Prepara una orden";return;}
   bool adjusted=false;
   if(!AdaptManualPlan(false,adjusted)) return;
   if(adjusted){csmPanelStatus+=" | confirma de nuevo";return;}
   MqlTick q;ENUM_ORDER_TYPE type;double lot=0,loss=0;
   if(!SymbolInfoTick(_Symbol,q) || !BuildOrderPlan(q,type,lot,loss))
   {csmPanelStatus="Orden invalida: revisa niveles, riesgo y lote";return;}
   PositionRow rows[];
   if(CollectManagedPositions(rows)>0 && !groupMode){csmPanelStatus="Activa Grupo para agregar entradas";return;}
   MqlTradeRequest request={};
   if(!BuildProtectedRequest(type,csmPlannedEntry,plannedStopLoss,plannedTakeProfit,lot,"Chu Sniper Manager",request)) return;
   if(SendProtectedEntry(request,OrderTypeCaption(type),loss,false))
   {
      orderPrepared=false;
      ForgetPriceLevel("Entrada");ForgetPriceLevel("Stop loss");ForgetPriceLevel("Take profit");
   }
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
      bool fresh=PriceLevelSlot(key)<0;
      DrawPriceLevel(key,OrderGetDouble(ORDER_PRICE_OPEN),buy?buyColor:sellColor,true);
      if(fresh) ObjectSetString(0,PanelObjectName(key),OBJPROP_TOOLTIP,
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
