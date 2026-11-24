// Fresh broker snapshot and current position state for every ticket.
bool SelectManagedTicket(const ulong ticket)
{
   return PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==_Symbol &&
          (IncludeOtherPositions || PositionGetInteger(POSITION_MAGIC)==(long)Magic);
}
int ApplyResolvedStop(const ulong ticket,const double wanted,const bool allowExactRetreat,
                      const int expectedDirection)
{
   if(!TradePermissionsAllowed() || !SelectManagedTicket(ticket)) return -1;
   int dir=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
   if(expectedDirection!=0 && dir!=expectedDirection) return -1;
   double oldSL=PositionGetDouble(POSITION_SL),oldTP=PositionGetDouble(POSITION_TP);
   BrokerRules b;MqlTick q;
   if(!ReadBrokerRules(b) || !SymbolInfoTick(_Symbol,q) || !ValidBrokerQuote(q)) return -1;
   double level=0;
   int decision=ResolvePositionStop(dir,q,b,wanted,oldSL,oldTP,allowExactRetreat,level);
   if(decision!=1 && decision!=2) return decision;
   if(!SelectManagedTicket(ticket) ||
      PriceChanged(PositionGetDouble(POSITION_SL),oldSL,b) ||
      PriceChanged(PositionGetDouble(POSITION_TP),oldTP,b)) return -1;
   if(!trade.PositionModify(ticket,level,oldTP) || !TradeResultCompleted())
   {
      PrintFormat("CSM SL #%I64u: %s",ticket,trade.ResultRetcodeDescription());
      return trade.ResultRetcode()==TRADE_RETCODE_FROZEN?4:-1;
   }
   if(!SelectManagedTicket(ticket) || PriceChanged(PositionGetDouble(POSITION_SL),level,b) ||
      PriceChanged(PositionGetDouble(POSITION_TP),oldTP,b)) return -1;
   return decision;
}
// Exact manual BE can move either way; adapted BE must improve existing SL.
void ApplyBreakEvenStops()
{
   if(!breakEvenShown || breakEvenPrice<=0){csmPanelStatus="Selecciona un nivel BE valido";return;}
   if(!TradePermissionsAllowed()){csmPanelStatus="BE: trading no permitido";return;}
   PositionRow rows[];
   int n=CollectManagedPositions(rows),exact=0,adapted=0,same=0,unchanged=0,frozen=0,failed=0;
   if(n==0){csmPanelStatus="BE: no hay posiciones elegibles";return;}
   for(int i=0;i<n;i++)
   {
      int outcome=ApplyResolvedStop(rows[i].id,breakEvenPrice,true,tradeSide);
      if(outcome==1) exact++;
      else if(outcome==2) adapted++;
      else if(outcome==3) same++;
      else if(outcome==4) frozen++;
      else if(outcome==0) unchanged++;
      else failed++;
   }
   csmPanelStatus=StringFormat("BE %d exact / %d adapt / %d igual / %d sin cambio",exact,adapted,same,unchanged+frozen+failed);
   PrintFormat("CSM BE: exactos=%d adaptados=%d iguales=%d sin mejora=%d freeze=%d rechazados/no verificados=%d",
               exact,adapted,same,unchanged,frozen,failed);
}
void CloseManagedPositions(bool all)
{
   if(!TradePermissionsAllowed()){csmPanelStatus="Cierre: trading no permitido";return;}
   PositionRow rows[];
   int n=CollectManagedPositions(rows);
   double floating=0;
   for(int i=0;i<n;i++) floating+=rows[i].floatPL;
   double target=percentTargetMode?floating*PanelInputNumber("amount")/100:PanelInputNumber("amount");
   if(n==0 || (!all && (target<=0 || target>floating+0.000001 || (percentTargetMode && PanelInputNumber("amount")>100))))
   {csmPanelStatus="Selecciona posiciones y un monto valido";return;}
   double executed=0, min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   int changes=0, failures=0;
   for(int i=0;i<n;i++)
   {
      if(!all && executed>=target-0.005) break;
      if(!TradePermissionsAllowed() || !SelectManagedTicket(rows[i].id) ||
         PositionGetInteger(POSITION_TYPE)!=(tradeSide>0?POSITION_TYPE_BUY:POSITION_TYPE_SELL))
      {failures++;continue;}
      double vol=PositionGetDouble(POSITION_VOLUME);
      double estimated=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP)+rows[i].cost;
      double amount=vol;
      if(!all && estimated>target-executed+0.005)
      {
         amount=RoundVolumeDown(vol*(target-executed)/estimated);
         if(vol-amount<min-1e-9) amount=RoundVolumeDown(vol-min);
         if(amount<min-1e-9) break;
      }
      bool full=amount>=vol-1e-9;
      if(!full && AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {csmPanelStatus="El cierre parcial de esta version requiere cuenta hedging";return;}
      bool sent=full?trade.PositionClose(rows[i].id):trade.PositionClosePartial(rows[i].id,amount);
      if(!sent || !TradeResultCompleted())
      {
         failures++;
         if(!all) break;
         continue;
      }
      ulong deal=trade.ResultDeal();
      if(!deal || !HistoryDealSelect(deal))
      {
         csmPanelStatus="Cierre enviado; revisa el historial antes de repetir";
         return;
      }
      double filled=HistoryDealGetDouble(deal,DEAL_VOLUME);
      executed+=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)
                +HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_FEE)
                +rows[i].cost*filled/vol;
      changes++;
      if(filled<amount-1e-9) failures++;
   }
   int remaining=CollectManagedPositions(rows);
   csmPanelStatus=StringFormat("Neto %.2f | cierres %d | abiertas %d | incidencias %d",executed,changes,remaining,failures);
}
void UpdateTrailingStops()
{
   if(!TradePermissionsAllowed() || trailingMode!=1 || ActivationPoints<=0 || TrailPoints<=0) return;
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote) || !ValidBrokerQuote(quote)) return;
   // Trailing applies to every eligible ticket independently of groupMode or tradeSide.
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(!ticket || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(!IncludeOtherPositions && PositionGetInteger(POSITION_MAGIC)!=(long)Magic) continue;
      int direction=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
      double market=direction>0?quote.bid:quote.ask;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      int key=ArraySize(trailingPositionTickets);
      for(int j=0;j<ArraySize(trailingPositionTickets);j++)
         if(trailingPositionTickets[j]==ticket){key=j;break;}
      if(key==ArraySize(trailingPositionTickets))
      {
         ArrayResize(trailingPositionTickets,key+1);
         ArrayResize(favorablePrices,key+1);
         trailingPositionTickets[key]=ticket;
         favorablePrices[key]=market;
      }
      if(direction*(market-favorablePrices[key])>0) favorablePrices[key]=market;
      double gain=direction*(favorablePrices[key]-entry)/_Point;
      if(gain<ActivationPoints) continue;
      double level=favorablePrices[key]-direction*TrailPoints*_Point;
      if(level<=0) continue;
      // No exact retreat and no adapted retreat; the fresh ticket decides.
      // A rejected/frozen server response must not produce a 250ms retry storm.
      if(ArraySize(trailingRetryAfter)!=ArraySize(trailingPositionTickets))
      {
         int previous=ArraySize(trailingRetryAfter);
         ArrayResize(trailingRetryAfter,ArraySize(trailingPositionTickets));
         for(int j=previous;j<ArraySize(trailingRetryAfter);j++) trailingRetryAfter[j]=0;
      }
      if(GetTickCount64()<trailingRetryAfter[key]) continue;
      int outcome=ApplyResolvedStop(ticket,level,false,direction);
      if(outcome<0 || outcome==4) trailingRetryAfter[key]=GetTickCount64()+3000;
   }
}
