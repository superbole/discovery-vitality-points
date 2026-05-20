import Toybox.Activity;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Math;
import Toybox.UserProfile;
import Toybox.Application.Properties;
import Toybox.ActivityMonitor;
import Toybox.FitContributor;
import Toybox.System;

//! Full-screen alert when projected Vitality points tier changes. App setting
//! DataFieldAlerts must be on; the user must also enable Activity settings ->
//! Alerts -> Connect IQ for this app (where supported).
class VitalityPointsChangeAlert extends WatchUi.DataFieldAlert {
    private var _fromPoints as Number;
    private var _toPoints as Number;

    function initialize(fromPoints as Number, toPoints as Number) {
        DataFieldAlert.initialize();
        _fromPoints = fromPoints;
        _toPoints = toPoints;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var title = _toPoints > _fromPoints ? "Points up" : "Points down";
        dc.drawText(w / 2, h / 2 - 24, Graphics.FONT_MEDIUM, title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(
            w / 2,
            h / 2 + 8,
            Graphics.FONT_SMALL,
            _fromPoints.toString() + " -> " + _toPoints.toString(),
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }
}

class DiscoveryVitalityPointsView extends WatchUi.DataField {

    private var mPoints as Number = 0;
    private var mMinutes as Number = 0;
    private var mGuidance as Dictionary<String, Number>?;
    private var mZone as Vitality.Calculator.Zone = Vitality.Calculator.ZONE_NOHR;
    private var mCurrentHR as Number? = null;
    private var mAvgHR as Number? = null;
    private var mStability as Dictionary<String, Number or Boolean>? = null;

    private var mAge as Number = 49;
    private var mPrimaryMetric as Number = 0; // 0 = points, 1 = avg HR, 2 = current HR
    // COMPACT/TILE: 0 = current HR, 1 = avg HR, 2 = points (see CompactMainMetric / CompactSecondaryMetric)
    private var mCompactMainMetric as Number = 0;
    private var mCompactSecondaryMetric as Number = 1;
    private var mIsEndurance as Boolean = false;
    private var mTargetPoints as Number? = null;
    private var mShowZone as Boolean = true;
    private var mShowHrGuidance as Boolean = true;
    private var mShowTierHeadroom as Boolean = false;
    // 0=Off 1=Values(bpm) 2=Names(V/M/L/E) 3=Both
    private var mHrAxisLabels as Number = 2;
    // 0=Off 1=Black 2=White 3=Red 4=Blue 5=Yellow 6=Green
    private var mCrosshairColorIndex as Number = 3;
    // Per-tier cell color indices (resolved to actual ColorValues in refreshSettings)
    // Defaults: 100=Charcoal, 200=Vitality Silver, 300=Hot Pink, 450=Pale Pink, 600=Hot Pink
    private var mTierColor100 as Number = 21;
    private var mTierColor200 as Number = 22;
    private var mTierColor300 as Number = 18;
    private var mTierColor450 as Number = 14;
    private var mTierColor600 as Number = 18;
    // Precomputed HR zone thresholds — set in refreshSettings to avoid Math.ceil in draw path
    private var mMaxHr    as Number = 171;
    private var mVigLow   as Number = 137;
    private var mModLow   as Number = 120;
    private var mLightLow as Number = 103;
    // Chart time range — set in drawLargeChartLayout to avoid Math.ceil in draw sub-functions
    private var mChartMaxMinutes as Number = 120;
    // Left edge of the chart time window (minutes); advances as user progresses
    private var mChartWindowStart as Number = 0;
    // Pre-resolved minute bounds array — computed in drawLargeChartLayout (depth 2) so
    // getMinuteBounds / bounds.add() never runs deeper than depth 3
    private var mMinuteBounds as Array<Number> = [0, 120];
    // Flat pre-resolved tier-points cache: mCellPointsCache[row * colCount + col]
    // Computed at depth 2 so getChartTierPoints never runs deeper than depth 3
    private var mCellPointsCache as Array<Number> = [];
    // Pre-resolved colors — avoids deep call chains inside the draw loop
    private var mResolvedColor100 as Graphics.ColorValue = 0xFFDD00 as Graphics.ColorValue;
    private var mResolvedColor200 as Graphics.ColorValue = 0xFF8800 as Graphics.ColorValue;
    private var mResolvedColor300 as Graphics.ColorValue = 0x44CC44 as Graphics.ColorValue;
    private var mResolvedColor450 as Graphics.ColorValue = 0x44CCAA as Graphics.ColorValue;
    private var mResolvedColor600 as Graphics.ColorValue = 0x4488FF as Graphics.ColorValue;
    private var mValidationMode as Boolean = false;
    private var mSoundAlerts as Boolean = true;
    private var mDataFieldAlerts as Boolean = true;
    private var mPointsHighlighted as Boolean = true; // glow halo + full contrast (default on)
    private var mHrRunningSum as Number = 0;
    private var mHrSampleCount as Number = 0;
    private var mChartSamples as Array<Dictionary<String, Number>> = [];
    private var mLastDurationMs as Number = 0;
    private var mLastPointsForAlert as Number? = null;
    private var mLastAtMaxTier as Boolean? = null;
    private var mFitPointsField as FitContributor.Field?;
    private var mIsRound as Boolean = false;

    function initialize() {
        DataField.initialize();
        var deviceSettings = System.getDeviceSettings();
        mIsRound = (deviceSettings.screenShape == System.SCREEN_SHAPE_ROUND);
        initializeFitField();
        refreshSettings();
    }

    //! Register a FIT developer field so final points are saved with activity data.
    private function initializeFitField() as Void {
        if (!(self has :createField)) {
            return;
        }

        try {
            mFitPointsField = createField(
                "vitalityPoints",
                0,
                FitContributor.DATA_TYPE_UINT16,
                {
                    :mesgType => FitContributor.MESG_TYPE_SESSION,
                    :units => "pts"
                }
            );
            mFitPointsField.setData(0);
        } catch (e) {
            mFitPointsField = null;
        }
    }

    function refreshSettings() as Void {
        mPrimaryMetric = Properties.getValue("PrimaryMetric");
        var cm = Properties.getValue("CompactMainMetric");
        mCompactMainMetric = (cm != null) ? cm : 0;
        var cs = Properties.getValue("CompactSecondaryMetric");
        mCompactSecondaryMetric = (cs != null) ? cs : 1;
        if (mCompactMainMetric == mCompactSecondaryMetric) {
            mCompactSecondaryMetric = (mCompactMainMetric + 1) % 3;
        }
        var ageSource = Properties.getValue("AgeSource");
        var birthYear = null;
        var birthMonth = null;
        var birthDay = null;

        if (ageSource == 0) { // Profile
            var profile = UserProfile.getProfile();
            if (profile != null && profile.birthYear != null) {
                birthYear = profile.birthYear;
                if (profile has :birthMonth) { birthMonth = profile.birthMonth; }
                if (profile has :birthDay) { birthDay = profile.birthDay; }
            }
        }

        // Fallback to manual birth date if profile is empty
        if (birthYear == null) {
            birthYear = Properties.getValue("BirthYear");
            birthMonth = Properties.getValue("BirthMonth");
            birthDay = Properties.getValue("BirthDay");
        }

        if (birthYear != null) {
            var today = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            mAge = today.year - birthYear;
            
            if (birthMonth != null) {
                if (today.month < birthMonth) {
                    mAge--;
                } else if (today.month == birthMonth && birthDay != null) {
                    if (today.day < birthDay) {
                        mAge--;
                    }
                }
            }
        } else {
            mAge = Properties.getValue("ManualAge");
        }

        mIsEndurance = Properties.getValue("IsEndurance");
        var guidanceMode = Properties.getValue("GuidanceMode");
        if (guidanceMode == 1) { // Target
            mTargetPoints = Properties.getValue("TargetPoints");
            if (!mIsEndurance && mTargetPoints != null && mTargetPoints > 300) {
                mTargetPoints = 300;
            }
        } else {
            mTargetPoints = null;
        }
        mShowZone = Properties.getValue("ShowZone");
        var showHrG = Properties.getValue("ShowHrGuidance");
        mShowHrGuidance = (showHrG != null) ? (showHrG as Boolean) : true;
        var showHead = Properties.getValue("ShowTierHeadroom");
        mShowTierHeadroom = (showHead != null) ? (showHead as Boolean) : false;
        var hrAxisLabels = Properties.getValue("HrAxisLabels");
        mHrAxisLabels = (hrAxisLabels != null) ? hrAxisLabels : 2;
        var crosshairColor = Properties.getValue("CrosshairColor");
        mCrosshairColorIndex = (crosshairColor != null) ? crosshairColor : 3;
        var tc100 = Properties.getValue("TierColor100");
        mTierColor100 = (tc100 != null) ? tc100 : 21; // Charcoal
        var tc200 = Properties.getValue("TierColor200");
        mTierColor200 = (tc200 != null) ? tc200 : 22; // Vitality Silver
        var tc300 = Properties.getValue("TierColor300");
        mTierColor300 = (tc300 != null) ? tc300 : 18; // Hot Pink
        var tc450 = Properties.getValue("TierColor450");
        mTierColor450 = (tc450 != null) ? tc450 : 14; // Pale Pink
        var tc600 = Properties.getValue("TierColor600");
        mTierColor600 = (tc600 != null) ? tc600 : 18; // Hot Pink
        // Pre-resolve to ColorValues once so the draw loop never calls getTierColorValue
        mResolvedColor100 = getTierColorValue(mTierColor100);
        mResolvedColor200 = getTierColorValue(mTierColor200);
        mResolvedColor300 = getTierColorValue(mTierColor300);
        mResolvedColor450 = getTierColorValue(mTierColor450);
        mResolvedColor600 = getTierColorValue(mTierColor600);
        var validationMode = Properties.getValue("ValidationMode");
        mValidationMode = (validationMode != null) ? validationMode : false;
        var pointsHighlighted = Properties.getValue("PointsHighlighted");
        mPointsHighlighted = (pointsHighlighted != null) ? (pointsHighlighted as Boolean) : true;
        mSoundAlerts = Properties.getValue("SoundAlerts");
        mDataFieldAlerts = Properties.getValue("DataFieldAlerts");
        mLastPointsForAlert = null;
        mLastAtMaxTier = null;
        // Pre-resolve HR thresholds so Math.ceil never runs inside the draw path
        mMaxHr    = Vitality.Calculator.getMaxHR(mAge);
        mVigLow   = Math.ceil(0.80 * mMaxHr).toNumber();
        mModLow   = Math.ceil(0.70 * mMaxHr).toNumber();
        mLightLow = Math.ceil(0.60 * mMaxHr).toNumber();
    }

    function compute(info as Activity.Info) as Void {
        // Prefer moving/active time if available, then elapsed.
        var durationMs = extractDurationMs(info);
        if (durationMs <= 10000 && mChartSamples.size() > 0) {
            // Fresh activity near 0: prevent previous-activity trace from flashing.
            resetSessionState();
        }
        if (durationMs > 0 && mLastDurationMs > 0 && durationMs < (mLastDurationMs - 5000)) {
            // New activity/session detected: clear any trace/history from prior ride.
            resetSessionState();
        }
        mLastDurationMs = durationMs;
        mMinutes = (durationMs / 60000).toNumber();
        mCurrentHR = extractCurrentHeartRate(info);
        mAvgHR = extractAverageHeartRate(info);

        var steps = null;
        if (info has :steps) {
            steps = info.steps;
        }

        var avgSpeed = null;
        if (info has :averageSpeed) {
            avgSpeed = info.averageSpeed;
        }

        var sport = null;
        if (Activity has :getProfileInfo) {
            var profileInfo = Activity.getProfileInfo();
            if (profileInfo != null && profileInfo has :sport) {
                sport = profileInfo.sport;
            }
        }
        
        if (sport == null) {
            var profile = UserProfile.getProfile();
            if (profile has :currentSport) {
                sport = profile.currentSport;
            }
        }

        mPoints = Vitality.Calculator.calculatePoints(mAge, mAvgHR, mMinutes, steps, mIsEndurance, avgSpeed, sport);
        mZone = Vitality.Calculator.getZone(mAge, mAvgHR);
        mGuidance = Vitality.Calculator.getGuidance(mAge, mAvgHR, mMinutes, mIsEndurance, mTargetPoints, avgSpeed, sport);
        mStability = Vitality.Calculator.getStabilityInfo(mAge, mAvgHR, mMinutes, mIsEndurance, avgSpeed, sport);
        recordChartSample(mMinutes, mAvgHR);

        // Precompute chart layout state here (depth 1) so onUpdate draw functions
        // never need to call Math.ceil, getChartMaxMinutes, getMinuteBounds, or
        // getChartTierPoints (all would overflow the FR745 ~8 KB stack at depth 4+).
        mChartMaxMinutes = getChartMaxMinutes();
        mMinuteBounds = getMinuteBounds(mChartMaxMinutes);
        mCellPointsCache = [];
        var numPreCols = mMinuteBounds.size() - 1;
        for (var pr = 0; pr < 4; pr++) {
            for (var pc = 0; pc < numPreCols; pc++) {
                var leftMin = mMinuteBounds[pc] as Number;
                mCellPointsCache.add(getChartTierPoints(pr, leftMin));
            }
        }
        mChartWindowStart = computeChartWindowStart();

        if (mFitPointsField != null) {
            mFitPointsField.setData(mPoints);
        }

        var maxTier = mIsEndurance ? 600 : 300;
        var atMax = mPoints >= maxTier;
        var maxEntered = mLastAtMaxTier != null && atMax && !mLastAtMaxTier;
        var maxLeft = mLastAtMaxTier != null && !atMax && mLastAtMaxTier;
        var pointsChanged = mLastPointsForAlert != null && mLastPointsForAlert != mPoints;

        if (mSoundAlerts && Attention has :playTone) {
            if (maxEntered) {
                Attention.playTone(Attention.TONE_SUCCESS);
            } else if (maxLeft) {
                Attention.playTone(Attention.TONE_FAILURE);
            } else if (pointsChanged) {
                if (mPoints > mLastPointsForAlert) {
                    Attention.playTone(Attention.TONE_ALERT_HI);
                } else {
                    Attention.playTone(Attention.TONE_ALERT_LO);
                }
            }
        }

        if (mDataFieldAlerts && mLastPointsForAlert != null && mLastPointsForAlert != mPoints) {
            if (WatchUi.DataField has :showAlert) {
                WatchUi.DataField.showAlert(new $.VitalityPointsChangeAlert(mLastPointsForAlert, mPoints));
            }
        }
        mLastPointsForAlert = mPoints;
        mLastAtMaxTier = atMax;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var backgroundColor = getBackgroundColor();
        dc.setColor(backgroundColor, backgroundColor);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        if (width == 0 || height == 0) {
            return;
        }

        var foregroundColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;

        if (!mIsRound && width >= 220 && height >= 150) {
            drawLargeChartLayout(dc, width, height, foregroundColor);
            return;
        }
        if (mIsRound && width >= 200 && height >= 150) {  // 200 covers 208px fr55, 218px fenix5s etc.
            drawRoundChartLayout(dc, width, height, foregroundColor);
            return;
        }
        // FR745 2-field (240×119): round standard — narrow matrix, no pipe guidance, centred HR/avg.
        if (mIsRound && width >= 200 && height >= 100 && height < 150) {
            drawStandardRoundLayout(dc, width, height, foregroundColor);
            return;
        }
        if (width >= 200 && height >= 100) {
            drawStandardLayout(dc, width, height, foregroundColor);
            return;
        }

        // COMPACT (w>=130) / TILE (w<130)
        drawCompactTileLayout(dc, width, height, foregroundColor);
    }

    //! COMPACT (`width >= 130`) / TILE (`width < 130`): two selectable metrics + pipe guidance.
    private function compactMetricString(code as Number) as String {
        if (code == 1) {
            if (mAvgHR != null && mAvgHR > 0) {
                return mAvgHR.toString();
            }
            return "--";
        }
        if (code == 2) {
            return mPoints.toString();
        }
        if (mCurrentHR != null && mCurrentHR > 0) {
            return mCurrentHR.toString();
        }
        return "--";
    }

    private function drawCompactTileLayout(dc as Graphics.Dc, width as Number, height as Number, foregroundColor as Graphics.ColorValue) as Void {
        var edgePad = 6;
        var ptsBg = getPointsColor(mPoints);
        var ink = getPointsTextColor(mPoints, foregroundColor);
        var guidanceText = buildGuidancePipeText();
        var guideFont = pickCompactGuidanceFont(height);
        var guideH = 0;
        if (guidanceText.length() > 0) {
            guideH = dc.getFontHeight(guideFont) + 4;
        }

        // Fill entire slot with points colour when points have been earned.
        // This makes day/night mode irrelevant — the background IS the colour signal.
        // Special case: 100pt tier uses device foreground as the fill (adaptive dark/light).
        if (getPointsColorIsForeground(mPoints)) {
            dc.setColor(foregroundColor, foregroundColor);
            dc.fillRectangle(0, 0, width, height);
        } else if (ptsBg != Graphics.COLOR_TRANSPARENT) {
            dc.setColor(ptsBg, ptsBg);
            dc.fillRectangle(0, 0, width, height);
        }

        var isTile = width < 130;
        var mainFont = isTile ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_HOT;
        var secFont = isTile ? Graphics.FONT_SMALL : Graphics.FONT_NUMBER_MEDIUM;

        var mainStr = compactMetricString(mCompactMainMetric);
        var secStr = compactMetricString(mCompactSecondaryMetric);

        var rowH = height - guideH - edgePad * 2;
        if (rowH < 14) {
            rowH = 14;
        }
        var rowMidY = edgePad + rowH / 2;

        // Wide round slots (e.g. FR745 3-field 240×86/68): centre the two metrics with a divider.
        if (mIsRound && width >= 200) {
            drawCompactRoundMetricRow(dc, width, rowMidY, mainFont, secFont, mainStr, secStr, ink, ink);
            if (guidanceText.length() > 0) {
                dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    width / 2,
                    height - edgePad - guideH / 2,
                    guideFont,
                    guidanceText,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
            }
            drawDevLayoutTierBadge(dc, width, height, 6);
            return;
        }

        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(getLeftMetricTextX(), rowMidY, mainFont, mainStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width - edgePad - 2, rowMidY, secFont, secStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (guidanceText.length() > 0) {
            dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                width / 2,
                height - edgePad - guideH / 2,
                guideFont,
                guidanceText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
        drawDevLayoutTierBadge(dc, width, height, isTile ? 4 : 3);
    }

    //! COMPACT-ROUND: centre main + secondary with small heart (HR+avg) or dot separator.
    private function drawCompactRoundMetricRow(
        dc as Graphics.Dc,
        width as Number,
        rowMidY as Number,
        mainFont as Graphics.FontDefinition,
        secFont as Graphics.FontDefinition,
        mainStr as String,
        secStr as String,
        mainColor as Graphics.ColorValue,
        secondaryInk as Graphics.ColorValue
    ) as Void {
        var useHeart = (mCompactMainMetric == 0 && mCompactSecondaryMetric == 1);
        var heartHalf = (dc.getFontHeight(mainFont) / 5).toNumber();
        if (heartHalf < 2) {
            heartHalf = 2;
        } else if (heartHalf > 5) {
            heartHalf = 5;
        }
        var pad = 6;
        var wL = dc.getTextWidthInPixels(mainStr, mainFont);
        var wR = dc.getTextWidthInPixels(secStr, secFont);
        var midW = 0;
        if (useHeart) {
            midW = 2 * heartHalf + 6;
        } else {
            midW = dc.getTextWidthInPixels("·", Graphics.FONT_TINY) + 8;
        }
        var total = wL + pad + midW + pad + wR;
        var x0 = (width - total) / 2;
        if (x0 < 4) {
            x0 = 4;
        }
        dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, rowMidY, mainFont, mainStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var xMid = x0 + wL + pad;
        if (useHeart) {
            drawFilledHeart(dc, xMid + heartHalf, rowMidY, heartHalf);
        } else {
            dc.setColor(secondaryInk, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xMid + midW / 2, rowMidY, Graphics.FONT_TINY, "·", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + wL + pad + midW + pad, rowMidY, secFont, secStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawLargeChartLayout(dc as Graphics.Dc, width as Number, height as Number, foregroundColor as Graphics.ColorValue) as Void {
        var edgePad = 8;
        var detailFont = Graphics.FONT_TINY;
        var hdrNumFont = mIsRound ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_HOT;
        var hdrH = dc.getFontHeight(hdrNumFont);
        var guidanceText = buildGuidancePipeText();
        var headroomLine = buildHeadroomSecondLineText(height, false);
        var guideFont = pickLargeRectChartGuidanceFont(detailFont);
        var microFont = Graphics.FONT_XTINY;
        var guideH = measureGuidanceBandHeight(dc, guidanceText, guideFont, headroomLine, microFont);

        var firstRowBottom = edgePad + hdrH + 4;
        var minTopAfterGuidance = firstRowBottom + (guideH > 0 ? guideH : 0);
        var chartTop = minTopAfterGuidance + 4;

        var xAxisPad = dc.getFontHeight(detailFont) + (height < 200 ? 6 : 12);
        var chartBottomPad = getChartBottomPad(height < 200 ? 8 : 12) + xAxisPad;
        var chartBottom = height - chartBottomPad;

        var minMatrixH = (height < 200) ? 40 : 48;
        if (chartBottom - chartTop < minMatrixH) {
            chartTop = chartBottom - minMatrixH;
        }
        if (chartTop < minTopAfterGuidance + 2) {
            chartTop = minTopAfterGuidance + 2;
            chartBottom = chartTop + minMatrixH;
            if (chartBottom > height - 4) {
                chartBottom = height - 4;
                chartTop = chartBottom - minMatrixH;
                if (chartTop < minTopAfterGuidance + 2) {
                    chartTop = minTopAfterGuidance + 2;
                }
            }
        }

        var yHrMid = edgePad + hdrH / 2;
        drawChartHeartRateHeader(dc, width, foregroundColor, hdrNumFont, yHrMid, edgePad);
        if (guidanceText.length() > 0 || headroomLine.length() > 0) {
            dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
            var y = firstRowBottom + 2;
            if (guidanceText.length() > 0) {
                var ph = dc.getFontHeight(guideFont);
                dc.drawText(width / 2, y + ph / 2, guideFont, guidanceText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                y += ph + 4;
            }
            if (headroomLine.length() > 0) {
                var mh = dc.getFontHeight(microFont);
                dc.drawText(width / 2, y + mh / 2, microFont, headroomLine, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        var maxHr = mMaxHr;
        var cL = getChartLeft();
        var cR = getChartRight(width);
        drawMatrixCells(dc, cL, cR, chartTop, chartBottom);
        drawMatrixGridAndLabels(dc, cL, cR, chartTop, chartBottom, detailFont, false);
        drawYAxisLabels(dc, chartTop, (chartBottom - chartTop).toNumber(), 4, detailFont, foregroundColor, maxHr, -1);
        drawBoldPoints(dc, cL, cR, chartTop, chartBottom, foregroundColor);
        drawCrosshair(dc, cL, cR, chartTop, chartBottom);
        drawTrendLine(dc, cL, cR, chartTop, chartBottom);
        if (mValidationMode) {
            drawValidationOverlay(dc, width, chartTop, chartBottom, detailFont, foregroundColor);
        }
        // tierCode: 0=chart-rect 1=chart-round 2=standard 3=compact 4=tile
        drawDevLayoutTierBadge(dc, width, height, 0);
    }

    private function drawTinyMatrixTileLayout(
        dc as Graphics.Dc,
        width as Number,
        height as Number,
        foregroundColor as Graphics.ColorValue,
        compactGuidanceText as String
    ) as Void {
        var labelFont = Graphics.FONT_XTINY;
        var valueFont = Graphics.FONT_SMALL;

        var leftPad = 18;
        var rightPad = 2;
        var topPad = 4;
        var bottomPad = 14;
        var plotLeft = leftPad;
        var plotTop = topPad;
        var plotRight = width - rightPad;
        var plotBottom = height - bottomPad;
        var plotWidth = (plotRight - plotLeft).toNumber();
        var plotHeight = (plotBottom - plotTop).toNumber();
        if (plotWidth < 40 || plotHeight < 24) {
            return;
        }

        var sliver = (plotHeight / 4).toNumber();
        if (sliver < 8) { sliver = 8; }
        if ((2 * sliver) > (plotHeight - 16)) {
            sliver = ((plotHeight - 16) / 2).toNumber();
        }
        var centerTop = plotTop + sliver;
        var centerBottom = plotBottom - sliver;
        var centerHeight = (centerBottom - centerTop).toNumber();

        var splitX = plotRight - sliver;
        if (splitX < (plotLeft + 24)) {
            splitX = plotLeft + 24;
        }

        var maxMinutes = getChartMaxMinutes();
        var minuteBounds = getMinuteBounds(maxMinutes);
        var col = getMinuteBandIndex(mMinutes, minuteBounds);
        var currentMinute = minuteBounds[col] as Number;
        var nextMinute = minuteBounds[col] as Number;
        if (col + 1 < minuteBounds.size()) {
            nextMinute = minuteBounds[col + 1] as Number;
        }

        var maxHr = Vitality.Calculator.getMaxHR(mAge);
        var currentRow = getHrRowForValue(mAvgHR, maxHr);
        var aboveRow = currentRow - 1;
        var belowRow = currentRow + 1;

        var aboveColorCurrent = getNeighborhoodCellColor(aboveRow, currentMinute);
        var midColorCurrent = getNeighborhoodCellColor(currentRow, currentMinute);
        var belowColorCurrent = getNeighborhoodCellColor(belowRow, currentMinute);
        var aboveColorNext = getNeighborhoodCellColor(aboveRow, nextMinute);
        var midColorNext = getNeighborhoodCellColor(currentRow, nextMinute);
        var belowColorNext = getNeighborhoodCellColor(belowRow, nextMinute);

        dc.setColor(aboveColorCurrent, aboveColorCurrent);
        dc.fillRectangle(plotLeft, plotTop, splitX - plotLeft, sliver);
        dc.setColor(midColorCurrent, midColorCurrent);
        dc.fillRectangle(plotLeft, centerTop, splitX - plotLeft, centerHeight);
        dc.setColor(belowColorCurrent, belowColorCurrent);
        dc.fillRectangle(plotLeft, centerBottom, splitX - plotLeft, sliver);

        dc.setColor(aboveColorNext, aboveColorNext);
        dc.fillRectangle(splitX, plotTop, plotRight - splitX, sliver);
        dc.setColor(midColorNext, midColorNext);
        dc.fillRectangle(splitX, centerTop, plotRight - splitX, centerHeight);
        dc.setColor(belowColorNext, belowColorNext);
        dc.fillRectangle(splitX, centerBottom, plotRight - splitX, sliver);

        // Matrix border lines: 1 vertical split + 2 horizontal center-band lines.
        var borderColor = foregroundColor;
        dc.setColor(borderColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(plotLeft, plotTop, plotRight - plotLeft, plotBottom - plotTop);
        dc.drawLine(splitX, plotTop, splitX, plotBottom);
        dc.drawLine(plotLeft, centerTop, plotRight, centerTop);
        dc.drawLine(plotLeft, centerBottom, plotRight, centerBottom);

        var hrNowText = mPoints.toString();
        if (mCurrentHR != null && mCurrentHR > 0) {
            hrNowText = mCurrentHR.toString();
        } else if (mAvgHR != null && mAvgHR > 0) {
            hrNowText = mAvgHR.toString();
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            plotLeft + ((splitX - plotLeft) / 2),
            centerTop + (centerHeight / 2),
            valueFont,
            hrNowText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // Border labels: one time split and two HR thresholds.
        var splitLabel = nextMinute.toString();
        if (col >= (minuteBounds.size() - 2)) {
            splitLabel = currentMinute.toString() + "+";
        }
        dc.drawText(splitX, plotBottom + 7, labelFont, splitLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var topHrLabel = getTopBoundaryHrForRow(currentRow, maxHr);
        var bottomHrLabel = getBottomBoundaryHrForRow(currentRow, maxHr);
        dc.drawText(plotLeft - 2, centerTop, labelFont, topHrLabel.toString(), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(plotLeft - 2, centerBottom, labelFont, bottomHrLabel.toString(), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Red trace with subtle halo; clamp to current column only.
        var lineLeft = plotLeft + 2;
        var lineRight = splitX - 2;
        var lastX = lineLeft;
        var lastY = centerTop + (centerHeight / 2);
        var hasLast = false;
        var prevX = lineLeft;
        var prevY = centerTop + (centerHeight / 2);
        var bandSpan = (nextMinute - currentMinute).toNumber();
        if (bandSpan < 1) { bandSpan = 1; }
        for (var i = 0; i < mChartSamples.size(); i++) {
            var sample = mChartSamples[i];
            var sampleMinute = sample["m"];
            var sampleHr = sample["hr"];
            if (sampleMinute == null || sampleHr == null) {
                continue;
            }
            if (sampleMinute < currentMinute || sampleMinute > nextMinute) {
                continue;
            }
            var xRatio = ((sampleMinute - currentMinute).toFloat() / bandSpan.toFloat());
            var x = (lineLeft + (xRatio * (lineRight - lineLeft))).toNumber();
            var y = mapHeartRateToChartY(sampleHr, plotTop, plotBottom, maxHr);
            if (hasLast) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(prevX, prevY - 1, x, y - 1);
                dc.drawLine(prevX, prevY + 1, x, y + 1);
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(prevX, prevY, x, y);
            }
            prevX = x;
            prevY = y;
            lastX = x;
            lastY = y;
            hasLast = true;
        }

        if (!hasLast && mAvgHR != null && mAvgHR > 0) {
            lastX = lineRight;
            lastY = mapHeartRateToChartY(mAvgHR, plotTop, plotBottom, maxHr);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(lineLeft, lastY - 1, lastX, lastY - 1);
            dc.drawLine(lineLeft, lastY + 1, lastX, lastY + 1);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(lineLeft, lastY, lastX, lastY);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lastX, lastY, 3);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(lastX, lastY, 2);

        var tinyGuidance = buildTinyGuidanceText(compactGuidanceText);
        if (tinyGuidance.length() > 0) {
            dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height - 2, labelFont, tinyGuidance, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function buildTinyGuidanceText(compactGuidanceText as String) as String {
        var text = "";
        if (mGuidance != null) {
            var nextPoints = mGuidance["nextPoints"];
            if (nextPoints != null && nextPoints > mPoints) {
                var minsNeeded = mGuidance["minsNeeded"];
                if (minsNeeded != null && minsNeeded > 0) {
                    text = minsNeeded + "m";
                }
                var hrNeeded = mGuidance["hrNeeded"];
                if (mShowHrGuidance && hrNeeded != null && hrNeeded > 0 && mAvgHR != null && mAvgHR > 0) {
                    var d = (hrNeeded as Number) - (mAvgHR as Number);
                    if (d > 0) {
                        if (text.length() > 0) {
                            text += "/";
                        }
                        text += "↑" + d.toString();
                    }
                }
            }
        }
        var margin = getHeadroomMarginBpm();
        if (margin > 0) {
            if (text.length() > 0) {
                text += "/";
            }
            text += "↓" + margin.toString();
        }
        if (text.length() == 0) {
            text = compactGuidanceText;
        }
        if (text.length() > 15) {
            text = text.substring(0, 15);
        }
        return text;
    }

    private function getMinuteBandIndex(minutes as Number, bounds as Array<Number>) as Number {
        var m = minutes;
        if (m < 0) { m = 0; }
        for (var i = 0; i < bounds.size() - 1; i++) {
            var right = bounds[i + 1] as Number;
            if (m < right) {
                return i;
            }
        }
        return bounds.size() - 2;
    }

    private function getHrRowForValue(hr as Number?, maxHr as Number) as Number {
        if (hr == null || hr <= 0) {
            return 3;
        }
        var lightLow = Math.ceil(0.60 * maxHr).toNumber();
        var modLow = Math.ceil(0.70 * maxHr).toNumber();
        var vigLow = Math.ceil(0.80 * maxHr).toNumber();
        if (hr >= vigLow) { return 0; }
        if (hr >= modLow) { return 1; }
        if (hr >= lightLow) { return 2; }
        return 3;
    }

    private function getNeighborhoodCellColor(row as Number, minutes as Number) as Graphics.ColorValue {
        if (row < 0 || row > 3) {
            return 0xDDDDDD as Graphics.ColorValue;
        }
        var pointsAtCell = getChartTierPoints(row, minutes);
        if (pointsAtCell <= 0) {
            return 0xDDDDDD as Graphics.ColorValue;
        }
        return getMatrixCellColor(pointsAtCell);
    }

    private function getTopBoundaryHrForRow(row as Number, maxHr as Number) as Number {
        var modLow = Math.ceil(0.70 * maxHr).toNumber();
        var vigLow = Math.ceil(0.80 * maxHr).toNumber();
        if (row == 1) { return vigLow; }
        if (row == 2) { return modLow; }
        if (row == 3) { return Math.ceil(0.60 * maxHr).toNumber(); }
        return maxHr;
    }

    private function getBottomBoundaryHrForRow(row as Number, maxHr as Number) as Number {
        var lightLow = Math.ceil(0.60 * maxHr).toNumber();
        var modLow = Math.ceil(0.70 * maxHr).toNumber();
        var vigLow = Math.ceil(0.80 * maxHr).toNumber();
        if (row == 0) { return vigLow; }
        if (row == 1) { return modLow; }
        if (row == 2) { return lightLow; }
        return 0;
    }

    private function drawFilledHeart(dc as Graphics.Dc, cx as Number, cy as Number, halfW as Number) as Void {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
        var r = (halfW * 7) / 10;
        if (r < 2) {
            r = 2;
        }
        dc.fillCircle(cx - halfW / 2, cy - halfW / 4, r);
        dc.fillCircle(cx + halfW / 2, cy - halfW / 4, r);
        var poly = [
            [cx - halfW - 1, cy - 1],
            [cx, cy + halfW + 2],
            [cx + halfW + 1, cy - 1]
        ] as Array;
        dc.fillPolygon(poly);
    }

    //! CHART-RECT / CHART-ROUND: red heart + large HR (left), large avg digits (right).
    private function drawChartHeartRateHeader(
        dc as Graphics.Dc,
        width as Number,
        foregroundColor as Graphics.ColorValue,
        hdrNumFont as Graphics.FontDefinition,
        yMid as Number,
        edgePad as Number
    ) as Void {
        var hrNow = "--";
        if (mCurrentHR != null && mCurrentHR > 0) {
            hrNow = mCurrentHR.toString();
        }
        var avgTxt = "--";
        if (mAvgHR != null && mAvgHR > 0) {
            avgTxt = mAvgHR.toString();
        }

        var heartHalf = (dc.getFontHeight(hdrNumFont) / 3).toNumber();
        if (heartHalf < 4) {
            heartHalf = 4;
        } else if (heartHalf > 8) {
            heartHalf = 8;
        }
        var xHeart = edgePad + heartHalf + 1;
        drawFilledHeart(dc, xHeart, yMid, heartHalf);

        var xHrDigits = edgePad + 2 * heartHalf + 10;
        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xHrDigits, yMid, hdrNumFont, hrNow, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.drawText(
            width - edgePad,
            yMid,
            hdrNumFont,
            avgTxt,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    //! CHART-ROUND / STANDARD-ROUND: HR and avg centred as a block with small heart between.
    private function drawChartHeartRateHeaderCentered(
        dc as Graphics.Dc,
        width as Number,
        foregroundColor as Graphics.ColorValue,
        hdrNumFont as Graphics.FontDefinition,
        yMid as Number
    ) as Void {
        var hrNow = "--";
        if (mCurrentHR != null && mCurrentHR > 0) {
            hrNow = mCurrentHR.toString();
        }
        var avgTxt = "--";
        if (mAvgHR != null && mAvgHR > 0) {
            avgTxt = mAvgHR.toString();
        }

        var heartHalf = (dc.getFontHeight(hdrNumFont) / 5).toNumber();
        if (heartHalf < 3) {
            heartHalf = 3;
        } else if (heartHalf > 6) {
            heartHalf = 6;
        }
        var pad = 8;
        var wHr = dc.getTextWidthInPixels(hrNow, hdrNumFont);
        var wAvg = dc.getTextWidthInPixels(avgTxt, hdrNumFont);
        var heartW = 2 * heartHalf + 6;
        var total = wHr + pad + heartW + pad + wAvg;
        var x0 = (width - total) / 2;
        if (x0 < 2) {
            x0 = 2;
        }
        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, yMid, hdrNumFont, hrNow, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        drawFilledHeart(dc, x0 + wHr + pad + heartHalf, yMid, heartHalf);
        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0 + wHr + pad + heartW + pad, yMid, hdrNumFont, avgTxt, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Draw colored matrix cells only. Kept deliberately small (few locals) so
    //! depth-4 Graphics calls fit in the FR745 ~8 KB stack.
    //! Reads mMinuteBounds, mChartWindowStart, mChartMaxMinutes, mCellPointsCache,
    //! mResolvedColor* — all precomputed in compute() at depth 1.
    private function drawMatrixCells(dc as Graphics.Dc, chartLeft as Number, chartRight as Number, chartTop as Number, chartBottom as Number) as Void {
        var chartWidth  = (chartRight - chartLeft).toNumber();
        var chartHeight = (chartBottom - chartTop).toNumber();
        if (chartWidth < 40 || chartHeight < 40) { return; }
        var colCount = mMinuteBounds.size() - 1;
        var winRange = (mChartMaxMinutes - mChartWindowStart).toNumber();
        if (winRange < 1) { winRange = 1; }
        var rowH = (chartHeight / 4).toNumber();

        for (var row = 0; row < 4; row++) {
            var rowTop = (chartTop + (row * rowH)).toNumber();
            for (var col = 0; col < colCount; col++) {
                var leftMin  = mMinuteBounds[col]     as Number;
                var rightMin = mMinuteBounds[col + 1] as Number;
                if (rightMin <= mChartWindowStart) { continue; }
                var adjLeft = leftMin - mChartWindowStart;
                if (adjLeft < 0) { adjLeft = 0; }
                var cellLeft  = (chartLeft + ((adjLeft * chartWidth) / winRange)).toNumber();
                var adjRight  = rightMin - mChartWindowStart;
                var cellRight = (chartLeft + ((adjRight * chartWidth) / winRange)).toNumber();
                var cellWidth = cellRight - cellLeft;
                if (cellWidth <= 0 || rowH <= 0) { continue; }
                var pts = mCellPointsCache[row * colCount + col] as Number;
                if (pts <= 0) { continue; }
                // Inline color selection — avoids depth-4 getMatrixCellColor call
                var cellColor = mResolvedColor100;
                if (pts >= 600) { cellColor = mResolvedColor600; }
                else if (pts >= 450) { cellColor = mResolvedColor450; }
                else if (pts >= 300) { cellColor = mResolvedColor300; }
                else if (pts >= 200) { cellColor = mResolvedColor200; }
                dc.setColor(cellColor, cellColor);
                dc.fillRectangle(cellLeft, rowTop, cellWidth, rowH);
            }
        }
    }

    //! Draw grid lines and X-axis tick labels. Split from drawMatrixCells to keep
    //! each function's frame small enough for the FR745 stack.
    private function drawMatrixGridAndLabels(
        dc as Graphics.Dc,
        chartLeft as Number,
        chartRight as Number,
        chartTop as Number,
        chartBottom as Number,
        detailFont as Graphics.FontDefinition,
        omitLastPlusLabel as Boolean
    ) as Void {
        var chartWidth  = (chartRight - chartLeft).toNumber();
        var chartHeight = (chartBottom - chartTop).toNumber();
        var colCount = mMinuteBounds.size() - 1;
        var winRange = (mChartMaxMinutes - mChartWindowStart).toNumber();
        if (winRange < 1) { winRange = 1; }

        dc.setColor(0x777777 as Graphics.ColorValue, Graphics.COLOR_TRANSPARENT);
        for (var r = 0; r <= 4; r++) {
            var lineY = (chartTop + ((r * chartHeight) / 4)).toNumber();
            dc.drawLine(chartLeft, lineY, chartRight, lineY);
        }
        for (var c = 0; c <= colCount; c++) {
            var t = mMinuteBounds[c] as Number;
            if (t < mChartWindowStart) { continue; }
            var lineX = (chartLeft + (((t - mChartWindowStart) * chartWidth) / winRange)).toNumber();
            dc.drawLine(lineX, chartTop, lineX, chartBottom);
        }

        var minGap = mIsRound ? 20 : 0;
        var lastX  = chartLeft - 100;
        for (var tick = 1; tick <= colCount; tick++) {
            var tickVal = mMinuteBounds[tick] as Number;
            if (tickVal <= mChartWindowStart) { continue; }
            var bX   = (chartLeft + (((tickVal - mChartWindowStart) * chartWidth) / winRange)).toNumber();
            var lX   = bX;
            var lTxt = tickVal.toString();
            var isLast = (tick == colCount);
            if (isLast) {
                var prevVal = mMinuteBounds[tick - 1] as Number;
                if (prevVal < mChartWindowStart) { prevVal = mChartWindowStart; }
                lX   = (chartLeft + ((((prevVal + tickVal - 2 * mChartWindowStart) / 2) * chartWidth) / winRange)).toNumber();
                lTxt = prevVal.toString() + "+";
            }
            if (isLast || (lX - lastX) >= minGap) {
                if (!(omitLastPlusLabel && isLast)) {
                    dc.drawText(lX, chartBottom + 8, detailFont, lTxt, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
                lastX = lX;
            }
        }
    }

    private function drawTrendLine(dc as Graphics.Dc, chartLeft as Number, chartRight as Number, chartTop as Number, chartBottom as Number) as Void {
        if (mChartSamples.size() < 2) {
            return;
        }

        var maxMinutes = mChartMaxMinutes;
        var winStart = mChartWindowStart;
        var winRangeF = (maxMinutes - winStart).toFloat();
        if (winRangeF < 1.0) { winRangeF = 1.0; }
        var prevX = -1;
        var prevY = -1;
        var hasPrev = false;
        var lastX = -1;
        var lastY = -1;

        // Draw a clear trace line; keep points clean except the final marker.
        for (var i = 0; i < mChartSamples.size(); i++) {
            var sample = mChartSamples[i];
            var sampleMinute = sample["m"];
            var sampleHr = sample["hr"];
            if (sampleMinute == null || sampleHr == null) {
                continue;
            }
            var clampedMinute = sampleMinute;
            if (clampedMinute < winStart) {
                clampedMinute = winStart;
            } else if (clampedMinute > maxMinutes) {
                clampedMinute = maxMinutes;
            }

            var xRatio = ((clampedMinute - winStart).toFloat() / winRangeF);
            var x = (chartLeft + (xRatio * (chartRight - chartLeft))).toNumber();
            var y = mapHeartRateToChartY(sampleHr, chartTop, chartBottom, mMaxHr);
            if (hasPrev) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(prevX, prevY - 1, x, y - 1);
                dc.drawLine(prevX, prevY + 1, x, y + 1);
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(prevX, prevY, x, y);
            }
            prevX = x;
            prevY = y;
            lastX = x;
            lastY = y;
            hasPrev = true;
        }

        // Mark only the latest point for quick glance reading.
        if (lastX >= 0 && lastY >= 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lastX, lastY, 3);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lastX, lastY, 2);
        }
    }

    private function drawValidationOverlay(dc as Graphics.Dc, width as Number, chartTop as Number, chartBottom as Number, detailFont as Graphics.FontDefinition, foregroundColor as Graphics.ColorValue) as Void {
        if (mAvgHR == null || mAvgHR <= 0) {
            return;
        }

        var y = mapHeartRateToChartY(mAvgHR, chartTop, chartBottom, mMaxHr);
        var chartLeft = getChartLeft();
        var chartRight = getChartRight(width);

        // Current average-HR horizontal guide.
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(chartLeft, y, chartRight, y);

        // Compact debug text.
        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        var zoneTxt = getZoneText(mZone);
        var debug = "VAL m" + mMinutes + " avg" + mAvgHR + " y" + y + " " + zoneTxt;
        dc.drawText(
            chartLeft,
            chartTop - 6,
            detailFont,
            debug,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function getChartMaxMinutes() as Number {
        // Keep explicit final "+" band visible by reserving room beyond the
        // highest threshold we care about for each mode.
        var minWindow = mIsEndurance ? 210 : 120;
        var maxWindow = 300; // practical cap (5h) for readability
        var minutes = mMinutes;
        if (minutes < minWindow) {
            return minWindow;
        }
        var rounded = (Math.ceil(minutes.toFloat() / 30.0).toNumber() * 30).toNumber();
        if (rounded < minWindow) {
            rounded = minWindow;
        }
        if (rounded > maxWindow) {
            rounded = maxWindow;
        }
        return rounded;
    }

    private function getMinuteBounds(maxChartMinutes as Number) as Array<Number> {
        var bounds = [0];
        if (mIsEndurance) {
            if (15 < maxChartMinutes) { bounds.add(15); }
            if (30 < maxChartMinutes) { bounds.add(30); }
            if (60 < maxChartMinutes) { bounds.add(60); }
            if (90 < maxChartMinutes) { bounds.add(90); }
            if (120 < maxChartMinutes) { bounds.add(120); }
            if (180 < maxChartMinutes) { bounds.add(180); }
        } else {
            if (15 < maxChartMinutes) { bounds.add(15); }
            if (30 < maxChartMinutes) { bounds.add(30); }
            if (60 < maxChartMinutes) { bounds.add(60); }
            if (90 < maxChartMinutes) { bounds.add(90); }
        }
        bounds.add(maxChartMinutes);
        return bounds;
    }

    private function mapHeartRateToChartY(hr as Number, chartTop as Number, chartBottom as Number, maxHr as Number) as Number {
        // Piecewise mapping to align the trace with matrix zone rows:
        // Easy (<60), Light (60-69), Moderate (70-79), Vigorous (80+).
        var chartHeight = (chartBottom - chartTop).toNumber();
        var rowH = (chartHeight / 4).toNumber();
        var row1Top = (chartTop + rowH).toNumber();
        var row2Top = (chartTop + (2 * rowH)).toNumber();
        var row3Top = (chartTop + (3 * rowH)).toNumber();

        var lightLow = mLightLow;
        var modLow   = mModLow;
        var vigLow   = mVigLow;

        var clampedHr = hr;
        if (clampedHr < 1) {
            clampedHr = 1;
        } else if (clampedHr > maxHr) {
            clampedHr = maxHr;
        }

        if (clampedHr >= vigLow) {
            var vigSpan = (maxHr - vigLow).toNumber();
            if (vigSpan < 1) { vigSpan = 1; }
            var vigNorm = ((clampedHr - vigLow).toFloat() / vigSpan.toFloat());
            return (row1Top - (vigNorm * rowH)).toNumber();
        } else if (clampedHr >= modLow) {
            var modSpan = (vigLow - modLow).toNumber();
            if (modSpan < 1) { modSpan = 1; }
            var modNorm = ((clampedHr - modLow).toFloat() / modSpan.toFloat());
            return (row2Top - (modNorm * rowH)).toNumber();
        } else if (clampedHr >= lightLow) {
            var lightSpan = (modLow - lightLow).toNumber();
            if (lightSpan < 1) { lightSpan = 1; }
            var lightNorm = ((clampedHr - lightLow).toFloat() / lightSpan.toFloat());
            return (row3Top - (lightNorm * rowH)).toNumber();
        }

        var easyHigh = lightLow - 1;
        if (easyHigh < 1) { easyHigh = 1; }
        var easyNorm = (clampedHr.toFloat() / easyHigh.toFloat());
        return (chartBottom - (easyNorm * rowH)).toNumber();
    }

    //! STANDARD layout uses 1/5 + 3/5 + 1/5 row heights, but mapHeartRateToChartY
    //! assumes four equal zone bands over the same height — Vig HR then lands in
    //! the top quarter and can plot above the first inner grid line (looks "above Vig").
    //! Map HR into the partial-top, centre, or partial-bottom band that matches the
    //! zoomed rows, with clamping when HR is outside the three visible zones.
    private function mapHeartRateToStandardZoomY(
        hr as Number,
        currentRow as Number,
        aboveRow as Number,
        belowRow as Number,
        partialTopY as Number,
        partialH as Number,
        centreTopY as Number,
        centreBottomY as Number,
        maxHr as Number
    ) as Number {
        var matrixBotY = centreBottomY + partialH - 1;
        var clampedHr = hr;
        if (clampedHr < 1) {
            clampedHr = 1;
        } else if (clampedHr > maxHr) {
            clampedHr = maxHr;
        }

        var zone = 3;
        if (clampedHr >= mVigLow) {
            zone = 0;
        } else if (clampedHr >= mModLow) {
            zone = 1;
        } else if (clampedHr >= mLightLow) {
            zone = 2;
        }

        var yMin = centreTopY;
        var yMax = centreBottomY - 1;
        var lo = 1;
        var hi = maxHr;

        if (zone == currentRow) {
            if (currentRow == 0) {
                lo = mVigLow;
                hi = maxHr;
            } else if (currentRow == 1) {
                lo = mModLow;
                hi = mVigLow - 1;
            } else if (currentRow == 2) {
                lo = mLightLow;
                hi = mModLow - 1;
            } else {
                lo = 1;
                hi = mLightLow - 1;
            }
        } else if (aboveRow >= 0 && zone == aboveRow) {
            yMin = partialTopY;
            yMax = partialTopY + partialH - 1;
            if (aboveRow == 0) {
                lo = mVigLow;
                hi = maxHr;
            } else if (aboveRow == 1) {
                lo = mModLow;
                hi = mVigLow - 1;
            } else if (aboveRow == 2) {
                lo = mLightLow;
                hi = mModLow - 1;
            } else {
                lo = 1;
                hi = mLightLow - 1;
            }
        } else if (belowRow <= 3 && zone == belowRow) {
            yMin = centreBottomY;
            yMax = matrixBotY;
            if (belowRow == 0) {
                lo = mVigLow;
                hi = maxHr;
            } else if (belowRow == 1) {
                lo = mModLow;
                hi = mVigLow - 1;
            } else if (belowRow == 2) {
                lo = mLightLow;
                hi = mModLow - 1;
            } else {
                lo = 1;
                hi = mLightLow - 1;
            }
        } else if (zone < currentRow) {
            return (partialTopY + (partialH / 2).toNumber());
        } else {
            return (centreBottomY + (partialH / 2).toNumber());
        }

        if (hi < lo) {
            hi = lo;
        }
        var c = clampedHr;
        if (c < lo) {
            c = lo;
        } else if (c > hi) {
            c = hi;
        }
        var span = hi - lo;
        if (span < 1) {
            span = 1;
        }
        var t = (c - lo).toFloat() / span.toFloat();
        var bandH = yMax - yMin;
        if (bandH < 1) {
            return yMin;
        }
        // Higher HR -> smaller y (top of band)
        return (yMax - (t * bandH).toNumber()).toNumber();
    }

    //! Returns the left edge of the chart plot area in pixels.
    private function getChartLeft() as Number {
        if (mHrAxisLabels == 0) { return 8; }   // Off: minimal margin
        if (mHrAxisLabels == 2) { return 32; }  // Names: room for 1-3 char label
        return 52;                               // Values or Both: room for 3-digit bpm
    }

    //! Returns the right edge of the chart plot area in pixels.
    private function getChartRight(width as Number) as Number {
        return width - 8;
    }

    //! Returns the bottom-of-chart padding in pixels.
    //! On round displays we raise the chart bottom so that the x-axis
    //! tick labels (drawn 8 px below chartBottom) stay within the circle.
    private function getChartBottomPad(baseBottomPad as Number) as Number {
        return mIsRound ? baseBottomPad + 12 : baseBottomPad;
    }

    private function getChartTierPoints(row as Number, minutes as Number) as Number {
        // Keep matrix rendering independent from calculator calls so chart draw
        // remains reliable even if runtime constraints differ by device.
        var points = 0;
        var is65Plus = (mAge >= 65);

        if (row == 3) { // Easy
            points = 0;
        } else if (row == 2) { // Light
            if (minutes >= 90) { points = 300; }
            else if (minutes >= 60) { points = 200; }
            else if (minutes >= 30) { points = 100; }
        } else if (row == 1) { // Moderate
            if (is65Plus) {
                if (minutes >= 30) { points = 300; }
            } else {
                if (minutes >= 60) { points = 300; }
                else if (minutes >= 30) { points = 200; }
                else if (minutes >= 15) { points = 100; }
            }
        } else { // Vigorous
            if (minutes >= 30) { points = 300; }
            else if (!is65Plus && minutes >= 15) { points = 100; }
        }

        if (mIsEndurance) {
            var endurancePoints = 0;
            if (row == 2) { // Light endurance ladder
                if (minutes >= 180) { endurancePoints = 600; }
                else if (minutes >= 120) { endurancePoints = 450; }
                else if (minutes >= 90) { endurancePoints = 300; }
            } else if (row <= 1) { // Moderate/Vigorous endurance ladder
                if (minutes >= 120) { endurancePoints = 600; }
                else if (minutes >= 90) { endurancePoints = 450; }
            }
            if (endurancePoints > points) {
                points = endurancePoints;
            }
        }

        return points;
    }

    private function getMatrixCellColor(points as Number) as Graphics.ColorValue {
        if (points <= 0) { return Graphics.COLOR_TRANSPARENT; }
        if (points >= 600) { return mResolvedColor600; }
        if (points >= 450) { return mResolvedColor450; }
        if (points >= 300) { return mResolvedColor300; }
        if (points >= 200) { return mResolvedColor200; }
        return mResolvedColor100;
    }

    private function getTierColorValue(idx as Number) as Graphics.ColorValue {
        switch (idx) {
            case 1:  return 0xFFFF99 as Graphics.ColorValue; // Pale Yellow
            case 2:  return 0xFFDD00 as Graphics.ColorValue; // Yellow
            case 3:  return 0xFFAA00 as Graphics.ColorValue; // Amber
            case 4:  return 0xFF8800 as Graphics.ColorValue; // Orange
            case 5:  return 0xFF5500 as Graphics.ColorValue; // Red-Orange
            case 6:  return 0xFF2200 as Graphics.ColorValue; // Red
            case 7:  return 0xFF6688 as Graphics.ColorValue; // Coral
            case 8:  return 0xAADD44 as Graphics.ColorValue; // Lt Green
            case 9:  return 0x44CC44 as Graphics.ColorValue; // Green
            case 10: return 0x44CCAA as Graphics.ColorValue; // Teal
            case 11: return 0x4488FF as Graphics.ColorValue; // Blue
            case 12: return 0x00CCFF as Graphics.ColorValue; // Cyan
            case 13: return 0xBBBBBB as Graphics.ColorValue; // Gray
            // Vitality pink ramp (added for default palette)
            case 14: return 0xFCE4F1 as Graphics.ColorValue; // Palest pink
            case 15: return 0xF8BBD0 as Graphics.ColorValue; // Soft pink
            case 16: return 0xF48AC1 as Graphics.ColorValue; // Mid pink
            case 17: return 0xF06292 as Graphics.ColorValue; // Mid-deep pink
            case 18: return 0xE91E8C as Graphics.ColorValue; // Hot pink
            case 19: return 0xC2185B as Graphics.ColorValue; // Deep crimson
            case 20: return 0x880E4F as Graphics.ColorValue; // Dark crimson
            case 21: return 0x424242 as Graphics.ColorValue; // Charcoal
            case 22: return 0xBDBDBD as Graphics.ColorValue; // Vitality Silver
            default: return Graphics.COLOR_TRANSPARENT;      // Off
        }
    }

    private function getHrAxisLabelForRow(row as Number, maxHr as Number) as String {
        var lightLow = Math.ceil(0.60 * maxHr).toNumber();
        var modLow = Math.ceil(0.70 * maxHr).toNumber();
        var vigLow = Math.ceil(0.80 * maxHr).toNumber();
        if (row == 0) {
            return ">= " + vigLow;
        } else if (row == 1) {
            return modLow + "-" + (vigLow - 1);
        } else if (row == 2) {
            return lightLow + "-" + (modLow - 1);
        }
        return "< " + lightLow;
    }

    private function buildChartGuidanceText() as String {
        return buildGuidancePipeText();
    }

    private function measureGuidanceBandHeight(
        dc as Graphics.Dc,
        pipeText as String,
        pipeFont as Graphics.FontDefinition,
        microLine as String,
        microFont as Graphics.FontDefinition
    ) as Number {
        var h = 0;
        if (pipeText.length() > 0) {
            h += dc.getFontHeight(pipeFont) + 4;
        }
        if (microLine.length() > 0) {
            h += dc.getFontHeight(microFont) + 2;
        }
        if (h > 0) {
            h += 2;
        }
        return h;
    }

    private function getHeadroomMarginBpm() as Number {
        if (!mShowTierHeadroom || mStability == null) {
            return 0;
        }
        var mg = mStability["marginBpm"];
        if (mg == null) {
            return 0;
        }
        var mgn = mg as Number;
        return (mgn > 0) ? mgn : 0;
    }

    //! Tall CHART slots: height >= 240. Tall STANDARD: height >= 110.
    private function buildHeadroomSecondLineText(height as Number, forStandardTier as Boolean) as String {
        var margin = getHeadroomMarginBpm();
        if (margin <= 0) {
            return "";
        }
        var tallEnough = forStandardTier ? (height >= 110) : (height >= 240);
        if (!tallEnough) {
            return "";
        }
        return (WatchUi.loadResource(Rez.Strings.GuidanceHeadroomSecondLine) as String) + margin.toString() + " bpm";
    }

    //! Next-tier + optional headroom: `12m | ↑5bpm | ↓12bpm` (wide) or slash form when narrow.
    private function buildGuidancePipeText() as String {
        return buildGuidancePipeTextInternal(false);
    }

    private function buildGuidancePipeTextInternal(narrowSlash as Boolean) as String {
        var downBpm = getHeadroomMarginBpm();
        var timePart = "";
        var upBpm = 0;
        if (mGuidance != null) {
            var nextPoints = mGuidance["nextPoints"];
            if (nextPoints != null && nextPoints > mPoints) {
                var minsNeeded = mGuidance["minsNeeded"];
                if (minsNeeded != null && minsNeeded > 0) {
                    timePart = minsNeeded.toString() + "m";
                }
                var hrNeeded = mGuidance["hrNeeded"];
                if (mShowHrGuidance && hrNeeded != null && hrNeeded > 0 && mAvgHR != null && mAvgHR > 0) {
                    var delta = (hrNeeded as Number) - (mAvgHR as Number);
                    if (delta > 0) {
                        upBpm = delta;
                    }
                }
            }
        }

        if (timePart.length() == 0 && upBpm == 0 && downBpm == 0) {
            return "";
        }

        var sep = narrowSlash ? "/" : " | ";
        var upSuffix = narrowSlash ? "" : "bpm";
        var dnSuffix = narrowSlash ? "" : "bpm";
        var out = "";
        if (timePart.length() > 0) {
            out = timePart;
        }
        if (upBpm > 0) {
            var upSeg = "↑" + upBpm.toString() + upSuffix;
            if (out.length() > 0) {
                out += sep + upSeg;
            } else {
                out = upSeg;
            }
        }
        if (downBpm > 0) {
            var dnSeg = "↓" + downBpm.toString() + dnSuffix;
            if (out.length() > 0) {
                out += sep + dnSeg;
            } else {
                out = dnSeg;
            }
        }
        if (narrowSlash && out.length() > 15) {
            out = out.substring(0, 15);
        }
        return out;
    }

    //! Left edge for left-justified HR digits: matches COMPACT/TILE main metric (`edgePad 6 + 2`).
    private function getLeftMetricTextX() as Number {
        return 8;
    }

    //! CHART-RECT only: one step larger than `pickChartGuidanceFontVsAxis` (axis TINY → MEDIUM).
    private function pickLargeRectChartGuidanceFont(axisFont as Graphics.FontDefinition) as Graphics.FontDefinition {
        if (axisFont == Graphics.FONT_XTINY) {
            return Graphics.FONT_SMALL;
        }
        if (axisFont == Graphics.FONT_TINY) {
            return Graphics.FONT_MEDIUM;
        }
        return Graphics.FONT_MEDIUM;
    }

    //! CHART / STANDARD pipe guidance: one step larger than y-axis tick font (`detailFont`).
    private function pickChartGuidanceFontVsAxis(axisFont as Graphics.FontDefinition) as Graphics.FontDefinition {
        if (axisFont == Graphics.FONT_XTINY) {
            return Graphics.FONT_TINY;
        }
        if (axisFont == Graphics.FONT_TINY) {
            return Graphics.FONT_SMALL;
        }
        return Graphics.FONT_SMALL;
    }

    //! COMPACT / TILE bottom guidance: readable but smaller than chart pipe.
    private function pickCompactGuidanceFont(height as Number) as Graphics.FontDefinition {
        if (height >= 80) {
            return Graphics.FONT_SMALL;
        }
        return Graphics.FONT_TINY;
    }

    function resetSessionState() as Void {
        mPoints = 0;
        mMinutes = 0;
        mGuidance = null;
        mZone = Vitality.Calculator.ZONE_NOHR;
        mCurrentHR = null;
        mAvgHR = null;
        mStability = null;

        mHrRunningSum = 0;
        mHrSampleCount = 0;
        mChartSamples = [];
        mLastDurationMs = 0;

        mLastPointsForAlert = null;
        mLastAtMaxTier = null;
        if (mFitPointsField != null) {
            mFitPointsField.setData(0);
        }
    }

    private function recordChartSample(minutes as Number, hr as Number?) as Void {
        if (hr == null || hr <= 0) {
            return;
        }

        var minuteInt = minutes.toNumber();
        if (mChartSamples.size() > 0) {
            var lastSample = mChartSamples[mChartSamples.size() - 1];
            var lastMinute = lastSample["m"];
            if (lastMinute != null && minuteInt < (lastMinute - 1)) {
                // Timer rolled back to a new activity; discard old trace history.
                mChartSamples = [];
                mHrRunningSum = 0;
                mHrSampleCount = 0;
            }
            if (lastMinute == minuteInt) {
                lastSample["hr"] = hr;
                return;
            }
        }

        mChartSamples.add({ "m" => minuteInt, "hr" => hr });
        while (mChartSamples.size() > 180) {
            mChartSamples.remove(mChartSamples[0]);
        }
    }

    //! Readable secondary text: avoid FONT_XTINY on full-size bike/wrist slots; still shrink for very short strips.
    //! Threshold raised to 80 px so that the small compact slots on round watches
    //! (e.g. 76 px tall 3-field rows on FR745) use FONT_TINY, keeping guidance
    //! text smaller and less likely to clip at the field boundary.
    private function pickCaptionFont(height as Number) as Graphics.FontDefinition {
        if (height < 80) {
            return Graphics.FONT_TINY;
        }
        return Graphics.FONT_SMALL;
    }

    private function pickDetailFont(captionFont as Graphics.FontDefinition, height as Number) as Graphics.FontDefinition {
        if (height < 52) {
            return Graphics.FONT_TINY;
        }
        // Keep detail text at least as readable as zone labels.
        return captionFont;
    }

    private function getHrStatusText(showNow as Boolean, showAvg as Boolean) as String {
        if (!showNow) {
            return "";
        }

        var nowPart = "";
        if (mCurrentHR != null && mCurrentHR > 0) {
            nowPart = "HR " + mCurrentHR;
        }

        if (!showAvg) {
            return nowPart;
        }

        var avgPart = "";
        if (mAvgHR != null && mAvgHR > 0) {
            avgPart = "Avg " + mAvgHR;
        }

        if (nowPart.length() > 0 && avgPart.length() > 0) {
            return nowPart + " | " + avgPart;
        }
        if (nowPart.length() > 0) {
            return nowPart;
        }
        return avgPart;
    }

    private function extractDurationMs(info as Activity.Info) as Number {
        if (info has :timerTime && info.timerTime != null && info.timerTime > 0) {
            return info.timerTime;
        }
        if (info has :elapsedTime && info.elapsedTime != null && info.elapsedTime > 0) {
            return info.elapsedTime;
        }
        if (info has :duration && info.duration != null && info.duration > 0) {
            return info.duration;
        }
        return 0;
    }

    private function extractAverageHeartRate(info as Activity.Info) as Number? {
        if (info has :averageHeartRate && info.averageHeartRate != null && info.averageHeartRate > 0) {
            return info.averageHeartRate;
        }
        if (info has :avgHeartRate && info.avgHeartRate != null && info.avgHeartRate > 0) {
            return info.avgHeartRate;
        }

        // SDK fallback: derive a running average from current HR if average isn't exposed.
        var currentHr = null;
        if (info has :currentHeartRate && info.currentHeartRate != null && info.currentHeartRate > 0) {
            currentHr = info.currentHeartRate;
        } else if (info has :heartRate && info.heartRate != null && info.heartRate > 0) {
            currentHr = info.heartRate;
        }

        if (currentHr != null) {
            mHrRunningSum += currentHr;
            mHrSampleCount += 1;
            if (mHrSampleCount > 0) {
                return (mHrRunningSum / mHrSampleCount).toNumber();
            }
        }
        return null;
    }

    private function extractCurrentHeartRate(info as Activity.Info) as Number? {
        if (info has :currentHeartRate && info.currentHeartRate != null && info.currentHeartRate > 0) {
            return info.currentHeartRate;
        }
        if (info has :heartRate && info.heartRate != null && info.heartRate > 0) {
            return info.heartRate;
        }
        return null;
    }

    //! Background fill colour for a given points value.
    //! Returns true when the points background fill should use the device foreground colour
    //! (i.e. the 100-point tier — device-adaptive: white block on dark watch, black on light).
    private function getPointsColorIsForeground(points as Number) as Boolean {
        return (points >= 100 && points < 200);
    }

    private function getPointsColor(points as Number) as Graphics.ColorValue {
        if (mIsEndurance) {
            if (points >= 600) { return 0xE91E8C as Graphics.ColorValue; } // Hot pink — goal achieved
            if (points >= 450) { return 0xFCE4F1 as Graphics.ColorValue; } // Pale pink — stepping stone
            if (points >= 300) { return 0xBDBDBD as Graphics.ColorValue; } // Vitality silver
            if (points >= 200) { return 0xBDBDBD as Graphics.ColorValue; } // Vitality silver
            // 100: caller uses foregroundColor as fill (device-adaptive)
            return Graphics.COLOR_TRANSPARENT;
        }
        // Standard palette
        if (points >= 300) { return 0xE91E8C as Graphics.ColorValue; } // Hot pink — goal achieved
        if (points >= 200) { return 0xBDBDBD as Graphics.ColorValue; } // Vitality silver
        // 100: caller uses foregroundColor as fill (device-adaptive)
        return Graphics.COLOR_TRANSPARENT;
    }

    //! Text/ink colour to use on top of a getPointsColor() background.
    //! Hot pink → white. Pale pink → dark crimson. Silver → dark text. Foreground fill → inverse.
    private function getPointsTextColor(points as Number, deviceForeground as Graphics.ColorValue) as Graphics.ColorValue {
        if (mIsEndurance) {
            if (points >= 600) { return Graphics.COLOR_WHITE; }                          // white on hot pink
            if (points >= 450) { return 0x880E4F as Graphics.ColorValue; }               // dark crimson on pale pink
            if (points >= 200) { return 0x212121 as Graphics.ColorValue; }               // dark text on silver
            if (points >= 100) {                                                          // inverse of foreground fill
                return (deviceForeground == Graphics.COLOR_WHITE)
                    ? (Graphics.COLOR_BLACK as Graphics.ColorValue)
                    : (Graphics.COLOR_WHITE as Graphics.ColorValue);
            }
            return deviceForeground;
        }
        // Standard
        if (points >= 300) { return Graphics.COLOR_WHITE; }                              // white on hot pink
        if (points >= 200) { return 0x212121 as Graphics.ColorValue; }                   // dark text on silver
        if (points >= 100) {                                                              // inverse of foreground fill
            return (deviceForeground == Graphics.COLOR_WHITE)
                ? (Graphics.COLOR_BLACK as Graphics.ColorValue)
                : (Graphics.COLOR_WHITE as Graphics.ColorValue);
        }
        return deviceForeground;
    }

    private function getZoneText(zone as Vitality.Calculator.Zone) as String {
        switch (zone) {
            case Vitality.Calculator.ZONE_VIGOROUS: return "VIGOROUS";
            case Vitality.Calculator.ZONE_MODERATE: return "MODERATE";
            case Vitality.Calculator.ZONE_LIGHT: return "LIGHT";
            case Vitality.Calculator.ZONE_BELOW: return "BELOW";
            default: return "NO HR";
        }
    }

    //! Glow/halo colour drawn behind the points text (±2px offset passes).
    //! Contrasts with the ink colour: dark halo behind white text, light halo behind dark text.
    private function getPointsGlowColor(points as Number, deviceForeground as Graphics.ColorValue) as Graphics.ColorValue {
        var ink = getPointsTextColor(points, deviceForeground);
        if (ink == Graphics.COLOR_WHITE) {
            // White text on hot pink → dark crimson halo gives punchy contrast
            return 0x880E4F as Graphics.ColorValue;
        }
        if (ink == (0x212121 as Graphics.ColorValue)) {
            // Dark text on silver → soft white glow lifts it off the background
            return Graphics.COLOR_WHITE;
        }
        if (ink == (0x880E4F as Graphics.ColorValue)) {
            // Dark crimson on pale pink → white glow
            return Graphics.COLOR_WHITE;
        }
        // Fallback: inverse of device foreground
        return (deviceForeground == Graphics.COLOR_WHITE)
            ? (Graphics.COLOR_BLACK as Graphics.ColorValue)
            : (Graphics.COLOR_WHITE as Graphics.ColorValue);
    }

    //! Returns the earliest minute shown on the left edge of the chart.
    //! Advances to the last passed threshold so the visible columns zoom in
    //! around the user's current position rather than always showing from 0.
    private function computeChartWindowStart() as Number {
        var ws = 0;
        if (mMinutes >= 15) { ws = 15; }
        if (mMinutes >= 30) { ws = 30; }
        if (mMinutes >= 60) { ws = 60; }
        if (mIsEndurance) {
            if (mMinutes >= 90)  { ws = 90; }
            if (mMinutes >= 120) { ws = 120; }
            if (mMinutes >= 180) { ws = 180; }
        } else {
            if (mMinutes >= 90) { ws = 90; }
        }
        // Never let the window start equal maxChartMinutes (would give 0-width window)
        var maxMin = mChartMaxMinutes;
        if (ws >= maxMin) { ws = maxMin - 30; }
        if (ws < 0) { ws = 0; }
        return ws;
    }

    //! Draw zone/HR labels on the Y-axis to the left of the chart.
    //! `axisHangRightX` < 0: legacy placement (slot-relative). >= 0: right-justify at this x (flush to chart).
    private function drawYAxisLabels(
        dc as Graphics.Dc,
        chartTop as Number,
        chartHeight as Number,
        rowCount as Number,
        detailFont as Graphics.FontDefinition,
        foregroundColor as Graphics.ColorValue,
        maxHr as Number,
        axisHangRightX as Number
    ) as Void {
        if (mHrAxisLabels == 0) { return; }
        var vigLow   = mVigLow;
        var modLow   = mModLow;
        var lightLow = mLightLow;
        var labelX = (axisHangRightX >= 0) ? axisHangRightX : (getChartLeft() - 4);
        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);

        if (mHrAxisLabels == 1) {
            // Values: numeric thresholds at the three interior row-boundary grid lines
            for (var r = 1; r <= 3; r++) {
                var lineY = (chartTop + ((r * chartHeight) / rowCount)).toNumber();
                var hrVal = 0;
                if (r == 1) { hrVal = vigLow; }
                else if (r == 2) { hrVal = modLow; }
                else { hrVal = lightLow; }
                dc.drawText(labelX, lineY, detailFont, hrVal.toString(), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        } else if (mHrAxisLabels == 2) {
            // Names: zone letter(s) centred in each row
            for (var row = 0; row < rowCount; row++) {
                var rowTop = (chartTop + ((row * chartHeight) / rowCount)).toNumber();
                var rowBottom = (chartTop + (((row + 1) * chartHeight) / rowCount)).toNumber();
                var rowMid = rowTop + ((rowBottom - rowTop) / 2);
                var name = "";
                if (row == 0) { name = mIsRound ? "V" : "Vig"; }
                else if (row == 1) { name = mIsRound ? "M" : "Mod"; }
                else if (row == 2) { name = mIsRound ? "L" : "Light"; }
                else { name = mIsRound ? "E" : "Easy"; }
                if (axisHangRightX >= 0) {
                    dc.drawText(labelX, rowMid, detailFont, name, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                } else {
                    dc.drawText(3, rowMid, detailFont, name, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }
        } else {
            // Both: zone name in top-third + bpm threshold in lower-third of each row
            for (var row = 0; row < rowCount; row++) {
                var rowTop = (chartTop + ((row * chartHeight) / rowCount)).toNumber();
                var rowBottom = (chartTop + (((row + 1) * chartHeight) / rowCount)).toNumber();
                var rowH = (rowBottom - rowTop).toNumber();
                var nameY = rowTop + (rowH / 3);
                var valY  = rowTop + ((2 * rowH) / 3);
                var name = "";
                if (row == 0) { name = mIsRound ? "V" : "Vig"; }
                else if (row == 1) { name = mIsRound ? "M" : "Mod"; }
                else if (row == 2) { name = mIsRound ? "L" : "Light"; }
                else { name = mIsRound ? "E" : "Easy"; }
                if (axisHangRightX >= 0) {
                    dc.drawText(labelX, nameY, detailFont, name, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                } else {
                    dc.drawText(3, nameY, detailFont, name, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                }
                if (row < 3) {
                    var hrVal = 0;
                    if (row == 0) { hrVal = vigLow; }
                    else if (row == 1) { hrVal = modLow; }
                    else { hrVal = lightLow; }
                    if (axisHangRightX >= 0) {
                        dc.drawText(labelX, valY, Graphics.FONT_XTINY, hrVal.toString(), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                    } else {
                        dc.drawText(3, valY, Graphics.FONT_XTINY, hrVal.toString(), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                    }
                }
            }
        }
    }

    //! Draw large bold points number centred on the chart (no "pts" suffix).
    //! When mPointsHighlighted: draws a ±2px glow in the halo colour first, then the text on top.
    //! When subdued: draws once at reduced opacity via a muted colour blend.
    private function drawBoldPoints(dc as Graphics.Dc, chartLeft as Number, chartRight as Number, chartTop as Number, chartBottom as Number, foregroundColor as Graphics.ColorValue) as Void {
        var cx = (chartLeft + chartRight) / 2;
        var cy = (chartTop + chartBottom) / 2;
        var numFont = mIsRound ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_HOT;
        var label = mPoints.toString();
        var inkColor = getPointsTextColor(mPoints, foregroundColor);
        if (mPointsHighlighted) {
            var haloColor = getPointsGlowColor(mPoints, foregroundColor);
            dc.setColor(haloColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - 2, cy,     numFont, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(cx + 2, cy,     numFont, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(cx,     cy - 2, numFont, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(cx,     cy + 2, numFont, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.setColor(inkColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, numFont, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Draw dashed crosshair lines at current avg-HR (horizontal) and elapsed time (vertical).
    private function drawCrosshair(dc as Graphics.Dc, chartLeft as Number, chartRight as Number, chartTop as Number, chartBottom as Number) as Void {
        if (mCrosshairColorIndex == 0) { return; }
        var color = getCrosshairColorValue();
        var chartWidth = (chartRight - chartLeft).toNumber();
        var maxMinutes = mChartMaxMinutes;
        var winStart = mChartWindowStart;
        var winRangeF = (maxMinutes - winStart).toFloat();
        if (winRangeF < 1.0) { winRangeF = 1.0; }
        var clampedMin = mMinutes;
        if (clampedMin < winStart) { clampedMin = winStart; }
        if (clampedMin > maxMinutes) { clampedMin = maxMinutes; }
        var vx = (chartLeft + (((clampedMin - winStart).toFloat() / winRangeF) * chartWidth)).toNumber();
        var hy = (mAvgHR != null && mAvgHR > 0)
            ? mapHeartRateToChartY(mAvgHR, chartTop, chartBottom, mMaxHr)
            : -1;
        // Dark halo at ±1 px — ensures visibility against both light and dark cells
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        drawDashedVLine(dc, vx - 1, chartTop, chartBottom);
        drawDashedVLine(dc, vx + 1, chartTop, chartBottom);
        if (hy >= 0) {
            drawDashedHLine(dc, chartLeft, chartRight, hy - 1);
            drawDashedHLine(dc, chartLeft, chartRight, hy + 1);
        }
        // Centre line in the user's chosen colour
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        drawDashedVLine(dc, vx, chartTop, chartBottom);
        if (hy >= 0) {
            drawDashedHLine(dc, chartLeft, chartRight, hy);
        }
    }

    private function drawDashedVLine(dc as Graphics.Dc, x as Number, y1 as Number, y2 as Number) as Void {
        var y = y1;
        var on = true;
        while (y < y2) {
            var next = y + (on ? 4 : 4);
            if (next > y2) { next = y2; }
            if (on) { dc.drawLine(x, y, x, next); }
            y = next;
            on = !on;
        }
    }

    private function drawDashedHLine(dc as Graphics.Dc, x1 as Number, x2 as Number, y as Number) as Void {
        var x = x1;
        var on = true;
        while (x < x2) {
            var next = x + (on ? 4 : 4);
            if (next > x2) { next = x2; }
            if (on) { dc.drawLine(x, y, next, y); }
            x = next;
            on = !on;
        }
    }

    private function getCrosshairColorValue() as Graphics.ColorValue {
        switch (mCrosshairColorIndex) {
            case 1: return Graphics.COLOR_BLACK;
            case 2: return Graphics.COLOR_WHITE;
            case 3: return Graphics.COLOR_RED;
            case 4: return 0x0055FF as Graphics.ColorValue;
            case 5: return Graphics.COLOR_YELLOW;
            case 6: return Graphics.COLOR_GREEN;
            default: return Graphics.COLOR_TRANSPARENT;
        }
    }

    //! Next-tier guidance. Uses pipe form when width allows; very narrow slots keep slash form.
    private function buildGuidanceText(width as Number) as String {
        return buildGuidancePipeTextInternal(width < 100);
    }

    private function drawRoundChartLayout(dc as Graphics.Dc, width as Number, height as Number, foregroundColor as Graphics.ColorValue) as Void {
        var edgePad = 24;
        var detailFont = Graphics.FONT_TINY;
        var hdrNumFont = Graphics.FONT_NUMBER_MEDIUM;
        var hdrH = dc.getFontHeight(hdrNumFont);
        var guidanceText = buildGuidancePipeText();
        var headroomLine = buildHeadroomSecondLineText(height, false);
        var guideFont = pickChartGuidanceFontVsAxis(detailFont);
        var microFont = Graphics.FONT_XTINY;
        var guideH = measureGuidanceBandHeight(dc, guidanceText, guideFont, headroomLine, microFont);
        guideFont = Graphics.FONT_MEDIUM; // bump one notch for rendering only — chartTop unaffected

        var firstRowBottom = edgePad + hdrH + 4;
        var minTopAfterGuidance = firstRowBottom + (guideH > 0 ? guideH : 0);
        var chartTop = minTopAfterGuidance + 4;

        var xAxisPad = dc.getFontHeight(detailFont) + (height < 200 ? 6 : 8);
        var chartBottomPad = getChartBottomPad(height < 200 ? 4 : 8) + xAxisPad;
        var chartBottom = height - chartBottomPad;

        var minMatrixH = (height < 200) ? 40 : 48;
        if (chartBottom - chartTop < minMatrixH) {
            chartTop = chartBottom - minMatrixH;
        }
        if (chartTop < minTopAfterGuidance + 2) {
            chartTop = minTopAfterGuidance + 2;
            chartBottom = chartTop + minMatrixH;
            if (chartBottom > height - 4) {
                chartBottom = height - 4;
                chartTop = chartBottom - minMatrixH;
                if (chartTop < minTopAfterGuidance + 2) {
                    chartTop = minTopAfterGuidance + 2;
                }
            }
        }

        var yHrMid = edgePad + hdrH / 2;
        drawChartHeartRateHeaderCentered(dc, width, foregroundColor, hdrNumFont, yHrMid);
        if (guidanceText.length() > 0 || headroomLine.length() > 0) {
            dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
            var y = firstRowBottom + 2;
            if (guidanceText.length() > 0) {
                var ph = dc.getFontHeight(guideFont);
                dc.drawText(width / 2, y + ph / 2, guideFont, guidanceText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                y += ph + 4;
            }
            if (headroomLine.length() > 0) {
                var mh = dc.getFontHeight(microFont);
                dc.drawText(width / 2, y + mh / 2, microFont, headroomLine, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        var cL = getChartLeft() + 4;
        var cR = getChartRight(width) - 18;
        drawMatrixCells(dc, cL, cR, chartTop, chartBottom);
        drawMatrixGridAndLabels(dc, cL, cR, chartTop, chartBottom, detailFont, true);
        drawYAxisLabels(dc, chartTop, (chartBottom - chartTop).toNumber(), 4, detailFont, foregroundColor, mMaxHr, cL - 2);
        drawBoldPoints(dc, cL, cR, chartTop, chartBottom, foregroundColor);
        drawCrosshair(dc, cL, cR, chartTop, chartBottom);
        drawTrendLine(dc, cL, cR, chartTop, chartBottom);
        if (mValidationMode) {
            drawValidationOverlay(dc, width, chartTop, chartBottom, detailFont, foregroundColor);
        }
        drawDevLayoutTierBadge(dc, width, height, 1);
    }

    //! STANDARD-ROUND (e.g. FR745 2-field 240×119): centred HR/avg, no pipe guidance, narrower matrix, no left zone letters.
    private function drawStandardRoundLayout(dc as Graphics.Dc, width as Number, height as Number, foregroundColor as Graphics.ColorValue) as Void {
        var edgePad = 8;
        var captionFont = Graphics.FONT_TINY;
        var captionH = dc.getFontHeight(captionFont);
        var bgColor = getBackgroundColor();
        var hdrNumFont = Graphics.FONT_NUMBER_MEDIUM;
        var hdrH = dc.getFontHeight(hdrNumFont);
        var yRow1 = edgePad + hdrH / 2;
        drawChartHeartRateHeaderCentered(dc, width, foregroundColor, hdrNumFont, yRow1);

        var roundSideInset = 22;
        var matrixLeft = edgePad + roundSideInset;
        var matrixRight = width - edgePad - roundSideInset;

        var matrixTop = edgePad + hdrH + 8;
        var matrixBottom = height - 22;
        var matrixH = matrixBottom - matrixTop;
        if (matrixH < 20) {
            matrixH = 20;
            matrixBottom = matrixTop + matrixH;
        }

        var centreH = (matrixH * 3) / 5;
        var partialH = matrixH / 5;
        var partialTopY = matrixTop;
        var centreTopY = matrixTop + partialH;
        var centreBottomY = centreTopY + centreH;
        var partialBotY = centreBottomY;

        var matrixW = matrixRight - matrixLeft;
        var currentColW = (matrixW * 3) / 4;
        var nextColW = matrixW / 4;
        var splitX = matrixLeft + currentColW;

        var currentRow = 3;
        if (mAvgHR != null && mAvgHR > 0) {
            if      (mAvgHR >= mVigLow)   { currentRow = 0; }
            else if (mAvgHR >= mModLow)   { currentRow = 1; }
            else if (mAvgHR >= mLightLow) { currentRow = 2; }
        }
        var aboveRow = currentRow - 1;
        var belowRow = currentRow + 1;
        var partialAboveRow = (aboveRow < 0) ? 0 : aboveRow;
        var partialBelowRow = (belowRow > 3) ? 3 : belowRow;

        var colCount = mMinuteBounds.size() - 1;
        var currentCol = getMinuteBandIndex(mMinutes, mMinuteBounds);
        var nextCol = (currentCol + 1 < colCount) ? currentCol + 1 : currentCol;

        drawStdCell(dc, matrixLeft, partialTopY,  currentColW, partialH, getStdCellColor(partialAboveRow, currentCol, colCount), bgColor, false);
        drawStdCell(dc, matrixLeft, centreTopY,   currentColW, centreH,  getStdCellColor(currentRow, currentCol, colCount), bgColor, false);
        drawStdCell(dc, matrixLeft, partialBotY,  currentColW, partialH, getStdCellColor(partialBelowRow, currentCol, colCount), bgColor, false);
        drawStdCell(dc, splitX,     partialTopY,  nextColW,    partialH, getStdCellColor(partialAboveRow, nextCol, colCount), bgColor, false);
        drawStdCell(dc, splitX,     centreTopY,   nextColW,    centreH,  getStdCellColor(currentRow, nextCol, colCount), bgColor, false);
        drawStdCell(dc, splitX,     partialBotY,  nextColW,    partialH, getStdCellColor(partialBelowRow, nextCol, colCount), bgColor, false);

        dc.setColor(0x777777 as Graphics.ColorValue, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(matrixLeft, centreTopY,    matrixRight, centreTopY);
        dc.drawLine(matrixLeft, centreBottomY, matrixRight, centreBottomY);
        if (nextColW > 0) {
            dc.drawLine(splitX, matrixTop, splitX, matrixBottom);
        }

        var numFont = hdrNumFont;
        if (centreH < 30 && hdrNumFont == Graphics.FONT_NUMBER_HOT) {
            numFont = Graphics.FONT_NUMBER_MEDIUM;
        }
        if (centreH < 22) {
            numFont = Graphics.FONT_SMALL;
        }
        var ptsCx = matrixLeft + currentColW / 2;
        var ptsCy = centreTopY + centreH / 2;
        var ptsLabel = mPoints.toString();
        var ptsInk = getPointsTextColor(mPoints, foregroundColor);
        if (mPointsHighlighted) {
            var ptsHalo = getPointsGlowColor(mPoints, foregroundColor);
            dc.setColor(ptsHalo, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ptsCx - 2, ptsCy,     numFont, ptsLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(ptsCx + 2, ptsCy,     numFont, ptsLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(ptsCx,     ptsCy - 2, numFont, ptsLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(ptsCx,     ptsCy + 2, numFont, ptsLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.setColor(ptsInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ptsCx, ptsCy, numFont, ptsLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (mCrosshairColorIndex != 0) {
            var xhColor = getCrosshairColorValue();
            dc.setColor(xhColor, Graphics.COLOR_TRANSPARENT);
            if (mAvgHR != null && mAvgHR > 0) {
                var hy = mapHeartRateToStandardZoomY(
                    mAvgHR,
                    currentRow,
                    aboveRow,
                    belowRow,
                    partialTopY,
                    partialH,
                    centreTopY,
                    centreBottomY,
                    mMaxHr
                );
                drawDashedHLine(dc, matrixLeft, splitX, hy);
            }
            var colL = mMinuteBounds[currentCol] as Number;
            var colR = mMinuteBounds[currentCol + 1] as Number;
            var colSpan = colR - colL;
            if (colSpan < 1) { colSpan = 1; }
            var minOff = mMinutes - colL;
            if (minOff < 0) { minOff = 0; }
            if (minOff > colSpan) { minOff = colSpan; }
            var vx = matrixLeft + (minOff * currentColW) / colSpan;
            drawDashedVLine(dc, vx, matrixTop, matrixBottom);
        }

        var tColL = mMinuteBounds[currentCol] as Number;
        var tColR = (currentCol + 1 < mMinuteBounds.size()) ? mMinuteBounds[currentCol + 1] as Number : tColL + 1;
        var tBand = (tColR - tColL).toNumber();
        if (tBand < 1) { tBand = 1; }
        var tLeft = matrixLeft + 2;
        var tRight = splitX - 2;
        var tPrevX = tLeft;
        var tPrevY = (centreTopY + centreBottomY) / 2;
        var tHas = false;
        for (var ti = 0; ti < mChartSamples.size(); ti++) {
            var tS = mChartSamples[ti];
            var tSm = tS["m"];
            var tSh = tS["hr"];
            if (tSm == null || tSh == null) { continue; }
            if (tSm < tColL || tSm > tColR) { continue; }
            var tXR = ((tSm - tColL).toFloat() / tBand.toFloat());
            var tx = (tLeft + (tXR * (tRight - tLeft))).toNumber();
            var ty = mapHeartRateToStandardZoomY(
                tSh,
                currentRow,
                aboveRow,
                belowRow,
                partialTopY,
                partialH,
                centreTopY,
                centreBottomY,
                mMaxHr
            );
            if (tHas) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(tPrevX, tPrevY - 1, tx, ty - 1);
                dc.drawLine(tPrevX, tPrevY + 1, tx, ty + 1);
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(tPrevX, tPrevY, tx, ty);
            }
            tPrevX = tx;
            tPrevY = ty;
            tHas = true;
        }
        if (tHas) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tPrevX, tPrevY, 3);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tPrevX, tPrevY, 2);
        }

        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        var colRightMin = mMinuteBounds[currentCol + 1] as Number;
        var xLabel = colRightMin.toString();
        if (currentCol >= colCount - 1) { xLabel = colRightMin.toString() + "+"; }
        dc.drawText(splitX, matrixBottom + 3 + captionH / 2, captionFont, xLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawDevLayoutTierBadge(dc, width, height, 5);
    }

    private function drawStandardLayout(dc as Graphics.Dc, width as Number, height as Number, foregroundColor as Graphics.ColorValue) as Void {
        var edgePad = 8;
        var captionFont = Graphics.FONT_TINY;
        var captionH = dc.getFontHeight(captionFont);
        var centerX = width / 2;
        var bgColor = getBackgroundColor();

        var yAxisW = (mHrAxisLabels == 0) ? 0 : 30;
        var matrixLeft = yAxisW;
        var matrixRight = width;

        var hdrNumFont = Graphics.FONT_NUMBER_MEDIUM;
        var guideFont = pickChartGuidanceFontVsAxis(captionFont);
        var guidanceText = buildGuidancePipeText();
        var headroomLine = buildHeadroomSecondLineText(height, true);
        var microFont = Graphics.FONT_XTINY;
        var hdrH = dc.getFontHeight(hdrNumFont);
        var gfh = dc.getFontHeight(guideFont);
        var row1H = hdrH;
        if (gfh > row1H) {
            row1H = gfh;
        }
        var row2H = 0;
        if (headroomLine.length() > 0) {
            row2H = dc.getFontHeight(microFont) + 2;
        }
        var rowBandH = row1H + row2H;
        var yRow1 = edgePad + row1H / 2;
        var yRow2 = edgePad + row1H + row2H / 2;

        var hrNow = "--";
        if (mCurrentHR != null && mCurrentHR > 0) {
            hrNow = mCurrentHR.toString();
        }
        var hrAvg = "--";
        if (mAvgHR != null && mAvgHR > 0) {
            hrAvg = mAvgHR.toString();
        }

        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(getLeftMetricTextX(), yRow1, hdrNumFont, hrNow, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (guidanceText.length() > 0) {
            dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, yRow1, guideFont, guidanceText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        dc.drawText(
            matrixRight - edgePad,
            yRow1,
            hdrNumFont,
            hrAvg,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        if (headroomLine.length() > 0) {
            dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, yRow2, microFont, headroomLine, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var matrixTop = edgePad + rowBandH + 8;
        var matrixBottom = height - 22;
        var matrixH = matrixBottom - matrixTop;
        if (matrixH < 20) {
            matrixH = 20;
            matrixBottom = matrixTop + matrixH;
        }

        var centreH = (matrixH * 3) / 5;
        var partialH = matrixH / 5;
        var partialTopY = matrixTop;
        var centreTopY = matrixTop + partialH;
        var centreBottomY = centreTopY + centreH;
        var partialBotY = centreBottomY;

        var matrixW = matrixRight - matrixLeft;
        var currentColW = (matrixW * 3) / 4;
        var nextColW = matrixW / 4;
        var splitX = matrixLeft + currentColW;

        var currentRow = 3;
        if (mAvgHR != null && mAvgHR > 0) {
            if      (mAvgHR >= mVigLow)   { currentRow = 0; }
            else if (mAvgHR >= mModLow)   { currentRow = 1; }
            else if (mAvgHR >= mLightLow) { currentRow = 2; }
        }
        var aboveRow = currentRow - 1;
        var belowRow = currentRow + 1;
        var partialAboveRow = (aboveRow < 0) ? 0 : aboveRow;
        var partialBelowRow = (belowRow > 3) ? 3 : belowRow;

        var colCount = mMinuteBounds.size() - 1;
        var currentCol = getMinuteBandIndex(mMinutes, mMinuteBounds);
        var nextCol = (currentCol + 1 < colCount) ? currentCol + 1 : currentCol;

        drawStdCell(dc, matrixLeft, partialTopY,  currentColW, partialH, getStdCellColor(partialAboveRow, currentCol, colCount), bgColor, false);
        drawStdCell(dc, matrixLeft, centreTopY,   currentColW, centreH,  getStdCellColor(currentRow, currentCol, colCount), bgColor, false);
        drawStdCell(dc, matrixLeft, partialBotY,  currentColW, partialH, getStdCellColor(partialBelowRow, currentCol, colCount), bgColor, false);
        drawStdCell(dc, splitX,     partialTopY,  nextColW,    partialH, getStdCellColor(partialAboveRow, nextCol, colCount), bgColor, false);
        drawStdCell(dc, splitX,     centreTopY,   nextColW,    centreH,  getStdCellColor(currentRow, nextCol, colCount), bgColor, false);
        drawStdCell(dc, splitX,     partialBotY,  nextColW,    partialH, getStdCellColor(partialBelowRow, nextCol, colCount), bgColor, false);

        dc.setColor(0x777777 as Graphics.ColorValue, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(matrixLeft, centreTopY,    matrixRight, centreTopY);
        dc.drawLine(matrixLeft, centreBottomY, matrixRight, centreBottomY);
        if (nextColW > 0) {
            dc.drawLine(splitX, matrixTop, splitX, matrixBottom);
        }

        var numFont = hdrNumFont;
        if (centreH < 30 && hdrNumFont == Graphics.FONT_NUMBER_HOT) {
            numFont = Graphics.FONT_NUMBER_MEDIUM;
        }
        if (centreH < 22) {
            numFont = Graphics.FONT_SMALL;
        }
        var ptsCx = matrixLeft + currentColW / 2;
        var ptsCy = centreTopY + centreH / 2;
        var ptsLabel = mPoints.toString();
        var ptsInk = getPointsTextColor(mPoints, foregroundColor);
        if (mPointsHighlighted) {
            var ptsHalo = getPointsGlowColor(mPoints, foregroundColor);
            dc.setColor(ptsHalo, Graphics.COLOR_TRANSPARENT);
            dc.drawText(ptsCx - 2, ptsCy,     numFont, ptsLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(ptsCx + 2, ptsCy,     numFont, ptsLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(ptsCx,     ptsCy - 2, numFont, ptsLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(ptsCx,     ptsCy + 2, numFont, ptsLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.setColor(ptsInk, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ptsCx, ptsCy, numFont, ptsLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (mCrosshairColorIndex != 0) {
            var xhColor = getCrosshairColorValue();
            dc.setColor(xhColor, Graphics.COLOR_TRANSPARENT);
            if (mAvgHR != null && mAvgHR > 0) {
                var hy = mapHeartRateToStandardZoomY(
                    mAvgHR,
                    currentRow,
                    aboveRow,
                    belowRow,
                    partialTopY,
                    partialH,
                    centreTopY,
                    centreBottomY,
                    mMaxHr
                );
                drawDashedHLine(dc, matrixLeft, splitX, hy);
            }
            var colL = mMinuteBounds[currentCol] as Number;
            var colR = mMinuteBounds[currentCol + 1] as Number;
            var colSpan = colR - colL;
            if (colSpan < 1) { colSpan = 1; }
            var minOff = mMinutes - colL;
            if (minOff < 0) { minOff = 0; }
            if (minOff > colSpan) { minOff = colSpan; }
            var vx = matrixLeft + (minOff * currentColW) / colSpan;
            drawDashedVLine(dc, vx, matrixTop, matrixBottom);
        }

        var tColL = mMinuteBounds[currentCol] as Number;
        var tColR = (currentCol + 1 < mMinuteBounds.size()) ? mMinuteBounds[currentCol + 1] as Number : tColL + 1;
        var tBand = (tColR - tColL).toNumber();
        if (tBand < 1) { tBand = 1; }
        var tLeft = matrixLeft + 2;
        var tRight = splitX - 2;
        var tPrevX = tLeft;
        var tPrevY = (centreTopY + centreBottomY) / 2;
        var tHas = false;
        for (var ti = 0; ti < mChartSamples.size(); ti++) {
            var tS = mChartSamples[ti];
            var tSm = tS["m"];
            var tSh = tS["hr"];
            if (tSm == null || tSh == null) { continue; }
            if (tSm < tColL || tSm > tColR) { continue; }
            var tXR = ((tSm - tColL).toFloat() / tBand.toFloat());
            var tx = (tLeft + (tXR * (tRight - tLeft))).toNumber();
            var ty = mapHeartRateToStandardZoomY(
                tSh,
                currentRow,
                aboveRow,
                belowRow,
                partialTopY,
                partialH,
                centreTopY,
                centreBottomY,
                mMaxHr
            );
            if (tHas) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(tPrevX, tPrevY - 1, tx, ty - 1);
                dc.drawLine(tPrevX, tPrevY + 1, tx, ty + 1);
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(tPrevX, tPrevY, tx, ty);
            }
            tPrevX = tx;
            tPrevY = ty;
            tHas = true;
        }
        if (tHas) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tPrevX, tPrevY, 3);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tPrevX, tPrevY, 2);
        }

        if (mHrAxisLabels != 0 && yAxisW > 0) {
            dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
            var rowNames = ["V", "M", "L", "E"] as Array<String>;
            if (currentRow >= 0 && currentRow <= 3) {
                dc.drawText(yAxisW - 2, centreTopY + centreH / 2, captionFont, rowNames[currentRow], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
            if (partialH >= 11) {
                if (aboveRow >= 0 && aboveRow <= 3) {
                    dc.drawText(yAxisW - 2, partialTopY + partialH / 2, captionFont, rowNames[aboveRow], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                }
                if (belowRow >= 0 && belowRow <= 3) {
                    dc.drawText(yAxisW - 2, partialBotY + partialH / 2, captionFont, rowNames[belowRow], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }
        }

        dc.setColor(foregroundColor, Graphics.COLOR_TRANSPARENT);
        var colRightMin = mMinuteBounds[currentCol + 1] as Number;
        var xLabel = colRightMin.toString();
        if (currentCol >= colCount - 1) { xLabel = colRightMin.toString() + "+"; }
        dc.drawText(splitX, matrixBottom + 3 + captionH / 2, captionFont, xLabel, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawDevLayoutTierBadge(dc, width, height, 2);
    }

    //! Faint design-spec tier label bottom-right (for simulator / layout checks).
    //! tierCode: 0=chart-rect 1=chart-round 2=standard 3=compact 4=tile 5=std-rnd 6=cmp-rnd
    private function drawDevLayoutTierBadge(dc as Graphics.Dc, width as Number, height as Number, tierCode as Number) as Void {
        if (!mValidationMode) {
            return;
        }
        var tag = "standard";
        if (tierCode == 0) {
            tag = (width < 120) ? "c-rect" : "chart-rect";
        } else if (tierCode == 1) {
            tag = (width < 120) ? "c-rnd" : "chart-round";
        } else if (tierCode == 2) {
            tag = (width < 130) ? "std" : "standard";
        } else if (tierCode == 3) {
            tag = (width < 100) ? "cmp" : "compact";
        } else if (tierCode == 5) {
            tag = "std-rnd";
        } else if (tierCode == 6) {
            tag = "cmp-rnd";
        } else {
            tag = "tile";
        }
        var bg = getBackgroundColor();
        var faint = (bg == Graphics.COLOR_BLACK) ? (0x606060 as Graphics.ColorValue) : (0xA0A0A0 as Graphics.ColorValue);
        var tagFont = Graphics.FONT_XTINY;
        var fh = dc.getFontHeight(tagFont);
        dc.setColor(faint, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 2, height - 3 - fh / 2, tagFont, tag, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function getStdCellColor(row as Number, col as Number, colCount as Number) as Graphics.ColorValue {
        if (row < 0 || row > 3 || col < 0 || col >= colCount) {
            return Graphics.COLOR_TRANSPARENT;
        }
        var idx = row * colCount + col;
        if (idx >= mCellPointsCache.size()) { return Graphics.COLOR_TRANSPARENT; }
        var pts = mCellPointsCache[idx] as Number;
        if (pts <= 0) { return Graphics.COLOR_TRANSPARENT; }
        if (pts >= 600) { return mResolvedColor600; }
        if (pts >= 450) { return mResolvedColor450; }
        if (pts >= 300) { return mResolvedColor300; }
        if (pts >= 200) { return mResolvedColor200; }
        return mResolvedColor100;
    }

    private function drawStdCell(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, color as Graphics.ColorValue, bgColor as Graphics.ColorValue, faded as Boolean) as Void {
        if (w <= 0 || h <= 0 || color == Graphics.COLOR_TRANSPARENT) { return; }
        var drawColor = color;
        if (faded) {
            var r = (((color >> 16) & 0xFF) + ((bgColor >> 16) & 0xFF)) / 2;
            var g = (((color >> 8) & 0xFF) + ((bgColor >> 8) & 0xFF)) / 2;
            var b = ((color & 0xFF) + (bgColor & 0xFF)) / 2;
            drawColor = ((r << 16) | (g << 8) | b) as Graphics.ColorValue;
        }
        dc.setColor(drawColor, drawColor);
        dc.fillRectangle(x, y, w, h);
    }
}
