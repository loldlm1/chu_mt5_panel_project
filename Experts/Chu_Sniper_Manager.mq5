#property strict
#property version "0.160"
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
   panelDirty=true;lastPanelRefresh=0;lastQuickQuoteRefresh=0;lastBEProjectionRefresh=0;
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
      RefreshBEProjectionDuringDrag();
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
         if(PanelInputNumber("points")>0)
         {
            stopDistancePoints=PanelInputNumber("points");fixedStopMode=true;
            if(orderPrepared)
            {
               plannedStopLoss=csmPlannedEntry-tradeSide*stopDistancePoints*_Point;
               if(riskRewardMode) plannedTakeProfit=csmPlannedEntry+tradeSide*MathAbs(csmPlannedEntry-plannedStopLoss)*rewardRiskRatio;
            }
         }
      }
      if(k=="ratio" && PanelInputNumber(k)>0)
      {
         rewardRiskRatio=PanelInputNumber(k);riskRewardMode=true;
         if(orderPrepared) plannedTakeProfit=NormalizeTradePrice(csmPlannedEntry+tradeSide*MathAbs(csmPlannedEntry-plannedStopLoss)*rewardRiskRatio);
      }
      if(k=="riskval" || k=="amount" || k=="points" || k=="ratio")
         SetPanelInputText(k,DoubleToString(PanelInputNumber(k),16));
      if(orderPrepared && (k=="points" || k=="ratio"))
      {
         bool adjusted=false;AdaptManualPlan(riskRewardMode,adjusted);
      }
      RenderPanel();return;
   }
   if(id!=CHARTEVENT_OBJECT_CLICK || chartLineDragging || panelGesture!=0 || suppressPanelClick) return;
   if(PriceLevelSlot(k)>=0 || !PanelControlVisible(k)) return;
   if(k=="title" || k=="resize" || k=="bg" || k=="quickInfo" || k=="beinfo") return;
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
   if(k=="buy") PrepareOrder(1);
   if(k=="sell") PrepareOrder(-1);
   if(k=="scope"){groupMode=!groupMode;breakEvenShown=false;}
   if(k=="mode")
   {
      pendingOrderMode=!pendingOrderMode;
      if(orderPrepared && pendingOrderMode)
      {
         MqlTick q;
         if(SymbolInfoTick(_Symbol,q))
         {
            double entry=NormalizeTradePrice((tradeSide>0?q.ask:q.bid)+tradeSide*stopDistancePoints*_Point);
            double delta=entry-csmPlannedEntry;
            csmPlannedEntry=entry;
            plannedStopLoss=NormalizeTradePrice(plannedStopLoss+delta);
            plannedTakeProfit=NormalizeTradePrice(plannedTakeProfit+delta);
         }
      }
   }
   if(k=="percent" && riskMode!=0){riskMode=0;SetPanelInputText("riskval","1");}
   if(k=="money" && riskMode!=1){riskMode=1;SetPanelInputText("riskval","200");}
   if(k=="lot" && riskMode!=2){riskMode=2;SetPanelInputText("riskval",DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),16));}
   if(k=="tpMode")
   {
      riskRewardMode=!riskRewardMode;
      if(riskRewardMode && orderPrepared)
         plannedTakeProfit=NormalizeTradePrice(csmPlannedEntry+tradeSide*MathAbs(csmPlannedEntry-plannedStopLoss)*rewardRiskRatio);
   }
   if(orderPrepared && (k=="mode" || k=="tpMode"))
   {
      bool adjusted=false;AdaptManualPlan(k=="tpMode" && riskRewardMode,adjusted);
   }
   if(k=="trail"){trailingMode=(trailingMode+1)%2;ArrayResize(trailingPositionTickets,0);ArrayResize(favorablePrices,0);ArrayResize(trailingRetryAfter,0);}
   if(k=="units") {percentTargetMode=!percentTargetMode;SetPanelInputText("amount",percentTargetMode?"50":"100");}
   if(k=="be")
   {
      if(breakEvenShown) breakEvenShown=false;
      else
      {
         PositionRow rows[];
         if(CollectManagedPositions(rows)>0)
         {
            breakEvenPrice=CalculateBreakEvenPrice(rows);breakEvenShown=breakEvenPrice>0;
            if(breakEvenShown) csmPanelStatus="BE proyectado: pendiente de aplicar";
         }
         else csmPanelStatus="Selecciona un lado con posiciones abiertas";
      }
   }
   if(k=="send" || k=="apply" || k=="realize" || k=="close")
   {
      if(!TradePermissionsAllowed()) csmPanelStatus="Trading no permitido: requiere hedging y permisos";
      else if(k=="send") SubmitOrder();
      else if(k=="apply")
      {
         if(PanelHit(k,(int)lp,(int)dp)) ApplyBreakEvenStops();
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
   panelDirty=true;
}
