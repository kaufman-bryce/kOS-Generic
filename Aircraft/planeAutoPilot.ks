declare parameter points.
// Paramer is waypoint lists: list(list(geopos, alt, speed, name))
//TODO: Setup an action group to automatically deploy science when waypoint reached

LOCAL iter IS points:ITERATOR.
LOCAL sp IS "        ".
// LOCAL thisAtmo IS SHIP:BODY:ATM.
LOCAL minq IS 10.
LOCAL maxq IS 40.
LOCAL bearmax IS 70. //Maximum roll angle

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
LOCAL yPID IS PIDLOOP(0.02, 0, 0.01, -1, 1).
LOCAL tPID IS PIDLOOP(0.04, 0.01, 0.3, 0, 1).
LOCAL exit IS FALSE.
LOCAL PAUSE IS TRUE.
LOCAL altSmooth IS ALTITUDE.
ON AG1 {SET exit TO TRUE.}
ON AG2 {
	TOGGLE PAUSE.
	SET SAS TO PAUSE.
	SET altSmooth TO ALTITUDE.
	PRESERVE.
}
ON AG3 {IF NOT iter:NEXT {SET EXIT TO TRUE.} PRESERVE.}
IF NOT iter:NEXT {SET EXIT TO TRUE.}
UNTIL (exit) {
	LOCAL args IS iter:VALUE.
	LOCAL dest IS args[0].
	LOCAL dAlt IS args[1].
	LOCAL speed IS args[2].
	LOCAL text IS args[3].
	LOCAL dT IS TIME:seconds - oldTime.
	SET oldTime TO TIME:seconds.
	LOCAL dist IS 1000.
	IF dT > 0 {
		LOCAL bear IS dest:bearing.
		SET dist TO dest:ALTITUDEPOSITION(ALTITUDE):MAG.
		LOCAL currentRoll IS VANG( SHIP:FACING:STARVECTOR, SHIP:UP:VECTOR ) - 90.
		LOCAL currentPitch IS 90 - VANG(SHIP:UP:VECTOR, SHIP:FACING:FOREVECTOR).
		
		LOCAL Q IS SHIP:Q * constant:ATMtokPa.
		LOCAL qMul IS 1 - MIN(1, MAX(0, Q - minq) / (maxq - minq)).
		LOCAL ctrlMul IS 0.9 * qMul + 0.1.
		LOCAL rollMax IS 0.5 * ctrlMul.
		LOCAL pitchMax IS 0.8 * ctrlMul.
		
		SET altSmooth TO altSmooth + (dAlt - altSmooth) / (5 / dT). //Setpoint smoothing
		LOCAL vsMax IS AIRSPEED / 4.
		LOCAL vsErr IS (altSmooth - ALTITUDE) / 5.
		SET vsErr TO max(-vsMax,min(vsMax,vsErr)).
		
		LOCAL bearErr IS bear * 3.
		if warp <> 0 or bear < 5 {
			SET rollAdjust TO (rollAdjust + bearErr * 0.001 * dT).
			SET rollAdjust TO max(1, min(6, rollAdjust)).
		} ELSE {SET rollAdjust TO 1.}
		LOCAL bearErr2 IS max(-bearmax, min(bearmax, bearErr * rollAdjust)).
		
		IF pause = FALSE {
			PRINT "  ===AUTOPILOT ENGAGED===  " AT (2, 0).
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
			SET SHIP:CONTROL:PITCH TO (vsOut + pOut + (ABS(currentRoll) / 90)) * pitchMax + vsPID:iterm * (1 - pitchMax). // I gets full control range
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
		PRINT ROUND(ALTITUDE)   + sp AT (16, 6).
		PRINT ROUND(ctrlMul,2)  + sp AT (16, 7).
		PRINT ROUND(Q)          + sp AT (16, 8).
		PRINT ROUND(dT,2)       + sp AT (16, 9).
		
		SET destArrow TO VECDRAWARGS(v(0, 0, 0), dest:ALTITUDEPOSITION(dAlt), CYAN, text, 1, TRUE).
	}
	wait 0.
	if dist < 200 {IF NOT ITER:NEXT {exit ON.}}
}
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
SET SAS TO TRUE.
UNSET destArrow.
clearscreen.