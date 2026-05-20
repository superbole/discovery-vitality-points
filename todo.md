# Development Plan: Discovery Vitality Points (v1.1)

## Phase 1: Logic & Core Calculations (`VitalityPointsCalculator.mc`)
- [x] **Task 1.1: Accurate Age Calculation.** Update logic to use day/month comparison for "date-accurate" age instead of simple year subtraction.
- [x] **Task 1.2: Speed-Based Fallback.** Implement sport-specific speed rules for 100 points (30+ mins, no HR):
    - Running/Walking: ≥ 5.5 km/h
    - Cycling: ≥ 10.0 km/h
    - Swimming: ≥ 1.5 km/h
- [x] **Task 1.3: Stability Logic.** Implement `getStabilityInfo` to compute `marginBpm` (the difference between `avgHR` and the current tier's minimum threshold).
- [x] **Task 1.4: Dual Guidance Path.** Refactor `getGuidance` to return both the "Time Path" (minutes remaining at current intensity) and "Intensity Path" (HR needed for the next tier).

## Phase 2: Configuration & Settings (`resources/settings/`)
- [x] **Task 2.1: Manual Date of Birth.** Replace/Expand `ManualAge` with `BirthYear`, `BirthMonth`, and `BirthDay` in `properties.xml` and `settings.xml`.
- [x] **Task 2.2: Constrained Target Points.** Update the `TargetPoints` setting to use a list of valid Vitality tiers (100, 200, 300, 450, 600).

## Phase 3: UI & User Experience (`DiscoveryVitalityPointsView.mc`)
- [x] **Task 3.1: Layout Refactoring.** Transition from fixed vertical offsets to a more dynamic "stack" layout to accommodate additional lines of information.
- [x] **Task 3.2: Render Stability Hints.** Add UI logic to display `Borderline: +X bpm` or `Below tier by X bpm` when the user is near a threshold.
- [x] **Task 3.3: Dual Guidance Display.** Update the view to show both the minutes remaining and the HR requirement simultaneously.
- [x] **Task 3.4: Color Polish.** Update the 50-point color to a light amber and ensure high-contrast foreground colors for all tiers.

## Phase 4: Cleanup & Validation
- [x] **Task 4.1: Workspace Cleanup.** Remove `test.txt.txt` and verify `manifest.xml` integrity.
- [x] **Task 4.2: Final Verification.** Run the internal test harness (Age 49 matrix) and verify simulator performance on Edge 840 and Edge 1040.

## Phase 5: Final Polish (v1.2)
- [x] **Task 5.1: Test Harness.** Implement a table-driven test suite in `source/VitalityTests.mc`.
- [x] **Task 5.2: Guidance Config.** Add "Hide HR Guidance" toggle to settings.
- [x] **Task 5.4: Defensive Probing.** Implement robust runtime checks for `averageHeartRate` and `averageSpeed`.
