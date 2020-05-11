RUNONCEPATH("/lib/orientation").
RUNONCEPATH("/lib/rocket").
RUNONCEPATH("/lib/node_basic").
RUNONCEPATH("/lib/node_rdvs").
RUNONCEPATH("/lib/predictImpact").
DECLARE PARAMETER targ.

LOCAL minSafeAltitude IS targ:TERRAINHEIGHT+1000.
LOCAL spaces IS "          ".
LOCAL spinner IS QUEUE("|","/","-","\").
//LOCAL spinner IS QUEUE("|  "," | ","  |"," | ").
//LOCAL spinner IS QUEUE("Ooo","oOo","ooO","oOo").

FUNCTION spin {
	PARAMETER x,y.
	PRINT spinner:peek() AT (x,y).
	spinner:push(spinner:pop()).
}

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

FUNCTION throtFrac {
	PARAMETER val, frac.
	RETURN safeSQRT(MAX(0,val * (accel() * frac))) / accel().
}

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
CLEARSCREEN.
PRINT "Preparing to land on " + BODY:name + " at (" + ROUND(targ:LAT,2) + "," + ROUND(targ:LNG,2) + ")...".
SET SHIP:CONTROL:MAINTHROTTLE TO 0.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SET SHIP:CONTROL:TRANSLATION TO V(0,0,0).
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
//Establish vessel height
PRINT "Performing pre-landing checks...".
stageCheck().
PRINT "Staging ok, checking gear..." AT (0,2).
GEAR ON.
FROM {LOCAL i IS 0.} UNTIL i = 50 STEP {SET i TO i + 1.} DO {
	spin(32,1).
	WAIT 0.1.
}
LOCAL gearheight IS ABS(SHIP:BOUNDS:FURTHESTCORNER(-SHIP:FACING:FOREVECTOR) * SHIP:FACING:FOREVECTOR).
PRINT "Gear Height: " + ROUND(gearheight,3) + spaces AT (0,2).
GEAR OFF.
FROM {LOCAL i IS 0.} UNTIL i = 50 STEP {SET i TO i + 1.} DO {
	spin(32,1).
	WAIT 0.1.
}
SAS OFF.
PRINT "ok." AT (32,1).


//Init logs
IF EXISTS("0:/LOGS/autoland_approach.csv") {DELETEPATH("0:/LOGS/autoland_approach.csv").}
LOG "Time,hDist,vDist,impactAvoid,impactTime,dHSpd,hSpd,dVSpd,VERTICALSPEED,steerErr,THROT,hPID:INPUT,hPID:SETPOINT,hPID:ERROR,hPID:OUTPUT,hPID:PTERM,hPID:ITERM,hPID:DTERM,vPID:INPUT,vPID:SETPOINT,vPID:ERROR,vPID:OUTPUT,vPID:PTERM,vPID:ITERM,vPID:DTERM,normE,totalE,periapsis" TO "0:/LOGS/autoland_approach.csv".
IF EXISTS("0:/LOGS/autoland_landing.csv") {DELETEPATH("0:/LOGS/autoland_landing.csv").}
LOG "Time,vDist,dVS,VERTICALSPEED,steerErr,THROT,tPID:INPUT,tPID:SETPOINT,tPID:ERROR,tPID:OUTPUT,tPID:PTERM,tPID:ITERM,tPID:DTERM,posErr " TO "0:/LOGS/autoland_landing.csv".


PRINT "Plotting approach orbit...".
SET targTime TO utOf(30).
SET ang TO 0.
SET err TO 0.
SET bodyrot TO 0.
LOCAL periPos IS V(0,0,0).
LOCAL insct IS V(0,0,0).
LOCAL targXCL IS V(0,0,0).
SET deorb TO NODE(targTime,0,0,0).
ADD deorb.
SET targTime TO deorb:ETA.

LOCAL FUNCTION makeDeorb {
	FOR n IN ALLNODES {REMOVE n.}
	SET deorb TO nodeMoveApsis(utOf(targTime),minSafeAltitude).
	ADD deorb.
	LOCAL tToPeri IS targTime + deorb:ORBIT:PERIOD/2.
	SET bodyrot TO 360 * (tToPeri / BODY:ROTATIONPERIOD).
	SET periPos TO POSITIONAT(SHIP,utOf(tToPeri)) - BODY:POSITION.
	SET insct TO VCRS(obtNrm(SHIP),periPos):NORMALIZED.
	SET targXCL TO VXCL(-insct,LATLNG(targ:LAT,targ:LNG + bodyrot):POSITION - BODY:POSITION).
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
	spin(25,2).
	//wait 0.1.
}
PRINT "ok." AT (25,2).
PRINT "Executing approach burn...".
doNode().
WAIT 1.
LOCAL t IS timeToTruAnom(OBT,270).
LOCAL sgn IS -1.
IF OBT:INCLINATION > 90 {
	SET t TO timeToTruAnom(OBT,90).
	SET sgn TO 1.
}
SET bodyrot TO 360 * (ETA:PERIAPSIS / BODY:ROTATIONPERIOD).
SET periPos TO POSITIONAT(SHIP,utPe()) - BODY:POSITION.
SET insct TO VCRS(obtNrm(SHIP),periPos):NORMALIZED.
SET targXCL TO VXCL(-insct,LATLNG(targ:LAT,targ:LNG + bodyrot):POSITION - BODY:POSITION).
SET err TO VANG(periPos,targXCL) * sgn.
SET t TO timeToTruAnom(OBT,270).
LOCAL align IS nodeInc(utOf(t),err).
ADD align.
IF align:DELTAV:MAG > 5 {
	PRINT "Executing course correction..." AT (0,3).
	doNode().
} ELSE {REMOVE align.}
 
//Terrain avoidance scanning
LOCAL mH IS 0.
LOCAL scan IS STACK().
SET t TO utOf(ETA:PERIAPSIS - 1.1 * (vAT(SHIP,ETA:PERIAPSIS):MAG / (accel() * 0.7))).
SET pSpd TO vAT(SHIP,t).
LOCK STEERING TO -pSpd.
PRINT "Performing terrain scan...".
LOCAL tScanStart IS TIME:SECONDS.
LOCAL spinTime IS TIME:SECONDS.
FROM {LOCAL x IS ETA:PERIAPSIS.} UNTIL x < t - TIME:SECONDS STEP {SET x TO x - 0.2.} DO {
	//PRINT ROUND(x - (t - TIME:SECONDS),1) + "   " AT (30,0).
	LOCAL p IS POSITIONAT(SHIP,utOf(x)).
	LOCAL lngOff IS MOD((BODY:GEOPOSITIONOF(p):LNG - (360 * (x / BODY:ROTATIONPERIOD))) + 180,360) - 180.
	LOCAL geo IS LATLNG(BODY:GEOPOSITIONOF(p):LAT,lngOff).
	LOCAL h IS geo:TERRAINHEIGHT - targ:TERRAINHEIGHT.
	IF h > mH {
		LOCAL fhDist IS 2 * CONSTANT:PI() * (targ:TERRAINHEIGHT + BODY:RADIUS) * (VANG(geo:POSITION - BODY:POSITION,targ:POSITION - BODY:POSITION)/360).
		scan:PUSH(LIST(ROUND(fhDist),h)).
		SET mH TO h.
		spin(26,4).
		//PRINT "D: " + ROUND(fhDist) + "    H: " + ROUND(h).
	} ELSE IF TIME:SECONDS > spinTime + 0.1 {
		spin(26,4).
		SET spinTime TO TIME:seconds.
	}
}
PRINT "ok." AT (26,4).
PRINT "Scan complete. " + scan:LENGTH + " elements. " + ROUND(TIME:SECONDS - tScanStart,2) + " seconds elapsed.".
PRINT "Waiting to begin approach guidance...".
WAIT 2.
WAIT UNTIL VANG(-pSpd,SHIP:FACING:VECTOR) < 0.5.
doWarp(t).

//Approach phase
SAS OFF.
CLEARSCREEN.
PRINT "Approach Guidance Active".
PRINT "runtime:".
PRINT "  vTime:".
PRINT "  hDist:".
PRINT "  vDist:".
PRINT " impAvd:".
PRINT "  dVSpd:".
PRINT " horErr:".
PRINT " vrtErr:".
PRINT " latErr:".
PRINT "sterErr:".
PRINT "  throt:".
PRINT " ".
PRINT "   hPID:".
PRINT "   vPID:".
PRINT "  normE:".
LOCAL hPID IS PIDLOOP(0.4,0.3,0.15,0,1).
LOCAL vPID IS PIDLOOP(0.04,0.01,0.06,0,1).
LOCAL oldTime IS TIME:SECONDS.
LOCAL impactAvoid IS 0.
LOCAL impactDist IS BODY:RADIUS.
LOCAL vWait IS TRUE.
LOCAL steer IS SRFRETROGRADE:VECTOR.
LOCK STEERING TO steer.
LOCAL hDist IS targ:ALTITUDEPOSITION(ALTITUDE):MAG.
WHEN hDist < 200 THEN {PRINT CHAR(7).}


UNTIL hDist < 1 {
	LOCAL dT IS TIME:SECONDS - oldTime.
	LOCAL vTime IS 0.
	LOCAL vDist IS 0.
	IF dT > 0 {
		SET oldTime TO TIME:SECONDS.
		LOCAL R IS BODY:POSITION.
		IF ARCSIN(2 * BODY:RADIUS / (2 * R:MAG)) >= VANG(SUN:POSITION,R) {LIGHTS ON.}
		ELSE {LIGHTS OFF.}
		SET hDist TO 2 * CONSTANT:PI() * (targ:TERRAINHEIGHT + BODY:RADIUS) * (VANG(-R,targ:POSITION - BODY:POSITION)/360).
		LOCAL srfNorm IS VCRS(SRFPROGRADE:VECTOR,UP:VECTOR):NORMALIZED.
		LOCAL hVec IS -VELOCITY:SURFACE:NORMALIZED.
		LOCAL hSpd IS VDOT(VCRS(VCRS(R,targ:POSITION),R):NORMALIZED,VELOCITY:SURFACE).
		LOCAL normEm IS VDOT(targ:POSITION,srfNorm).
		LOCAL normE IS 0.001 * safeSQRT(normEm).
		// 0.7 approximates cosine losses at 45 degrees, with ~1% wiggle room
		// i.e. what is the max accel we can get if *both* PIDs are locked at 100%
		LOCAL maxAccel IS accel() * 0.7.
		LOCAL dHSpd IS safeSQRT(2 * (hDist) * (maxAccel)).
		UNTIL impactDist < hDist {
			IF scan:EMPTY = FALSE {
				LOCAL imp IS scan:POP().
				SET impactDist TO imp[0].
				SET impactAvoid TO imp[1].
			} ELSE {SET impactDist TO 0. SET impactAvoid TO 0.}
		}
		//Adjust desired vertical speed based on slope to target or impact avoidance
		LOCAL vDist1 IS ALTITUDE - (targ:TERRAINHEIGHT + 150 + gearheight).
		LOCAL vDist2 IS vDist1 - impactAvoid.
		LOCAL vTime1 IS hDist / (hSpd / 2).
		LOCAL vTime2 IS (hDist - impactDist) / ((safeSQRT(2 * (hDist - impactDist) * (maxAccel)) + hSpd) / 2).
		LOCAL slope1 IS vDist1/hDist. //Slope to target
		LOCAL slope2 IS vDist2/(hDist - impactDist). //slope to next high spot
		LOCAL dVSpd IS 0.
		IF slope2 > slope1 {
			SET dVSpd TO -(2 * vDist1/vTime1).
			SET vDist TO vDist1.
			SET vTime TO vTime1.
		} ELSE {
			SET dVSpd TO -(2 * vDist2/vTime2).
			SET vDist TO vDist2.
			SET vTime TO vTime2.
		}
		
		SET hPID:SETPOINT TO -dHSpd.
		LOCAL hO IS hPID:UPDATE(TIME:SECONDS,-hSpd).
		IF vWait { // Ignore vertical speed adjustments until we start decellerating
			SET dVSpd TO VERTICALSPEED. // TODO: Ease into VS control based on mean anomaly?
			IF hPID:output > 0 {SET vWait TO FALSE.}
		}
		IF vPID:SETPOINT = 0 {SET vPID:SETPOINT TO dVSpd.}
		LOCAL gAcc IS dT * (BODY:MU/R:MAG^2) * 0.2.//Don't let gravity ever take full control
		SET dVSpd TO MAX(-gAcc,MIN(gAcc * 4,dVSpd - vPID:SETPOINT)) + vPID:SETPOINT.
		SET vPID:SETPOINT TO dVSpd.
		LOCAL vO IS vPID:UPDATE(TIME:SECONDS,VERTICALSPEED).
		//IF PERIAPSIS > 0 {SET vO TO 0.}
		SET totalE TO ROUND(hO + vO,2).
		SET steervec TO UP:VECTOR * vO + hVec * MAX(0.01,hO) + srfNorm * normE * CEILING(hO).
		SET steer TO steervec:NORMALIZED.
		SET steerErr TO VANG(steervec:NORMALIZED,FACING:VECTOR).
		SET THROT TO totalE * (1 - ROUND(MIN(1,(steerErr/30)^2),2)).
		SET SHIP:CONTROL:MAINTHROTTLE TO (SHIP:CONTROL:MAINTHROTTLE + THROT)/2.
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO SHIP:CONTROL:MAINTHROTTLE.
		PRINT ROUND(dT,2)+ spaces AT					(9,1).
		PRINT ROUND(vTime,2)+ spaces AT					(9,2).
		PRINT ROUND(hDist,2)+ spaces AT					(9,3).
		PRINT ROUND(vDist,1)+ spaces AT					(9,4).
		PRINT ROUND(impactAvoid,1)+ spaces AT			(9,5).
		PRINT ROUND(dVSpd,2)+ spaces AT					(9,6).
		PRINT ROUND(dHSpd-hSpd,2)+ spaces AT			(9,7).
		PRINT ROUND(dVSpd - VERTICALSPEED,1)+ spaces AT	(9,8).
		PRINT ROUND(normEm,2)+ spaces AT				(9,9).
		PRINT ROUND(steerErr,2)+ spaces AT				(9,10).
		PRINT ROUND(THROT,3)+ spaces AT					(9,11).
		PRINT ROUND(hO,3)+ spaces AT					(9,13).
		PRINT ROUND(vO,3)+ spaces AT					(9,14).
		PRINT ROUND(normE,3)+ spaces AT					(9,15).
		LOG TIME:SECONDS + "," + hDist + "," + vDist + "," + impactAvoid + "," 
		+ vTime + "," + dHSpd + "," + hSpd + "," + dVSpd + "," + VERTICALSPEED 
		+ "," + steerErr + "," + THROT + "," + hPID:INPUT + "," + hPID:SETPOINT
		+ "," + hPID:ERROR + "," + hO + "," + hPID:PTERM + "," + hPID:ITERM + ","
		+ hPID:DTERM + "," + vPID:INPUT + "," + vPID:SETPOINT + "," + vPID:ERROR
		+ "," + vO + "," + vPID:PTERM + "," + vPID:ITERM + "," + vPID:DTERM + ","
		+ normE + "," + totalE + "," + PERIAPSIS TO "0:/LOGS/autoland_approach.csv".
	}
	WAIT 0.
}

//Landing phase
GEAR ON. SAS OFF. RCS ON.
SET tPID TO PIDLOOP(0.4,0.4,0.01,0,1).
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
SET oldTime TO TIME:SECONDS.
UNTIL STATUS = "LANDED" {
	SET dT TO TIME:SECONDS - oldTime.
	SET oldTime TO TIME:SECONDS.
	IF dT > 0 {
		LOCAL impact IS predictImpact(targ:TERRAINHEIGHT).
		LOCAL vDist IS ALTITUDE - (targ:TERRAINHEIGHT + gearheight + 10).
		LOCAL dVS IS -MAX(2,safeSQRT(MAX(0,vDist * ((accel() * 0.98) - (BODY:MU/BODY:POSITION:MAG^2))))).
		LOCAL errDir IS VXCL(SHIP:UP:VECTOR,targ:POSITION - impact[1]:POSITION).
		IF errDir:MAG < 10 AND errDir:MAG > 0.05 {SET SHIP:CONTROL:TRANSLATION TO frameShift(errDir * 0.5,SHIP:FACING).}
		ELSE {SET SHIP:CONTROL:TRANSLATION TO V(0,0,0).}
		SET throt TO throtFrac(errDir:MAG, 0.3).
		SET tPID:SETPOINT TO dVS.
		tPID:UPDATE(TIME:SECONDS,VERTICALSPEED).
		SET steervec TO (-VELOCITY:SURFACE * MAX(1,tPID:OUTPUT)) + (errDir * 0.1).// - (HS:NORMALIZED * MIN(HS:MAG/10,0.1)).
		SET steer TO LOOKDIRUP(steervec:NORMALIZED,SHIP:FACING:UPVECTOR).
		SET steerErr TO VANG(steervec:NORMALIZED,FACING:VECTOR).
		IF steerErr > 25 {SET THROT TO 0.}
		SET T TO tPID:OUTPUT + throt * ((ALTITUDE - targ:TERRAINHEIGHT)/(150 + gearheight)).// + throtFrac(HS:MAG,0.2).
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
		LOG TIME:SECONDS + "," + vDist + "," + dVS + "," + VERTICALSPEED + "," 
		+ steerErr + "," + THROT + "," + tPID:INPUT + "," + tPID:SETPOINT + "," 
		+ tPID:ERROR + "," + tPID:OUTPUT + "," + tPID:PTERM + "," + tPID:ITERM 
		+ "," + tPID:DTERM + "," + errDir:MAG TO "0:/LOGS/autoland_landing.csv".
	}
	WAIT 0.
}
UNLOCK STEERING.
SET SHIP:CONTROL:MAINTHROTTLE TO 0.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SET SHIP:CONTROL:TRANSLATION TO V(0,0,0).
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
SAS ON. RCS OFF.
CLEARVECDRAWS().
PRINT CHAR(7).