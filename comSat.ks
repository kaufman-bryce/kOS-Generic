DECLARE PARAMETER grpName, totSats, targAlt.
RUNONCEPATH("lib/orientation").
RUNONCEPATH("lib/rocket").
RUNONCEPATH("lib/node_basic").


// Procedure for Satelite formation:
// 	Check for existing satelites
// 	If no other sats, just get to alt and circ.
// 	else, match SMA of previous sat, circ, then fine-tune period
// 	Assume start and target orbits are circular
// 	Plan node to raise ap to target orbit
// 	Move node forward until position at apsis is correct distance from previous sat
// 	Ensure we are on correct SIDE of sat as well.

LOCAL satNum IS 0.
LOCAL veslist IS 0.
LOCAL sat1 IS 0.
LOCAL sat2 IS 0.
LOCAL sat3 IS 0.
FUNCTION cmplt {PARAMETER x, y. PRINT "Complete!" AT (x, y).}

CLEARSCREEN.
PRINT "Communication Satelite Setup Utility".
PRINT "Constellation " + grpName + " in " + round(targAlt / 1000, 2) + "km orbit".
PRINT " ".

LIST TARGETS IN veslist.
LOCAL names IS LIST().
FOR ves IN veslist {names:ADD(ves:NAME).}// Convert list of vessels to list of names

FROM {LOCAL i IS 1.} UNTIL i > totSats STEP {SET i TO i + 1.} DO {
	IF names:CONTAINS(grpName + " " + i) {
		SET satNum TO i.
		IF i = 1 {SET sat1 TO VESSEL(grpName + " " + satNum).}
		IF i > 2 {SET sat3 TO sat2.}
		SET sat2 TO VESSEL(grpName + " " + satNum).
	} ELSE BREAK.
}

IF satNum < totSats {
	SET SHIP:NAME TO grpName + " " + (satNum + 1).
	SET SHIP:TYPE TO "Probe".
	PRINT "Comsat " + (satNum + 1) + "/" + totSats + " assuming constellation position.".
	PRINT " -Planning maneuvers...".
	ADD nodeMoveApsis(utOf(180), targAlt).
	
	IF satNum > 0 {
		LOCAL t IS 0.
		LOCAL tPos IS 0.
		LOCAL d1 IS 0.
		LOCAL d2 IS 0.
		LOCAL d3 IS 0.
		
		LOCAL tNode IS NEXTNODE.
		LOCAL dist1 IS 360 / totSats * satNum.
		LOCAL dist2 IS 360 / totSats.
		LOCAL dist3 IS 0.
		IF satNum > 2 {SET dist3 TO 360 / totSats * 2.}
		IF dist1 > 180 {SET dist1 TO 360 - dist1.}
		// Sacred target dance to summon working POSITIONAT()
		// TODO: Test if this is still neccessary.
		// Previously, needed to target a vessel first or POSITIONAT() would error out.
		SET TARGET TO sat1.
		wait 0.1.
		SET TARGET TO sat2.
		wait 0.1.
		IF satNum > 2 {
			SET TARGET TO sat3.
			wait 0.1.
		}
		FUNCTION update {
			SET t TO utOf(tNode:ETA + tNode:ORBIT:PERIOD / 2).
			SET tPos TO POSITIONAT(SHIP, t) - BODY:POSITION.
			SET d1 TO VANG(POSITIONAT(sat1, t) - BODY:POSITION, tPos).
			SET d2 TO VANG(POSITIONAT(sat2, t) - BODY:POSITION, tPos).
			IF satNum > 2 {SET d3 TO VANG(POSITIONAT(sat3, t) - BODY:POSITION, tPos).}
		}
		update().
		// Increase node ETA until ap position is correct
		UNTIL ABS(dist1 - d1) < 1 AND ABS(dist2 - d2) < 1 AND ABS(dist3 - d3) < 1 {
			LOCAL mul IS (ABS(dist1 - d1) + ABS(dist2 - d2) + ABS(dist3 - d3)).
			SET tNode:ETA TO tNode:ETA + mul.
			update().
		}
	}
	cmplt(24, 4).
	PRINT " -Executing transfer node...".
	doNode(NEXTNODE).
	SAS ON.
	cmplt(29, 5).
	WAIT 2.
	PRINT " -Executing circulatization node...".
	ADD nodeCirc(utAp()).
	doNode(NEXTNODE).
	cmplt(36, 6).

	IF satNum > 0 {
		PRINT " -Matching orbital period...".
		SAS OFF.
		IF sat1:OBT:PERIOD > OBT:PERIOD {SET steer TO PROGRADE.} ELSE {SET steer TO RETROGRADE.}
		LOCK STEERING TO steer.
		waitForRot(steer).
		LOCK THROTTLE TO 0.01.
		WAIT UNTIL ABS(sat1:OBT:PERIOD - OBT:PERIOD) <= 0.1.
		LOCK THROTTLE TO 0.
		cmplt(29, 7).
	}
	SAS ON.
	SET TARGET TO BODY.
	PRINT " ".
	PRINT " ".
	PRINT "Final orbit established.".
	IF ADDONS:AVAILABLE("RT") {
		PRINT "Deploying dishes.".
		FOR m IN SHIP:MODULESNAMED("ModuleRTAntenna") {
			IF m:HASEVENT("no target") {M:SETFIELD("target",m:PART:TAG).}
			IF m:HASEVENT("activate") {m:DOEVENT("activate").}
			WAIT 0.
		}
	}
}
ELSE PRINT "Error! Constellation already established!".