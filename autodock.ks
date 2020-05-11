// #include "lib/rocket"
// #include "lib/orientation"
PARAMETER targ IS TARGET.
RUNONCEPATH("/lib/orientation").
RUNONCEPATH("/lib/rocket").

LOCAL dock IS SHIP:DOCKINGPORTS[0].
IF NOT SHIP:PARTSTAGGED("dock"):EMPTY {
	SET dock TO SHIP:PARTSTAGGED("dock")[0].
}


IF targ:ISTYPE("Vessel") { // Find first available compatible docking port, or use prenamed port.
	IF targ:PARTSTAGGED("dockhere"):EMPTY {
		IF NOT targ:DOCKINGPORTS:EMPTY { 
			FOR d IN targ:DOCKINGPORTS {
				IF d:STATE = "Ready" AND d:NODETYPE = dock:NODETYPE {
					SET targ TO d.
					BREAK.
				}
			}
		}
	}
	ELSE {SET targ TO targ:PARTSTAGGED("dockhere")[0].}
}

IF targ:ISTYPE("Part") {
	FUNCTION numFormat {
		PARAMETER n, d.
		SET d TO d - 1.
		LOCAL pre IS "".
		LOCAL i IS 10^d.
		IF n >= 0 {SET pre TO pre + " ".}
		UNTIL i = 1 {
			IF abs(n) < i {SET pre TO pre + " ".}
			SET i TO i / 10.
		}
		RETURN pre + n.
	}
	FUNCTION frameShift {
		PARAMETER vec, dir.
		LOCAL ret IS V(0, 0, 0).
		SET ret:X TO dir:STARVECTOR * vec.
		SET ret:Y TO dir:UPVECTOR * vec.
		SET ret:Z TO dir:VECTOR * vec.
		RETURN ret.
	}

	ABORT OFF.

	CLEARSCREEN.
	PRINT "Orienting...".
	SAS OFF.
	SET steer TO LOOKDIRUP(-targ:PORTFACING:VECTOR, targ:PORTFACING:UPVECTOR)
	 * (dock:PORTFACING:INVERSE * SHIP:FACING).
	LOCK STEERING TO steer.
	waitForRot(steer).
	LOCAL exit IS FALSE.
	LOCAL minSpd IS 0.2.
	LOCAL vOff IS V(0, 0, 0).
	LOCAL vSpd IS frameShift(SHIP:VELOCITY:ORBIT - targ:SHIP:VELOCITY:ORBIT, SHIP:FACING).
	LOCAL vSpdOld IS vSpd.
	LOCAL acc IS 10.
	LOCAL vSpdD IS V(0, 0, 0).
	LOCAL vSpdE IS V(0, 0, 0).
	LOCAL oldTime IS TIME:SECONDS.
	LOCAL pos IS targ:NODEPOSITION.
	LOCAL posMode IS "approach".
	LOCAL drawT IS VECDRAW(
		{RETURN dock:NODEPOSITION + dock:PORTFACING:VECTOR:NORMALIZED * dock:ACQUIRERANGE.},
		{RETURN frameShift(vSpdE * 5, -SHIP:FACING).},
		GREEN,
		"Thrust",
		1,
		TRUE
	).
	LOCAL drawPos IS VECDRAW(
		{RETURN dock:NODEPOSITION.},
		{RETURN pos - dock:NODEPOSITION.},
		CYAN,
		"Target",
		1,
		TRUE
	).
	IF (dock:NODEPOSITION - targ:NODEPOSITION) * targ:PORTFACING:VECTOR < 0 {
		SET posMode TO "clearance".
	}
	RCS ON.
	CLEARSCREEN.
	PRINT "X".
	PRINT "Y".
	PRINT "Z".
	UNTIL exit = TRUE {
		SET steer TO LOOKDIRUP(-targ:PORTFACING:VECTOR, targ:PORTFACING:UPVECTOR)
		 * (dock:PORTFACING:INVERSE * SHIP:FACING).
		FUNCTION setPos {
			PARAMETER p.
			SET pos TO p.
			SET vOff TO frameShift(pos - dock:NODEPOSITION, SHIP:FACING).
		}
		
		IF posMode = "dock" {
			LOCAL acqRange IS (dock:ACQUIRERANGE + targ:ACQUIRERANGE) / 2.
			setPos(targ:NODEPOSITION + (targ:PORTFACING:VECTOR * acqRange)).
			SET maxSpd TO 1.
			SET cutoff TO 0.05.
			// Magnify lateral errors to ensure alignment before reaching target.
			LOCAL v2 IS frameShift(V(5, 5, 1) * dock:PORTFACING, SHIP:FACING).
			SET vOff TO V(vOff:X * v2:X, vOff:Y * v2:Y, vOff:Z * v2:Z).
			IF vOff:MAG < acqRange {exit ON.}
		} ELSE IF posMode = "approach" {
			setPos(targ:NODEPOSITION + (targ:PORTFACING:VECTOR * 20)).
			SET maxSpd TO 10.
			SET cutoff TO 0.1.
			IF vOff:MAG < 0.2 SET posMode TO "dock".
		} ELSE IF posMode = "clearance" {
			LOCAL offDir IS VXCL(targ:PORTFACING:VECTOR, dock:NODEPOSITION - targ:NODEPOSITION):NORMALIZED.
			IF (targ:NODEPOSITION - dock:NODEPOSITION):MAG >= 40 {
				setPos(targ:NODEPOSITION + targ:PORTFACING:VECTOR * 10 + offDir * 40).
			} ELSE {setPos(offDir * 45).}
			SET maxSpd TO 10.
			SET cutoff TO 0.15.
			IF (dock:NODEPOSITION - targ:NODEPOSITION) * targ:PORTFACING:VECTOR > 0 {
				SET posMode TO "approach".
			}
		}
		
		SET vSpdOld TO vSpd.
		SET vSpd TO frameShift(SHIP:VELOCITY:ORBIT - targ:SHIP:VELOCITY:ORBIT, SHIP:FACING).
		SET vSpdD TO vOff:NORMALIZED * MAX(minSpd, MIN(maxSpd, SQRT(vOff:MAG * acc * 0.9))).
		SET vSpdE TO (vSpdD - vSpd) * 2.
		IF vSpdE:MAG < cutoff {SET vSpdE TO V(0, 0, 0).}
		SET SHIP:CONTROL:TRANSLATION TO vSpdE.
		LOCAL dT IS TIME:SECONDS - oldTime.
		SET oldTime TO TIME:SECONDS.
		IF vSpdE:MAG >= 1 {SET acc TO ((acc * 14) + ABS(vSpd:MAG - vSpdOld:MAG) / dT)/15.}
		
		PRINT numFormat(ROUND(vOff:X, 2), 3) AT (2, 0).
		PRINT numFormat(ROUND(vOff:Y, 2), 3) AT (2, 1).
		PRINT numFormat(ROUND(vOff:Z, 2), 3) AT (2, 2).
		PRINT "| " + numFormat(ROUND(vSpd:X, 2), 2) + " m/s" AT (10, 0).
		PRINT "| " + numFormat(ROUND(vSpd:Y, 2), 2) + " m/s" AT (10, 1).
		PRINT "| " + numFormat(ROUND(vSpd:Z, 2), 2) + " m/s" AT (10, 2).
		PRINT "| " + numFormat(ROUND(vSpdE:X, 2), 2) AT (23, 0).
		PRINT "| " + numFormat(ROUND(vSpdE:Y, 2), 2) AT (23, 1).
		PRINT "| " + numFormat(ROUND(vSpdE:Z, 2), 2) AT (23, 2).
		PRINT posMode + "       " AT (0,3).
		// PRINT "Acc: " + numFormat(ROUND(acc, 2), 2) AT (0,4).
		
		IF ABORT exit ON.
	}
	SET SHIP:CONTROL:TRANSLATION TO V(0,0,0).
	SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
	CLEARVECDRAWS().
	CLEARSCREEN.
	RCS OFF.
} ELSE PRINT "Autodock failed: Invalid target!".