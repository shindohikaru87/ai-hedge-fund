#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# —— Force headless plotting —— 
export MPLBACKEND=Agg

# —— Configuration —— 
LOG_DIR=logs
START_DATE="2015-01-04"

# macOS-compatible: get last Friday (or today if today is a weekday)
dow=$(date +%u)
if [ "$dow" -eq 6 ]; then
  END_DATE=$(date -v-1d +%Y-%m-%d)  # Saturday → Friday
elif [ "$dow" -eq 7 ]; then
  END_DATE=$(date -v-2d +%Y-%m-%d)  # Sunday → Friday
else
  END_DATE=$(date +%Y-%m-%d)        # Weekday → today
fi

INITIAL_CAPITAL=5000
MARGIN=1.0
MODEL=deepseek-chat
MAX_RETRIES=3

# Tickers you’re excluding (for reference)
EXCLUDED=(MA V PYPL TSLA PINS BA VRT XOM CVX INTC MS WFC SPOT AVGO)
INCLUDED=(AMD META GOOG)

# —— All backtest jobs —— 
BACKTEST_JOBS=(
  # * ----------------------------- TECHNOLOGY --------------------------------- #
  # "AMD:technical_analyst,sentiment_analyst,valuation_analyst,stanley_druckenmiller"              # Deep Seek Combination
  # "AMD:technical_analyst,sentiment_analyst,fundamentals_analyst,valuation_analyst,michael_burry" # 🏷️ Style:Momentum&Sentiment+Fundamental&Value+TailRiskHedge #Combines price trends and sentiment spikes for entries, confirms with financial/valuation filters, hedges large downside
  # "AMD:technical_analyst,valuation_analyst,michael_burry"                                        # 🏷️ Style:Momentum+IntrinsicValue+TailRiskHedge #Trades momentum breakouts only when undervalued, exits early via tail-risk alerts
  # "AMD:technical_analyst,bill_ackman,stanley_druckenmiller"                                      # 🏷️ Style:Momentum+ActivistConviction+MacroOverlay #Follows price momentum, adds activist lens to justify position, exits on macro deterioration
  # "AMD:technical_analyst,peter_lynch,phil_fisher,stanley_druckenmiller"                          # 🏷️ Style:Momentum+GARP+QualityGrowth+MacroHedge #Enters on strength, filters for GARP and high-quality growth, exits when macro shifts
  # "AMD:sentiment_analyst,fundamentals_analyst,michael_burry"                                     # 🏷️ Style:SentimentDriven+FundamentalAnchor+TailRiskGuard #Takes contrarian sentiment trades with earnings support, hedges extreme downside
  # "AMD:technical_analyst,fundamentals_analyst,valuation_analyst"                                 # 🏷️ Style:MeanReversion+Financials&DCF+StopLossDiscipline #Buys dips when fundamentals/valuation justify, cuts losses fast with technical stops

  # "NVDA:technical_analyst,sentiment_analyst,peter_lynch,stanley_druckenmiller"    # Deep Seek Combination
  # "NVDA:technical_analyst,peter_lynch,valuation_analyst,michael_burry"            # 🏷️ Style:MomentumGARP+TailHedge—rides trends with valuation confirmation, protects downside via Burry’s crash detection
  # "NVDA:technical_analyst,fundamentals_analyst,stanley_druckenmiller"             # 🏷️ Style:TwinMomentum+MacroOverlay—aligns price/fundamental momentum, exits early in macro regime shifts
  # "NVDA:technical_analyst,sentiment_analyst,phil_fisher,stanley_druckenmiller"    # 🏷️ Style:QualityTrend+SentimentGuard—trades strong uptrends with sentiment boost, exits early on macro stress
  # "NVDA:sentiment_analyst,valuation_analyst,technical_analyst"                    # 🏷️ Style:ContrarianMeanRevert—exploits sentiment extremes, confirms with valuation, manages risk with stops
  # "NVDA:sentiment_analyst,peter_lynch,phil_fisher,michael_burry"                  # 🏷️ Style:GARPValueContrarian—buys dips on strong fundamentals, filters through sentiment, hedges bubbles
  # "NVDA:sentiment_analyst,technical_analyst,bill_ackman"                          # 🏷️ Style:CatalystSwingSentiment—trades sentiment reversals with Ackman’s thesis conviction, exits with chart/risk rules

  # "GOOGL:technical_analyst, valuation_analyst, peter_lynch, stanley_druckenmiller"                    # Deep Seek Combination
  # "GOOGL:technical_analyst,valuation_analyst,michael_burry"                                           # 🏷️ Style: Value Momentum + Hedge Enters on momentum, confirms with value, hedges tail risk
  # "GOOGL:sentiment_analyst,phil_fisher,stanley_druckenmiller"                                         # 🏷️ Style: Growth Sentiment + Macro Rides bullish sentiment with quality growth, exits on macro shifts
  # "GOOGL:technical_analyst,peter_lynch,bill_ackman,stanley_druckenmiller"                             # 🏷️ Style: GARP + Activist Macro Trades fair-growth setups with catalysts, exits on macro signs
  # "GOOGL:sentiment_analyst,fundamentals_analyst,michael_burry"                                        # 🏷️ Style: Contrarian Value + Hedge Buys oversold with solid fundamentals, hedges downside
  # "GOOGL:technical_analyst,sentiment_analyst,peter_lynch,michael_burry"                               # 🏷️ Style: Dual Signal GARP + Hedge Trades aligned tech/sentiment with GARP, protects drawdown
  # "GOOGL:technical_analyst,sentiment_analyst,valuation_analyst,michael_burry,stanley_druckenmiller"   # 🏷️ Style: Multi-Signal Value + Hedges Filters entries by tech/sentiment, confirms value, double hedged

  # "AAPL:technical_analyst,peter_lynch,stanley_druckenmiller"                                  # Deek Seek Combination
  # "AAPL:technical_analyst,valuation_analyst,michael_burry"                                    # 🏷️ Style: Momentum + Value + Tail Hedge Uses charts for timing, DCF to confirm value, and hedges crash risks.
  # "AAPL:technical_analyst,peter_lynch,stanley_druckenmiller"                                  # 🏷️ Style: Momentum + GARP + Macro Uses momentum, GARP filters, and macro hedging.
  # "AAPL:sentiment_analyst,fundamentals_analyst,michael_burry"                                 # 🏷️ Style: Sentiment + Fundamentals + Tail Hedge Times trades on sentiment, confirms with financials, and protects downside.
  # "AAPL:technical_analyst,bill_ackman,stanley_druckenmiller"                                  # 🏷️ Style: Momentum + Activist + Macro Tracks trends, targets value with catalysts, filters with macro guardrails.
  # "AAPL:technical_analyst,sentiment_analyst,fundamentals_analyst,phil_fisher,michael_burry"   # 🏷️ Style: Multi-Factor + Quality + Tail Hedge Combines signals, strong business screens, and hedging.
  # "AAPL:technical_analyst,sentiment_analyst,ben_graham"                                       # 🏷️ Style: Mean Reversion + Deep Value + Stop-Loss Buys fear-driven dips with value buffer and strict exits.

  # "MSFT:technical_analyst,peter_lynch,stanley_druckenmiller"                                              # Deep Seek Combination
  # "MSFT:technical_analyst,sentiment_analyst,fundamentals_analyst,valuation_analyst,stanley_druckenmiller" # Momentum+Sentiment+Fundamentals+Valuation+Macro hedge for consistent entries, valuation filters, and crisis protection
  # "MSFT:technical_analyst,sentiment_analyst,fundamentals_analyst,stanley_druckenmiller"                   # Sentiment-driven timing with fundamental filter and macro guardrails for crash-resilient growth trades
  # "MSFT:technical_analyst,phil_fisher,michael_burry"                                                      # Quality growth breakout trades with tail-risk protection for upside capture and rare crash hedges
  # "MSFT:technical_analyst,sentiment_analyst,valuation_analyst,michael_burry"                              # Contrarian entries on panic dips with value screens and downside crash insurance
  # "MSFT:technical_analyst,peter_lynch,valuation_analyst"                                                  # Mean-reversion GARP trades with technical stop-loss to limit drawdown in volatile phases
  # "MSFT:technical_analyst,bill_ackman,stanley_druckenmiller"                                              # Activist value confirmation via technical trend plus macro hedge against global shocks

  # "META:technical_analyst,sentiment_analyst,valuation_analyst,stanley_druckenmiller,michael_burry" # Deep Seek Combination
  # "META:technical_analyst,sentiment_analyst,valuation_analyst,michael_burry,stanley_druckenmiller" # 🏷️ Multi-Signal Value Macro Hedge: momentum+sentiment entries, DCF filter, dual risk guards for crash resilience
  # "META:technical_analyst,peter_lynch,stanley_druckenmiller"                                       # 🏷️ GARP Momentum Macro: growth-at-reasonable-price filter with macro exits and trend signals
  # "META:technical_analyst,valuation_analyst,michael_burry"                                         # 🏷️ Value Momentum Hedge: trades only when undervalued and trending, hedged with tail-risk protection
  # "META:sentiment_analyst,bill_ackman,stanley_druckenmiller"                                       # 🏷️ Sentiment Activist Macro: contrarian sentiment turns plus deep value with macro risk filter
  # "META:technical_analyst,phil_fisher,michael_burry"                                               # 🏷️ Quality Momentum Hedge: buys strong trend in high-quality firms, protects via tail-risk hedge
  # "META:sentiment_analyst,fundamentals_analyst,technical_analyst"                                  # 🏷️ Sentiment Fundamental Stop-Loss: sentiment rebound trades with earnings filters and strict stop logic

  # "NFLX:sentiment_analyst,phil_fisher,stanley_druckenmiller"            # Deep Seek Combination
  # "NFLX:technical_analyst,valuation_analyst,michael_burry"              # 🏷️ Style:Momentum+IntrinsicValue+TailRiskHedge,rides trends only when valuation aligns and exits early in bubbles/crashes
  # "NFLX:technical_analyst,peter_lynch,stanley_druckenmiller"            # 🏷️ Style:MeanReversion+GARP+MacroOverlay,buys dips on quality growth with macro-triggered exits
  # "NFLX:sentiment_analyst,fundamentals_analyst,technical_analyst"       # 🏷️ Style:News-Driven+FinancialFilter+Stop-Loss,enters on sentiment spikes if financials agree, exits via strict stop rules
  # "NFLX:sentiment_analyst,phil_fisher,stanley_druckenmiller"            # 🏷️ Style:ContrarianSentiment+QualityGrowth+MacroHedge,buys on panic in great companies and adapts to macro risk
  # "NFLX:sentiment_analyst,bill_ackman,michael_burry"                    # 🏷️ Style:DeepValueContrarian+TailHedge,buys fear-driven collapses with activist insight and hedges speculative excess
  # "NFLX:technical_analyst,fundamentals_analyst,stanley_druckenmiller"   # 🏷️ Style:TwinMomentum+MacroGuardrails,trades only when price and fundamentals align, exits early in regime shifts

  # "TSLA:technical_analyst,sentiment_analyst,stanley_druckenmiller,michael_burry" # Deep Seek Combination
  # "TSLA:technical_analyst,valuation_analyst,michael_burry"                       # 🏷️ Momentum+Valuation+TailRiskHedge uses price breakouts for entry, filters with intrinsic valuation, and exits or hedges via Burry-style crash detection logic
  # "TSLA:sentiment_analyst,peter_lynch,phil_fisher,stanley_druckenmiller"         # 🏷️ SentimentGARP+MacroFilter captures social buzz spikes, filters on growth+quality, and overlays macro risk conditions for position sizing
  # "TSLA:technical_analyst,fundamentals_analyst,stanley_druckenmiller"            # 🏷️ Trend+Earnings+MacroGuard uses technical trend to enter, filters with earnings momentum, and hedges via macro regime overlays
  # "TSLA:valuation_analyst,cathie_wood,technical_analyst,michael_burry"           # 🏷️ DisruptiveGrowth+DCF+CrashHedge bets on innovation with valuation grounding and stop-loss+put protection during reversals
  # "TSLA:sentiment_analyst,bill_ackman,technical_analyst"                         # 🏷️ ActivistSentiment+StopLoss leverages activist catalysts and sentiment triggers, manages risk via technical trailing stops
  # "TSLA:technical_analyst,phil_fisher,valuation_analyst,stanley_druckenmiller"   # 🏷️ QualityMomentum+MacroTiming combines ROIC-based quality filter with price momentum and macro regime-aware trade timing

  # * ----------------------------- FINANCE --------------------------------- #  
  # "JPM:technical_analyst,sentiment_analyst,warren_buffett,stanley_druckenmiller"                   # Deep seek combination
  # "JPM:technical_analyst,sentiment_analyst,fundamentals_analyst,bill_ackman,stanley_druckenmiller" # 🏷️ Style:All-WeatherMulti-Strategy uses sentiment and momentum to time entries, filters with fundamentals, and hedges macro/tail risks effectively
  # "JPM:technical_analyst,bill_ackman,stanley_druckenmiller"                                        # 🏷️ Style:Trend-FollowingActivistHedge rides trends with timing, adds conviction via value catalysts, and exits early on macro risk cues
  # "JPM:technical_analyst,ben_graham,michael_burry"                                                 # 🏷️ Style:DeepValueTrendwithTailHedge buys only undervalued setups, enters with technical confirmation, and hedges or exits on systemic threats
  # "JPM:technical_analyst,warren_buffett,stanley_druckenmiller"                                     # 🏷️ Style:QualityValue+TrendHedge enters strong franchises on fair value, exits when technical/macro risks arise, minimizing drawdowns
  # "JPM:technical_analyst,sentiment_analyst,fundamentals_analyst"                                   # 🏷️ Style:QuantMultiFactor only trades when trend,sentiment,and fundamentals align; strict stop-losses ensure low drawdown
  # "JPM:technical_analyst,peter_lynch,michael_burry"                                                # 🏷️ Style:GARPMomentum+ContrarianHedge growth-at-reasonable-price entries confirmed with momentum; exits proactively if risk sentiment turns
  
  # "MS:technical_analyst,sentiment_analyst,valuation_analyst,stanley_druckenmiller,michael_burry" # Deep seek combination 
  # "MS:technical_analyst,sentiment_analyst,fundamentals_analyst,valuation_analyst,michael_burry"  # 🏷️ Style:Momentum+FundamentalswithCrashHedgeuseschart+sentimenttimingwithvaluationfiltersandBurry'stailriskhedgingforlowdrawdowndailytrading
  # "MS:technical_analyst,valuation_analyst,stanley_druckenmiller"                                 # 🏷️ Style:MeanReversion+ValuewithMacroGuardbuysundervalueddipsviacharts+valuationonlyifmacrosupportsrecovery
  # "MS:sentiment_analyst,peter_lynch,technical_analyst"                                           # 🏷️ Style:Sentiment-DrivenGARP+StrictRiskControlusesnewsflowtimingwithGARPgrowthscreensandstop-lossriskcontrolsforsteadyreturns
  # "MS:bill_ackman,technical_analyst,michael_burry"                                               # 🏷️ Style:ActivistValue+TechnicalHedgedeepfundamentalanalysispairedwithcharttimingandmacrohedgingtoavoidcrashes
  # "MS:phil_fisher,sentiment_analyst,stanley_druckenmiller"                                       # 🏷️ Style:QualityGrowth+ContrarianwithMacroHedgebuysMSonpaniciflong-termfundamentalsareintact,macroscreenavoidssystemicrisks
  # "MS:warren_buffett,technical_analyst,sentiment_analyst"                                        # 🏷️ Style:DeepValue+TrendTimingShieldclassicBuffettvaluationfilteredbycharttrendsandsentimentextremesforentry/exittiming

  # "GS:valuation_analyst,technical_analyst,michael_burry"               # Deep seek combination
  # "GS:technical_analyst,fundamentals_analyst,michael_burry"            # 🏷️ Style:Momentum+ValueHedge[Ridesuptrendsviatechnicalsignals,filtersforundervaluation/strongfundamentals,andhedgesextremedropswithtail-riskstops]
  # "GS:sentiment_analyst,fundamentals_analyst,stanley_druckenmiller"    # 🏷️ Style:Sentiment+ValuewithMacroGuardrails[Buysonpositivenews/socialsentiment,ensuressolidfundamentalsonentry,andcutsexposurewhenmacroindicatorswarnofdownturns]
  # "GS:bill_ackman,technical_analyst,michael_burry"                     # 🏷️ Style:ActivistMomentum+CrashProtection[TargetsGSviaactivist-stylecatalysts,tradesonpricemomentumbreakouts,andusescrashhedgestolimitlosses]
  # "GS:phil_fisher,technical_analyst,stanley_druckenmiller"             # 🏷️ Style:Growth+QualityTrendwithMacroOversight[FocusesonGS’sgrowth/qualityfundamentals,ridesstronguptrends,andusesmacrooverlaystotrimriskifthecycleshifts]
  # "GS:peter_lynch,technical_analyst,michael_burry"                     # 🏷️ Style:GARPMomentum+TailHedge[SelectsGSwhengrowthprospectsmeetreasonablevaluation(GARP),followsmomentumuptrends,anddeploystail-riskhedgesonsharpdownturns]
  # "GS:valuation_analyst,technical_analyst,michael_burry"               # 🏷️ Style:ValuationBreakout+TailHedge[Choosesbreakouttradesbackedbyattractivevaluation,tradesmomentumbreakouts,andprotectsagainstsevereselloffswithcrashhedges]

  # "C:technical_analyst,fundamentals_analyst,stanley_druckenmiller" # Deepseek combination
  # "C:technical_analyst,phil_fisher,michael_burry"                  # 🏷️ Style:Momentum+QualityGrowth+TailRiskHedge,uses price trends for timing, Fisher’s quality filter for entries, and Burry for crash protection
  # "C:technical_analyst,valuation_analyst,michael_burry"            # 🏷️ Style:Momentum+IntrinsicValue+TailRiskHedge,executes on momentum only when valuation is compelling, exits on Burry-style risk triggers
  # "C:technical_analyst,fundamentals_analyst,stanley_druckenmiller" # 🏷️ Style:Momentum+FundamentalHealth+MacroHedge,uses fundamentals to validate trends, exits when Druckenmiller macro risk flags trigger
  # "C:sentiment_analyst,valuation_analyst,stanley_druckenmiller"    # 🏷️ Style:Sentiment+ValueFocus+MacroHedge,bets on crowd mood shifts filtered by value, with Druckenmiller macro exits to avoid euphoric traps
  # "C:technical_analyst,bill_ackman,michael_burry"                  # 🏷️ Style:Momentum+ActivistValue+TailRiskHedge,trades momentum filtered by Ackman’s value lens, exits on Burry’s capital preservation logic
  # "C:technical_analyst,fundamentals_analyst,michael_burry"         # 🏷️ Style:Momentum+FundamentalValue+TailRiskHedge,times entries on price moves backed by earnings strength, hedges fast on rising market stress

  # "BAC:technical_analyst,valuation_analyst,stanley_druckenmiller,michael_burry,charlie_munger" # Deep seek Combination
  # "BAC:technical_analyst,fundamentals_analyst,michael_burry"                                   # 🏷️ BalancedMomentum–Usestechnicalsignalsforentries,fundamentalsfiltertrades,Burryaddsdownsidehedge
  # "BAC:technical_analyst,valuation_analyst,warren_buffett,stanley_druckenmiller"               # 🏷️ Value+MacroTrend–Macrooverlayguidesentries,valuationandBuffettensurequalitypicks,stop-losslimitsrisk
  # "BAC:technical_analyst,fundamentals_analyst,bill_ackman,michael_burry"                       # 🏷️ ActivistValueMomentum–Momentumtiming,Ackman'sactivistfilter,Burryhedgescrashes
  # "BAC:sentiment_analyst,peter_lynch,valuation_analyst,stanley_druckenmiller"                  # 🏷️ GrowthSentiment&Value–Sentimentdrivesentries,Lynchandvaluationfiltergrowth,Druckenmillermanagesmacroexposure
  # "BAC:sentiment_analyst,phil_fisher,cathie_wood,stanley_druckenmiller,michael_burry"          # 🏷️ InnovativeGrowth&Macro–Sentimentboostsentry,Fisher/Woodfocusoninnovation,Druckenmiller/Burrycovercyclicalandtailrisk
  # "BAC:technical_analyst,valuation_analyst,charlie_munger,michael_burry"                       # 🏷️ QualityValueDefensive–Technicalsforentry,Munger+valuationensuremoats,Burrybuffersagainstsharpdrawdowns

  # "WFC:technical_analyst,fundamentals_analyst,valuation_analyst,stanley_druckenmiller"    # Deep seek combination
  # "WFC:technical_analyst,fundamentals_analyst,valuation_analyst,michael_burry"            # 🏷️ Value-Momentum Balanced#Uses trend signals confirmed by fundamentals/valuation; Burry provides tail risk guard with stop-loss protection
  # "WFC:technical_analyst,sentiment_analyst,fundamentals_analyst,stanley_druckenmiller"    # 🏷️ News-Momentum Macro#Combines price/news timing with fundamental filters and macro downside exits
  # "WFC:phil_fisher,peter_lynch,technical_analyst,michael_burry"                           # 🏷️ Growth-Value Contrarian#GARP filters with momentum timing; Burry hedges valuation extremes and stops limit loss
  # "WFC:technical_analyst,fundamentals_analyst,phil_fisher,stanley_druckenmiller"          # 🏷️ Adaptive Growth-Value#Quality growth with timing logic; macro exits and dynamic volatility filters protect downside
  # "WFC:technical_analyst,valuation_analyst,bill_ackman,stanley_druckenmiller"             # 🏷️ Catalyst-Value Momentum#Breakouts in undervalued stocks with activist insight; Druckenmiller exits on macro shifts
  # "WFC:technical_analyst,sentiment_analyst,phil_fisher,bill_ackman,michael_burry"         # 🏷️ Aggressive Catalyst-Value#Sentiment and growth catalysts gated by Ackman’s and Burry’s risk checks, plus stop-loss limits
)

