// A hidden chart-profile marker survives the EA's volatile CSM_ object cleanup.
// Scope includes the account, server, symbol, magic and chart instance; never TF.
string PanelPersistenceIdentity()
{
   string marker="ChuSniper_StateIdentity";
   string identity="";
   if(ObjectFind(0,marker)>=0) identity=ObjectGetString(0,marker,OBJPROP_TEXT);
   if(identity=="")
   {
      identity=StringFormat("%I64d_%I64u",ChartID(),GetMicrosecondCount());
      if(ObjectFind(0,marker)<0 && !ObjectCreate(0,marker,OBJ_LABEL,0,0,0)) return "";
      ObjectSetString(0,marker,OBJPROP_TEXT,identity);
      ObjectSetInteger(0,marker,OBJPROP_TIMEFRAMES,OBJ_NO_PERIODS);
      ObjectSetInteger(0,marker,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,marker,OBJPROP_SELECTABLE,false);
   }
   // Never use arbitrary object text as a path.
   for(int i=0;i<StringLen(identity);i++)
   {
      ushort c=StringGetCharacter(identity,i);
      if((c<'0' || c>'9') && c!='_' && c!='-') return "";
   }
   if(StringLen(identity)>64) return "";
   // A copied template must not share the state file with another open chart.
   for(long chart=ChartFirst();chart>=0;chart=ChartNext(chart))
   {
      if(chart==ChartID() || ObjectFind(chart,marker)<0) continue;
      if(ObjectGetString(chart,marker,OBJPROP_TEXT)!=identity) continue;
      identity=StringFormat("%I64d_%I64u",ChartID(),GetMicrosecondCount());
      ObjectSetString(0,marker,OBJPROP_TEXT,identity);
      break;
   }
   string scope=AccountInfoString(ACCOUNT_SERVER)+"|"+_Symbol;
   uint hash=2166136261;
   for(int i=0;i<StringLen(scope);i++) hash=(hash^(uint)StringGetCharacter(scope,i))*16777619;
   return StringFormat("CSM_state_%I64d_%I64u_%u_%s.txt",AccountInfoInteger(ACCOUNT_LOGIN),Magic,hash,identity);
}
bool ValidStateNumber(const double v){return MathIsValidNumber(v) && v>=0;}
string StateNumber(const double v){return DoubleToString(v,16);}
bool OwnedTrailingTicket(const ulong ticket)
{
   return ticket>0 && PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL)==_Symbol &&
          (IncludeOtherPositions || PositionGetInteger(POSITION_MAGIC)==(long)Magic);
}
string CurrentPanelScope()
{
   return StringFormat("%I64d|%I64u|%s|%s",AccountInfoInteger(ACCOUNT_LOGIN),Magic,
                       AccountInfoString(ACCOUNT_SERVER),_Symbol);
}
void CapturePanelInputs()
{
   // Same-scope reinit retains validated configuration even when disk is unavailable.
   savedRiskText=DoubleToString(PanelInputNumber("riskval"),16);
   savedAmountText=DoubleToString(PanelInputNumber("amount"),16);
   savedPointsText=DoubleToString(stopDistancePoints,16);
   savedRatioText=DoubleToString(rewardRiskRatio,16);
}
void ResetPanelOperationalState()
{
   tradeSide=1;breakEvenSide=1;takeProfitSide=1;riskMode=0;trailingMode=0;groupMode=true;pendingOrderMode=false;
   orderPrepared=false;fixedStopMode=false;riskRewardMode=true;percentTargetMode=false;breakEvenShown=false;takeProfitShown=false;
   csmPlannedEntry=0;plannedStopLoss=0;plannedTakeProfit=0;breakEvenPrice=0;takeProfitPrice=0;
   stopDistancePoints=250;rewardRiskRatio=2;
   panelX=12;panelY=20;panelScale=1.0;panelMinimized=false;
   savedRiskText="1";savedPointsText="250";savedRatioText="2";savedAmountText="100";
   ArrayResize(trailingPositionTickets,0);ArrayResize(favorablePrices,0);
   ArrayResize(initialRiskCache,0);trailingNoSL=0;trailingUnknown=0;
   panelStateReady=false;panelStateFile="";lastSavedPanelRecord="";lastStateSave=0;
}
void LoadPanelState()
{
   string scope=CurrentPanelScope();
   // MT5 preserves globals across chart/parameter changes. Reuse only same-scope
   // committed state; never carry a different symbol/account/magic's draft.
   if(activePanelScope==scope) return;
   ResetPanelOperationalState();
   activePanelScope=scope;
   // Tester runs must not inherit a live chart's state.
   if(MQLInfoInteger(MQL_TESTER)) return;
   panelStateFile=PanelPersistenceIdentity();
   if(panelStateFile=="") {Print("CSM: chart identity unavailable");return;}
   panelStateReady=true;
   int h=FileOpen(panelStateFile,FILE_READ|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return;
   string record=FileReadString(h);FileClose(h);
   string a[];
   int n=StringSplit(record,'|',a);
   if(n<24 || (a[0]!="CSM140" && a[0]!="CSM160" && a[0]!="CSM170")){Print("CSM: invalid saved state");return;}
   bool hasTP=a[0]=="CSM170",hasBESide=a[0]!="CSM140";
   int side=(int)StringToInteger(a[5]),risk=(int)StringToInteger(a[6]),trail=(int)StringToInteger(a[7]);
   double scale=StringToDouble(a[3]),points=StringToDouble(a[15]),ratio=StringToDouble(a[16]);
   double entry=StringToDouble(a[17]),sl=StringToDouble(a[18]),tp=StringToDouble(a[19]),be=StringToDouble(a[20]);
   double riskValue=StringToDouble(a[21]),amount=StringToDouble(a[22]);
   int count=(int)StringToInteger(a[23]);
   bool pointsValid=ParseNonnegativePanelDecimal(a[15],points) && (hasTP || points>0);
   bool valid=(side==1 || side==-1) && risk>=0 && risk<=2 && trail>=0 && trail<=1 &&
              scale>=0.65 && scale<=2.0 && pointsValid && ratio>0 &&
              ValidStateNumber(entry) && ValidStateNumber(sl) && ValidStateNumber(tp) && ValidStateNumber(be) &&
              MathIsValidNumber(points) && MathIsValidNumber(ratio) && count>=0 && count<=10000 && n==24+count*2+(hasTP?4:hasBESide?1:0) &&
              ValidStateNumber(riskValue) && ValidStateNumber(amount);
   for(int i=8;i<=14;i++) if(a[i]!="0" && a[i]!="1") valid=false;
   if(a[4]!="0" && a[4]!="1") valid=false;
   int beSide=side,tpSide=side;double tpLevel=0;bool tpShown=false;
   if(valid && hasBESide)
   {
      int ix=24+count*2;
      if(a[ix]!="1" && a[ix]!="-1") valid=false;
      else beSide=(int)StringToInteger(a[ix]);
      if(hasTP)
      {
         if((a[ix+1]!="1" && a[ix+1]!="-1") || (a[ix+2]!="0" && a[ix+2]!="1")) valid=false;
         tpSide=(int)StringToInteger(a[ix+1]);tpShown=a[ix+2]=="1";tpLevel=StringToDouble(a[ix+3]);
         if(!ValidStateNumber(tpLevel) || (tpShown && tpLevel<=0)) valid=false;
      }
   }
   if(!valid){Print("CSM: rejected saved state");return;}
   panelX=(int)MathMax(0,MathMin(100000,StringToInteger(a[1])));
   panelY=(int)MathMax(0,MathMin(100000,StringToInteger(a[2])));
   panelScale=scale;
   panelMinimized=a[4]=="1";tradeSide=side;breakEvenSide=beSide;takeProfitSide=tpSide;takeProfitShown=tpShown;takeProfitPrice=tpLevel;riskMode=risk;trailingMode=trail;
   groupMode=a[8]=="1";pendingOrderMode=a[9]=="1";
   bool validDraftLevels=points>0?(sl>0 && tp>0):
      (hasTP && sl==0 && (a[12]=="1"?tp==0:tp>0));
   // Parsing malformed saved levels must not accidentally opt in to absent protection.
   double checkedSL=0,checkedTP=0;
   if(hasTP && (!ParseNonnegativePanelDecimal(a[18],checkedSL) ||
                !ParseNonnegativePanelDecimal(a[19],checkedTP))) validDraftLevels=false;
   orderPrepared=a[10]=="1" && entry>0 && validDraftLevels;
   fixedStopMode=a[11]=="1";riskRewardMode=a[12]=="1";percentTargetMode=a[13]=="1";breakEvenShown=a[14]=="1" && be>0;
   stopDistancePoints=points;rewardRiskRatio=ratio;csmPlannedEntry=entry;plannedStopLoss=sl;plannedTakeProfit=tp;breakEvenPrice=be;
   savedRiskText=a[21];savedPointsText=DoubleToString(points,16);savedRatioText=DoubleToString(ratio,16);savedAmountText=a[22];
   for(int i=0;i<count;i++)
   {
      ulong ticket=(ulong)StringToInteger(a[24+2*i]);
      double best=StringToDouble(a[25+2*i]);
      if(!OwnedTrailingTicket(ticket) || !ValidStateNumber(best) || best<=0) continue;
      int k=ArraySize(trailingPositionTickets);
      ArrayResize(trailingPositionTickets,k+1);ArrayResize(favorablePrices,k+1);
      trailingPositionTickets[k]=ticket;favorablePrices[k]=best;
   }
   lastSavedPanelRecord=record;
   csmPanelStatus="Estado restaurado; revisa niveles antes de operar";
}
void SavePanelState()
{
   if(!panelStateReady || panelStateFile=="" || MQLInfoInteger(MQL_TESTER)) return;
   lastStateSave=GetTickCount64();
   // Do not persist an uncommitted price gesture or close confirmation.
   if(chartLineDragging || panelGesture!=0) return;
   double risk=PanelInputNumber("riskval"),amount=PanelInputNumber("amount");
   if(!ValidStateNumber(risk) || !ValidStateNumber(amount)) return;
   string pairs="";
   int count=0;
   for(int i=0;i<ArraySize(trailingPositionTickets);i++)
   {
      if(!OwnedTrailingTicket(trailingPositionTickets[i]) || favorablePrices[i]<=0 || !MathIsValidNumber(favorablePrices[i])) continue;
      pairs+="|"+StringFormat("%I64u",trailingPositionTickets[i])+"|"+StateNumber(favorablePrices[i]);count++;
   }
   string record=StringFormat("CSM170|%d|%d|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d",
      panelX,panelY,StateNumber(panelScale),(int)panelMinimized,tradeSide,riskMode,trailingMode,
      (int)groupMode,(int)pendingOrderMode,(int)orderPrepared,(int)fixedStopMode,(int)riskRewardMode,(int)percentTargetMode,(int)breakEvenShown);
   record+="|"+StateNumber(stopDistancePoints)+"|"+StateNumber(rewardRiskRatio)+"|"+StateNumber(csmPlannedEntry)+
      "|"+StateNumber(plannedStopLoss)+"|"+StateNumber(plannedTakeProfit)+"|"+StateNumber(breakEvenPrice)+
      "|"+StateNumber(risk)+"|"+StateNumber(amount)+"|"+IntegerToString(count)+pairs+"|"+IntegerToString(breakEvenSide)+"|"+IntegerToString(takeProfitSide)+"|"+IntegerToString((int)takeProfitShown)+"|"+StateNumber(takeProfitPrice);
   if(record==lastSavedPanelRecord) return;
   string temp=panelStateFile+".tmp";
   int h=FileOpen(temp,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE){Print("CSM: state write failed ",GetLastError());return;}
   uint written=FileWriteString(h,record+"\r\n");
   FileFlush(h);FileClose(h);
   if(written==0 || !FileMove(temp,0,panelStateFile,FILE_REWRITE))
      Print("CSM: state replace failed ",GetLastError());
   else lastSavedPanelRecord=record;
}
