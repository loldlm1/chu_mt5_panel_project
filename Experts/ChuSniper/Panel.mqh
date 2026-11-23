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
