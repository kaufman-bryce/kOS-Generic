RUNONCEPATH("/lib/orientation").
RUNONCEPATH("/lib/rocket").
RUNONCEPATH("/lib/node_basic").
//RUN lib_PID.
CLEARSCREEN.


//LOCAL vPID IS pid_new(2,0.5,0.2).
//pid_limits(vPID,-10,90,-10,90).

FUNCTION descentHold {RETURN weight()/AVAILABLETHRUST.}
FUNCTION radar {RETURN (SHIP:POSITION - SHIP:GEOPOSITION:POSITION):MAG.}
FUNCTION vsLim {
	LOCAL modifier IS 0.015*GROUNDSPEED/accel().
	RETURN -MAX(1,(1-modifier)*0.5*radar()^0.7).
}

LOCAL ipu IS CONFIG:IPU.
IF ipu<400 {SET CONFIG:IPU TO 400.}

IF PERIAPSIS > 10000 {
	ADD nodeMoveApsis(utOf(180),5000).
	doNode(NEXTNODE).
}

LOCAL periTime IS utOf(ETA:PERIAPSIS).
LOCAL periVel IS VELOCITYAT(SHIP,periTime):SURFACE:MAG.
LOCAL totalTime IS burnTime(periVel).
PRINT "Warping to burn start.".
doWarp(periTime-20-totalTime/2).
SAS OFF.
LOCAL steer IS SRFRETROGRADE.
LOCK STEERING TO steer.
PRINT "Orienting retrograde.".
WAIT UNTIL TIME:SECONDS > periTime-totalTime/2.
PRINT "Starting burn.".
PRINT "     VS Limit:".
PRINT " weightCancel:".
PRINT "       VS Err:".
PRINT "       HS Err:".
PRINT "   HS VS comp:".
LOCAL vsErr IS 0.
LOCAL hsErr IS 0.
LOCK THROTTLE TO descentHold() - vsErr + hsErr.
//WAIT UNTIL GROUNDSPEED <= vsLim().
UNTIL STATUS = "LANDED" {
	stageCheck().
	SET vsErr TO min(descentHold()*0.8,VERTICALSPEED-vsLim())/10.
	SET hsErr TO ROUND(max(0,(GROUNDSPEED+vsLim())/50),2).
	SET steer TO LOOKDIRUP(SRFRETROGRADE:VECTOR + (UP:VECTOR * -MIN(0,vsErr)),SRFRETROGRADE:UPVECTOR).
	PRINT ROUND(vsLim(),2)       + "     " AT (15,3).
	PRINT ROUND(descentHold(),2) + "     " AT (15,4).
	PRINT ROUND(vsErr,2)         + "     " AT (15,5).
	PRINT hsErr                  + "     " AT (15,6).
	PRINT ROUND(0.015*GROUNDSPEED/accel(),2)+"     " AT (15,7).
	WAIT 0.
}
UNLOCK THROTTLE.
UNLOCK STEERING.
SAS ON.
WAIT 5.
SAS OFF.

//LOCAL stopThrust IS AVAILABLETHRUST - weight().
//LOCAL stopDist IS AIRSPEED^2 / (2*(max(0.001,stoppingThrust)/MASS)).


SET CONFIG:IPU TO ipu.
