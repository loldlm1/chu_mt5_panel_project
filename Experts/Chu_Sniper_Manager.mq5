#property strict
#property version "0.12"
#include <Trade/Trade.mqh>
#include "ChuSniper/State.mqh"
#include "ChuSniper/ChartObjects.mqh"
#include "ChuSniper/Positions.mqh"
#include "ChuSniper/Orders.mqh"
#include "ChuSniper/TradeManagement.mqh"
#include "ChuSniper/Panel.mqh"
#include "ChuSniper/ChartInteraction.mqh"

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   trade.SetTypeFillingBySymbol(_Symbol);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,C'43,44,48');
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,C'41,167,165');
   ChartSetInteger(0,CHART_COLOR_CHART_UP,C'41,167,165');
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,C'228,92,88');
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,C'228,92,88');
   tradeExecutionEnabled=(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO || MQLInfoInteger(MQL_TESTER))
         && AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   csmPanelStatus=tradeExecutionEnabled?"Demo: selecciona Comprar o Vender":"Vista previa: ejecucion disponible en demo";
   InitializeChartInteraction();
   EventSetMillisecondTimer(250);
   RenderPanel();
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){EventKillTimer();RestoreChartInteraction();ObjectsDeleteAll(0,panelObjectPrefix);}
void OnTimer()
{
   if(chartLineDragging && GetTickCount64()-chartDragStartedAt>20000)
   {
      // Avoid leaving scrolling disabled if the mouse was released off-chart.
      CancelChartDrag();
   }
   UpdateTrailingStops();
   RenderPanel();
}
void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp)
{
   if(id==CHARTEVENT_MOUSE_MOVE)
   {
      HandleChartMouseMove((int)lp,(int)dp,sp);
      return;
   }
   if(StringFind(sp,panelObjectPrefix)!=0) return;
   string k=StringSubstr(sp,StringLen(panelObjectPrefix));
   if(id==CHARTEVENT_OBJECT_DRAG)
   {
      if(chartLineDragging) FinishChartDrag();
      else if(lastReleasedChartKey!=k || GetTickCount64()-lastReleasedChartAt>750)
      {
         ApplyChartLevelRelease(k,NormalizeTradePrice(ObjectGetDouble(0,sp,OBJPROP_PRICE)));
         RenderPanel();
      }
      return;
   }
   if(id==CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(k=="points")
      {
         editingStopPoints=false;
         if(PanelInputNumber("points")>0){stopDistancePoints=PanelInputNumber("points");fixedStopMode=true;}
      }
      if(k=="ratio" && PanelInputNumber(k)>0){rewardRiskRatio=PanelInputNumber(k);riskRewardMode=true;}
      RenderPanel();return;
   }
   if(id!=CHARTEVENT_OBJECT_CLICK) return;
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
         if(SymbolInfoTick(_Symbol,q)) csmPlannedEntry=NormalizeTradePrice((tradeSide>0?q.ask:q.bid)+tradeSide*stopDistancePoints*_Point);
      }
   }
   if(k=="percent" && riskMode!=0){riskMode=0;SetPanelInputText("riskval","1");}
   if(k=="money" && riskMode!=1){riskMode=1;SetPanelInputText("riskval","200");}
   if(k=="lot" && riskMode!=2){riskMode=2;SetPanelInputText("riskval",DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),4));}
   if(k=="tpMode") riskRewardMode=!riskRewardMode;
   if(k=="avg") averagingEnabled=!averagingEnabled;
   if(k=="trail"){trailingMode=(trailingMode+1)%2;ArrayResize(trailingPositionTickets,0);ArrayResize(favorablePrices,0);}
   if(k=="units") {percentTargetMode=!percentTargetMode;SetPanelInputText("amount",percentTargetMode?"50":"100");}
   if(k=="be")
   {
      if(breakEvenShown) breakEvenShown=false;
      else if(!groupMode) csmPanelStatus="Activa Grupo para usar el break-even grupal";
      else
      {
         PositionRow rows[];
         if(CollectManagedPositions(rows)>0){breakEvenPrice=CalculateBreakEvenPrice(rows);breakEvenShown=breakEvenPrice>0;}
         else csmPanelStatus="Selecciona un lado con posiciones abiertas";
      }
   }
   if(k=="send" || k=="apply" || k=="realize" || k=="close")
   {
      if(!tradeExecutionEnabled) csmPanelStatus="Ejecucion disponible solo en demo hedging";
      else if(k=="send") SubmitOrder();
      else if(k=="apply") ApplyBreakEvenStops();
      else if(k=="realize") CloseManagedPositions(false);
      else if(closeConfirmationDeadline>GetTickCount64()){closeConfirmationDeadline=0;CloseManagedPositions(true);}
      else closeConfirmationDeadline=GetTickCount64()+4000;
   }
   RenderPanel();
}
