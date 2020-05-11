// #include "/lib/orientation"
// #include "/lib/rocket"
// #include "/lib/node_basic"
// #include "/lib/node_rdvs"
PARAMETER mode is 0.
LOCAL tgt IS TARGET.
IF BODY <> tgt:OBT:BODY {PRINT "Err: Target must orbit same body as current vessel.".}
ELSE IF SHIP:DOCKINGPORTS:EMPTY {PRINT "Err: Craft has no docking ports".}
ELSE {
	RUNONCEPATH("/lib/orientation").
	RUNONCEPATH("/lib/rocket").
	RUNONCEPATH("/lib/node_basic").
	RUNONCEPATH("/lib/node_rdvs").

	IF mode > 0 {// 1, plane alignment
		CLEARSCREEN.
		ADD nodeAlignPlane(tgt).
		IF NEXTNODE:DELTAV:MAG > 5 {
			PRINT "Performing plane alignment...".
			doNode(NEXTNODE).
		} ELSE REMOVE NEXTNODE.
	}
	IF mode > 1 {// 2, plot intercept transfer + match vel
		PRINT "Performing intercept burn...".
		ADD nodeIntercept(tgt).
		doNode(NEXTNODE).
		IF ETA:APOAPSIS < ETA:PERIAPSIS {
			PRINT "Matching vel at ap...".
			ADD nodeMatchVel(utAP(),tgt).
		} ELSE {
			PRINT "Matching vel at pe...".
			ADD nodeMatchVel(utPE(),tgt).
		}
		doNode(NEXTNODE).
	}
	IF mode > 2 {// 3, final approach
		SET dist TO tgt:POSITION:MAG.
		IF dist > 500 {
			PRINT "Final approach...".
			LOCAL t IS utOf(150).
			ADD vecToNode(t,((POSITIONAT(tgt,t) - POSITIONAT(SHIP,t)):NORMALIZED * (dist / 100))).
			doNode(NEXTNODE).
			ADD nodeMatchVel(utOf((dist * 0.9) / (tgt:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT):MAG),tgt).
			doNode(NEXTNODE).
		}
		PRINT "Rendezvous complete.".
	}
	IF mode > 3 {// 4, dock on arrival
		IF NOT tgt:DOCKINGPORTS:EMPTY {
			IF mode = 5 {SET SHIP:NAME TO tgt:NAME.} // For attaching new station modules
			RUN autodock(tgt).
		} ELSE PRINT "Err: Target has no docking ports!".
	}
}