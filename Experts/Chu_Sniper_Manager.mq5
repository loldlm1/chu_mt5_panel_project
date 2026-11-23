#property strict
#property version "0.12"
#include <Trade/Trade.mqh>
input ulong Magic=110629;
input int ActivationPoints=250;
input int TrailPoints=150;
input int StepPoints=250;
input bool IncludeOtherPositions=false;
CTrade trade;
string P="CSM_",csmPanelStatus="";
int side=1, risk=1, trailing=0;
bool group=false, pending=false, prep=false, fixedStop=false, ratioMode=true, averaging=false, pct=false, be=false, armed=false;
double csmPlannedEntry=0,plannedStopLoss=0,plannedTakeProfit=0,stopPoints=250,rr=2,bePrice=0;
ulong closeDeadline=0;
bool editingPoints=false;
ulong tracked[];
double best[];
#define CSM_PANEL_NAVY C'20,30,43'
color ink=C'225,232,241', gold=C'255,215,49', blue=C'70,169,255', red=C'255,100,100', green=C'42,192,179';

string N(string key){return P+key;}
void Box(string key,ENUM_OBJECT type,int x,int y,int w,int h,string label,color bg,color fg)
{
   string n=N(key);
   bool fresh=ObjectFind(0,n)<0;
   if(fresh) ObjectCreate(0,n,type,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_COLOR,fg);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,type==OBJ_RECTANGLE_LABEL?0:5);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   if(type!=OBJ_EDIT || fresh) ObjectSetString(0,n,OBJPROP_TEXT,label);
}
void B(string k,int x,int y,int w,string s,color c=CSM_PANEL_NAVY){Box(k,OBJ_BUTTON,x,y,w,25,s,c,c==gold?clrBlack:ink);}
void E(string k,int x,int y,int w,string s){Box(k,OBJ_EDIT,x,y,w,25,s,CSM_PANEL_NAVY,ink);}
string T(string k){return ObjectGetString(0,N(k),OBJPROP_TEXT);}
double V(string k){string s=T(k);StringReplace(s,",",".");return StringToDouble(s);}
void S(string k,string s){ObjectSetString(0,N(k),OBJPROP_TEXT,s);}
void Line(string k,double p,color c,bool drag)
{
   string n=N(k);
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_HLINE,0,0,p);
   ObjectSetDouble(0,n,OBJPROP_PRICE,p);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,drag);
   ObjectSetString(0,n,OBJPROP_TOOLTIP,k);
}
double Price(double p)
{
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return NormalizeDouble(tick>0?MathRound(p/tick)*tick:p,_Digits);
}
double Down(double v)
{
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   return step>0?NormalizeDouble(MathFloor(v/step+1e-9)*step,8):0;
}
ENUM_ORDER_TYPE Direction(){return side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;}
bool Profit(double open,double end,double lots,double &result)
{
   return OrderCalcProfit(Direction(),_Symbol,lots,open,end,result);
}
struct PositionRow {ulong id; double open,vol,stop,target,swap,cost,floatPL;};
int Positions(PositionRow &rows[])
{
   ArrayResize(rows,0);
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong id=PositionGetTicket(i);
      if(!id || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE)!=(side>0?POSITION_TYPE_BUY:POSITION_TYPE_SELL)) continue;
      if(!IncludeOtherPositions && PositionGetInteger(POSITION_MAGIC)!=(long)Magic) continue;
      int n=ArraySize(rows);
      ArrayResize(rows,n+1);
      rows[n].id=id;
      rows[n].open=PositionGetDouble(POSITION_PRICE_OPEN);
      rows[n].vol=PositionGetDouble(POSITION_VOLUME);
      rows[n].stop=PositionGetDouble(POSITION_SL);
      rows[n].target=PositionGetDouble(POSITION_TP);
      rows[n].swap=PositionGetDouble(POSITION_SWAP);
      rows[n].cost=0;
      rows[n].floatPL=PositionGetDouble(POSITION_PROFIT)+rows[n].swap;
   }
   for(int i=1;i<ArraySize(rows);i++)
      for(int j=i;j>0 && (group?side*(rows[j].open-rows[j-1].open)>0:rows[j].id>rows[j-1].id);j--)
      {
         PositionRow tmp=rows[j];
         rows[j]=rows[j-1];
         rows[j-1]=tmp;
      }
   if(!group && ArraySize(rows)>1) ArrayResize(rows,1);
   for(int i=0;i<ArraySize(rows);i++)
   {
      if(!PositionSelectByTicket(rows[i].id)) continue;
      if(!HistorySelectByPosition((ulong)PositionGetInteger(POSITION_IDENTIFIER))) continue;
      double inVolume=0,fees=0;
      for(int j=0;j<HistoryDealsTotal();j++)
      {
         ulong deal=HistoryDealGetTicket(j);
         if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
         inVolume+=HistoryDealGetDouble(deal,DEAL_VOLUME);
         fees+=HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_FEE);
      }
      if(inVolume>0) rows[i].cost=fees*rows[i].vol/inVolume;
      rows[i].floatPL+=rows[i].cost;
   }
   return ArraySize(rows);
}
double AtLevel(PositionRow &rows[],double level)
{
   double total=0;
   for(int i=0;i<ArraySize(rows);i++)
   {
      double value=0;
      if(!Profit(rows[i].open,level,rows[i].vol,value)) return EMPTY_VALUE;
      total+=value+rows[i].swap+rows[i].cost;
   }
   return total;
}
double BreakEven(PositionRow &rows[])
{
   double sum=0,vol=0;
   for(int i=0;i<ArraySize(rows);i++){sum+=rows[i].open*rows[i].vol;vol+=rows[i].vol;}
   if(vol<=0) return 0;
   double base=sum/vol, move=MathMax(_Point*100,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
   double a=AtLevel(rows,base), b=AtLevel(rows,base+move);
   if(a==EMPTY_VALUE || b==EMPTY_VALUE || MathAbs(a-b)<1e-10) return Price(base);
   return Price(base-a*move/(b-a));
}
string OrderName(ENUM_ORDER_TYPE t)
{
   switch(t)
   {
      case ORDER_TYPE_BUY_STOP:return "Buy Stop";
      case ORDER_TYPE_BUY_LIMIT:return "Buy Limit";
      case ORDER_TYPE_SELL_STOP:return "Sell Stop";
      case ORDER_TYPE_SELL_LIMIT:return "Sell Limit";
      default:return side>0?"compra a mercado":"venta a mercado";
   }
}
bool Plan(MqlTick &q, ENUM_ORDER_TYPE &type,double &lot,double &loss)
{
   type=Direction();
   double quote=side>0?q.ask:q.bid;
   if(!pending) csmPlannedEntry=Price(quote);
   if(fixedStop) plannedStopLoss=Price(csmPlannedEntry-side*stopPoints*_Point);
   if(ratioMode) plannedTakeProfit=Price(csmPlannedEntry+side*MathAbs(csmPlannedEntry-plannedStopLoss)*rr);
   double gap=MathMax(_Point,SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point);
   if(pending)
   {
      if(side>0) type=csmPlannedEntry>quote?ORDER_TYPE_BUY_STOP:ORDER_TYPE_BUY_LIMIT;
      else type=csmPlannedEntry<quote?ORDER_TYPE_SELL_STOP:ORDER_TYPE_SELL_LIMIT;
   }
   double one=0, reference=pending?csmPlannedEntry:(side>0?q.bid:q.ask);
   if(csmPlannedEntry<=0 || plannedStopLoss<=0 || plannedTakeProfit<=0 || side*(csmPlannedEntry-plannedStopLoss)<=0 || side*(reference-plannedStopLoss)<gap-1e-9 ||
      side*(plannedTakeProfit-csmPlannedEntry)<=0 || side*(plannedTakeProfit-reference)<gap-1e-9 || (pending && MathAbs(csmPlannedEntry-quote)<gap-1e-9) ||
      !Profit(csmPlannedEntry,plannedStopLoss,1,one) || one>=0) return false;
   double budget=V("riskval");
   if(risk==0) budget*=AccountInfoDouble(ACCOUNT_BALANCE)/100;
   double max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   lot=risk==2?Down(budget):Down(MathMin(max,budget/-one));
   loss=-one*lot;
   return lot>=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)-1e-9 && lot<=max+1e-9 && (risk!=2 || MathAbs(lot-budget)<1e-8);
}
bool Done()
{
   uint code=trade.ResultRetcode();
   return code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL || code==TRADE_RETCODE_NO_CHANGES;
}
void Prepare(int dir)
{
   if(side!=dir){be=false;ObjectDelete(0,N("BE"));}
   side=dir;
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q)) return;
   double quote=side>0?q.ask:q.bid;
   csmPlannedEntry=Price(quote+(pending?side*stopPoints*_Point:0));
   plannedStopLoss=Price(csmPlannedEntry-side*stopPoints*_Point);
   plannedTakeProfit=Price(csmPlannedEntry+side*stopPoints*_Point*rr);
   prep=true;
   csmPanelStatus="Ajusta las lineas y confirma la orden";
}
void Submit()
{
   MqlTick q;
   ENUM_ORDER_TYPE type;
   double lot=0,loss=0;
   if(!prep || !SymbolInfoTick(_Symbol,q) || !Plan(q,type,lot,loss)){csmPanelStatus="Orden invalida: revisa niveles, riesgo y lote";return;}
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      csmPanelStatus="La ejecucion de esta beta requiere cuenta demo hedging";
      return;
   }
   PositionRow rows[];
   if(Positions(rows)>0 && (!group || !averaging)){csmPanelStatus="Activa Grupo y Promediacion para agregar entradas";return;}
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
   if(ok && (Done() || trade.ResultRetcode()==TRADE_RETCODE_PLACED))
   {
      prep=false;
      ObjectDelete(0,N("Entrada"));ObjectDelete(0,N("Stop loss"));ObjectDelete(0,N("Take profit"));
      csmPanelStatus="Orden aceptada: "+OrderName(type);
   }
   else csmPanelStatus="Orden: "+trade.ResultRetcodeDescription();
}
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
void Paint()
{
   int x=12,y=20,w=460;
   Box("bg",OBJ_RECTANGLE_LABEL,x,y,w,343,"",C'10,17,26',ink);
   x+=8;y+=7;
   B("title",x,y,444,"Chu Sniper Manager  |  MT5  |  DEMO");
   y+=29;
   B("buy",x,y,105,"Comprar",side>0?green:CSM_PANEL_NAVY);
   B("sell",x+110,y,105,"Vender",side<0?red:CSM_PANEL_NAVY);
   B("scope",x+220,y,110,group?"Grupo":"Individual",gold);
   B("mode",x+335,y,109,pending?"Pendiente":"Mercado",gold);
   y+=29;
   B("percent",x,y,103,"% cuenta",risk==0?gold:CSM_PANEL_NAVY);
   B("money",x+107,y,102,"Dinero",risk==1?gold:CSM_PANEL_NAVY);
   B("lot",x+213,y,102,"Lote fijo",risk==2?gold:CSM_PANEL_NAVY);
   E("riskval",x+319,y,125,"200");
   y+=29;
   B("stoplabel",x,y,105,"Stop (puntos)");
   E("points",x+110,y,77,"250");
   B("tpMode",x+192,y,149,ratioMode?"Take profit R:B":"Take profit Manual",gold);
   E("ratio",x+347,y,97,"2");
   y+=29;
   MqlTick q;
   ENUM_ORDER_TYPE type=Direction();
   double lot=0,loss=0;
   bool valid=prep && SymbolInfoTick(_Symbol,q) && Plan(q,type,lot,loss);
   if(prep)
   {
      Line("Entrada",csmPlannedEntry,green,pending);Line("Stop loss",plannedStopLoss,red,true);Line("Take profit",plannedTakeProfit,blue,true);
      if(!fixedStop && !ObjectGetInteger(0,N("points"),OBJPROP_SELECTED))
      {
         // Update on drag and quote changes unless the text edit is focused.
         if(!editingPoints) S("points",DoubleToString(MathAbs(csmPlannedEntry-plannedStopLoss)/_Point,1));
      }
   }
   B("preview",x,y,444,valid?StringFormat("Lote %.4f  |  Riesgo estimado %.2f %s",lot,loss,AccountInfoString(ACCOUNT_CURRENCY)):"Prepara la orden y ajusta los niveles");
   y+=29;
   B("send",x,y,444,prep?"Confirmar "+OrderName(type):"Confirmar orden",valid?green:CSM_PANEL_NAVY);
   y+=29;
   string trailModes[]={"Apagado","Objetivos","Distancia","Hibrido"};
   B("avg",x,y,150,averaging?"Promediacion activa":"Promediacion",averaging?gold:CSM_PANEL_NAVY);
   B("trail",x+155,y,289,"Trailing: "+trailModes[trailing],trailing?gold:CSM_PANEL_NAVY);
   y+=29;
   PositionRow rows[];
   int count=Positions(rows);
   double floating=0;
   for(int i=0;i<count;i++) floating+=rows[i].floatPL;
   double at=be?AtLevel(rows,bePrice):0,bal=AccountInfoDouble(ACCOUNT_BALANCE);
   B("scopeinfo",x,y,444,StringFormat("%s %s | %d posiciones | Flotante %+.2f",_Symbol,side>0?"Compras":"Ventas",count,floating));
   y+=29;
   B("be",x,y,108,"Break-even",gold);
   B("apply",x+112,y,106,"Aplicar nivel",be?gold:CSM_PANEL_NAVY);
   B("units",x+222,y,108,pct?"% flotante":"Dinero",gold);
   E("amount",x+334,y,110,"100");
   y+=29;
   B("realize",x,y,218,"Realizar ganancia",blue);
   B("close",x+222,y,222,closeDeadline>GetTickCount64()?"Confirmar cerrar todo":"Cerrar todo",red);
   y+=29;
   B("status",x,y,444,csmPanelStatus);
   if(be && count>0)
   {
      Line("BE",bePrice,gold,true);
      string preview=at==EMPTY_VALUE?"Cierre estimado no disponible":StringFormat("Cierre %+.2f %s (%+.2f%%) | Retroceso %.2f",at,AccountInfoString(ACCOUNT_CURRENCY),bal>0?at*100/bal:0,MathMax(0,floating-at));
      int bx=484,by=y;
      int py=0,px=0;
      if(ChartTimePriceToXY(0,0,iTime(_Symbol,_Period,0),bePrice,px,py)) by=MathMax(0,py-27);
      if(ChartGetInteger(0,CHART_WIDTH_IN_PIXELS)<900){bx=x;by=y+28;}
      Box("beinfo",OBJ_BUTTON,bx,by,405,25,preview,CSM_PANEL_NAVY,at==EMPTY_VALUE||MathAbs(at)<0.005?clrSilver:at>0?blue:red);
   }
   else {ObjectDelete(0,N("BE"));ObjectDelete(0,N("beinfo"));}
   ChartRedraw();
}
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