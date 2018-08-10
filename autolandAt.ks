RUNONCEPATH("/lib/orientation").
RUNONCEPATH("/lib/rocket").
RUNONCEPATH("/lib/node_basic").
RUNONCEPATH("/lib/node_rdvs").
RUNONCEPATH("/lib/predictImpact").
DECLARE PARAMETER targ.

SET minSafeAltitude TO targ:TERRAINHEIGHT+1000.
SET spaces TO "          ".
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
FUNCTION safeSQRT {
	PARAMETER x.
	IF x < 0 {RETURN SQRT(ABS(x)) * -1.}
	ELSE {RETURN SQRT(x).}
}

FUNCTION frameShift {
    PARAMETER vec,dir.
    LOCAL ret IS V(0,0,0).
    SET ret:X TO dir:STARVECTOR * vec.
    SET ret:Y TO dir:UPVECTOR * vec.
    SET ret:Z TO dir:VECTOR * vec.
    RETURN ret.
}

CLEARSCREEN.
SET targTime TO utOf(30).
SET ang TO 0.
SET err TO 0.
SET bodyrot TO 0.
SET deorb TO NODE(targTime,0,0,0).
ADD deorb.
SET targTime TO deorb:ETA.

LOCAL FUNCTION makeDeorb {
	FOR n IN ALLNODES {REMOVE n.}
	SET deorb TO nodeMoveApsis(utOf(targTime),minSafeAltitude).
	ADD deorb.
	LOCAL t IS targTime + deorb:ORBIT:PERIOD/2.
	SET bodyrot TO 360 * (t / BODY:ROTATIONPERIOD).
	LOCAL periPos IS POSITIONAT(SHIP,utOf(t)) - BODY:POSITION.
	
	LOCAL insct IS VCRS(obtNrm(SHIP),periPos):NORMALIZED.
	LOCAL targXCL IS VXCL(-insct,LATLNG(targ:LAT,targ:LNG + bodyrot):POSITION - BODY:POSITION).
	SET err TO VANG(periPos,targXCL).
	IF OBT:INCLINATION > 90 {SET err TO -err.}
	SET periPos TO (periPos * ANGLEAXIS(err,insct)).
	
	SET ang TO VANG(LATLNG(targ:LAT,targ:LNG + bodyrot):POSITION - BODY:POSITION,periPos) + MAX(0,err - 90)/5.
}
makeDeorb().
UNTIL ang < 0.1 AND err <= 90{ //Position PE over target LNG
    SET targTime TO targTime + ang * ((OBT:PERIOD / 360)).
    IF targTime < 0 {SET targTime TO targTime + OBT:PERIOD.}
    makeDeorb().
	//wait 0.1.
}
doNode().
WAIT 1.
SET periPos TO POSITIONAT(SHIP,utPe()) - BODY:POSITION.
LOCAL t IS timeToTruAnom(OBT,270).
LOCAL sgn IS -1.
IF OBT:INCLINATION > 90 {
	SET t TO timeToTruAnom(OBT,90).
	SET sgn TO 1.
}
SET bodyrot TO 360 * (ETA:PERIAPSIS / BODY:ROTATIONPERIOD).
LOCAL insct IS VCRS(obtNrm(SHIP),periPos):NORMALIZED.
LOCAL targXCL IS VXCL(-insct,LATLNG(targ:LAT,targ:LNG + bodyrot):POSITION - BODY:POSITION).
LOCAL err IS VANG(periPos,targXCL) * sgn.
LOCAL t IS timeToTruAnom(OBT,270).
LOCAL align IS nodeInc(utOf(t),err).
ADD align.
IF align:DELTAV:MAG > 5 {doNode().} ELSE {REMOVE align.}

