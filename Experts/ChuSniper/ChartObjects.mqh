string PanelObjectName(string key){return panelObjectPrefix+key;}
void DrawPanelObject(string key,ENUM_OBJECT type,int x,int y,int w,int h,string label,color bg,color fg)
{
   string n=PanelObjectName(key);
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
void DrawPanelButton(string k,int x,int y,int w,string s,color c=CSM_PANEL_NAVY){DrawPanelObject(k,OBJ_BUTTON,x,y,w,25,s,c,c==highlightColor?clrBlack:textColor);}
void DrawPanelInput(string k,int x,int y,int w,string s){DrawPanelObject(k,OBJ_EDIT,x,y,w,25,s,CSM_PANEL_NAVY,textColor);}
string PanelInputText(string k){return ObjectGetString(0,PanelObjectName(k),OBJPROP_TEXT);}
double PanelInputNumber(string k){string s=PanelInputText(k);StringReplace(s,",",".");return StringToDouble(s);}
void SetPanelInputText(string k,string s){ObjectSetString(0,PanelObjectName(k),OBJPROP_TEXT,s);}
void DrawPriceLevel(string k,double p,color c,bool drag)
{
   string n=PanelObjectName(k);
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_HLINE,0,0,p);
   // Do not snap an actively dragged level back to its previous timer price.
   if(!chartLineDragging || chartDragKey!=k) ObjectSetDouble(0,n,OBJPROP_PRICE,p);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,3);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,drag);
   if(drag && !chartLineDragging) ObjectSetInteger(0,n,OBJPROP_SELECTED,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,8);
   ObjectSetString(0,n,OBJPROP_TOOLTIP,k);
}
