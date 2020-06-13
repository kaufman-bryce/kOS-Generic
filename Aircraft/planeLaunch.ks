declare parameter ap.
ClearScreen.
IF BODY:ATM:EXISTS = TRUE {
	SET altStart TO 100.
	SET altEnd TO 45000.
	SET endAlt to BODY:ATM:HEIGHT.
} ELSE {
 	SET altStart TO 10.
	SET altEnd TO 1000.
	SET endAlt to 0.
}.
SET jets TO SHIP:PARTSTAGGED("ascentjet").
SET oms TO SHIP:PARTSTAGGED("oms").
SET northPole TO latlng(90,0).

SET oldmode to 0.

SET thisAtmo TO SHIP:BODY:ATM.
SET minq TO 10000.
SET maxq TO 1000000.

SET bearmax TO 70. //Maximum roll angle

SET pKp TO 0.02.
SET pKi TO 0.01.
SET pKd TO 0.01.

SET rKp TO 0.005.
SET rKi TO 0.002.
SET rKd TO 0.01.

SET tKp TO 0.06.
SET tKi TO 0.01.
SET tKd TO 0.005.

//Variable initialization
SET pP TO 0. SET pI TO 0. SET pD TO 0.
SET rP TO 0. SET rI TO 0. SET rD TO 0.
SET tP TO 0. SET tI TO 0. SET tD TO 0.

SET oldTime TO 0. SET oldPitch TO 0. SET oldRoll TO 0. SET oldSpd TO 0. SET numOut TO 0.
SET vsErr to 0.
SET pE TO 0. SET rE TO 0. SET tE TO 0.
SET exit TO false.

on AG1 {SET exit TO true. Preserve.} //TODO: Y U NO WORK!

when numOut > 0 THEN {
	set flightmode to 2.
}
when ALTITUDE > 20000 THEN {
	set alt to 40000.
}

ClearScreen.
Print "Flying to orbit.".
Print "      Apoapsis:".
Print "Vertical Speed:".
Print "   Flight Mode:".
Print "   Pitch Error:".
Print "    Roll Error:".
Print "  Control mult:".
Print "             Q:".
Print "    Delta Time:".
Print "AG 1 to exit.".

SET P TO 0.
SET R TO 0.
SET T TO 0.
SET ship:control:PILOTMAINTHROTTLE TO 0.
SET SAS TO FALSE.

