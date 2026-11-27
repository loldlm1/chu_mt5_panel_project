string PanelObjectName(string key){return panelObjectPrefix+key;}

// Cache properties written by the EA; native edit controls retain their input.
struct PanelObjectState
{
   string key,label;
   int x,y,w,h,font;
   bool visible;
   color bg,fg;
};
PanelObjectState panelObjects[];

void ForgetPanelObject(const string key)
{
   for(int i=ArraySize(panelObjects)-1;i>=0;i--)
      if(panelObjects[i].key==key)
      {
         ObjectDelete(0,PanelObjectName(key));
         for(int j=i;j<ArraySize(panelObjects)-1;j++) panelObjects[j]=panelObjects[j+1];
         ArrayResize(panelObjects,ArraySize(panelObjects)-1);
         return;
      }
}
void DrawPanelObjectRaw(string key,ENUM_OBJECT type,int x,int y,int w,int h,string label,color bg,color fg,int font=10,bool visible=true)
{
   string n=PanelObjectName(key);
   int slot=-1;
   for(int i=0;i<ArraySize(panelObjects);i++)
      if(panelObjects[i].key==key){slot=i;break;}
   bool fresh=slot<0;
   if(fresh)
   {
      if(ObjectFind(0,n)<0 && !ObjectCreate(0,n,type,0,0,0)) return;
      slot=ArraySize(panelObjects);ArrayResize(panelObjects,slot+1);
      panelObjects[slot].key=key;
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      if(type!=OBJ_RECTANGLE_LABEL && PanelTheme==PANEL_PANDORA) ObjectSetString(0,n,OBJPROP_FONT,"Trebuchet MS");
      ObjectSetInteger(0,n,OBJPROP_ZORDER,type==OBJ_RECTANGLE_LABEL?10:100);
      ObjectSetInteger(0,n,OBJPROP_BACK,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   }
   if(type!=OBJ_RECTANGLE_LABEL && (fresh || panelObjects[slot].font!=font)) ObjectSetInteger(0,n,OBJPROP_FONTSIZE,font);
   if(fresh || panelObjects[slot].visible!=visible) ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,visible?OBJ_ALL_PERIODS:OBJ_NO_PERIODS);
   if(fresh || panelObjects[slot].x!=x) ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   if(fresh || panelObjects[slot].y!=y) ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   if(fresh || panelObjects[slot].w!=w) ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   if(fresh || panelObjects[slot].h!=h) ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   if(fresh || panelObjects[slot].fg!=fg) ObjectSetInteger(0,n,OBJPROP_COLOR,fg);
   if(fresh || panelObjects[slot].bg!=bg)
   {
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
      ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,bg);
      if(key=="bg") ObjectSetInteger(0,n,OBJPROP_COLOR,PanelBorder());
   }
   if(fresh || (type!=OBJ_EDIT && panelObjects[slot].label!=label)) ObjectSetString(0,n,OBJPROP_TEXT,label);
   panelObjects[slot].x=x;panelObjects[slot].y=y;
   panelObjects[slot].w=w;panelObjects[slot].h=h;
   panelObjects[slot].bg=bg;panelObjects[slot].fg=fg;panelObjects[slot].label=label;
   panelObjects[slot].font=font;panelObjects[slot].visible=visible;
}
bool UpdatePanelCaption(const string key,const string caption)
{
   for(int i=0;i<ArraySize(panelObjects);i++)
   {
      if(panelObjects[i].key!=key || !panelObjects[i].visible) continue;
      if(panelObjects[i].label==caption) return false;
      ObjectSetString(0,PanelObjectName(key),OBJPROP_TEXT,caption);
      panelObjects[i].label=caption;
      return true;
   }
   return false;
}
bool PanelControlVisible(const string key)
{
   for(int i=0;i<ArraySize(panelObjects);i++) if(panelObjects[i].key==key) return panelObjects[i].visible;
   return false;
}
bool PanelHit(const string key,const int x,const int y)
{
   for(int i=0;i<ArraySize(panelObjects);i++)
      if(panelObjects[i].key==key && panelObjects[i].visible)
         return x>=panelObjects[i].x && x<panelObjects[i].x+panelObjects[i].w && y>=panelObjects[i].y && y<panelObjects[i].y+panelObjects[i].h;
   return false;
}
bool PointOnPanel(const int x,const int y)
{
   for(int i=0;i<ArraySize(panelObjects);i++)
      if(panelObjects[i].visible && x>=panelObjects[i].x && x<panelObjects[i].x+panelObjects[i].w &&
         y>=panelObjects[i].y && y<panelObjects[i].y+panelObjects[i].h) return true;
   return false;
}
bool CompactPanelControl(const string key)
{
   return key=="bg" || key=="title" || key=="minimize" || key=="quickBuy" ||
          key=="quickSell" || key=="quickInfo" || key=="status";
}
void DrawPanelObject(string key,ENUM_OBJECT type,int x,int y,int w,int h,string label,color bg,color fg)
{
   bool visible=!panelMinimized || CompactPanelControl(key);
   if(key=="status" && panelMinimized) y=94+CSM_QUICK_EXTRA;
   bool quick=(key=="quickBuy" || key=="quickSell");
   int font=(int)MathMax(6,MathMin(quick?34:22,MathRound((quick?16:10)*panelDrawScale)));
   DrawPanelObjectRaw(key,type,panelX+(int)MathRound(x*panelDrawScale),panelY+(int)MathRound(y*panelDrawScale),
      (int)MathMax(1,MathRound(w*panelDrawScale)),(int)MathMax(1,MathRound(h*panelDrawScale)),
      label,key=="bg"?PanelBackground():PanelAccent(bg),PanelInk(bg,fg),font,visible);
}
void DrawPanelButton(string k,int x,int y,int w,string s,color c=CSM_PANEL_NAVY){DrawPanelObject(k,OBJ_BUTTON,x,y,w,25,s,c,c==highlightColor?clrBlack:textColor);}
// Formatting is presentation-only: the original precise value remains available
// when a formatted field has not been edited.
double ParsePanelNumber(string s)
{
   StringReplace(s,",",".");
   return StringToDouble(s);
}
// StringToDouble alone maps malformed text to zero, which must never opt in
// to an unprotected entry. Accept only a finite, explicit decimal.
bool ParseNonnegativePanelDecimal(string text,double &value)
{
   StringTrimLeft(text);StringTrimRight(text);
   StringReplace(text,",",".");
   bool digit=false,point=false,nonzero=false;
   for(int i=0;i<StringLen(text);i++)
   {
      ushort c=StringGetCharacter(text,i);
      if(c>='0' && c<='9'){digit=true;if(c!='0') nonzero=true;}
      else if(c=='.' && !point) point=true;
      else return false;
   }
   if(!digit) return false;
   value=StringToDouble(text);
   return MathIsValidNumber(value) && value>=0 && value!=EMPTY_VALUE && (!nonzero || value>0);
}
string PanelNumberText(const double value)
{
   if(!MathIsValidNumber(value)) return "--";
   if(value>0 && value<0.005) return "<0.01";
   string text=DoubleToString(value,2);
   while(StringLen(text)>0 && StringSubstr(text,StringLen(text)-1)=="0")
      text=StringSubstr(text,0,StringLen(text)-1);
   if(StringLen(text)>0 && StringSubstr(text,StringLen(text)-1)==".")
      text=StringSubstr(text,0,StringLen(text)-1);
   return text=="-0"?"0":text;
}
string PanelInputRaw(const string key)
{
   if(key=="riskval") return savedRiskText;
   if(key=="points") return savedPointsText;
   if(key=="ratio") return savedRatioText;
   if(key=="amount") return savedAmountText;
   return "";
}
void RememberPanelInput(const string key,const string raw)
{
   if(key=="riskval") savedRiskText=raw;
   if(key=="points") savedPointsText=raw;
   if(key=="ratio") savedRatioText=raw;
   if(key=="amount") savedAmountText=raw;
}
void SetPanelPrecisionHint(const string key,const double value)
{
   string caption=PanelNumberText(value);
   string hint="\n";
   if(caption=="<0.01" || MathAbs(value-ParsePanelNumber(caption))>1e-10)
      hint="Valor exacto: "+DoubleToString(value,16);
   ObjectSetString(0,PanelObjectName(key),OBJPROP_TOOLTIP,hint);
}
void DrawPanelInput(string k,int x,int y,int w,string s)
{
   bool fresh=true;
   for(int i=0;i<ArraySize(panelObjects);i++) if(panelObjects[i].key==k){fresh=false;break;}
   double value=ParsePanelNumber(s);
   DrawPanelObject(k,OBJ_EDIT,x,y,w,25,PanelNumberText(value),CSM_PANEL_NAVY,textColor);
   if(fresh) SetPanelPrecisionHint(k,value);
}
string PanelInputText(string k){return ObjectGetString(0,PanelObjectName(k),OBJPROP_TEXT);}
bool ReadPanelDecimal(const string key,double &value)
{
   string caption=PanelInputText(key),raw=PanelInputRaw(key);
   double precise=0;
   if(raw!="" && ParseNonnegativePanelDecimal(raw,precise) && caption==PanelNumberText(precise))
   {value=precise;return true;}
   return ParseNonnegativePanelDecimal(caption,value);
}
double PanelInputNumber(string k)
{
   string text=PanelInputText(k),raw=PanelInputRaw(k);
   double precise=ParsePanelNumber(raw);
   if(raw!="" && text==PanelNumberText(precise)) return precise;
   return ParsePanelNumber(text);
}
void SetPanelInputText(string k,string s)
{
   double value=ParsePanelNumber(s);
   string caption=PanelNumberText(value);
   bool preciseChanged=(PanelInputRaw(k)!=s);
   RememberPanelInput(k,s);
   if(PanelInputText(k)!=caption) ObjectSetString(0,PanelObjectName(k),OBJPROP_TEXT,caption);
   if(preciseChanged) SetPanelPrecisionHint(k,value);
}

