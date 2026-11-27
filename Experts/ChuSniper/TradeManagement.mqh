// Fresh broker snapshot and current position state for every ticket.
bool SelectManagedTicket(const ulong ticket)
{
   return PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==_Symbol &&
          (IncludeOtherPositions || PositionGetInteger(POSITION_MAGIC)==(long)Magic);
}
// A manual BE may adapt only after the executable quote has strictly crossed
// the requested level. This guard is NOT part of automatic trailing.
bool BEPriceCrossed(const int direction,const MqlTick &q,const double wanted)
{
   return ValidBrokerQuote(q) && MathIsValidNumber(wanted) && wanted>0 &&
          (direction>0?q.bid>wanted:q.ask<wanted);
}
// Outcome 5: requested manual BE has not been crossed.
int ApplyResolvedStop(const ulong ticket,const double wanted,const bool allowExactRetreat,
                      const int expectedDirection,const bool requireCrossedBE=false)
{
   if(!TradePermissionsAllowed() || !SelectManagedTicket(ticket)) return -1;
   int dir=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
   if(expectedDirection!=0 && dir!=expectedDirection) return -1;
   double oldSL=PositionGetDouble(POSITION_SL),oldTP=PositionGetDouble(POSITION_TP);
   BrokerRules b;MqlTick q;
   if(!ReadBrokerRules(b) || !SymbolInfoTick(_Symbol,q) || !ValidBrokerQuote(q)) return -1;
   if(requireCrossedBE && !BEPriceCrossed(dir,q,wanted)) return 5;
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
   int n=CollectManagedPositionsForSide(rows,breakEvenSide),exact=0,adapted=0,same=0,unchanged=0,frozen=0,failed=0,notCrossed=0;
   if(n==0){csmPanelStatus="BE: no hay posiciones elegibles";return;}
   for(int i=0;i<n;i++)
   {
      int outcome=ApplyResolvedStop(rows[i].id,breakEvenPrice,true,breakEvenSide,true);
      if(outcome==1) exact++;
      else if(outcome==2) adapted++;
      else if(outcome==3) same++;
      else if(outcome==4) frozen++;
      else if(outcome==5) notCrossed++;
      else if(outcome==0) unchanged++;
      else failed++;
   }
   if(notCrossed==n) csmPanelStatus=StringFormat("BE %s no superado: %d sin cambios",BESideCaption(),n);
   else csmPanelStatus=StringFormat("BE %s: %d ex / %d ad / %d ig / %d no sup / %d fr / %d otros",
                                  BESideCaption(),exact,adapted,same,notCrossed,frozen,unchanged+failed);
   PrintFormat("CSM BE %s: exactos=%d adaptados=%d iguales=%d no superado=%d sin mejora=%d freeze=%d rechazados/no verificados=%d",
               BESideCaption(),exact,adapted,same,notCrossed,unchanged,frozen,failed);
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
// Read opening deals from the stable position identifier, not from today's SL.
// The opening order must be terminal; never trail a partially filled live order
// with a distance which might change when the rest fills.
int RecoverInitialRisk(const ulong identifier,const int direction,const double currentVolume,
                       const double currentEntry,double &entry,double &distance)
{
   entry=0;distance=0;
   if(!identifier || !HistorySelectByPosition(identifier)) return -1;
   long orderState=0;
   if(!HistoryOrderGetInteger(identifier,ORDER_STATE,orderState) ||
      (orderState!=ORDER_STATE_FILLED && orderState!=ORDER_STATE_CANCELED && orderState!=ORDER_STATE_EXPIRED)) return -1;
   double sum=0,opened=0,closed=0,initialSL=0;
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0) return -1;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(!deal) return -1;
      long type=HistoryDealGetInteger(deal,DEAL_TYPE);
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
      if((ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID)!=identifier ||
         HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol) return -1;
      double volume=HistoryDealGetDouble(deal,DEAL_VOLUME);
      if(!MathIsValidNumber(volume) || volume<=0) return -1;
      long kind=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(kind==DEAL_ENTRY_OUT || kind==DEAL_ENTRY_OUT_BY){closed+=volume;continue;}
      if(kind!=DEAL_ENTRY_IN || type!=(direction>0?DEAL_TYPE_BUY:DEAL_TYPE_SELL) ||
         (ulong)HistoryDealGetInteger(deal,DEAL_ORDER)!=identifier) return -1;
      double price=0,sl=0;
      if(!HistoryDealGetDouble(deal,DEAL_PRICE,price) || !HistoryDealGetDouble(deal,DEAL_SL,sl) ||
         !MathIsValidNumber(price) || price<=0 || !MathIsValidNumber(sl) || sl<0) return -1;
      if(opened>0 && MathAbs(sl-initialSL)>tick*1e-6) return -1;
      initialSL=sl;opened+=volume;sum+=price*volume;
   }
   if(opened<=0 || MathAbs(opened-closed-currentVolume)>1e-7) return -1;
   entry=sum/opened;
   if(!MathIsValidNumber(entry) || MathAbs(entry-currentEntry)>tick+1e-9) return -1;
   if(initialSL==0) return 0;
   distance=direction*(entry-initialSL);
   if(!MathIsValidNumber(distance) || distance<=0) return -1;
   return 1;
}
int GetInitialRisk(const ulong identifier,const int direction,const double volume,
                   const double currentEntry,double &entry,double &distance)
{
   int key=-1;
   for(int i=0;i<ArraySize(initialRiskCache);i++)
      if(initialRiskCache[i].identifier==identifier){key=i;break;}
   ulong now=GetTickCount64();
   if(key<0)
   {
      key=ArraySize(initialRiskCache);
      ArrayResize(initialRiskCache,key+1);
      initialRiskCache[key].identifier=identifier;
      initialRiskCache[key].checked=0;
      initialRiskCache[key].volume=-1;
   }
   // Volume changes can mean a late partial fill. Revalidate history, not SL.
   if(MathAbs(initialRiskCache[key].volume-volume)>1e-8 ||
      (initialRiskCache[key].state<0 && now-initialRiskCache[key].checked>=5000))
   {
      double origin=0,gap=0;
      int state=RecoverInitialRisk(identifier,direction,volume,currentEntry,origin,gap);
      initialRiskCache[key].volume=volume;initialRiskCache[key].checked=now;
      initialRiskCache[key].entry=origin;initialRiskCache[key].distance=gap;
      initialRiskCache[key].state=state;
      if(state<0) PrintFormat("CSM trailing #%I64u: SL inicial no verificable",identifier);
   }
   entry=initialRiskCache[key].entry;distance=initialRiskCache[key].distance;
   return initialRiskCache[key].state;
}
void UpdateTrailingStops()
{
   trailingNoSL=0;trailingUnknown=0;
   if(!TradePermissionsAllowed() || trailingMode!=1) return;
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
      ulong identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      double volume=PositionGetDouble(POSITION_VOLUME),currentEntry=PositionGetDouble(POSITION_PRICE_OPEN);
      double entry=0,distance=0;
      int initial=GetInitialRisk(identifier,direction,volume,currentEntry,entry,distance);
      if(initial==0){trailingNoSL++;continue;}
      if(initial<0){trailingUnknown++;continue;}
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
      double gain=direction*(favorablePrices[key]-entry);
      if(gain+_Point*1e-7<distance) continue;
      double level=favorablePrices[key]-direction*distance;
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
