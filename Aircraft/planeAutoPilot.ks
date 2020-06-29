declare parameter points.
// Paramer is waypoint lists: list(list(geopos, alt, speed, name, blend))
// TODO: Setup an action group to automatically deploy science when waypoint reached
// TODO: Switch to lexicon?
// declare wpProto TO LEX(
// 	"coords", LATLNG(0,0),
// 	"altitude", 2000,
// 	"speed", 300,
// 	"name", "--default wp name--",
// 	"blend", false
// ).

LOCAL iter IS points:ITERATOR.
LOCAL sp IS "        ".
LOCAL minq IS 10.
LOCAL maxq IS 40.
LOCAL bearmax IS 80. //Maximum roll angle

CLEARSCREEN.
PRINT " ".
PRINT "Flying to:".
PRINT "Waypoint ".
PRINT "Time Remaining:".
PRINT "      Distance:".
PRINT "       Bearing:".
PRINT "      Altitude:".
PRINT "  Control mult:".
PRINT "             Q:".
PRINT "      Sideslip:".
PRINT "    Delta Time:".
PRINT "AG 1 to exit.".
PRINT "AG 2 to toggle autopilot.".
PRINT "AG 3 to skip waypoint.".


LOCAL oldTime IS TIME:seconds.
LOCAL rollAdjust IS 1.
LOCAL pPID IS PIDLOOP(0, 0, 0.01, -1, 1).
LOCAL vsPID IS PIDLOOP(0.02, 0.01, 0, -1, 1).
LOCAL rPID IS PIDLOOP(0.02, 0, 0.01, -1, 1).
LOCAL yPID IS PIDLOOP(0.04, 0, 0.005, -1, 1).
LOCAL tPID IS PIDLOOP(0.04, 0.01, 0.3, 0, 1).
LOCAL exit IS FALSE.
LOCAL blend IS FALSE.
LOCAL PAUSE IS TRUE.
LOCAL dest IS LATLNG(0,0).
LOCAL dAlt IS 0.
LOCAL speed IS 0.
LOCAL text IS "Err: Uninitialized".
LOCAL altSmooth IS ALTITUDE.

function nextWaypoint {
	IF NOT iter:NEXT {SET EXIT TO TRUE.}
	LOCAL args IS iter:VALUE.
	SET dest TO args[0].
	SET dAlt TO args[1].
	SET speed TO args[2].
	SET text TO args[3].
	if (args:length > 4) and not (iter:index <= 0) {
		HUDTEXT("Blend triggered", 3, 2, 50, blue, false).
		set text to text + " [B]".
		set blend to true.
		local dest1 is args.
		local dest2 is points[iter:INDEX - 1].
		set doBlend to {
			local blendRatio is MIN(dest1[0]:distance / (dest1[0]:position - dest2[0]:position):mag, 1).
			local dir is (dest2[0]:ALTITUDEPOSITION(dest2[1]) - dest1[0]:ALTITUDEPOSITION(dest1[1])):normalized.
			local dPos IS dest1[0]:ALTITUDEPOSITION(dest1[1]).
			local dAng is VANG(dir, -dPos).
			local linePos is dPos + dir * dPos:mag * 0.5.
			set dest to BODY:geopositionof(linePos).
			set dAlt to dest1[1] + (dest2[1] - dest1[1]) * blendRatio.
			set speed to dest1[2] + (dest2[2] - dest1[2]) * blendRatio.
		}.
	} else {
		set blend to false.
	}
	SET destArrow:label to text.
}

// Triggers, TODO: Switch to terminal input.
ON AG1 {SET exit TO TRUE.}
ON AG2 {
	TOGGLE PAUSE.
	SET SAS TO PAUSE.
	SET altSmooth TO ALTITUDE.
	PRESERVE.
}
ON AG3 {nextWaypoint(). PRESERVE.}

