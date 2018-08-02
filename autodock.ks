//DEPENDS:{/lib/rocket,/lib/orientation}
PARAMETER targ.
RUNONCEPATH("/lib/orientation").
RUNONCEPATH("/lib/rocket").

FUNCTION numFormat{
    PARAMETER n,d.
    SET d TO d-1.
    LOCAL pre IS "".
    LOCAL i IS 10^d.
    IF n >= 0 {SET pre TO pre + " ".}
    UNTIL i = 1{
        IF abs(n) < i {SET pre TO pre + " ".}
        SET i TO i/10.
    }
    RETURN pre+n.
}
FUNCTION frameShift {
    PARAMETER vec,dir.
    LOCAL ret IS V(0,0,0).
    SET ret:X TO dir:STARVECTOR * vec.
    SET ret:Y TO dir:UPVECTOR * vec.
    SET ret:Z TO dir:VECTOR * vec.
    RETURN ret.
}

ag1 off.
LOCAL dock TO SHIP:PARTSTAGGED("dock")[0].

LOCAL drawT TO VECDRAW().
SET drawT:LABEL TO "Thrust".
SET drawT:COLOR TO GREEN.
LOCAL drawPos TO VECDRAW().
SET drawPos:LABEL TO "Target".
SET drawPos:COLOR TO CYAN.


CLEARSCREEN.
SAS OFF.
SET steer TO LOOKDIRUP(-targ:PORTFACING:VECTOR,targ:PORTFACING:UPVECTOR) * (dock:PORTFACING:INVERSE * SHIP:FACING).
LOCK STEERING TO steer.
waitForRot(steer).
LOCAL exit TO FALSE.
LOCAL vOff TO V(6,0,0).
LOCAL posMode TO "approach".
IF (dock:position-targ:POSITION) * targ:PORTFACING:VECTOR < 0{SET posMode TO "clearance".}
LOCAL pos TO targ:POSITION.
RCS ON.
PRINT "X".
PRINT "Y".
PRINT "Z".
SET drawT:SHOW TO TRUE.
SET drawPos:SHOW TO TRUE.
UNTIL exit = TRUE {
    SET steer TO LOOKDIRUP(-targ:PORTFACING:VECTOR,targ:PORTFACING:UPVECTOR) * (dock:PORTFACING:INVERSE * SHIP:FACING).
    FUNCTION setPos {
        PARAMETER p.
        SET pos TO p.
        SET vOff TO frameShift(pos - dock:position,SHIP:FACING).
    }
    
    IF posMode = "dock" {
        setPos(targ:POSITION).
        SET maxSpd TO 1.
        SET cutoff TO 0.
		LOCAL v2 IS frameShift(V(5,5,1)*dock:PORTFACING,SHIP:FACING).
		SET vOff TO V(vOff:X*v2:X,vOff:Y*v2:Y,vOff:Z*v2:Z).
        IF vOff:MAG < 1 exit on.
    } ELSE IF posMode = "approach" {
        setPos(targ:POSITION + (targ:PORTFACING:VECTOR * 20)).
        SET maxSpd TO MIN(5,MAX(1,vOff:MAG/50)).
        SET cutoff TO 0.1.
        IF vOff:MAG < 0.2 SET posMode TO "dock".
    } ELSE IF posMode = "clearance" {
        LOCAL offDir IS VXCL(targ:PORTFACING:VECTOR,dock:position-targ:POSITION):NORMALIZED.
        IF (targ:POSITION-dock:POSITION):MAG >= 40 {
            setPos(targ:POSITION + targ:PORTFACING:VECTOR * 10 + offDir * 40).
        } ELSE {setPos(offDir * 45).}
        SET maxSpd TO MIN(5,MAX(1,vOff:MAG/50)).
        SET cutoff TO 0.15.
        IF (dock:position-targ:POSITION) * targ:PORTFACING:VECTOR > 0 SET posMode TO "approach".
    }
    
    SET vSpd TO frameshift(SHIP:VELOCITY:ORBIT-targ:SHIP:VELOCITY:ORBIT,SHIP:FACING).
    SET vSpdD TO vOff:NORMALIZED * MAX(0.2,MIN(maxSpd,vOff:MAG * (maxSpd/15))).
    SET vSpdE TO (vSpdD - vSpd) * 2.
    IF vSpdE:MAG < cutoff {SET vSpdE TO V(0,0,0).}
    SET SHIP:CONTROL:TRANSLATION TO vSpdE.
    
    PRINT numFormat(round(vOff:X,2),3) AT (2,0).
    PRINT numFormat(round(vOff:Y,2),3) AT (2,1).
    PRINT numFormat(round(vOff:Z,2),3) AT (2,2).
    PRINT "| " + numFormat(round(vSpd:X,2),2) + " m/s" AT (10,0).
    PRINT "| " + numFormat(round(vSpd:Y,2),2) + " m/s" AT (10,1).
    PRINT "| " + numFormat(round(vSpd:Z,2),2) + " m/s" AT (10,2).
    PRINT "| " + numFormat(round(vSpdE:X,2),2) AT (23,0).
    PRINT "| " + numFormat(round(vSpdE:Y,2),2) AT (23,1).
    PRINT "| " + numFormat(round(vSpdE:Z,2),2) AT (23,2).
    PRINT posMode + "       " AT (0,3).
    
    SET drawT:START to dock:POSITION + dock:PORTFACING:VECTOR * 2.
    SET drawT:vec to vSpdE * 20.
    SET drawPos:START to dock:POSITION.
    SET drawPos:vec to pos - dock:position.
    if ag1 exit on.
}
SET SHIP:CONTROL:TRANSLATION TO V(0,0,0).
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
CLEARVECDRAWS().
CLEARSCREEN.