input ulong Magic=110629;
input bool IncludeOtherPositions=false;
enum ENUM_CSM_PANEL_THEME { PANEL_ORIGINAL=0, PANEL_PANDORA=1 };
input ENUM_CSM_PANEL_THEME PanelTheme=PANEL_ORIGINAL;
CTrade trade;
string panelObjectPrefix="CSM_",csmPanelStatus="";
int tradeSide=1, breakEvenSide=1, takeProfitSide=1, riskMode=0, trailingMode=0;
bool groupMode=true, pendingOrderMode=false, orderPrepared=false, fixedStopMode=false, riskRewardMode=true, percentTargetMode=false, breakEvenShown=false, takeProfitShown=false, tradeExecutionEnabled=false;
double csmPlannedEntry=0,plannedStopLoss=0,plannedTakeProfit=0,stopDistancePoints=250,rewardRiskRatio=2,breakEvenPrice=0,takeProfitPrice=0;
ulong closeConfirmationDeadline=0;
bool editingStopPoints=false;
ulong trailingPositionTickets[];
double favorablePrices[];
ulong trailingRetryAfter[]; // transient server-rejection cooldown, never persisted
// 1 = reliable original distance, 0 = opened without SL, -1 = unavailable.
// The authoritative durable record is opening deal/order history, never current SL.
struct InitialRiskRecord
{
   ulong identifier,checked;
   double volume,entry,distance;
   int state;
};
InitialRiskRecord initialRiskCache[];
int trailingNoSL=0,trailingUnknown=0;
#define CSM_PANEL_NAVY C'20,30,43'
color textColor=C'225,232,241', highlightColor=C'255,215,49', infoColor=C'70,169,255', sellColor=C'255,100,100', buyColor=C'42,192,179';

// The custom mouse gesture is the only owner of an EA line drag.
bool previousChartMouseScroll=true, chartMouseScrollCaptured=false;
bool previousMouseMoveEnabled=false, chartMouseMoveConfigured=false;
bool previousTradeLevelDrag=true, tradeLevelDragCaptured=false;
bool chartLineDragging=false, chartLeftPressed=false;
string chartDragKey="";
double chartDragStartPrice=0, chartDragPrice=0, chartDragMouseOffset=0;
double chartDragStartSL=0, chartDragStartTP=0;
bool chartDragOriginalFixedStop=false, chartDragOriginalRiskReward=false;
ulong chartDragLastEvent=0, chartHoverAt=0,lastPanelRefresh=0;
bool panelDirty=true;

int panelX=12,panelY=20;
double panelScale=1.0,panelDrawScale=1.0;
bool panelMinimized=false;
int panelGesture=0,panelGestureX=0,panelGestureY=0,panelGestureStartX=0,panelGestureStartY=0;
double panelGestureStartScale=1.0;
bool suppressPanelClick=false;
ulong panelGestureLastEvent=0;
string savedRiskText="1",savedPointsText="250",savedRatioText="2",savedAmountText="100";

string panelStateFile="";
bool panelStateReady=false;
ulong lastStateSave=0;

string activePanelScope="",lastSavedPanelRecord="";

ulong lastQuickQuoteRefresh=0,lastBEProjectionRefresh=0,lastTPProjectionRefresh=0;

#define CSM_QUICK_HEIGHT 50
#define CSM_QUICK_EXTRA (CSM_QUICK_HEIGHT-25)
