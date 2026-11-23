input ulong Magic=110629;
input int ActivationPoints=250;
input int TrailPoints=150;
input int StepPoints=250;
input bool IncludeOtherPositions=false;
CTrade trade;
string P="CSM_",csmPanelStatus="";
int side=1, risk=1, trailing=0;
bool group=false, pending=false, prep=false, fixedStop=false, ratioMode=true, averaging=false, pct=false, be=false, armed=false;
double csmPlannedEntry=0,plannedStopLoss=0,plannedTakeProfit=0,stopPoints=250,rr=2,bePrice=0;
ulong closeDeadline=0;
bool editingPoints=false;
ulong tracked[];
double best[];
#define CSM_PANEL_NAVY C'20,30,43'
color ink=C'225,232,241', gold=C'255,215,49', blue=C'70,169,255', red=C'255,100,100', green=C'42,192,179';
