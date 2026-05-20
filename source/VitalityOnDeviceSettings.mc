import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.UserProfile;
import Toybox.WatchUi;

//! On-device Connect IQ settings (AppBase.getSettingsView): root Menu2 plus pushed pick menus.

class VitalityDfRootMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => WatchUi.loadResource(Rez.Strings.SettingsMenuTitle)});
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingPrimaryMetric), primarySublabel(), "open_primary", {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingCompactMainMetric), compactMainSublabel(), "open_compact_main", {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingCompactSecondaryMetric), compactSecondarySublabel(), "open_compact_secondary", {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingAgeSource), ageSourceSublabel(), "open_age_src", {}));
        var ageSrc = Properties.getValue("AgeSource");
        var useManual = (ageSrc != null && (ageSrc as Number) == 1);
        if (useManual) {
            addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingBirthYear), birthYearSublabel(), "open_birth_y", {}));
            addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingBirthMonth), birthMonthSublabel(), "open_birth_m", {}));
            addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingBirthDay), birthDaySublabel(), "open_birth_d", {}));
            addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingManualAge), manualAgeSublabel(), "open_manual_age", {}));
        }
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.SettingIsEndurance), WatchUi.loadResource(Rez.Strings.SettingIsEnduranceHelp) as String, "IsEndurance", boolProp("IsEndurance"), {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingGuidanceMode), guidanceSublabel(), "open_guidance", {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingTargetPoints), targetPointsSublabel(), "open_target", {}));
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.SettingShowZone), WatchUi.loadResource(Rez.Strings.SettingShowZoneHelp) as String, "ShowZone", boolProp("ShowZone"), {}));
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.SettingShowHrGuidance), WatchUi.loadResource(Rez.Strings.SettingShowHrGuidanceHelp) as String, "ShowHrGuidance", boolProp("ShowHrGuidance"), {}));
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.SettingShowTierHeadroom), WatchUi.loadResource(Rez.Strings.SettingShowTierHeadroomHelp) as String, "ShowTierHeadroom", boolProp("ShowTierHeadroom"), {}));
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.SettingSoundAlerts), WatchUi.loadResource(Rez.Strings.SettingSoundAlertsHelp) as String, "SoundAlerts", boolProp("SoundAlerts"), {}));
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.SettingDataFieldAlerts), WatchUi.loadResource(Rez.Strings.SettingDataFieldAlertsHelp) as String, "DataFieldAlerts", boolProp("DataFieldAlerts"), {}));
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.SettingValidationMode), WatchUi.loadResource(Rez.Strings.SettingValidationModeHelp) as String, "ValidationMode", boolProp("ValidationMode"), {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingDisclaimerMenu), null, "open_disclaimer", {}));
    }

    private function primarySublabel() as String {
        var v = Properties.getValue("PrimaryMetric");
        if (v != null && (v as Number) == 1) {
            return WatchUi.loadResource(Rez.Strings.SettingPrimaryMetricAvgHr) as String;
        }
        if (v != null && (v as Number) == 2) {
            return WatchUi.loadResource(Rez.Strings.SettingPrimaryMetricCurrentHr) as String;
        }
        return WatchUi.loadResource(Rez.Strings.SettingPrimaryMetricPoints) as String;
    }

    private function compactMainSublabel() as String {
        var v = Properties.getValue("CompactMainMetric");
        if (v != null && (v as Number) == 1) {
            return WatchUi.loadResource(Rez.Strings.SettingCompactMetricAvg) as String;
        }
        if (v != null && (v as Number) == 2) {
            return WatchUi.loadResource(Rez.Strings.SettingCompactMetricPoints) as String;
        }
        return WatchUi.loadResource(Rez.Strings.SettingCompactMetricHr) as String;
    }

    private function compactSecondarySublabel() as String {
        var v = Properties.getValue("CompactSecondaryMetric");
        if (v != null && (v as Number) == 1) {
            return WatchUi.loadResource(Rez.Strings.SettingCompactMetricAvg) as String;
        }
        if (v != null && (v as Number) == 2) {
            return WatchUi.loadResource(Rez.Strings.SettingCompactMetricPoints) as String;
        }
        return WatchUi.loadResource(Rez.Strings.SettingCompactMetricHr) as String;
    }

    private function ageSourceSublabel() as String {
        var v = Properties.getValue("AgeSource");
        if (v != null && (v as Number) == 1) {
            return WatchUi.loadResource(Rez.Strings.SettingAgeSourceManual) as String;
        }
        var profile = UserProfile.getProfile();
        if (profile != null && profile.birthYear != null) {
            var y = profile.birthYear as Number;
            var mo = null;
            var d = null;
            if (profile has :birthMonth) {
                mo = profile.birthMonth;
            }
            if (profile has :birthDay) {
                d = profile.birthDay;
            }
            if (mo != null && d != null) {
                return y + "-" + mo + "-" + d;
            }
            return y.toString();
        }
        return WatchUi.loadResource(Rez.Strings.SettingAgeSourceProfileNoDob) as String;
    }

    private function birthYearSublabel() as String {
        return Properties.getValue("BirthYear").toString();
    }

    private function birthMonthSublabel() as String {
        return Properties.getValue("BirthMonth").toString();
    }

    private function birthDaySublabel() as String {
        return Properties.getValue("BirthDay").toString();
    }

    private function manualAgeSublabel() as String {
        return Properties.getValue("ManualAge").toString();
    }

    private function guidanceSublabel() as String {
        var v = Properties.getValue("GuidanceMode");
        if (v != null && (v as Number) == 1) {
            return WatchUi.loadResource(Rez.Strings.SettingGuidanceModeTarget) as String;
        }
        return WatchUi.loadResource(Rez.Strings.SettingGuidanceModeNextTier) as String;
    }

    private function targetPointsSublabel() as String {
        return Properties.getValue("TargetPoints").toString();
    }

    private function boolProp(key as String) as Boolean {
        var v = Properties.getValue(key);
        return (v != null) ? (v as Boolean) : false;
    }
}

class VitalityDfRootDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) as Void {
        if (item instanceof ToggleMenuItem) {
            var t = item as ToggleMenuItem;
            var tid = t.getId();
            if (tid instanceof String) {
                Properties.setValue(tid as String, t.isEnabled());
                getApp().onSettingsChanged();
            }
            return;
        }

        var id = item.getId();
        if (!(id instanceof String)) {
            return;
        }

        var nav = id as String;
        if (nav.equals("open_primary")) {
            VitalityDfSettingsActions.pushPrimaryMetricMenu();
        } else if (nav.equals("open_compact_main")) {
            VitalityDfSettingsActions.pushCompactMainMetricMenu();
        } else if (nav.equals("open_compact_secondary")) {
            VitalityDfSettingsActions.pushCompactSecondaryMetricMenu();
        } else if (nav.equals("open_age_src")) {
            VitalityDfSettingsActions.pushAgeSourceMenu();
        } else if (nav.equals("open_birth_y")) {
            VitalityDfSettingsActions.pushBirthYearMenu();
        } else if (nav.equals("open_birth_m")) {
            VitalityDfSettingsActions.pushBirthMonthMenu();
        } else if (nav.equals("open_birth_d")) {
            VitalityDfSettingsActions.pushBirthDayMenu();
        } else if (nav.equals("open_manual_age")) {
            VitalityDfSettingsActions.pushManualAgeMenu();
        } else if (nav.equals("open_guidance")) {
            VitalityDfSettingsActions.pushGuidanceModeMenu();
        } else if (nav.equals("open_target")) {
            VitalityDfSettingsActions.pushTargetPointsMenu();
        } else if (nav.equals("open_disclaimer")) {
            WatchUi.pushView(new VitalityDisclaimerView(), new VitalityDisclaimerDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

class VitalityDisclaimerView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var x = w / 2;
        var y = 12;
        var lines = [
            WatchUi.loadResource(Rez.Strings.DisclaimerLine1) as String,
            WatchUi.loadResource(Rez.Strings.DisclaimerLine2) as String,
            WatchUi.loadResource(Rez.Strings.DisclaimerLine3) as String,
            WatchUi.loadResource(Rez.Strings.DisclaimerLine4) as String,
            WatchUi.loadResource(Rez.Strings.DisclaimerLine5) as String
        ] as Array<String>;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(x, y, Graphics.FONT_XTINY, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += dc.getFontHeight(Graphics.FONT_XTINY) + 6;
        }
        y += 8;
        dc.drawText(x, y, Graphics.FONT_XTINY, "Press Back to close", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class VitalityDisclaimerDelegate extends WatchUi.InputDelegate {

    function initialize() {
        InputDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}

class VitalityPropIntDelegate extends WatchUi.Menu2InputDelegate {

    private var _key as String;

    function initialize(propertyKey as String) {
        Menu2InputDelegate.initialize();
        _key = propertyKey;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            var newVal = id as Number;
            var oldVal = Properties.getValue(_key);
            Properties.setValue(_key, newVal);
            getApp().onSettingsChanged();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            if (_key.equals("AgeSource") && (oldVal == null || (oldVal as Number) != newVal)) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                WatchUi.pushView(new VitalityDfRootMenu(), new VitalityDfRootDelegate(), WatchUi.SLIDE_IMMEDIATE);
            }
        }
    }
}

class VitalityDfSettingsActions {

    static function pushPrimaryMetricMenu() as Void {
        var m = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.SettingPrimaryMetric)});
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingPrimaryMetricPoints), null, 0, {}));
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingPrimaryMetricAvgHr), null, 1, {}));
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingPrimaryMetricCurrentHr), null, 2, {}));
        WatchUi.pushView(m, new VitalityPropIntDelegate("PrimaryMetric"), WatchUi.SLIDE_IMMEDIATE);
    }

    static function pushCompactMainMetricMenu() as Void {
        var m = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.SettingCompactMainMetric)});
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingCompactMetricHr), null, 0, {}));
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingCompactMetricAvg), null, 1, {}));
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingCompactMetricPoints), null, 2, {}));
        WatchUi.pushView(m, new VitalityPropIntDelegate("CompactMainMetric"), WatchUi.SLIDE_IMMEDIATE);
    }

    static function pushCompactSecondaryMetricMenu() as Void {
        var m = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.SettingCompactSecondaryMetric)});
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingCompactMetricHr), null, 0, {}));
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingCompactMetricAvg), null, 1, {}));
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingCompactMetricPoints), null, 2, {}));
        WatchUi.pushView(m, new VitalityPropIntDelegate("CompactSecondaryMetric"), WatchUi.SLIDE_IMMEDIATE);
    }

    static function pushAgeSourceMenu() as Void {
        var m = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.SettingAgeSource)});
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingAgeSourceProfile), null, 0, {}));
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingAgeSourceManual), null, 1, {}));
        WatchUi.pushView(m, new VitalityPropIntDelegate("AgeSource"), WatchUi.SLIDE_IMMEDIATE);
    }

    static function pushBirthYearMenu() as Void {
        var m = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.SettingBirthYear)});
        for (var y = 2100; y >= 1900; y--) {
            m.addItem(new WatchUi.MenuItem(y.toString(), null, y, {}));
        }
        WatchUi.pushView(m, new VitalityPropIntDelegate("BirthYear"), WatchUi.SLIDE_IMMEDIATE);
    }

    static function pushBirthMonthMenu() as Void {
        var m = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.SettingBirthMonth)});
        for (var mo = 1; mo <= 12; mo++) {
            m.addItem(new WatchUi.MenuItem(mo.toString(), null, mo, {}));
        }
        WatchUi.pushView(m, new VitalityPropIntDelegate("BirthMonth"), WatchUi.SLIDE_IMMEDIATE);
    }

    static function pushBirthDayMenu() as Void {
        var m = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.SettingBirthDay)});
        for (var d = 1; d <= 31; d++) {
            m.addItem(new WatchUi.MenuItem(d.toString(), null, d, {}));
        }
        WatchUi.pushView(m, new VitalityPropIntDelegate("BirthDay"), WatchUi.SLIDE_IMMEDIATE);
    }

    static function pushManualAgeMenu() as Void {
        var m = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.SettingManualAge)});
        for (var a = 1; a <= 120; a++) {
            m.addItem(new WatchUi.MenuItem(a.toString(), null, a, {}));
        }
        WatchUi.pushView(m, new VitalityPropIntDelegate("ManualAge"), WatchUi.SLIDE_IMMEDIATE);
    }

    static function pushGuidanceModeMenu() as Void {
        var m = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.SettingGuidanceMode)});
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingGuidanceModeNextTier), null, 0, {}));
        m.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SettingGuidanceModeTarget), null, 1, {}));
        WatchUi.pushView(m, new VitalityPropIntDelegate("GuidanceMode"), WatchUi.SLIDE_IMMEDIATE);
    }

    static function pushTargetPointsMenu() as Void {
        var m = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.SettingTargetPoints)});
        var vals = [100, 200, 300, 450, 600] as Array<Number>;
        for (var i = 0; i < vals.size(); i++) {
            var v = vals[i] as Number;
            m.addItem(new WatchUi.MenuItem(v.toString(), null, v, {}));
        }
        WatchUi.pushView(m, new VitalityPropIntDelegate("TargetPoints"), WatchUi.SLIDE_IMMEDIATE);
    }
}