SET destArrow TO VECDRAWARGS(v(0, 0, 0), {return dest:ALTITUDEPOSITION(dAlt).}, CYAN, text, 1, TRUE).
nextWaypoint().
UNTIL (exit) {
	LOCAL dT IS TIME:seconds - oldTime.
	SET oldTime TO TIME:seconds.

	if blend {doBlend().}

	LOCAL bear IS dest:bearing.
	LOCAL dist IS dest:ALTITUDEPOSITION(ALTITUDE):MAG.
	LOCAL currentRoll IS VANG( SHIP:FACING:STARVECTOR, SHIP:UP:VECTOR ) - 90.
	LOCAL currentPitch IS 90 - VANG(SHIP:UP:VECTOR, SHIP:FACING:FOREVECTOR).
	
	LOCAL Q IS SHIP:Q * constant:ATMtokPa.
	LOCAL qMul IS 1 - MIN(1, MAX(0, Q - minq) / (maxq - minq)).
	LOCAL ctrlMul IS 0.9 * qMul + 0.1.
	LOCAL rollMax IS 0.5 * ctrlMul.
	LOCAL pitchMax IS 0.8 * ctrlMul.
	
	LOCAL bearErr IS bear * 3.
	if warp <> 0 or bear < 5 {
		SET rollAdjust TO (rollAdjust + bearErr * 0.001 * dT).
		SET rollAdjust TO max(1, min(6, rollAdjust)).
	} ELSE {SET rollAdjust TO 1.}
	LOCAL bearErr2 IS max(-bearmax, min(bearmax, bearErr * rollAdjust)).
	
	// Setpoint smoothing
	SET altSmooth TO altSmooth + (dAlt - altSmooth) / (5 / dT).
	LOCAL vsMax IS AIRSPEED / 4.
	LOCAL vsErr IS (altSmooth - ALTITUDE) / 5.
	SET vsErr TO max(-vsMax, min(vsMax, vsErr)).

	IF pause = FALSE {
		PRINT "===AUTOPILOT ENGAGED===   " AT (2, 0).
		IF ALT:RADAR < 100 {GEAR ON.} ELSE {GEAR OFF.}
		

		// Bearing correction; roll if in air, wheelsteer + yaw on ground
		IF STATUS = "PRELAUNCH" OR STATUS = "LANDED" {
			SET SHIP:CONTROL:ROLL TO 0.
			SET rPID:setpoint TO 0. // round(bearErr, 1).
			SET SHIP:control:wheelsteer TO rPID:update(TIME:seconds,bearErr) /5.
			IF speed = 0 {
				BRAKES ON.
				IF AIRSPEED < 5 {IF NOT ITER:NEXT {exit ON.}}
			} ELSE {BRAKES OFF.}
		} ELSE {
			SET SHIP:CONTROL:YAW TO 0.
			SET rPID:setpoint TO bearErr2. // round(bearErr2, 1).
			SET SHIP:CONTROL:ROLL TO rPID:update(TIME:seconds,currentRoll) * rollMax.
		}

		// Pitch output: Controlled by vertical speed but with D term of actual craft pitch
		SET vsPID:setpoint TO vsErr.
		LOCAL vsOut IS vsPID:update(TIME:seconds,VERTICALSPEED).
		LOCAL pOut IS pPID:update(TIME:seconds,currentPitch).
		SET SHIP:CONTROL:PITCH TO (vsOut + pOut + (ABS(currentRoll) / (bearmax * 1.5))) * pitchMax + vsPID:iterm * (1 - pitchMax). // I gets full control range
		PRINT round(vsPID:iterm,4) + sp AT (26, 8). // debug
		
		// Sideslip control
		LOCAL sideslip IS VANG(VXCL(SHIP:facing:upvector, SHIP:velocity:surface), SHIP:facing:starvector) - 90.
		LOCAL yOut IS yPID:update(TIME:seconds, -sideslip).
		SET SHIP:CONTROL:YAW TO yOut * rollMax - vsOut * pitchMax * currentRoll / 60.


		// Throttle control
		SET tPID:setpoint TO speed.
		SET T TO round(tPID:update(TIME:seconds,AIRSPEED), 2).
		SET ship:control:PILOTMAINTHROTTLE TO T.
	} ELSE {
		PRINT " ! AUTOPILOT DISENGAGED ! " AT (2, 0).
		SET ship:control:NEUTRALIZE TO TRUE.
	}

	// Print info
	PRINT text + " at: (" + round(dest:lat, 2) + "," + round(dest:lng, 2) + ")" + sp AT (11, 1).
	PRINT (iter:index + 1) + " of " + points:length + sp AT (9, 2).
	LOCAL sec IS dist / AIRSPEED.
	LOCAL mins IS sec / 60.
	LOCAL hours IS mins / 60.
	LOCAL timeToDest IS FLOOR(hours) + "h" + FLOOR(MOD(mins, 60)) + "m" + FLOOR(MOD(sec, 60)) + "s".
	PRINT timeToDest        + sp AT (16, 3).
	PRINT FLOOR(dist)       + sp AT (16, 4).
	PRINT ROUND(bear,2)     + sp AT (16, 5).
	PRINT ROUND(dAlt)   + sp AT (16, 6).
	PRINT ROUND(ctrlMul,2)  + sp AT (16, 7).
	PRINT ROUND(Q)          + sp AT (16, 8).
	PRINT ROUND(dT,2)       + sp AT (16, 9).

	wait 0.
	if dist < 200 {nextWaypoint().}
}
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
SET SAS TO TRUE.
UNSET destArrow.
clearscreen.