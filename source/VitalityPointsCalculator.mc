import Toybox.Lang;
import Toybox.Math;

module Vitality {

    class Calculator {
        enum Zone {
            ZONE_BELOW,
            ZONE_LIGHT,
            ZONE_MODERATE,
            ZONE_VIGOROUS,
            ZONE_NOHR
        }

        static function getMaxHR(age as Number) as Number {
            return 220 - age;
        }

        static function getZone(age as Number, avgHR as Number?) as Zone {
            if (avgHR == null || avgHR == 0) {
                return ZONE_NOHR;
            }

            var maxHR = getMaxHR(age);
            var lightLow = Math.ceil(0.60 * maxHR).toNumber();
            var modLow = Math.ceil(0.70 * maxHR).toNumber();
            var vigLow = Math.ceil(0.80 * maxHR).toNumber();

            if (avgHR >= vigLow) {
                return ZONE_VIGOROUS;
            } else if (avgHR >= modLow) {
                return ZONE_MODERATE;
            } else if (avgHR >= lightLow) {
                return ZONE_LIGHT;
            } else {
                return ZONE_BELOW;
            }
        }

        static function calculatePoints(age as Number, avgHR as Number?, minutes as Number, steps as Number?, isEndurance as Boolean, averageSpeed as Float?, sport as Number?) as Number {
            var zone = getZone(age, avgHR);

            if (zone == ZONE_NOHR) {
                // 1. Speed-based fallback (Only if no HR and 30+ mins)
                if (minutes >= 30 && averageSpeed != null && sport != null) {
                    var avgSpeedKph = averageSpeed * 3.6; // m/s to km/h
                    var qualifies = false;
                    
                    if (sport == 1 /* SPORT_RUNNING */ || sport == 11 /* SPORT_WALKING */ || sport == 12 /* SPORT_HIKING */) {
                        if (avgSpeedKph >= 5.5 && avgSpeedKph <= 25.0) { qualifies = true; }
                    } else if (sport == 2 /* SPORT_CYCLING */) {
                        if (avgSpeedKph >= 10.0 && avgSpeedKph <= 60.0) { qualifies = true; }
                    } else if (sport == 5 /* SPORT_SWIMMING */) {
                        if (avgSpeedKph >= 1.5 && avgSpeedKph <= 6.0) { qualifies = true; }
                    }

                    if (qualifies) {
                        return 100;
                    }
                }

                // 2. Steps-based fallback
                if (steps == null) {
                    return 0;
                }
                if (age < 65) {
                    if (steps >= 10000) { return 100; }
                    if (steps >= 5000) { return 50; }
                } else {
                    if (steps >= 7500) { return 100; }
                    if (steps >= 5000) { return 50; }
                }
                return 0;
            }

            if (zone == ZONE_BELOW) {
                return 0;
            }

            var points = 0;

            if (age < 65) {
                if (zone == ZONE_LIGHT) {
                    if (minutes >= 90) { points = 300; }
                    else if (minutes >= 60) { points = 200; }
                    else if (minutes >= 30) { points = 100; }
                } else if (zone == ZONE_MODERATE) {
                    if (minutes >= 60) { points = 300; }
                    else if (minutes >= 30) { points = 200; }
                    else if (minutes >= 15) { points = 100; }
                } else if (zone == ZONE_VIGOROUS) {
                    if (minutes >= 30) { points = 300; }
                    else if (minutes >= 15) { points = 100; }
                }
            } else {
                // 65+ Rules
                if (zone == ZONE_LIGHT) {
                    if (minutes >= 90) { points = 300; }
                    else if (minutes >= 60) { points = 200; }
                    else if (minutes >= 30) { points = 100; }
                } else {
                    // 70%+ (Moderate or Vigorous): align with Discovery calculator
                    // where 15-29 min for 65+ returns 0 points.
                    if (minutes >= 30) { points = 300; }
                }
            }

            // Endurance / High Performance extension
            if (isEndurance) {
                var endurancePoints = 0;
                if (zone == ZONE_LIGHT) {
                    if (minutes >= 180) { endurancePoints = 600; }
                    else if (minutes >= 120) { endurancePoints = 450; }
                    else if (minutes >= 90) { endurancePoints = 300; }
                } else if (zone >= ZONE_MODERATE) {
                    if (minutes >= 180) { endurancePoints = 600; }
                    else if (minutes >= 120) { endurancePoints = 600; }
                    else if (minutes >= 90) { endurancePoints = 450; }
                }

                if (endurancePoints > points) {
                    points = endurancePoints;
                }
            }

            return points;
        }

