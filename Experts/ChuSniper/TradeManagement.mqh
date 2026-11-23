bool ImproveStopLoss(PositionRow &row,double level)
{
   if(!PositionSelectByTicket(row.id)) return false;
   if(PositionGetString(POSITION_SYMBOL)!=_Symbol) return false;
   if(!IncludeOtherPositions && PositionGetInteger(POSITION_MAGIC)!=(long)Magic) return false;
   double old=PositionGetDouble(POSITION_SL);
   int direction=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
   if(old>0 && direction*(level-old)<=_Point/2) return false;
   return trade.PositionModify(row.id,level,PositionGetDouble(POSITION_TP)) && TradeResultCompleted();
}
void ApplyBreakEvenStops()
{
   if(!breakEvenShown || !groupMode || breakEvenPrice<=0)
   {
      csmPanelStatus="Activa Grupo y selecciona un nivel BE valido";
      return;
   }
   if(!tradeExecutionEnabled)
   {
      csmPanelStatus="BE: la modificacion de stops requiere Demo hedging";
      return;
   }
   PositionRow rows[];
   int n=CollectManagedPositions(rows), ok=0,protectedCount=0;
   if(n==0){csmPanelStatus="BE: no hay posiciones elegibles";return;}
   for(int i=0;i<n;i++)
   {
      if(rows[i].stop>0 && tradeSide*(breakEvenPrice-rows[i].stop)<=_Point/2){protectedCount++;continue;}
      if(ImproveStopLoss(rows[i],breakEvenPrice)) ok++;
   }
   csmPanelStatus=StringFormat("Stops: %d aplicados / %d conservados / %d sin aplicar",ok,protectedCount,n-ok-protectedCount);
}
void CloseManagedPositions(bool all)
{
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
      if(!PositionSelectByTicket(rows[i].id)){failures++;continue;}
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
   if(!tradeExecutionEnabled || trailingMode!=1 || ActivationPoints<=0 || TrailPoints<=0) return;
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote)) return;
   double gap=MathMax(_Point,(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point);
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
      double level=NormalizeTradePrice(favorablePrices[key]-direction*TrailPoints*_Point);
      if(level<=0 || direction*(market-level)<gap-1e-9) continue;
      PositionRow row;
      row.id=ticket;
      // ImproveStopLoss also checks the server's live SL and never worsens it.
      ImproveStopLoss(row,level);
   }
}