# —— Prepare logs folder —— 
mkdir -p "$LOG_DIR"

# —— Backtest Runner Function —— 
run_job() {
  local ticker=$1
  local analysts=$2
  local start_date=$3
  local attempt=1

  # Override END_DATE for META
  if [ "$ticker" = "META" ]; then
    END_DATE="2022-05-31"
  fi

  # Sanitize analyst names for file naming
  local analysts_tag
  analysts_tag=$(echo "$analysts" | tr ',' '_' | tr -cd '[:alnum:]_')

  while [ $attempt -le $MAX_RETRIES ]; do
    echo "▶️  Attempt $attempt: $ticker from $start_date to $END_DATE"

    # Sanitize date for filenames
    local date_tag="${start_date}_to_${END_DATE}"

    local log_file="$LOG_DIR/${ticker}_${analysts_tag}_${date_tag}_attempt${attempt}.log"
    local plot_file="$LOG_DIR/${ticker}_${analysts_tag}_${date_tag}.png"

    if poetry run python3 src/backtester.py \
      --ticker "$ticker" \
      --start-date "$start_date" \
      --end-date "$END_DATE" \
      --initial-capital "$INITIAL_CAPITAL" \
      --margin-requirement "$MARGIN" \
      --selected-analysts "$analysts" \
      --llm-model "$MODEL" \
      --save-plot "$plot_file" \
      --show-reasoning \
      2>&1 | tee "$log_file"; then
        echo "✅  Success on attempt $attempt for $ticker"
        return 0
    else
        echo "❌  Failed attempt $attempt for $ticker"
        attempt=$((attempt + 1))

        year=$(date -jf "%Y-%m-%d" "$start_date" "+%Y")
        month_day=$(date -jf "%Y-%m-%d" "$start_date" "+%m-%d")
        start_date="$((year + 1))-$month_day"

        echo "🔁  Retrying with START_DATE=$start_date"
    fi
  done

  echo "❌  All $MAX_RETRIES attempts failed for $ticker"
  return 1
}


