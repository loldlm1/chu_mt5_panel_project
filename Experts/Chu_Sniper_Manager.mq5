#property strict
#property version "0.170"
#include <Trade/Trade.mqh>
#include "ChuSniper/State.mqh"
#include "ChuSniper/ChartStyle.mqh"
#include "ChuSniper/ChartObjects.mqh"
#include "ChuSniper/Positions.mqh"
#include "ChuSniper/BrokerConstraints.mqh"
#include "ChuSniper/Orders.mqh"
#include "ChuSniper/TradeManagement.mqh"
#include "ChuSniper/Panel.mqh"
#include "ChuSniper/ChartInteraction.mqh"
#include "ChuSniper/PanelPersistence.mqh"

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   trade.SetTypeFillingBySymbol(_Symbol);
   ApplyPandoraChartStyle(ChartID());
   ArrayResize(trailingRetryAfter,0);
   tradeExecutionEnabled=SupportedTradingAccount();
   csmPanelStatus=tradeExecutionEnabled?AccountModeCaption()+": selecciona Comprar o Vender":"Vista previa: requiere Demo/Real hedging";
   ObjectsDeleteAll(0,panelObjectPrefix);
   // OnInit may run again without a new EA instance; discard stale object caches.
   ArrayResize(panelObjects,0);ArrayResize(priceLevels,0);InvalidatePositionFeeCache();
   chartLeftPressed=false;suppressPanelClick=false;editingStopPoints=false;
   closeConfirmationDeadline=0;panelGesture=0;chartLineDragging=false;chartDragKey="";
   panelDirty=true;lastPanelRefresh=0;lastQuickQuoteRefresh=0;lastBEProjectionRefresh=0;lastTPProjectionRefresh=0;
   LoadPanelState();
   InitializeChartInteraction();
   EventSetMillisecondTimer(250);
   RenderPanel();
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(chartLineDragging) CancelChartDrag();
   FinishPanelGesture();
   CapturePanelInputs();
   SavePanelState();
   RestoreChartInteraction();
   ObjectsDeleteAll(0,panelObjectPrefix);
}
void OnTick(){RefreshQuickQuotes();}
void OnTimer()
{
   ulong now=GetTickCount64();
   if(chartLineDragging && now-chartDragLastEvent>20000) CancelChartDrag();
   if(panelGesture!=0 && now-panelGestureLastEvent>20000) FinishPanelGesture();
   // Keep server-side stop management active even during a chart gesture.
   UpdateTrailingStops();
   if(chartLineDragging)
   {
      // Quotes/positions may change even when the pointer is stationary.
      RefreshManagementProjectionDuringDrag();
      return;
   }
   if(panelGesture!=0) return; // No full periodic repaint during a live gesture.
   if(panelDirty || now-lastPanelRefresh>=750) RenderPanel();
   if(panelStateReady && now-lastStateSave>=5000) SavePanelState();
}
void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp)
{
   if(id==CHARTEVENT_MOUSE_MOVE)
   {
      HandleChartMouseMove((int)lp,(int)dp,sp);
      return;
   }
   if(id==CHARTEVENT_CHART_CHANGE){panelDirty=true;return;}
   if(StringFind(sp,panelObjectPrefix)!=0) return;
   string k=StringSubstr(sp,StringLen(panelObjectPrefix));
   if(id==CHARTEVENT_OBJECT_DRAG) return; // Custom gestures own previews and pending edits.
   if(id==CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(k=="points")
      {
         editingStopPoints=false;
         double points=stopDistancePoints;
         if(!ReadPanelDecimal("points",points))
         {
            SetPanelInputText("points",DoubleToString(stopDistancePoints,16));
            csmPanelStatus="SL invalido: valor anterior conservado";RenderPanel();return;
         }
         // Use the retained precise numeric value when the caption is unchanged.
         stopDistancePoints=points;fixedStopMode=true;
         SetPanelInputText("points",DoubleToString(points,16));
         if(orderPrepared)
         {
            plannedStopLoss=points==0?0:csmPlannedEntry-tradeSide*points*_Point;
            if(riskRewardMode)
               plannedTakeProfit=points==0?0:csmPlannedEntry+tradeSide*MathAbs(csmPlannedEntry-plannedStopLoss)*rewardRiskRatio;
            else SeedManualTargetIfAbsent();
         }
         if(points==0) csmPanelStatus="SIN SL | riesgo no limitado por SL";
      }
      if(k=="riskval" || k=="amount" || k=="ratio")
      {
         double value=0;
         if(!ReadPanelDecimal(k,value) || (k=="ratio" && value<=0))
         {
            SetPanelInputText(k,PanelInputRaw(k));
            csmPanelStatus="Valor invalido: anterior conservado";RenderPanel();return;
         }
         SetPanelInputText(k,DoubleToString(value,16));
         if(k=="ratio")
         {
            rewardRiskRatio=value;riskRewardMode=true;
            if(orderPrepared) plannedTakeProfit=stopDistancePoints==0?0:NormalizeTradePrice(csmPlannedEntry+tradeSide*MathAbs(csmPlannedEntry-plannedStopLoss)*rewardRiskRatio);
         }
      }
      if(orderPrepared && (k=="points" || k=="ratio"))
      {
         bool adjusted=false;AdaptManualPlan(riskRewardMode,adjusted);
      }
      RenderPanel();return;
   }
   if(id!=CHARTEVENT_OBJECT_CLICK || chartLineDragging || panelGesture!=0 || suppressPanelClick) return;
   if(PriceLevelSlot(k)>=0 || !PanelControlVisible(k)) return;
   if(k=="title" || k=="resize" || k=="bg" || k=="quickInfo" || k=="beinfo" || k=="tpinfo") return;
   if(k=="minimize")
   {
      ObjectSetInteger(0,sp,OBJPROP_STATE,false);
      panelMinimized=!panelMinimized;closeConfirmationDeadline=0;RenderPanel();return;
   }
   if(k=="quickBuy" || k=="quickSell")
   {
      if(!PanelHit(k,(int)lp,(int)dp)) return;
      closeConfirmationDeadline=0;
      ObjectSetInteger(0,sp,OBJPROP_STATE,false);
      SubmitQuickMarket(k=="quickBuy"?1:-1);
      RenderPanel();return;
   }
   if(k=="points"){editingStopPoints=true;return;}
   ObjectSetInteger(0,sp,OBJPROP_STATE,false);
   if(k!="close") closeConfirmationDeadline=0;
   if(k=="buy" || k=="sell")
   {
      int direction=k=="buy"?1:-1;
      if(!PanelHit(k,(int)lp,(int)dp)) return;
      if(orderPrepared && tradeSide==direction) CancelOrderDraft();
      else
      {
         if(breakEvenShown && breakEvenSide!=direction) breakEvenShown=false;
         if(takeProfitShown && takeProfitSide!=direction) takeProfitShown=false;
         PrepareOrder(direction);
      }
   }
   if(k=="scope"){groupMode=!groupMode;breakEvenShown=false;takeProfitShown=false;}
   if(k=="mode")
   {
      pendingOrderMode=!pendingOrderMode;
      if(orderPrepared && pendingOrderMode)
      {
         MqlTick q;BrokerRules b;
         if(SymbolInfoTick(_Symbol,q) && ValidBrokerQuote(q) && ReadBrokerRules(b))
         {
            double entry=NormalizeTradePrice((tradeSide>0?q.ask:q.bid)+tradeSide*InitialPendingOffset(b));
            double delta=entry-csmPlannedEntry;
            double nextSL=plannedStopLoss>0?NormalizeTradePrice(plannedStopLoss+delta):0;
            double nextTP=plannedTakeProfit>0?NormalizeTradePrice(plannedTakeProfit+delta):0;
            if((plannedStopLoss>0 && nextSL<=0) || (plannedTakeProfit>0 && nextTP<=0))
            {pendingOrderMode=false;csmPanelStatus="Entrada proyectada invalida";}
            else {csmPlannedEntry=entry;plannedStopLoss=nextSL;plannedTakeProfit=nextTP;}
         }
         else {pendingOrderMode=false;csmPanelStatus="Sin cotizacion o reglas";}
      }
   }
   if(k=="percent" && riskMode!=0){riskMode=0;SetPanelInputText("riskval","1");}
   if(k=="money" && riskMode!=1){riskMode=1;SetPanelInputText("riskval","200");}
   if(k=="lot" && riskMode!=2){riskMode=2;SetPanelInputText("riskval",DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),16));}
   if(k=="tpMode")
   {
      riskRewardMode=!riskRewardMode;
      if(orderPrepared)
      {
         if(riskRewardMode)
            plannedTakeProfit=stopDistancePoints==0?0:NormalizeTradePrice(csmPlannedEntry+tradeSide*MathAbs(csmPlannedEntry-plannedStopLoss)*rewardRiskRatio);
         else SeedManualTargetIfAbsent();
      }
   }
   if(orderPrepared && (k=="mode" || k=="tpMode"))
   {
      bool adjusted=false;AdaptManualPlan(k=="tpMode" && riskRewardMode,adjusted);
   }
   if(k=="trail"){trailingMode=(trailingMode+1)%2;ArrayResize(trailingPositionTickets,0);ArrayResize(favorablePrices,0);ArrayResize(trailingRetryAfter,0);}
   if(k=="units") {percentTargetMode=!percentTargetMode;SetPanelInputText("amount",percentTargetMode?"50":"100");}
   if(k=="be")
   {
      if(!PanelHit(k,(int)lp,(int)dp)) return;
      if(breakEvenShown) breakEvenShown=false;
      else
      {
         // A sole held direction takes precedence. Never invert a prepared order.
         int direction=ResolveBEActivationSide(tradeSide);
         PositionRow rows[];
         if(direction!=0 && CollectManagedPositionsForSide(rows,direction)>0)
         {
            double level=CalculateBreakEvenPrice(rows,direction);
            if(MathIsValidNumber(level) && level>0 && level!=EMPTY_VALUE)
            {
               breakEvenSide=direction;breakEvenPrice=level;breakEvenShown=true;
               if(!orderPrepared) tradeSide=direction;
               csmPanelStatus="BE "+BESideCaption()+" proyectado: pendiente de aplicar";
            }
            else csmPanelStatus="BE: nivel no disponible";
         }
         else csmPanelStatus="BE: no hay posiciones elegibles";
      }
   }
   if(k=="tp")
   {
      if(!PanelHit(k,(int)lp,(int)dp)) return;
      if(takeProfitShown) takeProfitShown=false;
      else
      {
         int direction=ResolveBEActivationSide(tradeSide);
         PositionRow rows[];
         if(direction!=0 && CollectManagedPositionsForSide(rows,direction)>0)
         {
            double level=CalculateBreakEvenPrice(rows,direction,true);
            if(MathIsValidNumber(level) && level>0 && level!=EMPTY_VALUE)
            {
               takeProfitSide=direction;takeProfitPrice=level;takeProfitShown=true;
               if(!orderPrepared) tradeSide=direction;
               csmPanelStatus="TP "+TPSideCaption()+" proyectado: pendiente de aplicar";
            }
            else csmPanelStatus="TP: nivel no disponible";
         }
         else csmPanelStatus="TP: no hay posiciones elegibles";
      }
   }
   if(k=="send" || k=="apply" || k=="applyTP" || k=="realize" || k=="close")
   {
      if(!TradePermissionsAllowed()) csmPanelStatus="Trading no permitido: requiere hedging y permisos";
      else if(k=="send") SubmitOrder();
      else if(k=="apply")
      {
         if(PanelHit(k,(int)lp,(int)dp) && ManagementApplyEnabled(false)) ApplyBreakEvenStops();
      }
      else if(k=="applyTP")
      {
         if(PanelHit(k,(int)lp,(int)dp) && ManagementApplyEnabled(true)) ApplyTakeProfitTargets();
      }
      else if(k=="realize") CloseManagedPositions(false);
      else if(closeConfirmationDeadline>GetTickCount64()){closeConfirmationDeadline=0;CloseManagedPositions(true);}
      else closeConfirmationDeadline=GetTickCount64()+4000;
   }
   RenderPanel();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   // SL-only modifications do not change the entry commissions.
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD || trans.type==TRADE_TRANSACTION_DEAL_UPDATE ||
      trans.type==TRADE_TRANSACTION_DEAL_DELETE)
      InvalidatePositionFeeCache();
   // Broker history corrections can invalidate a previously verified origin.
   if(trans.type==TRADE_TRANSACTION_DEAL_UPDATE || trans.type==TRADE_TRANSACTION_DEAL_DELETE)
      ArrayResize(initialRiskCache,0);
   panelDirty=true;
}