LOCAL mH IS 0.
LOCAL scan IS STACK().
SET t TO utOf(ETA:PERIAPSIS - 1.5 * (vAT(SHIP,ETA:PERIAPSIS):MAG / accel() * 0.75)).
SET pSpd TO vAT(SHIP,t).
LOCK STEERING TO -pSpd.
PRINT "Performing terrain scan...".
LOCAL oldTime IS TIME:SECONDS.
FROM {LOCAL x IS ROUND(ETA:PERIAPSIS).} UNTIL x < t - TIME:SECONDS STEP {SET x TO x - 0.1.} DO {
	//PRINT ROUND(x - (t - TIME:SECONDS),1) + "   " AT (30,0).
	LOCAL p IS POSITIONAT(SHIP,utOf(x)).
	LOCAL ang IS MOD((BODY:GEOPOSITIONOF(p):LNG - (360 * (x / BODY:ROTATIONPERIOD))) + 180,360) - 180.
	LOCAL geo IS LATLNG(BODY:GEOPOSITIONOF(p):LAT,ang).
	LOCAL h IS geo:TERRAINHEIGHT - targ:TERRAINHEIGHT.
	IF h > mH {
		LOCAL fhDist IS 2 * CONSTANT:PI() * (targ:TERRAINHEIGHT + BODY:RADIUS) * (VANG(geo:POSITION - BODY:POSITION,targ:POSITION - BODY:POSITION)/360).
		scan:PUSH(LIST(ROUND(fhDist),h)).
		SET mH TO h.
		//PRINT "D: " + ROUND(fhDist) + "    H: " + ROUND(h).
	}
}
PRINT "Scan complete. " + scan:LENGTH + " elements. " + ROUND(TIME:SECONDS - oldTime,2) + " seconds elapsed.".
WAIT UNTIL VANG(-pSpd,SHIP:FACING:VECTOR) < 0.5.
doWarp(t).

