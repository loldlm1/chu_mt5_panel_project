// Mouse events own the entire custom gesture; native OBJECT_DRAG never commits.
void InitializeChartInteraction()
{
   previousMouseMoveEnabled=(bool)ChartGetInteger(0,CHART_EVENT_MOUSE_MOVE);
   chartMouseMoveConfigured=true;
   ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,true);
}
void SetChartScrollCaptured(const bool capture)
{
   if(capture && !chartMouseScrollCaptured)
   {
      previousChartMouseScroll=(bool)ChartGetInteger(0,CHART_MOUSE_SCROLL);
      chartMouseScrollCaptured=true;ChartSetInteger(0,CHART_MOUSE_SCROLL,false);
   }
   else if(!capture && chartMouseScrollCaptured)
   {
      ChartSetInteger(0,CHART_MOUSE_SCROLL,previousChartMouseScroll);chartMouseScrollCaptured=false;
   }
}
void SetTradeLevelDragCaptured(const bool capture)
{
   if(capture && !tradeLevelDragCaptured)
   {
      previousTradeLevelDrag=(bool)ChartGetInteger(0,CHART_DRAG_TRADE_LEVELS);
      tradeLevelDragCaptured=true;ChartSetInteger(0,CHART_DRAG_TRADE_LEVELS,false);ChartRedraw();
   }
   else if(!capture && tradeLevelDragCaptured)
   {
      ChartSetInteger(0,CHART_DRAG_TRADE_LEVELS,previousTradeLevelDrag);tradeLevelDragCaptured=false;ChartRedraw();
   }
}
void RestoreChartInteraction()
{
   SetChartScrollCaptured(false);SetTradeLevelDragCaptured(false);
   if(chartMouseMoveConfigured)
   {ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,previousMouseMoveEnabled);chartMouseMoveConfigured=false;}
}
bool MouseChartPrice(const int x,const int y,double &price)
{
   int window=0;datetime when=0;
   return ChartXYToTimePrice(0,x,y,window,when,price) && window==0;
}
string ChartLevelNearMouse(const int x,const int y)
{
   if(PointOnPanel(x,y)) return "";
   double price=0,offset=0;
   if(!MouseChartPrice(x,y,price) || !MouseChartPrice(x,y+7,offset)) return "";
   double tolerance=MathAbs(price-offset),best=tolerance;
   string closest="";
   for(int i=0;i<ArraySize(priceLevels);i++)
   {
      if(!priceLevels[i].draggable) continue;
      string key=priceLevels[i].key;
      double distance=MathAbs(priceLevels[i].price-price);
      if(distance>tolerance) continue;
      if(key=="BE" && breakEvenShown) return key;
      if(distance<=best){closest=key;best=distance;}
   }
   return closest;
}
void PreviewDraggedPrice(const double price)
{
   chartDragPrice=price;
   if(chartDragKey=="Entrada")
   {
      csmPlannedEntry=price;
      plannedStopLoss=NormalizeTradePrice(chartDragStartSL+price-chartDragStartPrice);
      plannedTakeProfit=NormalizeTradePrice(chartDragStartTP+price-chartDragStartPrice);
      SetPriceLevel("Stop loss",plannedStopLoss);SetPriceLevel("Take profit",plannedTakeProfit);
   }
   else if(chartDragKey=="Stop loss"){plannedStopLoss=price;fixedStopMode=false;riskRewardMode=false;}
   else if(chartDragKey=="Take profit"){plannedTakeProfit=price;riskRewardMode=false;}
   else if(chartDragKey=="BE") breakEvenPrice=price;
   else if(StringFind(chartDragKey,"Pending_")==0)
   {
      double delta=price-chartDragStartPrice;
      if(chartDragStartSL>0) DrawPriceLevel("DragPendingSL",NormalizeTradePrice(chartDragStartSL+delta),sellColor,false);
      if(chartDragStartTP>0) DrawPriceLevel("DragPendingTP",NormalizeTradePrice(chartDragStartTP+delta),infoColor,false);
   }
   SetPriceLevel(chartDragKey,price);
   ChartRedraw();
}
void ClearDragPreview()
{
   ForgetPriceLevel("DragPendingSL");ForgetPriceLevel("DragPendingTP");
   chartLineDragging=false;chartDragKey="";
   SetChartScrollCaptured(false);SetTradeLevelDragCaptured(false);
   panelDirty=true;
}
void CancelChartDrag()
{
   if(!chartLineDragging) return;
   PreviewDraggedPrice(chartDragStartPrice);
   fixedStopMode=chartDragOriginalFixedStop;riskRewardMode=chartDragOriginalRiskReward;
   ClearDragPreview();
}
void FinishChartDrag()
{
   if(!chartLineDragging) return;
   string key=chartDragKey;
   double price=chartDragPrice,initial=chartDragStartPrice;
   bool changed=MathAbs(price-initial)>_Point/2;
   ClearDragPreview();
   if(!changed){fixedStopMode=chartDragOriginalFixedStop;riskRewardMode=chartDragOriginalRiskReward;}
   else if(key=="BE" && breakEvenShown) ApplyBreakEvenStops();
   else if(StringFind(key,"Pending_")==0)
      AdjustBrokerPendingOrder(key,price,initial,chartDragStartSL,chartDragStartTP);
   RenderPanel();
}
void FinishPanelGesture()
{
   if(panelGesture==0) return;
   panelGesture=0;
   SetChartScrollCaptured(false);SetTradeLevelDragCaptured(false);
   suppressPanelClick=true;panelDirty=true;
}
void HandleChartMouseMove(const int x,const int y,const string state)
{
   bool pressed=(((int)StringToInteger(state))&1)!=0;
   bool edge=pressed && !chartLeftPressed;
   chartLeftPressed=pressed;chartHoverAt=GetTickCount64();
   if(edge) suppressPanelClick=false;
   if(panelGesture!=0)
   {
      panelGestureLastEvent=chartHoverAt;
      if(panelGesture==1)
      {
         panelX=panelGestureStartX+x-panelGestureX;
         panelY=panelGestureStartY+y-panelGestureY;
      }
      else panelScale=panelGestureStartScale+(double)(x-panelGestureX)/460;
      RenderPanel();
      if(!pressed) FinishPanelGesture();
      return;
   }
   if(chartLineDragging)
   {
      chartDragLastEvent=chartHoverAt;
      double price=0;
      if(MouseChartPrice(x,y,price))
      {
         price=NormalizeTradePrice(price+chartDragMouseOffset);
         if(price>0 && MathAbs(price-chartDragPrice)>_Point/10) PreviewDraggedPrice(price);
      }
      if(!pressed)
      {
         FinishChartDrag();
         // Keep native trade drag blocked only while the cursor is over our UI.
         // A second drag at the same BE/SL price must not go to the broker level.
         SetTradeLevelDragCaptured(PointOnPanel(x,y) || ChartLevelNearMouse(x,y)!="");
      }
      return;
   }
   if(!pressed)
   {
      SetTradeLevelDragCaptured(PointOnPanel(x,y) || ChartLevelNearMouse(x,y)!="");
      return;
   }
   if(!edge) return;
   if(PanelHit("title",x,y) || PanelHit("resize",x,y))
   {
      panelGesture=PanelHit("resize",x,y)?2:1;
      panelGestureX=x;panelGestureY=y;
      panelGestureStartX=panelX;panelGestureStartY=panelY;
      panelGestureStartScale=panelDrawScale;
      panelGestureLastEvent=chartHoverAt;
      suppressPanelClick=true;
      SetTradeLevelDragCaptured(true);SetChartScrollCaptured(true);ChartRedraw();
      return;
   }
   string candidate=ChartLevelNearMouse(x,y);
   if(candidate=="") return;
   double mouse=0;
   int slot=PriceLevelSlot(candidate);
   if(slot<0 || !MouseChartPrice(x,y,mouse)) return;
   chartDragStartSL=plannedStopLoss;chartDragStartTP=plannedTakeProfit;
   if(StringFind(candidate,"Pending_")==0)
   {
      ulong ticket=(ulong)StringToInteger(StringSubstr(candidate,StringLen("Pending_")));
      if(!IsManagedPendingOrder(ticket)) return;
      if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-priceLevels[slot].price)>_Point/2)
      {panelDirty=true;return;}
      chartDragStartSL=OrderGetDouble(ORDER_SL);chartDragStartTP=OrderGetDouble(ORDER_TP);
   }
   chartDragKey=candidate;chartDragStartPrice=priceLevels[slot].price;
   chartDragPrice=chartDragStartPrice;chartDragMouseOffset=chartDragStartPrice-mouse;
   chartDragOriginalFixedStop=fixedStopMode;chartDragOriginalRiskReward=riskRewardMode;
   chartDragLastEvent=chartHoverAt;chartLineDragging=true;suppressPanelClick=true;
   SetTradeLevelDragCaptured(true);SetChartScrollCaptured(true);ChartRedraw();
}
