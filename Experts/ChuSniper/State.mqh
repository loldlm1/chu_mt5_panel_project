input ulong Magic=110629;
input int ActivationPoints=250;
input int TrailPoints=150;
input int StepPoints=250;
input bool IncludeOtherPositions=false;
CTrade trade;
string panelObjectPrefix="CSM_",csmPanelStatus="";
int tradeSide=1, riskMode=1, trailingMode=0;
bool groupMode=false, pendingOrderMode=false, orderPrepared=false, fixedStopMode=false, riskRewardMode=true, averagingEnabled=false, percentTargetMode=false, breakEvenShown=false, tradeExecutionEnabled=false;
double csmPlannedEntry=0,plannedStopLoss=0,plannedTakeProfit=0,stopDistancePoints=250,rewardRiskRatio=2,breakEvenPrice=0;
ulong closeConfirmationDeadline=0;
bool editingStopPoints=false;
ulong trailingPositionTickets[];
double favorablePrices[];
#define CSM_PANEL_NAVY C'20,30,43'
color textColor=C'225,232,241', highlightColor=C'255,215,49', infoColor=C'70,169,255', sellColor=C'255,100,100', buyColor=C'42,192,179';