//Approach phase
SAS OFF.
CLEARSCREEN.
PRINT "runtime:".
PRINT "  hDist:".
PRINT "  vDist:".
PRINT " impAvd:".
PRINT " vrtErr:".
PRINT " latErr:".
PRINT " horErr:".
PRINT "  vTime:".
PRINT "sterErr:".
PRINT "  throt:".
PRINT " ".
PRINT "   hPID:".
PRINT "   vPID:".
PRINT "  normE:".
LOCAL hPID IS PIDLOOP(0.4,0.3,0.15,0,1).
LOCAL vPID IS PIDLOOP(0.03,0.02,0.02,0,1).
LOCAL oldTime IS TIME:SECONDS.
LOCAL scanTime IS 0.
LOCAL impactAvoid IS 0.
LOCAL impactDist IS BODY:RADIUS.
LOCAL impactTime IS 0.
LOCAL steer IS SRFRETROGRADE:VECTOR.
LOCK STEERING TO steer.
LOCAL hDist IS targ:ALTITUDEPOSITION(ALTITUDE):MAG.
UNTIL hDist < 20 {
	LOCAL dT IS TIME:SECONDS - oldTime.
	IF dT > 0 {
		SET oldTime TO TIME:SECONDS.
		LOCAL R IS BODY:POSITION.
		SET hDist TO 2 * CONSTANT:PI() * (targ:TERRAINHEIGHT + BODY:RADIUS) * (VANG(-R,targ:POSITION - BODY:POSITION)/360).
		LOCAL srfNorm IS VCRS(SRFPROGRADE:VECTOR,UP:VECTOR):NORMALIZED.
		LOCAL hVec IS -VELOCITY:SURFACE:NORMALIZED.
		LOCAL hSpd IS VDOT(VCRS(VCRS(R,targ:POSITION),R):NORMALIZED,VELOCITY:SURFACE).
		LOCAL normEm IS VDOT(targ:POSITION,srfNorm).
		LOCAL normE IS 0.001 * safeSQRT(normEm).
		LOCAL dHSpd IS safeSQRT( 1.8 * (hDist - 1) * accel()).
		//LOCAL impact IS predictImpact(targ:TERRAINHEIGHT).
		//IF impact[0] AND impact[1]:DISTANCE < targ:DISTANCE AND hDist > 500 AND utOf(impact[2]) < impactTime AND impactTime > TIME:SECONDS {
		//	LOCAL h IS (impact[1]:TERRAINHEIGHT) - (targ:TERRAINHEIGHT).
		//	IF  h > impactAvoid {
		//		SET impactAvoid TO h.
		//		SET impactTime TO utOf(impact[2]).
		//	}
		//} ELSE {
		//	SET impactAvoid TO ROUND(impactAvoid * 0.95,2).
		//	SET impactTime TO utOf(burntime(dHSpd)).
		//}
		UNTIL impactDist < hDist {
			IF scan:EMPTY = FALSE {
				LOCAL imp IS scan:POP().
				SET impactDist TO imp[0].
				SET impactAvoid TO imp[1].
			} ELSE {SET impactDist TO 0. SET impactAvoid TO 0.}
		}
		LOCAL vDist1 IS ALTITUDE - (targ:TERRAINHEIGHT + 150).
		LOCAL vDist2 IS vDist1 - impactAvoid.
		LOCAL vTime1 IS hDist / (hSpd / 2).
		LOCAL vTime2 IS (hDist - impactDist) / ((safeSQRT( 1.8 * (impactDist - 1) * accel()) + hSpd) / 2).
		//IF impact[0] {SET vTime TO MIN(impact[2],vTime).}
		LOCAL slope1 IS vDist1/hDist. //Slope to target
		LOCAL slope2 IS vDist2/(hDist - impactDist). //slope to next high spot
		LOCAL dVSpd IS 0.//-safeSQRT(vDist * MAX((BODY:MU/R:MAG^2) * 0.5,accel() * 0.5 - (BODY:MU/R:MAG^2))).
		IF slope2 > slope1 {
			SET dVSpd TO -(vDist1/vTime1).
			SET vDist TO vDist1.
			SET vTime TO vTime1.
		} ELSE {
			SET dVSpd TO -(vDist2/vTime2).
			SET vDist TO vDist2.
			SET vTime TO vTime2.
		}
		SET hPID:SETPOINT TO -dHSpd.
		SET vPID:SETPOINT TO dVSpd.
		LOCAL hO IS hPID:UPDATE(oldTime,-hSpd).
		LOCAL vO IS vPID:UPDATE(oldTime,VERTICALSPEED).
		IF PERIAPSIS > 0 {SET vO TO 0.}
		SET totalE TO ROUND(hO + vO,2).
		SET steervec TO UP:VECTOR * vO + hVec * MAX(0.01,hO) + srfNorm * normE * CEILING(hO).
		SET steer TO steervec:NORMALIZED.
		SET steerErr TO VANG(steervec:NORMALIZED,FACING:VECTOR).
		SET THROT TO totalE.
		SET SHIP:CONTROL:MAINTHROTTLE TO THROT.
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO THROT.
		PRINT ROUND(dT,2)+ spaces AT (9,0).
		PRINT ROUND(hDist,2)+ spaces AT (9,1).
		PRINT ROUND(vDist,1)+ spaces AT (9,2).
		PRINT ROUND(impactAvoid,1)+ spaces AT (9,3).
		PRINT ROUND(dVSpd - VERTICALSPEED,1)+ spaces AT (9,4).
		PRINT ROUND(normEm,2)+ spaces AT (9,5).
		PRINT ROUND(dHSpd-hSpd,2)+ spaces AT (9,6).
		PRINT ROUND(vTime2,2)+ spaces AT (9,7).
		PRINT ROUND(steerErr,2)+ spaces AT (9,8).
		PRINT ROUND(THROT,3)+ spaces AT (9,9).
		PRINT ROUND(hO,3)+ spaces AT (9,11).
		PRINT ROUND(vO,3)+ spaces AT (9,12).
		PRINT ROUND(normE,3)+ spaces AT (9,13).
		LOG TIME:SECONDS + "," + hDist + "," + vDist + "," + impactAvoid + "," + vTime + "," + dHSpd + "," + hSpd + "," + dVSpd + "," + VERTICALSPEED + "," + steerErr + "," + THROT + "," +
		hPID:INPUT + "," + hPID:SETPOINT + "," + hPID:ERROR + "," + hO + "," + hPID:PTERM + "," + hPID:ITERM + "," + hPID:DTERM + "," + 
		vPID:INPUT + "," + vPID:SETPOINT + "," + vPID:ERROR + "," + vO + "," + vPID:PTERM + "," + vPID:ITERM + "," + vPID:DTERM + "," + 
		normE + "," + totalE TO "0:/LOGS/autoland_1.csv".
	}
    WAIT 0.
}

