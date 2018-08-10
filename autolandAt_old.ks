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
//SET targTime TO utOf(30).
//SET ang TO 0.
//SET err TO 0.
//SET bodyrot TO 0.
//SET deorb TO NODE(targTime,0,0,0).
//ADD deorb.
//SET targTime TO deorb:ETA.
//
//LOCAL FUNCTION makeDeorb {
//	FOR n IN ALLNODES {REMOVE n.}
//	SET deorb TO nodeMoveApsis(utOf(targTime),minSafeAltitude).
//	ADD deorb.
//	LOCAL t IS targTime + deorb:ORBIT:PERIOD/2.
//	SET bodyrot TO 360 * (t / BODY:ROTATIONPERIOD).
//	LOCAL periPos IS POSITIONAT(SHIP,utOf(t)) - BODY:POSITION.
//	
//	LOCAL insct IS VCRS(obtNrm(SHIP),periPos):NORMALIZED.
//	LOCAL targXCL IS VXCL(-insct,LATLNG(targ:LAT,targ:LNG + bodyrot):POSITION - BODY:POSITION).
//	SET err TO VANG(periPos,targXCL).
//	IF OBT:INCLINATION > 90 {SET err TO -err.}
//	SET periPos TO (periPos * ANGLEAXIS(err,insct)).
//	
//	SET ang TO VANG(LATLNG(targ:LAT,targ:LNG + bodyrot):POSITION - BODY:POSITION,periPos) + MAX(0,err - 90)/5.
//}
//makeDeorb().
//UNTIL ang < 0.1 AND err <= 90{ //Position PE over target LNG
//    SET targTime TO targTime + ang * ((OBT:PERIOD / 360)).
//    IF targTime < 0 {SET targTime TO targTime + OBT:PERIOD.}
//    makeDeorb().
//	//wait 0.1.
//}
//doNode().
//WAIT 1.
//SET periPos TO POSITIONAT(SHIP,utPe()) - BODY:POSITION.
//LOCAL t IS timeToTruAnom(OBT,270).
//LOCAL sgn IS -1.
//IF OBT:INCLINATION > 90 {
//	SET t TO timeToTruAnom(OBT,90).
//	SET sgn TO 1.
//}
//SET bodyrot TO 360 * (ETA:PERIAPSIS / BODY:ROTATIONPERIOD).
//LOCAL insct IS VCRS(obtNrm(SHIP),periPos):NORMALIZED.
//LOCAL targXCL IS VXCL(-insct,LATLNG(targ:LAT,targ:LNG + bodyrot):POSITION - BODY:POSITION).
//LOCAL err IS VANG(periPos,targXCL) * sgn.
//LOCAL t IS timeToTruAnom(OBT,270).
//LOCAL align IS nodeInc(utOf(t),err).
//ADD align.
//IF align:DELTAV:MAG > 5 {doNode().} ELSE {REMOVE align.}
//
SET t TO utOf(ETA:PERIAPSIS - 1.5 * (vAT(SHIP,ETA:PERIAPSIS):MAG / accel() * 0.75)).
SET pSpd TO vAT(SHIP,t).
LOCK STEERING TO -pSpd.
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
PRINT "   dSpd:".
PRINT "   hSpd:".
PRINT "sterErr:".
PRINT "  throt:".
PRINT " ".
PRINT "   hPID:".
PRINT "   vPID:".
PRINT "  normE:".
LOCAL hPID IS PIDLOOP(0.4,0.3,0.0,0,1).
LOCAL vPID IS PIDLOOP(0.04,0.03,0.06,0,1).
LOCAL oldTime IS 0.
LOCAL scanTime IS 0.
LOCAL impactAvoid IS 0.
LOCAL steer IS SRFRETROGRADE:VECTOR.
LOCK STEERING TO steer.
LOCAL hDist IS targ:ALTITUDEPOSITION(ALTITUDE):MAG.
UNTIL hDist < 60 {
	LOCAL dT IS TIME:SECONDS - oldTime.
	IF dT > 0 {
		SET oldTime TO TIME:SECONDS.
		LOCAL R IS BODY:POSITION.
		SET hDist TO targ:ALTITUDEPOSITION(ALTITUDE):MAG.
		LOCAL impact IS predictImpact(targ:TERRAINHEIGHT).
		IF impact[1]:DISTANCE < targ:DISTANCE AND hDist > 500 {
			SET impactAvoid TO MAX(impactAvoid,(impact[1]:TERRAINHEIGHT + 20) - (targ:TERRAINHEIGHT + 50)).
		} ELSE {SET impactAvoid TO ROUND(impactAvoid * 0.95,1).}
		LOCAL vDist IS ALTITUDE - (targ:TERRAINHEIGHT + 50 + impactAvoid).
		LOCAL srfNorm IS VCRS(SRFPROGRADE:VECTOR,UP:VECTOR):NORMALIZED.
		LOCAL hVec IS -VCRS(R,VCRS(VELOCITY:SURFACE,R)):NORMALIZED.
		LOCAL hSpd IS VDOT(VCRS(VCRS(R,targ:POSITION),R):NORMALIZED,VELOCITY:SURFACE).
		LOCAL normEm IS VDOT(targ:POSITION,srfNorm).
		LOCAL normE IS 0.0005 * MAX(-1000,MIN(1000,normEm)).
		LOCAL dHSpd IS safeSQRT( 1.8 * MAX(1,hDist - 50) * accel()).
		LOCAL dVSpd IS -safeSQRT(vDist * ((accel() * 0.5) - (BODY:MU/R:MAG^2))).
		SET hPID:SETPOINT TO -dHSpd.
		SET vPID:SETPOINT TO dVSpd.
		hPID:UPDATE(oldTime,-hSpd).
		vPID:UPDATE(oldTime,VERTICALSPEED).
		SET totalE TO ROUND(hPID:OUTPUT + ABS(vPID:OUTPUT),2).
		SET steervec TO UP:VECTOR * vPID:OUTPUT + hVec * MAX(0.01,hPID:OUTPUT) + srfNorm * normE * CEILING(hPID:OUTPUT).
		SET steer TO steervec:NORMALIZED.
		SET steerErr TO VANG(steervec:NORMALIZED,FACING:VECTOR).
		SET THROT TO totalE.
		//SET SHIP:CONTROL:MAINTHROTTLE TO THROT.
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO THROT.
		PRINT ROUND(dT,2)+ spaces AT (9,0).
		PRINT ROUND(hDist,2)+ spaces AT (9,1).
		PRINT ROUND(vDist,1)+ spaces AT (9,2).
		PRINT ROUND(impactAvoid,1)+ spaces AT (9,3).
		PRINT ROUND(MIN(0,dVSpd - VERTICALSPEED),1)+ spaces AT (9,4).
		PRINT ROUND(normEm,2)+ spaces AT (9,5).
		PRINT ROUND(dHSpd,2)+ spaces AT (9,6).
		PRINT ROUND(hSpd,2)+ spaces AT (9,7).
		PRINT ROUND(steerErr,2)+ spaces AT (9,8).
		PRINT ROUND(THROT,3)+ spaces AT (9,9).
		PRINT ROUND(hPID:OUTPUT,3)+ spaces AT (9,11).
		PRINT ROUND(vPID:OUTPUT,3)+ spaces AT (9,12).
		PRINT ROUND(normE,3)+ spaces AT (9,13).
		LOG TIME:SECONDS + "," + hDist + "," + vDist + "," + impactAvoid + "," + dHSpd + "," + hSpd + "," + dVSpd + "," + VERTICALSPEED + "," + steerErr + "," + THROT + "," +
		hPID:INPUT + "," + hPID:SETPOINT + "," + hPID:ERROR + "," + hPID:OUTPUT + "," + hPID:PTERM + "," + hPID:ITERM + "," + hPID:DTERM + "," + 
		vPID:INPUT + "," + vPID:SETPOINT + "," + vPID:ERROR + "," + vPID:OUTPUT + "," + vPID:PTERM + "," + vPID:ITERM + "," + vPID:DTERM + "," + 
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
        SET throt TO  ROUND(MAX(0,errDir:MAG - 5),2)* 0.02 * MIN(10,0.1 * MAX(0,ALTITUDE - targ:TERRAINHEIGHT)).
		SET tPID:SETPOINT TO dVS.
        tPID:UPDATE(TIME:SECONDS,VERTICALSPEED).
		SET steervec TO (UP:VECTOR * MAX(0.2,tPID:OUTPUT)) + (errDir:NORMALIZED * MIN(1,throt)).
		SET steer TO steervec:NORMALIZED.
		SET steerErr TO VANG(steervec:NORMALIZED,FACING:VECTOR).
        IF steerErr > 45 {SET THROT TO 0.}
		SET T TO tPID:OUTPUT + throt.
        //SET SHIP:CONTROL:MAINTHROTTLE TO T.
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
    }
    WAIT 0.
}
UNLOCK STEERING.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SET SHIP:CONTROL:TRANSLATION TO V(0,0,0).
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
SAS ON. RCS OFF.
UNSET impactdraw.
PRINT CHAR(7).