# —— Run all backtests —— 
for job in "${BACKTEST_JOBS[@]}"; do
  IFS=':' read -r ticker analysts <<< "$job"
  run_job "$ticker" "$analysts" "$START_DATE"
  echo
done

# —— Show excluded tickers —— 
echo "📒 Excluded tickers (not run):"
for t in "${EXCLUDED[@]}"; do echo "  • $t"; done

# —— Quick Summary —— 
echo
echo "📊 Consolidated Performance Summary:"
printf "%-5s  %-8s  %-7s  %-8s  %-9s  %-9s  %-9s\n" \
  "TICK" "RETURN" "SHARPE" "SORTINO" "WIN/LOSS" "DRAWDOWN" "WIN%"

for log in "$LOG_DIR"/*.log; do
  tick=$(basename "$log" .log)

  ret=$(grep -E "Total Return:" "$log" | tail -n 1 | awk '{print $3}')
  sharpe=$(grep -E "^Sharpe Ratio:" "$log" | tail -n 1 | awk '{print $3}')
  sortino=$(grep -E "^Sortino Ratio:" "$log" | tail -n 1 | awk '{print $3}')
  wl_ratio=$(grep -E "^Win/Loss Ratio:" "$log" | tail -n 1 | awk '{print $3}')
  winpct=$(grep -E "^Win Rate:" "$log" | tail -n 1 | awk '{print $3}')
  dd=$(grep -E "^Maximum Drawdown:" "$log" | tail -n 1 | sed -E 's/.*Drawdown: ([0-9.]+%).*/\1/')

  printf "%-5s  %-8s  %-7s  %-8s  %-9s  %-9s  %-9s\n" \
    "$tick" "$ret" "$sharpe" "$sortino" "$wl_ratio" "$dd" "$winpct"
done
