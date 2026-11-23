bool Improve(PositionRow &row,double level)
{
   if(!PositionSelectByTicket(row.id)) return false;
   double old=PositionGetDouble(POSITION_SL);
   if(old>0 && side*(level-old)<=_Point/2) return false;
   return trade.PositionModify(row.id,level,PositionGetDouble(POSITION_TP)) && Done();
}
void Apply()
{
   if(!be) return;
   PositionRow rows[];
   int n=Positions(rows), ok=0,protectedCount=0;
   for(int i=0;i<n;i++)
   {
      if(rows[i].stop>0 && side*(bePrice-rows[i].stop)<=_Point/2){protectedCount++;continue;}
      if(Improve(rows[i],bePrice)) ok++;
   }
   csmPanelStatus=StringFormat("Stops: %d aplicados / %d conservados / %d sin aplicar",ok,protectedCount,n-ok-protectedCount);
}
void Close(bool all)
{
   PositionRow rows[];
   int n=Positions(rows);
   double floating=0;
   for(int i=0;i<n;i++) floating+=rows[i].floatPL;
   double target=pct?floating*V("amount")/100:V("amount");
   if(n==0 || (!all && (target<=0 || target>floating+0.000001 || (pct && V("amount")>100))))
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
         amount=Down(vol*(target-executed)/estimated);
         if(vol-amount<min-1e-9) amount=Down(vol-min);
         if(amount<min-1e-9) break;
      }
      bool full=amount>=vol-1e-9;
      if(!full && AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {csmPanelStatus="El cierre parcial de esta version requiere cuenta hedging";return;}
      bool sent=full?trade.PositionClose(rows[i].id):trade.PositionClosePartial(rows[i].id,amount);
      if(!sent || !Done())
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
   int remaining=Positions(rows);
   csmPanelStatus=StringFormat("Neto %.2f | cierres %d | abiertas %d | incidencias %d",executed,changes,remaining,failures);
}
void Trail()
{
   if(!armed || trailing==0 || TrailPoints<=0 || StepPoints<=0 || ActivationPoints<=0) return;
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q)) return;
   double market=side>0?q.bid:q.ask;
   PositionRow rows[];
   int n=Positions(rows);
   double gap=MathMax(_Point,SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point);
   for(int i=0;i<n;i++)
   {
      int key=ArraySize(tracked);
      for(int j=0;j<ArraySize(tracked);j++) if(tracked[j]==rows[i].id){key=j;break;}
      if(key==ArraySize(tracked)){ArrayResize(tracked,key+1);ArrayResize(best,key+1);tracked[key]=rows[i].id;best[key]=market;}
      if(side*(market-best[key])>0) best[key]=market;
      double gain=side*(best[key]-rows[i].open)/_Point;
      if(gain<ActivationPoints) continue;
      double lock=0;
      if(trailing==1) lock=MathFloor((gain-ActivationPoints)/StepPoints)*StepPoints;
      if(trailing==2) lock=gain-TrailPoints;
      if(trailing==3 && gain>=ActivationPoints+StepPoints) lock=MathMax(ActivationPoints,gain-TrailPoints);
      double level=Price(rows[i].open+side*lock*_Point);
      if(level>0 && side*(market-level)>=gap-1e-9) Improve(rows[i],level);
   }
}
