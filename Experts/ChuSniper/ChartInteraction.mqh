// Chart-native controls are restored on release and at EA removal.
void InitializeChartInteraction()
{
   previousMouseMoveEnabled=(bool)ChartGetInteger(0,CHART_EVENT_MOUSE_MOVE);
   chartMouseMoveConfigured=true;
   ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,true);
}

void SetChartScrollCaptured(const bool capture)
{
   if(capture)
   {
      if(!chartMouseScrollCaptured)
      {
         previousChartMouseScroll=(bool)ChartGetInteger(0,CHART_MOUSE_SCROLL);
         chartMouseScrollCaptured=true;
      }
      ChartSetInteger(0,CHART_MOUSE_SCROLL,false);
   }
   else if(chartMouseScrollCaptured)
   {
      ChartSetInteger(0,CHART_MOUSE_SCROLL,previousChartMouseScroll);
      chartMouseScrollCaptured=false;
   }
}

void RestoreChartInteraction()
{
   SetChartScrollCaptured(false);
   if(chartMouseMoveConfigured)
   {
      ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,previousMouseMoveEnabled);
      chartMouseMoveConfigured=false;
   }
}

bool MouseChartPrice(const int x,const int y,double &price)
{
   int window=0;
   datetime when=0;
   if(!ChartXYToTimePrice(0,x,y,window,when,price)) return false;
   return window==0;
}

string ChartLevelNearMouse(const int x,const int y)
{
   double price=0,offsetPrice=0;
   if(!MouseChartPrice(x,y,price) || !MouseChartPrice(x,y+7,offsetPrice)) return "";
   double tolerance=MathAbs(price-offsetPrice);
   string closest="";
   double bestDistance=tolerance;
   string keys[]={"Stop loss","Take profit","Entrada","BE"};
   for(int i=0;i<ArraySize(keys);i++)
   {
      string key=keys[i],object=PanelObjectName(key);
      if(key=="BE" && !breakEvenShown) continue;
      if(key=="Entrada" && (!orderPrepared || !pendingOrderMode)) continue;
      if((key=="Stop loss" || key=="Take profit") && !orderPrepared) continue;
      if(ObjectFind(0,object)<0) continue;
      double distance=MathAbs(ObjectGetDouble(0,object,OBJPROP_PRICE)-price);
      if(distance<=bestDistance){closest=key;bestDistance=distance;}
   }
   string pendingPrefix=PanelObjectName("Pending_");
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string object=ObjectName(0,i);
      if(StringFind(object,pendingPrefix)!=0) continue;
      double distance=MathAbs(ObjectGetDouble(0,object,OBJPROP_PRICE)-price);
      if(distance<=bestDistance)
      {
         closest=StringSubstr(object,StringLen(panelObjectPrefix));
         bestDistance=distance;
      }
   }
   return closest;
}

void UpdateDraggedLevel(const string key,const double price)
{
   if(key=="Entrada" && pendingOrderMode) csmPlannedEntry=price;
   else if(key=="Stop loss"){plannedStopLoss=price;fixedStopMode=false;}
   else if(key=="Take profit"){plannedTakeProfit=price;riskRewardMode=false;}
   else if(key=="BE") breakEvenPrice=price;
}

void ApplyChartLevelRelease(const string key,const double price)
{
   if(price<=0) return;
   if(key=="Entrada" && pendingOrderMode && orderPrepared) csmPlannedEntry=price;
   else if(key=="Stop loss" && orderPrepared){plannedStopLoss=price;fixedStopMode=false;}
   else if(key=="Take profit" && orderPrepared){plannedTakeProfit=price;riskRewardMode=false;}
   else if(key=="BE" && breakEvenShown)
   {
      breakEvenPrice=price;
      if(groupMode) ApplyBreakEvenStops();
      else csmPanelStatus="Activa Grupo para aplicar el nivel BE";
   }
   else if(StringFind(key,"Pending_")==0)
      AdjustBrokerPendingOrder(key,price);
}

void CancelChartDrag()
{
   if(!chartLineDragging) return;
   string key=chartDragKey;
   double previous=chartDragStartPrice;
   chartLineDragging=false;
   chartDragKey="";
   chartDragMoved=false;
   UpdateDraggedLevel(key,previous);
   fixedStopMode=chartDragOriginalFixedStop;
   riskRewardMode=chartDragOriginalRiskReward;
   SetChartScrollCaptured(false);
}

void FinishChartDrag()
{
   if(!chartLineDragging) return;
   string key=chartDragKey;
   double price=NormalizeTradePrice(ObjectGetDouble(0,PanelObjectName(key),OBJPROP_PRICE));
   bool changed=chartDragMoved || MathAbs(price-chartDragStartPrice)>_Point/2;
   chartLineDragging=false;
   chartDragKey="";
   chartDragMoved=false;
   SetChartScrollCaptured(false);
   lastReleasedChartKey=key;
   lastReleasedChartAt=GetTickCount64();
   if(changed) ApplyChartLevelRelease(key,price);
   RenderPanel();
}

void HandleChartMouseMove(const int x,const int y,const string state)
{
   bool leftPressed=(((int)StringToInteger(state))&1)!=0;
   if(!leftPressed)
   {
      if(chartLineDragging) FinishChartDrag();
      return;
   }
   if(!chartLineDragging)
   {
      string candidate=ChartLevelNearMouse(x,y);
      if(candidate=="") return;
      chartLineDragging=true;
      chartDragMoved=false;
      chartDragKey=candidate;
      chartDragStartPrice=ObjectGetDouble(0,PanelObjectName(candidate),OBJPROP_PRICE);
      chartDragOriginalFixedStop=fixedStopMode;
      chartDragOriginalRiskReward=riskRewardMode;
      chartDragStartedAt=GetTickCount64();
      SetChartScrollCaptured(true);
   }
   double price=0;
   if(!MouseChartPrice(x,y,price)) return;
   price=NormalizeTradePrice(price);
   if(price<=0) return;
   if(MathAbs(price-chartDragStartPrice)>_Point/2) chartDragMoved=true;
   if(chartDragMoved)
   {
      ObjectSetDouble(0,PanelObjectName(chartDragKey),OBJPROP_PRICE,price);
      UpdateDraggedLevel(chartDragKey,price);
   }
}
