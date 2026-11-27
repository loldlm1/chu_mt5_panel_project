// Reserve a readable fallback row for each overlay on crowded charts.
int PanelBaseHeight(){return (panelMinimized?126:417)+CSM_QUICK_EXTRA+(breakEvenShown?29:0)+(takeProfitShown?29:0);}
void ClampPanelGeometry()
{
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   panelScale=MathMax(0.65,MathMin(2.0,panelScale));
   panelDrawScale=panelScale;
   if(cw>0 && ch>0)
      panelDrawScale=MathMax(0.01,MathMin(panelScale,MathMin((double)cw/460,(double)ch/PanelBaseHeight())));
   panelX=(int)MathMax(0,MathMin(panelX,cw>0?MathMax(0,cw-460*panelDrawScale):panelX));
   panelY=(int)MathMax(0,MathMin(panelY,ch>0?MathMax(0,ch-PanelBaseHeight()*panelDrawScale):panelY));
}
string QuickQuoteCaption(const bool buy,const MqlTick &quote,const bool available)
{
   string side=buy?"BUY":"SELL";
   return side+"  "+(available?PanelNumberText(buy?quote.ask:quote.bid):"--");
}
// Quote-only update: no position/history queries or full layout on every tick.
void RefreshQuickQuotes()
{
   ulong now=GetTickCount64();
   if(chartLineDragging || panelGesture!=0 || now-lastQuickQuoteRefresh<100) return;
   lastQuickQuoteRefresh=now;
   MqlTick quote;
   bool available=SymbolInfoTick(_Symbol,quote) && quote.bid>0 && quote.ask>=quote.bid;
   bool sellChanged=UpdatePanelCaption("quickSell",QuickQuoteCaption(false,quote,available));
   bool buyChanged=UpdatePanelCaption("quickBuy",QuickQuoteCaption(true,quote,available));
   if(sellChanged || buyChanged) ChartRedraw();
}
// Prefer the v0.16 chart-side caption immediately above the price line.
// If space is constrained, the dedicated panel fallback keeps each drag handle accessible.
struct ProjectionRect {int x,y,w,h;};
bool ProjectionRectsOverlap(const ProjectionRect &a,const ProjectionRect &b)
{
   return a.x<b.x+b.w && a.x+a.w>b.x && a.y<b.y+b.h && a.y+a.h>b.y;
}
void ProjectionFallback(const bool isTP,ProjectionRect &r)
{
   int y=(panelMinimized?123:413)+CSM_QUICK_EXTRA+(isTP && breakEvenShown?29:0);
   r.x=panelX+(int)MathRound(8*panelDrawScale);
   r.y=panelY+(int)MathRound(y*panelDrawScale);
   r.w=(int)MathMax(1,MathRound(444*panelDrawScale));
   r.h=(int)MathMax(1,MathRound(25*panelDrawScale));
}
bool PlaceChartProjection(const double level,const int cw,const int ch,const ProjectionRect &panel,
                          const ProjectionRect &other,const bool avoidOther,ProjectionRect &r)
{
   int px=0,py=0;
   if(cw<=0 || ch<25 || !ChartTimePriceToXY(0,0,iTime(_Symbol,_Period,0),level,px,py) ||
      py<0 || py>=ch) return false;
   r.w=(int)MathMin(405,cw);r.h=25;
   int right=panel.x+panel.w+8,left=panel.x-r.w-8;
   int xs[3];xs[0]=right;xs[1]=left;xs[2]=(int)MathMax(0,MathMin(panel.x,cw-r.w));
   // Search above first, then a nearby lower slot; only accept a fully visible
   // rectangle that touches neither the panel nor the other caption.
   for(int step=0;step<5;step++)
   {
      int ys[2];ys[0]=py-27-step*29;ys[1]=py+4+step*29;
      for(int j=0;j<2;j++)
         for(int k=0;k<3;k++)
         {
            r.x=xs[k];r.y=ys[j];
            if(r.x<0 || r.y<0 || r.x+r.w>cw || r.y+r.h>ch) continue;
            if(ProjectionRectsOverlap(r,panel) || (avoidOther && ProjectionRectsOverlap(r,other))) continue;
            return true;
         }
   }
   return false;
}
void ManagementProjectionRects(ProjectionRect &be,ProjectionRect &tp)
{
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   ProjectionRect panel;
   panel.x=panelX;panel.y=panelY;panel.w=(int)MathRound(460*panelDrawScale);
   panel.h=(int)MathRound(PanelBaseHeight()*panelDrawScale);
   ProjectionFallback(false,be);ProjectionFallback(true,tp);
   ProjectionRect candidate;
   if(breakEvenShown && PlaceChartProjection(breakEvenPrice,cw,ch,panel,tp,false,candidate)) be=candidate;
   if(takeProfitShown && PlaceChartProjection(takeProfitPrice,cw,ch,panel,be,breakEvenShown,candidate)) tp=candidate;
}
// Clicking and dragging a caption selects its own projection, even at equal prices.
void RenderManagementProjection(PositionRow &rows[],const bool isTP,const double floating)
{
   int direction=isTP?takeProfitSide:breakEvenSide;
   double level=isTP?takeProfitPrice:breakEvenPrice;
   string tag=isTP?"TP":"BE",side=direction>0?"BUY":"SELL";
   double at=ArraySize(rows)>0?ProfitAtPriceLevel(rows,level,direction,isTP):EMPTY_VALUE;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   string preview=at==EMPTY_VALUE?tag+" "+side+": estimacion no disponible":
      StringFormat("%s %s proy. %+.2f %s (%+.2f%%) | Retroceso %.2f",tag,side,at,
                   AccountInfoString(ACCOUNT_CURRENCY),bal>0?at*100/bal:0,MathMax(0,floating-at));
   ProjectionRect be,tp,r;
   ManagementProjectionRects(be,tp);
   if(isTP) r=tp;else r=be;
   color ink=at==EMPTY_VALUE||MathAbs(at)<0.005?clrSilver:at>0?(isTP?infoColor:highlightColor):sellColor;
   string key=isTP?"tpinfo":"beinfo";
   DrawPanelObjectRaw(key,OBJ_BUTTON,r.x,r.y,r.w,r.h,preview,PanelAccent(CSM_PANEL_NAVY),ink,
      (int)MathMax(6,MathMin(10,MathRound(r.h*0.4))));
   ObjectSetInteger(0,PanelObjectName(key),OBJPROP_STATE,false);
}
void RefreshManagementProjectionDuringDrag(const bool force=false)
{
   if(!chartLineDragging) return;
   bool isTP=chartDragKey=="ManagedTP";
   if(isTP?!takeProfitShown:(chartDragKey!="BE" || !breakEvenShown)) return;
   ulong now=GetTickCount64(),last=isTP?lastTPProjectionRefresh:lastBEProjectionRefresh;
   if(!force && now-last<100) return;
   if(isTP) lastTPProjectionRefresh=now;else lastBEProjectionRefresh=now;
   PositionRow rows[];
   int count=CollectManagedPositionsForSide(rows,isTP?takeProfitSide:breakEvenSide,true);
   double floating=0;
   for(int i=0;i<count;i++) floating+=rows[i].floatPL;
   RenderManagementProjection(rows,isTP,floating);
   if(breakEvenShown && takeProfitShown)
   {
      if(breakEvenSide==takeProfitSide) RenderManagementProjection(rows,!isTP,floating);
      else
      {
         PositionRow otherRows[];
         int otherCount=CollectManagedPositionsForSide(otherRows,isTP?breakEvenSide:takeProfitSide,true);
         double otherFloating=0;
         for(int i=0;i<otherCount;i++) otherFloating+=otherRows[i].floatPL;
         RenderManagementProjection(otherRows,!isTP,otherFloating);
      }
   }
   ChartRedraw();
}
void RenderPanel()
{
   ClampPanelGeometry();
   int x=8,y=7;
   DrawPanelObject("bg",OBJ_RECTANGLE_LABEL,0,0,460,PanelBaseHeight(),"",PanelBackground(),PanelBorder());
   DrawPanelButton("title",x,y,407,"Chu Sniper Manager | v0.17.0 | "+AccountModeCaption()+(SupportedTradingAccount()?"":" (solo vista)"));
   DrawPanelButton("minimize",x+412,y,32,panelMinimized?"+":"-");
   y+=29;
   MqlTick quickQuote;
   bool hasQuote=SymbolInfoTick(_Symbol,quickQuote) && quickQuote.bid>0 && quickQuote.ask>=quickQuote.bid;
   DrawPanelObject("quickSell",OBJ_BUTTON,x,y,219,CSM_QUICK_HEIGHT,QuickQuoteCaption(false,quickQuote,hasQuote),sellColor,textColor);
   DrawPanelObject("quickBuy",OBJ_BUTTON,x+225,y,219,CSM_QUICK_HEIGHT,QuickQuoteCaption(true,quickQuote,hasQuote),buyColor,textColor);
   y+=CSM_QUICK_HEIGHT+4;
   // Draw inputs before the quick summary, even if hidden in compact mode.
   DrawPanelInput("riskval",x+319,123+CSM_QUICK_EXTRA,125,savedRiskText);
   DrawPanelInput("points",x+110,152+CSM_QUICK_EXTRA,77,savedPointsText);
   DrawPanelInput("ratio",x+347,152+CSM_QUICK_EXTRA,97,savedRatioText);
   DrawPanelInput("amount",x+334,297+CSM_QUICK_EXTRA,110,savedAmountText);
   string riskCaption=riskMode==0?"% cuenta":riskMode==1?AccountInfoString(ACCOUNT_CURRENCY):"lotes";
   string quickInfo=stopDistancePoints==0?
      StringFormat("SIN SL | riesgo no limitado | lote %s %s",riskMode==2?"fijo":"min.",
                   PanelNumberText(riskMode==2?PanelInputNumber("riskval"):SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))):
      StringFormat("Rapido: %s %s | SL %s pts | R:B %s",PanelNumberText(PanelInputNumber("riskval")),riskCaption,PanelNumberText(stopDistancePoints),PanelNumberText(rewardRiskRatio));
   DrawPanelButton("quickInfo",x,y,444,quickInfo,stopDistancePoints==0?highlightColor:CSM_PANEL_NAVY);
   y+=29;
   // Direction is retained when the draft is canceled. Active drafts use side ink.
   DrawPanelButton("buy",x,y,105,tradeSide>0?(orderPrepared?"X Comprar":"Comprar *"):"Comprar",
                   tradeSide>0?(orderPrepared?buyColor:highlightColor):CSM_PANEL_NAVY);
   DrawPanelButton("sell",x+110,y,105,tradeSide<0?(orderPrepared?"X Vender":"Vender *"):"Vender",
                   tradeSide<0?(orderPrepared?sellColor:highlightColor):CSM_PANEL_NAVY);
   DrawPanelButton("scope",x+220,y,110,groupMode?"Grupo":"Individual",highlightColor);
   DrawPanelButton("mode",x+335,y,109,pendingOrderMode?"Pendiente":"Mercado",highlightColor);
   y+=29;
   DrawPanelButton("percent",x,y,103,"% cuenta",riskMode==0?highlightColor:CSM_PANEL_NAVY);
   DrawPanelButton("money",x+107,y,102,"Dinero",riskMode==1?highlightColor:CSM_PANEL_NAVY);
   DrawPanelButton("lot",x+213,y,102,"Lote fijo",riskMode==2?highlightColor:CSM_PANEL_NAVY);
   // riskval is drawn above.
   y+=29;
   DrawPanelButton("stoplabel",x,y,105,"Stop (puntos)");
   // points is drawn above.
   DrawPanelButton("tpMode",x+192,y,149,riskRewardMode?"Take profit R:B":"Take profit Manual",highlightColor);
   // ratio is drawn above.
   y+=29;
   MqlTick q;
   ENUM_ORDER_TYPE type=SelectedOrderDirection();
   double lot=0,loss=0;
   bool valid=orderPrepared && SymbolInfoTick(_Symbol,q) && BuildOrderPlan(q,type,lot,loss);
   if(!orderPrepared)
   {
      ForgetPriceLevel("Entrada");
      ForgetPriceLevel("Stop loss");
      ForgetPriceLevel("Take profit");
   }
   if(orderPrepared)
   {
      if(pendingOrderMode) DrawPriceLevel("Entrada",csmPlannedEntry,buyColor,true);
      else ForgetPriceLevel("Entrada");
      if(plannedStopLoss>0) DrawPriceLevel("Stop loss",plannedStopLoss,sellColor,true);
      else ForgetPriceLevel("Stop loss");
      if(plannedTakeProfit>0) DrawPriceLevel("Take profit",plannedTakeProfit,infoColor,true);
      else ForgetPriceLevel("Take profit");
      // The input remains the requested distance; the preview shows the effective SL.
      // Rendering does not change the operator's settings.
   }
   string draftCaption=valid?(stopDistancePoints==0?
      StringFormat("SIN SL | lote %s | riesgo no limitado",PanelNumberText(lot)):
      StringFormat("Lote %s | SL %s pts | Riesgo %.2f %s",PanelNumberText(lot),PanelNumberText(MathAbs(csmPlannedEntry-plannedStopLoss)/_Point),loss,AccountInfoString(ACCOUNT_CURRENCY))):
      (orderPrepared?(stopDistancePoints==0?"SIN SL | lote/niveles invalidos":"Niveles/riesgo invalidos; revisa o confirma ajuste"):"Prepara la orden y ajusta los niveles");
   DrawPanelButton("preview",x,y,444,draftCaption,orderPrepared && stopDistancePoints==0?highlightColor:CSM_PANEL_NAVY);
   y+=29;
   DrawPanelButton("send",x,y,444,orderPrepared?"Confirmar "+OrderTypeCaption(type):"Confirmar orden",valid?buyColor:CSM_PANEL_NAVY);
   y+=29;
   string trailCaption=trailingMode?StringFormat("Trailing 1R | sin SL %d | desconocido %d",trailingNoSL,trailingUnknown):"Trailing: Apagado";
   DrawPanelButton("trail",x,y,444,trailCaption,trailingMode?highlightColor:CSM_PANEL_NAVY);
   y+=29;
   PositionRow rows[];
   int count=CollectManagedPositions(rows,true);
   double floating=0;
   for(int i=0;i<count;i++) floating+=rows[i].floatPL;
   DrawPanelButton("scopeinfo",x,y,444,StringFormat("%s %s | %d posiciones | Flotante %+.2f",_Symbol,tradeSide>0?"Compras":"Ventas",count,floating));
   y+=29;
   DrawPanelButton("be",x,y,108,breakEvenShown?"BE "+BESideCaption():"Break-even",highlightColor);
   DrawPanelButton("apply",x+112,y,106,"Aplicar BE",breakEvenShown?highlightColor:CSM_PANEL_NAVY);
   DrawPanelButton("units",x+222,y,108,percentTargetMode?"% flotante":"Dinero",highlightColor);
   // amount is drawn above.
   y+=29;
   DrawPanelButton("tp",x,y,218,takeProfitShown?"TP "+TPSideCaption():"Take profit",takeProfitShown?clrDeepSkyBlue:CSM_PANEL_NAVY);
   DrawPanelButton("applyTP",x+222,y,222,"Aplicar TP",takeProfitShown?clrDeepSkyBlue:CSM_PANEL_NAVY);
   y+=29;
   DrawPanelButton("realize",x,y,218,"Realizar ganancia",infoColor);
   DrawPanelButton("close",x+222,y,222,closeConfirmationDeadline>GetTickCount64()?"Confirmar cerrar todo":"Cerrar todo",sellColor);
   y+=29;
   DrawPanelButton("status",x,y,panelMinimized?444:415,csmPanelStatus);
   DrawPanelButton("resize",428,y,24,"//");
   PositionRow beRows[],tpRows[];
   int beCount=0,tpCount=0;
   if(breakEvenShown)
   {
      if(breakEvenSide==tradeSide){ArrayCopy(beRows,rows);beCount=count;}
      else beCount=CollectManagedPositionsForSide(beRows,breakEvenSide,true);
      if(beCount==0) breakEvenShown=false;
   }
   if(takeProfitShown)
   {
      if(breakEvenShown && takeProfitSide==breakEvenSide){ArrayCopy(tpRows,beRows);tpCount=beCount;}
      else if(takeProfitSide==tradeSide){ArrayCopy(tpRows,rows);tpCount=count;}
      else tpCount=CollectManagedPositionsForSide(tpRows,takeProfitSide,true);
      if(tpCount==0) takeProfitShown=false;
   }
   if(breakEvenShown)
   {
      double beFloating=0;
      for(int i=0;i<beCount;i++) beFloating+=beRows[i].floatPL;
      bool fresh=PriceLevelSlot("BE")<0;
      DrawPriceLevel("BE",breakEvenPrice,highlightColor,true);
      if(fresh) ObjectSetString(0,PanelObjectName("BE"),OBJPROP_TOOLTIP,"BE "+BESideCaption()+" proyectado; arrastra linea o resumen");
      RenderManagementProjection(beRows,false,beFloating);
   }
   else {ForgetPriceLevel("BE");ForgetPanelObject("beinfo");}
   if(takeProfitShown)
   {
      double tpFloating=0;
      for(int i=0;i<tpCount;i++) tpFloating+=tpRows[i].floatPL;
      bool fresh=PriceLevelSlot("ManagedTP")<0;
      DrawPriceLevel("ManagedTP",takeProfitPrice,infoColor,true);
      if(fresh)
      {
         ObjectSetString(0,PanelObjectName("ManagedTP"),OBJPROP_TOOLTIP,"TP "+TPSideCaption()+" proyectado; arrastra linea o resumen");
         ObjectSetInteger(0,PanelObjectName("ManagedTP"),OBJPROP_WIDTH,3);
         ObjectSetInteger(0,PanelObjectName("ManagedTP"),OBJPROP_STYLE,STYLE_SOLID);
      }
      RenderManagementProjection(tpRows,true,tpFloating);
   }
   else {ForgetPriceLevel("ManagedTP");ForgetPanelObject("tpinfo");}
   RenderBrokerPendingLines();
   lastPanelRefresh=GetTickCount64();panelDirty=false;
   ChartRedraw();
}
