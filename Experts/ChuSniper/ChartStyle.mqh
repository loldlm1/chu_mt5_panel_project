// Source: HFT_GRID_AI bot/pandora_box_ea, 31526823bd1ad5850e918e6cd324b98d67320e53
// Chart style independent of panel theme. No Pandora trading code imported.
const color COLOR_CHART_BACKGROUND = C'44,45,50';
const color COLOR_CHART_FOREGROUND = clrDarkTurquoise;
const color COLOR_CHART_BULL       = clrLightSeaGreen;
const color COLOR_CHART_BEAR       = C'239,83,80';
const color COLOR_CANDLE_BULL      = clrLightSeaGreen;
const color COLOR_CANDLE_BEAR      = C'239,83,80';
const color COLOR_CHART_LINE       = C'38,166,154';
const color COLOR_CHART_VOLUME     = C'38,166,154';
const color COLOR_CHART_BID        = C'38,166,154';
const color COLOR_CHART_ASK        = C'239,83,80';
const color COLOR_CHART_LAST       = C'156,186,240';
const color COLOR_CHART_STOP_LEVEL = C'239,83,80';

void ApplyPandoraChartStyle(const long chart_id)
{
  ChartSetInteger(chart_id, CHART_SHOW_OBJECT_DESCR, true);
  ChartSetInteger(chart_id, CHART_QUICK_NAVIGATION, false);
  ChartSetInteger(chart_id, CHART_SHOW_GRID, 0, false);
  ChartSetInteger(chart_id, CHART_SHOW_VOLUMES, 0, false);
  ChartSetInteger(chart_id, CHART_AUTOSCROLL, 0, true);
  ChartSetInteger(chart_id, CHART_SHIFT, 0, true);

  ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, COLOR_CHART_BACKGROUND);
  ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, COLOR_CHART_FOREGROUND);
  ChartSetInteger(chart_id, CHART_COLOR_CHART_UP, COLOR_CHART_BULL);
  ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, COLOR_CHART_BEAR);
  ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, COLOR_CANDLE_BULL);
  ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, COLOR_CANDLE_BEAR);
  ChartSetInteger(chart_id, CHART_COLOR_CHART_LINE, COLOR_CHART_LINE);
  ChartSetInteger(chart_id, CHART_COLOR_VOLUME, COLOR_CHART_VOLUME);
  ChartSetInteger(chart_id, CHART_COLOR_BID, COLOR_CHART_BID);
  ChartSetInteger(chart_id, CHART_COLOR_ASK, COLOR_CHART_ASK);
  ChartSetInteger(chart_id, CHART_COLOR_LAST, COLOR_CHART_LAST);
  ChartSetInteger(chart_id, CHART_COLOR_STOP_LEVEL, COLOR_CHART_STOP_LEVEL);
  ChartSetInteger(chart_id, CHART_SHOW_ONE_CLICK, false);
}

color PanelBackground(){return PanelTheme==PANEL_PANDORA?C'31,33,38':C'10,17,26';}
color PanelBorder(){return PanelTheme==PANEL_PANDORA?C'38,166,154':textColor;}
color PanelAccent(color c)
{
   if(PanelTheme==PANEL_ORIGINAL) return c;
   if(c==CSM_PANEL_NAVY) return C'44,45,50';
   if(c==buyColor) return clrLightSeaGreen;
   if(c==sellColor) return C'239,83,80';
   if(c==highlightColor) return C'38,166,154';
   if(c==infoColor) return C'156,186,240';
   return c;
}
color PanelInk(color bg,color fg)
{
   if(PanelTheme==PANEL_ORIGINAL) return fg;
   if(bg==CSM_PANEL_NAVY) return clrDarkTurquoise;
   if(bg==buyColor || bg==sellColor || bg==highlightColor || bg==infoColor) return clrBlack;
   return clrDarkTurquoise;
}
