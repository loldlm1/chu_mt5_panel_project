#property strict
#property version "0.12"
#include <Trade/Trade.mqh>
#include "ChuSniper/State.mqh"
#include "ChuSniper/ChartObjects.mqh"
#include "ChuSniper/Positions.mqh"
#include "ChuSniper/Orders.mqh"
#include "ChuSniper/TradeManagement.mqh"
#include "ChuSniper/Panel.mqh"

int OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   trade.SetTypeFillingBySymbol(_Symbol);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,C'43,44,48');
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,C'41,167,165');
   ChartSetInteger(0,CHART_COLOR_CHART_UP,C'41,167,165');
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,C'228,92,88');
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,C'228,92,88');
   armed=(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO || MQLInfoInteger(MQL_TESTER))
         && AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   csmPanelStatus=armed?"Demo: selecciona Comprar o Vender":"Vista previa: ejecucion disponible en demo";
   EventSetMillisecondTimer(250);
   Paint();
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){EventKillTimer();ObjectsDeleteAll(0,P);}
void OnTimer(){Trail();Paint();}
void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp)
{
   if(StringFind(sp,P)!=0) return;
   string k=StringSubstr(sp,StringLen(P));
   if(id==CHARTEVENT_OBJECT_DRAG)
   {
      double price=Price(ObjectGetDouble(0,sp,OBJPROP_PRICE));
      if(k=="BE") bePrice=price;
      if(k=="Entrada" && pending) csmPlannedEntry=price;
      if(k=="Stop loss"){plannedStopLoss=price;fixedStop=false;}
      if(k=="Take profit"){plannedTakeProfit=price;ratioMode=false;}
      Paint();return;
   }
   if(id==CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(k=="points")
      {
         editingPoints=false;
         if(V("points")>0){stopPoints=V("points");fixedStop=true;}
      }
      if(k=="ratio" && V(k)>0){rr=V(k);ratioMode=true;}
      Paint();return;
   }
   if(id!=CHARTEVENT_OBJECT_CLICK) return;
   if(k=="points"){editingPoints=true;return;}
   ObjectSetInteger(0,sp,OBJPROP_STATE,false);
   if(k!="close") closeDeadline=0;
   if(k=="buy") Prepare(1);
   if(k=="sell") Prepare(-1);
   if(k=="scope"){group=!group;be=false;}
   if(k=="mode")
   {
      pending=!pending;
      if(prep && pending)
      {
         MqlTick q;
         if(SymbolInfoTick(_Symbol,q)) csmPlannedEntry=Price((side>0?q.ask:q.bid)+side*stopPoints*_Point);
      }
   }
   if(k=="percent" && risk!=0){risk=0;S("riskval","1");}
   if(k=="money" && risk!=1){risk=1;S("riskval","200");}
   if(k=="lot" && risk!=2){risk=2;S("riskval",DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),4));}
   if(k=="tpMode") ratioMode=!ratioMode;
   if(k=="avg") averaging=!averaging;
   if(k=="trail"){trailing=(trailing+1)%4;ArrayResize(tracked,0);ArrayResize(best,0);}
   if(k=="units") {pct=!pct;S("amount",pct?"50":"100");}
   if(k=="be")
   {
      if(be) be=false;
      else
      {
         PositionRow rows[];
         if(Positions(rows)>0){bePrice=BreakEven(rows);be=bePrice>0;}
         else csmPanelStatus="Selecciona un lado con posiciones abiertas";
      }
   }
   if(k=="send" || k=="apply" || k=="realize" || k=="close")
   {
      if(!armed) csmPanelStatus="Ejecucion disponible solo en demo hedging";
      else if(k=="send") Submit();
      else if(k=="apply") Apply();
      else if(k=="realize") Close(false);
      else if(closeDeadline>GetTickCount64()){closeDeadline=0;Close(true);}
      else closeDeadline=GetTickCount64()+4000;
   }
   Paint();
}