struct PriceLevelState
{
   string key;
   double price;
   color shade;
   bool draggable;
};
PriceLevelState priceLevels[];
int PriceLevelSlot(const string key)
{
   for(int i=0;i<ArraySize(priceLevels);i++) if(priceLevels[i].key==key) return i;
   return -1;
}
void ForgetPriceLevel(const string key)
{
   int slot=PriceLevelSlot(key);
   if(slot<0) return;
   ObjectDelete(0,PanelObjectName(key));
   for(int i=slot;i<ArraySize(priceLevels)-1;i++) priceLevels[i]=priceLevels[i+1];
   ArrayResize(priceLevels,ArraySize(priceLevels)-1);
}
void SetPriceLevel(const string key,const double price)
{
   int slot=PriceLevelSlot(key);
   if(slot<0) return;
   if(MathAbs(priceLevels[slot].price-price)<=_Point/10) return;
   priceLevels[slot].price=price;
   ObjectSetDouble(0,PanelObjectName(key),OBJPROP_PRICE,price);
}
void DrawPriceLevel(string key,double price,color shade,bool draggable)
{
   int slot=PriceLevelSlot(key);
   string object=PanelObjectName(key);
   if(slot<0)
   {
      if(ObjectFind(0,object)<0 && !ObjectCreate(0,object,OBJ_HLINE,0,0,price)) return;
      slot=ArraySize(priceLevels);ArrayResize(priceLevels,slot+1);
      priceLevels[slot].key=key;priceLevels[slot].price=price;
      priceLevels[slot].shade=shade;
      ObjectSetDouble(0,object,OBJPROP_PRICE,price);
      ObjectSetInteger(0,object,OBJPROP_COLOR,shade);
      ObjectSetInteger(0,object,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,object,OBJPROP_WIDTH,3);
      // EA levels are handled exclusively by the mouse state machine.
      ObjectSetInteger(0,object,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,object,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,object,OBJPROP_ZORDER,1);
      ObjectSetString(0,object,OBJPROP_TOOLTIP,key);
   }
   priceLevels[slot].draggable=draggable;
   if(priceLevels[slot].shade!=shade)
   {
      ObjectSetInteger(0,object,OBJPROP_COLOR,shade);
      priceLevels[slot].shade=shade;
   }
   if(!chartLineDragging || chartDragKey!=key) SetPriceLevel(key,price);
}