//Landing phase
LIST PARTS IN partlist.
SET gearheight TO 0.
FOR part IN partlist{
    SET partY TO part:POSITION:MAG*COS(VANG(FACING:FOREVECTOR,part:POSITION)).
    SET gearheight TO MIN(gearheight,partY - 3).
}
GEAR ON. SAS OFF. RCS ON.
SET tPID TO PIDLOOP(0.8,0.05,0.05,0,1).
CLEARSCREEN.
PRINT "runtime:".
PRINT "  Speed:".
PRINT "desSped:".
PRINT " posErr:".
PRINT "       :".
PRINT "sterErr:".
PRINT "    PID:".
PRINT "  throt:".
PRINT "      T:".
SET steer TO SRFRETROGRADE:VECTOR.
LOCK STEERING TO steer.
UNTIL STATUS = "LANDED" {
    SET dT TO time:seconds - oldTime.
    SET oldTime TO time:seconds.
    IF DT > 0 {
        LOCAL impact IS predictImpact(targ:TERRAINHEIGHT).
		LOCAL vDist IS ALTITUDE - (targ:TERRAINHEIGHT + gearheight + 10).
		LOCAL dVS IS -MAX(2,safeSQRT(MAX(0,vDist * (accel() - (BODY:MU/BODY:POSITION:MAG^2))))).
        SET errDir TO VXCL(SHIP:UP:VECTOR,targ:POSITION - impact[1]:POSITION).
		IF errDir:MAG < 10 AND errDir:MAG > 0.05 {SET SHIP:CONTROL:TRANSLATION TO frameShift(errDir * 0.5,SHIP:FACING).}
		ELSE {SET SHIP:CONTROL:TRANSLATION TO V(0,0,0).}
        SET throt TO  ROUND(MAX(0,errDir:MAG - 2),2)* 0.02 * MAX(0.01,accel()/(MAX(0,ALTITUDE - targ:TERRAINHEIGHT)/10)).
		SET tPID:SETPOINT TO dVS.
        tPID:UPDATE(TIME:SECONDS,VERTICALSPEED).
		SET steervec TO (-VELOCITY:SURFACE * MAX(0.2,tPID:OUTPUT)) + (errDir:NORMALIZED * MIN(1,throt)).
		SET steer TO LOOKDIRUP(steervec:NORMALIZED,SHIP:FACING:UPVECTOR).
		SET steerErr TO VANG(steervec:NORMALIZED,FACING:VECTOR).
        IF steerErr > 45 {SET THROT TO 0.}
		SET T TO tPID:OUTPUT + throt.
        SET SHIP:CONTROL:MAINTHROTTLE TO T.
        SET SHIP:CONTROL:PILOTMAINTHROTTLE TO T.
        PRINT ROUND(dT,2)+ spaces AT (9,0).
        PRINT ROUND(VERTICALSPEED,2)+ spaces AT (9,1).
        PRINT ROUND(dVS,2)+ spaces AT (9,2).
        PRINT ROUND(errDir:MAG,1)+ spaces AT (9,3).
        PRINT ROUND(steerErr,3)+ spaces AT (9,5).
        PRINT ROUND(tPID:OUTPUT,3)+ spaces AT (9,6).
        PRINT ROUND(throt,3)+ spaces AT (9,7).
        PRINT ROUND(T,3)+ spaces AT (9,8).
		SET impactDRAW TO VECDRAWARGS(impact[1]:ALTITUDEPOSITION(impact[1]:TERRAINHEIGHT+ALT:RADAR),impact[1]:ALTITUDEPOSITION(impact[1]:TERRAINHEIGHT-ALT:RADAR) - impact[1]:ALTITUDEPOSITION(impact[1]:TERRAINHEIGHT),CYAN,"I", 1, TRUE).
		SET posDRAW TO VECDRAWARGS(targ:ALTITUDEPOSITION(impact[1]:TERRAINHEIGHT+ALT:RADAR),targ:ALTITUDEPOSITION(targ:TERRAINHEIGHT-ALT:RADAR) - targ:ALTITUDEPOSITION(targ:TERRAINHEIGHT),GREEN,"P", 1, TRUE).
    }
    WAIT 0.
}
UNLOCK STEERING.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SET SHIP:CONTROL:TRANSLATION TO V(0,0,0).
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
SAS ON. RCS OFF.
UNSET impactdraw.
UNSET posdraw.
PRINT CHAR(7).