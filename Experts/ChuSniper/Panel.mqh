void RenderPanel()
{
   int x=12,y=20,w=460;
   DrawPanelObject("bg",OBJ_RECTANGLE_LABEL,x,y,w,343,"",C'10,17,26',textColor);
   x+=8;y+=7;
   DrawPanelButton("title",x,y,444,"Chu Sniper Manager  |  MT5  |  DEMO");
   y+=29;
   DrawPanelButton("buy",x,y,105,"Comprar",tradeSide>0?buyColor:CSM_PANEL_NAVY);
   DrawPanelButton("sell",x+110,y,105,"Vender",tradeSide<0?sellColor:CSM_PANEL_NAVY);
   DrawPanelButton("scope",x+220,y,110,groupMode?"Grupo":"Individual",highlightColor);
   DrawPanelButton("mode",x+335,y,109,pendingOrderMode?"Pendiente":"Mercado",highlightColor);
   y+=29;
   DrawPanelButton("percent",x,y,103,"% cuenta",riskMode==0?highlightColor:CSM_PANEL_NAVY);
   DrawPanelButton("money",x+107,y,102,"Dinero",riskMode==1?highlightColor:CSM_PANEL_NAVY);
   DrawPanelButton("lot",x+213,y,102,"Lote fijo",riskMode==2?highlightColor:CSM_PANEL_NAVY);
   DrawPanelInput("riskval",x+319,y,125,"200");
   y+=29;
   DrawPanelButton("stoplabel",x,y,105,"Stop (puntos)");
   DrawPanelInput("points",x+110,y,77,"250");
   DrawPanelButton("tpMode",x+192,y,149,riskRewardMode?"Take profit R:B":"Take profit Manual",highlightColor);
   DrawPanelInput("ratio",x+347,y,97,"2");
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
      // The displayed points are derived from the locked absolute price.
      // Never overwrite a user editing the distance input.
      if(!editingStopPoints)
      {
         string points=DoubleToString(MathAbs(csmPlannedEntry-plannedStopLoss)/_Point,1);
         if(PanelInputText("points")!=points) SetPanelInputText("points",points);
      }
   }
   DrawPanelButton("preview",x,y,444,valid?StringFormat("Lote %.4f  |  Riesgo estimado %.2f %s",lot,loss,AccountInfoString(ACCOUNT_CURRENCY)):"Prepara la orden y ajusta los niveles");
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
   DrawPanelInput("amount",x+334,y,110,"100");
   y+=29;
   DrawPanelButton("realize",x,y,218,"Realizar ganancia",infoColor);
   DrawPanelButton("close",x+222,y,222,closeConfirmationDeadline>GetTickCount64()?"Confirmar cerrar todo":"Cerrar todo",sellColor);
   y+=29;
   DrawPanelButton("status",x,y,444,csmPanelStatus);
   if(breakEvenShown && count>0)
   {
      DrawPriceLevel("BE",breakEvenPrice,highlightColor,true);
      string preview=at==EMPTY_VALUE?"Cierre estimado no disponible":StringFormat("Cierre aprox. %+.2f %s (%+.2f%%) | Retroceso %.2f",at,AccountInfoString(ACCOUNT_CURRENCY),bal>0?at*100/bal:0,MathMax(0,floating-at));
      int bx=484,by=y;
      int py=0,px=0;
      if(ChartTimePriceToXY(0,0,iTime(_Symbol,_Period,0),breakEvenPrice,px,py)) by=MathMax(0,py-27);
      if(ChartGetInteger(0,CHART_WIDTH_IN_PIXELS)<900){bx=x;by=y+28;}
      DrawPanelObject("beinfo",OBJ_BUTTON,bx,by,405,25,preview,CSM_PANEL_NAVY,at==EMPTY_VALUE||MathAbs(at)<0.005?clrSilver:at>0?infoColor:sellColor);
   }
   else {ForgetPriceLevel("BE");ForgetPanelObject("beinfo");if(count==0) breakEvenShown=false;}
   RenderBrokerPendingLines();
   lastPanelRefresh=GetTickCount64();panelDirty=false;
   ChartRedraw();
}
