import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class DiscoveryVitalityPointsApp extends Application.AppBase {

    private var mView as DiscoveryVitalityPointsView?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        if (mView != null) {
            mView.resetSessionState();
        }
    }

    function onSettingsChanged() as Void {
        if (mView != null) {
            mView.refreshSettings();
        }
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        mView = new DiscoveryVitalityPointsView();
        return [ mView ];
    }

    //! System 4+ on-device data field settings: Activity settings → Connect IQ Settings.
    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [ new VitalityDfRootMenu(), new VitalityDfRootDelegate() ];
    }
}

function getApp() as DiscoveryVitalityPointsApp {
    return Application.getApp() as DiscoveryVitalityPointsApp;
}
