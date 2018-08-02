//DEPENDS:{/lib/rocket,/lib/node_basic}
//DECLARE PARAMETER Inc IS 0, Ap IS 10000.
DECLARE PARAMETER arg1 IS "Blank", arg2 IS 0, arg3 IS "---".
RUNONCEPATH("/lib/orientation").
RUNONCEPATH("/lib/rocket").
RUNONCEPATH("/lib/node_basic").

//Defaults
LOCAL Ap IS 10000.
LOCAL Inc IS 0.
LOCAL LAN IS arg3.
LOCAL doLAN IS FALSE.

//Type Handling
IF arg1:TYPENAME = "Scalar" { //Passing desired orbital elements directly
	SET Ap TO Arg1.
	SET Inc TO Arg2.
	IF arg3:TYPENAME = "Scalar" {
		SET doLAN TO TRUE.
	}
}
IF arg1:TYPENAME = "Vessel" OR (arg1:TYPENAME = "Body" AND arg1:BODY = BODY){
	SET arg1 TO arg1:OBT.
}
IF arg1:TYPENAME = "Orbit" {
	SET Inc TO arg1:INCLINATION.
	SET LAN TO arg1:LAN.
	SET doLAN TO TRUE.
}

/////////////////////////
//Launch Window
IF doLAN {
	LOCAL lat IS SHIP:LATITUDE.
	LOCAL eclipticNormal IS v(0,-1,0) * ANGLEAXIS(-Inc,SOLARPRIMEVECTOR * ANGLEAXIS(Lan, v(0,-1,0))).
	LOCAL planetNormal IS HEADING(0,lat):VECTOR.
	LOCAL bodyInc IS VANG(planetNormal, eclipticNormal).
	LOCAL beta IS ARCCOS(MAX(-1,MIN(1,COS(bodyInc) * SIN(lat) / SIN(bodyInc)))).
	LOCAL intersectdir IS VCRS(planetNormal, eclipticNormal):NORMALIZED.
	LOCAL intersectpos IS -VXCL(planetNormal, eclipticNormal):NORMALIZED.
	LOCAL launchtimedir IS (intersectdir * SIN(beta) + intersectpos * COS(beta)) * COS(lat) + SIN(lat) * planetNormal.
	LOCAL launchtime IS VANG(launchtimedir, SHIP:POSITION - BODY:POSITION) / 360 * BODY:ROTATIONPERIOD.
	if VCRS(launchtimedir, SHIP:POSITION - BODY:POSITION)*planetNormal < 0 {
		SET launchtime TO BODY:ROTATIONPERIOD/2 - launchtime.
		SET inc TO -inc.
	}
	IF launchtime < 21600 { //6 hours
		CLEARSCREEN.
		PRINT "Warping to launch window...".
		doWarp(utOf(launchtime)-110).
	}
	ELSE SET doLAN TO FALSE.
}
/////////////////////////

FUNCTION calcazi {
    LOCAL l IS round(LATITUDE,3).
    IF abs(Inc) > 90 AND abs(Inc) > 180-abs(l) {SET Inc TO 180-abs(l). RETURN 270.}
    IF abs(Inc) < abs(l) {SET Inc TO abs(l). RETURN 90.}
    LOCAL head IS ARCSIN(COS(inc)/COS(l)).
    IF inc < 0 SET head TO 180 - head.
    LOCAL vO IS SHIP:VELOCITY:ORBIT.
    LOCAL vD IS HEADING(head,0)*V(0,0,sqrt(BODY:MU/(Ap+BODY:RADIUS))).
    IF vO:MAG > vD:MAG*0.9 SET vO:MAG TO vD:MAG*0.9.
    LOCAL V_corr IS (vD)-(vO-VDOT(vO,UP:VECTOR)*UP:VECTOR).
    RETURN arctan2(vdot(V_corr, heading(90,0):vector),vdot(V_corr, ship:north:vector)).
}
WHEN STATUS <> "LANDED" AND STATUS <> "PRELAUNCH" THEN {GEAR OFF. LEGS OFF.}
LOCAL ApMgn IS 0.
LOCAL errMul IS 3000.
LOCAL turnStart IS 100.
LOCAL turnEnd IS 2000.
LOCAL endAlt IS 0.
LOCAL THRT IS 1.
LOCAL PITCH IS 90.
LOCAL Atmo IS FALSE.
LOCAL azi IS calcazi().
LOCAL sp IS "              ".
IF BODY:ATM:EXISTS = TRUE {
	IF Ap < BODY:ATM:HEIGHT {SET Ap TO BODY:ATM:HEIGHT + 10000.}
    SET ApMgn TO 500.
	SET errMul TO errMul * 10.
	UNTIL BODY:ATM:ALTITUDEPRESSURE(turnStart) <= 0.003 {SET turnStart TO turnStart + 100.}
	SET turnEnd TO turnStart.
	UNTIL BODY:ATM:ALTITUDEPRESSURE(turnEnd) <= 0.0003 {SET turnEnd TO turnEnd + 100.}
	SET Atmo TO TRUE.
    SET endAlt TO BODY:ATM:HEIGHT.
}
CLEARSCREEN.
PRINT "Launching to " + (Ap/1000) + "km orbit".
LOCAL Txt IS "with an inclination of " + round(ABS(Inc),1).
IF doLAN SET Txt TO Txt + " and a LAN of " + round(ABS(Lan),1) + " degrees.".
ELSE SET Txt TO Txt + " degrees.".
PRINT Txt.
IF STATUS = "LANDED" OR STATUS = "PRELAUNCH"{
    PRINT "Counting down:" + sp + sp + sp AT (0,2).
    FROM {LOCAL cd IS 5.} UNTIL cd = 0 STEP {SET cd TO cd-1.} DO {
        PRINT cd AT (15,2). WAIT 1.
    }
}
IF NOT SHIP:PARTSTAGGED("launchRCS"):EMPTY RCS ON.
PRINT "Launch!" + sp.

SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
SAS OFF.
LOCK THROTTLE TO THRT.
LOCAL steer IS LOOKDIRUP(SHIP:UP:VECTOR,SHIP:FACING:UPVECTOR).
LOCK STEERING TO steer.
stageCheck().
WAIT UNTIL ALT:RADAR > 20. //Clear launch area
PRINT "Performing roll maneuver..." + sp AT (0,2).
SET steer TO HEADING(azi,PITCH). //Roll maneuver
IF Atmo { //Gravity turn
	WAIT UNTIL AIRSPEED > 65.
	PRINT "Starting gravity turn..." + sp AT (0,2).
	SET steer TO HEADING(azi,80).
	LOCAL t IS TIME:SECONDS.
	WAIT UNTIL VANG(SRFPROGRADE:VECTOR,SHIP:UP:vector) > 10.// OR TIME:SECONDS - t > 15.
}
PRINT "Main guidance active." + sp AT (0,2).
PRINT "Current apoapsis:".
PRINT "     Current LAN:".
PRINT "  Launch heading:".
PRINT "       Pitch err:".
PRINT "     Desired TWR:".
PRINT "     Current TWR:".
PRINT " ".
PRINT "Atlitude Percent:".
LOCAL HIST IS FALSE.
UNTIL ALTITUDE > endAlt AND APOAPSIS >= Ap - ApMgn/2 {
    stageCheck().
    LOCAL ALTPER IS MIN(1,MAX(0,ALT:RADAR-turnStart)/(turnEnd-turnStart)).
    LOCAL dTWR IS 1.75 + ALTPER.
    SET azi TO calcazi().
	LOCAL timeCorr IS MAX(0,(40-ETA:APOAPSIS)/15)^1.5 * 6.
	LOCAL srfPitch IS (VANG(UP:VECTOR, SRFPROGRADE:VECTOR)) * (1-ALTPER).
	LOCAL orbPitch IS (90 - timeCorr) * ALTPER.
	SET PITCH TO 90 - srfPitch - orbPitch.
	SET steer TO HEADING(azi,PITCH).
    SET mTWR TO SHIP:AVAILABLETHRUST / MAX(weight(),MASS*KERBIN:MU/KERBIN:RADIUS^2).
    IF mTWR = 0 SET mTWR TO 10.
    LOCAL apErr IS (Ap+ApMgn-APOAPSIS) / (errMul*MAX(0.01,mTWR-1)) + timeCorr.
	LOCAL dTHRT IS max(0,min(dTWR/mTWR,apErr)).
	IF dTHRT < 0.05 SET dTHRT TO 0.05.
	IF APOAPSIS < AP SET HIST TO FALSE.
	IF APOAPSIS > AP + ApMgn OR HIST = TRUE {SET dTHRT TO 0. SET HIST TO TRUE.}
    SET THRT TO THRT + max(-0.01-ALTPER*.04,min(dTHRT-THRT,0.01+ALTPER*.04)). //throttle smoothing
    PRINT round(APOAPSIS) + sp AT (18,3).
    PRINT round(OBT:LAN,3)+ sp AT (18,4).
    PRINT round(azi,2) + sp AT (18,5).
    PRINT round(PITCH-curPitch(),1) + sp AT (18,6).
	PRINT round(dTWR,1) + sp AT (18,7).
    PRINT round(mTWR*THRT,1) + sp AT (18,8).
	PRINT round(ALTPER,2) + sp AT (18,10).
    WAIT 0.
}
RCS OFF.
SET THRT TO 0.
WAIT 0.
UNLOCK THROTTLE.
IF NOT SHIP:PARTSTAGGED("launchStage"):EMPTY {STAGE. WAIT 4.}
LOCAL mods IS LIST(
	"ModuleProceduralFairing",
	"ModuleDeployableAntenna",
	"ModuleDeployableSolarPanel",
	"ModuleDeployableRadiator",
	"ModuleActiveRadiator"
).
LOCAL ev IS LIST(
	"Deploy",
	"Extend Antenna",
	"Extend Solar Panel",
	"Extend Radiator",
	"Activate Radiator"
).
LOCAL iter IS mods:ITERATOR.
UNTIL NOT iter:NEXT{
    LOCAL event IS FALSE.
    FOR p IN SHIP:PARTSTAGGED("launch") {IF partEvent(p,iter:VALUE,ev[iter:INDEX]) = TRUE SET event TO TRUE.}
    IF event = TRUE {
        IF iter:INDEX = 0 {WAIT 4.}
        WAIT 0.
    }
}
CLEARSCREEN.
PRINT "Circularizing...".
ADD nodeCirc(utAP()).
doNode(NEXTNODE).
SAS ON.
WAIT 0.5.
IF NOT SHIP:PARTSTAGGED("endStage"):EMPTY {STAGE. WAIT 5.}