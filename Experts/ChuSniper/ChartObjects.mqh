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
