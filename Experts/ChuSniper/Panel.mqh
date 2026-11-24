// The resize grip shares the status row; reserve another row only for BE info.
int PanelBaseHeight(){return (panelMinimized?126:388)+CSM_QUICK_EXTRA+(breakEvenShown?29:0);}
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
void RenderPanel()
{
   ClampPanelGeometry();
   int x=8,y=7;
   DrawPanelObject("bg",OBJ_RECTANGLE_LABEL,0,0,460,PanelBaseHeight(),"",PanelBackground(),PanelBorder());
   DrawPanelButton("title",x,y,407,"Chu Sniper Manager | v0.14.0 | DEMO");
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
   DrawPanelButton("quickInfo",x,y,444,StringFormat("Rapido: %s %s | SL %s pts | R:B %s",PanelNumberText(PanelInputNumber("riskval")),riskCaption,PanelNumberText(stopDistancePoints),PanelNumberText(rewardRiskRatio)));
   y+=29;
   DrawPanelButton("buy",x,y,105,"Comprar",tradeSide>0?buyColor:CSM_PANEL_NAVY);
   DrawPanelButton("sell",x+110,y,105,"Vender",tradeSide<0?sellColor:CSM_PANEL_NAVY);
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
      DrawPriceLevel("Stop loss",plannedStopLoss,sellColor,true);
      DrawPriceLevel("Take profit",plannedTakeProfit,infoColor,true);
      // The input remains the requested distance; the preview shows the effective SL.
      // Rendering does not change the operator's settings.
   }
   DrawPanelButton("preview",x,y,444,valid?StringFormat("Lote %s | SL %s pts | Riesgo %.2f %s",PanelNumberText(lot),PanelNumberText(MathAbs(csmPlannedEntry-plannedStopLoss)/_Point),loss,AccountInfoString(ACCOUNT_CURRENCY)):(orderPrepared?"Niveles/riesgo invalidos; revisa o confirma ajuste":"Prepara la orden y ajusta los niveles"));
   y+=29;
   DrawPanelButton("send",x,y,444,orderPrepared?"Confirmar "+OrderTypeCaption(type):"Confirmar orden",valid?buyColor:CSM_PANEL_NAVY);
   y+=29;
   string trailModes[]={"Apagado","Simple"};
   DrawPanelButton("trail",x,y,444,"Trailing: "+trailModes[trailingMode],trailingMode?highlightColor:CSM_PANEL_NAVY);
   y+=29;
   PositionRow rows[];
   int count=CollectManagedPositions(rows,true);
   double floating=0;
   for(int i=0;i<count;i++) floating+=rows[i].floatPL;
   double at=breakEvenShown?ProfitAtPriceLevel(rows,breakEvenPrice):0,bal=AccountInfoDouble(ACCOUNT_BALANCE);
   DrawPanelButton("scopeinfo",x,y,444,StringFormat("%s %s | %d posiciones | Flotante %+.2f",_Symbol,tradeSide>0?"Compras":"Ventas",count,floating));
   y+=29;
   DrawPanelButton("be",x,y,108,"Break-even",highlightColor);
   DrawPanelButton("apply",x+112,y,106,"Aplicar nivel",breakEvenShown?highlightColor:CSM_PANEL_NAVY);
   DrawPanelButton("units",x+222,y,108,percentTargetMode?"% flotante":"Dinero",highlightColor);
   // amount is drawn above.
   y+=29;
   DrawPanelButton("realize",x,y,218,"Realizar ganancia",infoColor);
   DrawPanelButton("close",x+222,y,222,closeConfirmationDeadline>GetTickCount64()?"Confirmar cerrar todo":"Cerrar todo",sellColor);
   y+=29;
   DrawPanelButton("status",x,y,panelMinimized?444:415,csmPanelStatus);
   DrawPanelButton("resize",428,y,24,"//");
   if(breakEvenShown && count>0)
   {
      DrawPriceLevel("BE",breakEvenPrice,highlightColor,true);
      string preview=at==EMPTY_VALUE?"Cierre estimado no disponible":StringFormat("Cierre aprox. %+.2f %s (%+.2f%%) | Retroceso %.2f",at,AccountInfoString(ACCOUNT_CURRENCY),bal>0?at*100/bal:0,MathMax(0,floating-at));
      int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
      int bw=(int)MathMin(405,MathMax(1,cw));
      int bx=(int)MathMin(MathMax(0,cw-bw),panelX+460*panelDrawScale+8),by=panelY;
      int py=0,px=0;
      if(ChartTimePriceToXY(0,0,iTime(_Symbol,_Period,0),breakEvenPrice,px,py)) by=MathMax(0,py-27);
      if(cw<panelX+460*panelDrawScale+bw+8)
      {
         bx=(int)MathMax(0,MathMin(panelX,cw-bw));
         by=panelY+(int)MathRound(PanelBaseHeight()*panelDrawScale)+4;
         if(by+25>ch) by=MathMax(0,panelY-29);
      }
      bool visible=by+25<=ch && (bx>=panelX+460*panelDrawScale || bx+bw<=panelX ||
                    by>=panelY+PanelBaseHeight()*panelDrawScale || by+25<=panelY);
      color ink=at==EMPTY_VALUE||MathAbs(at)<0.005?clrSilver:at>0?infoColor:sellColor;
      if(visible)
         DrawPanelObjectRaw("beinfo",OBJ_BUTTON,bx,by,bw,25,preview,PanelAccent(CSM_PANEL_NAVY),ink);
      else
         DrawPanelObjectRaw("beinfo",OBJ_BUTTON,panelX+(int)MathRound(8*panelDrawScale),
            panelY+(int)MathRound((panelMinimized?123+CSM_QUICK_EXTRA:y+29)*panelDrawScale),
            (int)MathMax(1,MathRound(444*panelDrawScale)),
            (int)MathMax(1,MathRound(25*panelDrawScale)),preview,PanelAccent(CSM_PANEL_NAVY),ink,
            (int)MathMax(6,MathRound(10*panelDrawScale)));
   }
   else {ForgetPriceLevel("BE");ForgetPanelObject("beinfo");if(count==0) breakEvenShown=false;}
   RenderBrokerPendingLines();
   lastPanelRefresh=GetTickCount64();panelDirty=false;
   ChartRedraw();
}