SET flightmode TO 1.
UNTIL (exit) {
	SET dT TO TIME:SECONDS - oldTime.
	SET oldTime TO TIME:SECONDS.

	IF dT > 0 {
		if not (oldmode = flightmode) {
			if flightmode = 1 {
				for eng in oms {eng:SHUTDOWN().}
				for eng in jets {eng:ACTIVATE().}
				SET alt TO 26000.
				SET oldmode to flightmode.
			} else if flightmode = 2{
				for eng in jets {eng:SHUTDOWN().}
				for eng in oms {eng:ACTIVATE().}
				SET alt TO ap.
			}
			SET oldmode to flightmode.
		}
		SET currentRoll TO  VANG( FACING:STARVECTOR, UP:VECTOR ) - 90.
		SET currentPitch TO -1*(VANG( FACING:FOREVECTOR, UP:VECTOR ) - 90).
		SET bear TO 90-mod(360 - northPole:bearing,360).


		SET Q TO 0.5*((thisAtmo:SEALEVELPRESSURE + (CONSTANT():E^(-ALTITUDE/thisAtmo:SCALE)))*1.2230948554874)*(AIRSPEED^2).
		SET qMul TO 1-MIN(1,MAX(0,Q-minq)/(maxq-minq)).
		SET ctrlMul to 0.9*(qMul^3)+0.1.
		SET rollmax TO 0.7*ctrlMul.//Maximum roll control
		SET pitchmax to 0.8.//Maximum pitch control

		if flightmode = 1{
			if ALTITUDE < 20000{SET vsMax to min(((AIRSPEED^2)/700), 200).}
			else {set vsMax to 100.}
			SET altErr TO (alt - ALTITUDE)/60.
			if altErr > vsMax {SET altErr to vsMax.}
			if altErr < -vsMax {SET altErr to -vsMax.}
			SET vsErr to altErr-VERTICALSPEED.
			SET pitchErr to vsErr.
		} else if flightmode = 2{
			SET ALTPER TO MIN(1,MAX(0,ALT:RADAR-altStart)/(altEnd-altStart)).
			SET PITCH TO 90*(1-ALTPER^(0.6-(ALTPER/2))).
			SET pitchErr to PITCH-currentPitch.
		}
		
		if bear < 0 {SET bearErr to -10*(abs(bear)^(0.4)).}
		else {SET bearErr to 10*(abs(bear)^(0.4)).}
		if bearErr < -bearmax {SET bearErr TO -bearmax.}
		if bearErr > bearmax {SET bearErr TO bearmax.}
		SET rollErr TO (bearErr - currentRoll)-(max(1-abs(bear),0)*currentRoll*5).
		
		SET spdErr TO (ap - APOAPSIS)/10.
		
		SET pKp TO 0.02 * ctrlMul.
		if AIRSPEED < 200 {
			SET pKi TO 0.0.
			SET pI TO 0.
		} else {SET pKi TO 0.01.}
		SET pKd TO -0.005.
		
		//Pitch
		SET pmax to pitchmax.
		SET pE TO pitchErr.
		SET pP TO pE.
		SET pI TO (pI + pE*pKi*dT).
		SET pD TO (oldPitch-currentPitch) / dT.
		SET pI TO max(-1,min(1,pI)).
		SET P TO (pP*pKp + pI + pD*pKd). //should be between 0 & 1
		IF P > 1 {SET P TO 1.}.
		IF P < -1 {SET P TO -1.}.
		SET P to P*pmax.
		SET oldPitch TO currentPitch.
		
		//Roll
		SET rmax to rollmax.
		SET rE TO rollErr.
		SET rP TO rE.
		SET rI TO (rI + rE*rKi*dT).
		SET rD TO (oldRoll-currentRoll) / dT.
		SET rI TO max(-1,min(1,rI)).
		SET R TO (rP*rKp + rD*rKd). //should be between 0 & 1
		IF R > 1 {SET R TO 1.}.
		IF R < -1 {SET R TO -1.}.
		SET R to R*rmax.
		SET oldRoll TO currentRoll.
		
		//Throttle
		SET tE TO spdErr.
		SET tP TO tE.
		SET tI TO (tI + tE*tKi*dT).
		SET tD TO (AIRSPEED - oldSpd) / dT.
		SET tI TO max(-1,min(1,tI)).
		SET T TO (tP*tKp + tI + tD*tKd). //should be between 0 & 1
		SET T TO max(0,min(1,T)).
		SET oldSpd TO AIRSPEED.
		
		SET ship:control:PITCH TO P.
		SET ship:control:ROLL TO R.
		SET ship:control:MAINTHROTTLE TO T.
		SET ship:control:PILOTMAINTHROTTLE TO T.
		
		// Print info
		if flightmode = 1{set dispmode to "Air Breathing".}
		else if flightmode = 2 {set dispmode to "Closed Cycle".}
		else if flightmode = 3 {set dispmode to "Complete".}
		Print round(APOAPSIS,0) + " m     " at (15,1).
		Print round(VERTICALSPEED,1) + "     " at (15,2).
		Print dispmode + "     " at (15,3).
		Print round(pE,2) + "       " at (15,4).
		Print round(rE,2) + "       " at (15,5).
		Print round(ctrlMul,2) + "       " at (15,6).
		Print round(Q,0) + "       " at (15,7).
		Print round(dT,3) + "       " at (15,8).
		Print R at (15,12).
		Print currentRoll at (15,13).
	}
	set numOut to 0.
	for eng in jets {if eng:flameout {set numOut to numOut + 1.}}
	if ALTITUDE > endAlt and APOAPSIS>ap-50 and APOAPSIS<ap+50 {
		set exit to true.
		set flightmode to 3.
	}
	wait 0.01.
}
SET ship:control:NEUTRALIZE TO true.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SET SAS TO TRUE.
set warp to 0.
wait 0.2.
if flightmode = 3{
	run calcNode("circ","ap",0).
	run doNode.
}
clearscreen.