        // Returns { "marginBpm" => Number, "isBelow" => Boolean }
        static function getStabilityInfo(age as Number, avgHR as Number?, minutes as Number, isEndurance as Boolean, averageSpeed as Float?, sport as Number?) as Dictionary<String, Number or Boolean>? {
            if (avgHR == null || avgHR == 0) {
                return null;
            }

            var currentPoints = calculatePoints(age, avgHR, minutes, null, isEndurance, averageSpeed, sport);
            if (currentPoints == 0) {
                return null;
            }

            var maxHR = getMaxHR(age);
            var minHrForTier = -1;

            // Find the minimum HR that would still yield the current points at the current minutes
            // We search downwards from current avgHR
            var lightLow = Math.ceil(0.60 * maxHR).toNumber();
            for (var hr = avgHR; hr >= lightLow; hr--) {
                if (calculatePoints(age, hr, minutes, null, isEndurance, averageSpeed, sport) == currentPoints) {
                    minHrForTier = hr;
                } else {
                    break;
                }
            }

            if (minHrForTier == -1) {
                return null;
            }

            var margin = avgHR - minHrForTier;
            return {
                "marginBpm" => margin,
                "isBelow" => (margin < 0) // Should not happen with current logic but for safety
            };
        }

        // Returns { "nextPoints" => Number, "minsNeeded" => Number, "hrNeeded" => Number }
        static function getGuidance(age as Number, avgHR as Number?, minutes as Number, isEndurance as Boolean, targetPoints as Number?, averageSpeed as Float?, sport as Number?) as Dictionary<String, Number> {
            var currentPoints = calculatePoints(age, avgHR, minutes, null, isEndurance, averageSpeed, sport);
            var maxHR = getMaxHR(age);
            var effectiveTarget = targetPoints;

            // Guard against invalid target tiers when endurance mode is off.
            if (!isEndurance && effectiveTarget != null && effectiveTarget > 300) {
                effectiveTarget = 300;
            }

            var nextTier = currentPoints;
            if (effectiveTarget != null && effectiveTarget > currentPoints) {
                nextTier = effectiveTarget;
            } else {
                // Find next tier
                var tiers = isEndurance ? [100, 200, 300, 450, 600] : [100, 200, 300];
                for (var i = 0; i < tiers.size(); i++) {
                    if (tiers[i] > currentPoints) {
                        nextTier = tiers[i];
                        break;
                    }
                }
            }

            if (nextTier <= currentPoints) {
                return { "nextPoints" => currentPoints, "minsNeeded" => 0, "hrNeeded" => 0 };
            }

            // Simple iterative search for the next tier requirement
            // We want to find the minimum minutes needed at CURRENT zone
            var minsNeeded = -1;
            for (var m = minutes; m < 300; m++) { // capped at 5 hours for guidance
                if (calculatePoints(age, avgHR, m, null, isEndurance, averageSpeed, sport) >= nextTier) {
                    minsNeeded = m - minutes;
                    break;
                }
            }

            // Find minimum HR needed at CURRENT minutes
            var hrNeeded = -1;
            if (avgHR != null) {
                for (var hr = avgHR; hr <= maxHR; hr++) {
                    if (calculatePoints(age, hr, minutes, null, isEndurance, averageSpeed, sport) >= nextTier) {
                        hrNeeded = hr;
                        break;
                    }
                }
            }

            // If not found by increasing HR, try checking lower zones (e.g. if we are at Light but need Moderate)
            if (hrNeeded == -1) {
                var modLow = Math.ceil(0.70 * maxHR).toNumber();
                var vigLow = Math.ceil(0.80 * maxHR).toNumber();
                if (calculatePoints(age, modLow, minutes, null, isEndurance, averageSpeed, sport) >= nextTier) {
                    hrNeeded = modLow;
                } else if (calculatePoints(age, vigLow, minutes, null, isEndurance, averageSpeed, sport) >= nextTier) {
                    hrNeeded = vigLow;
                }
            }

            return {
                "nextPoints" => nextTier,
                "minsNeeded" => minsNeeded,
                "hrNeeded" => hrNeeded
            };
        }
    }
}
