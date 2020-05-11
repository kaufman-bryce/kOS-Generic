@LAZYGLOBAL OFF.
// #include lib\node_basic.ks

function timeToTruAnom {
	PARAMETER orb, a2.
	// Returns time in seconds until orb will pass True Anomaly a2 (deg)
	LOCAL pi IS CONSTANT():PI.
	LOCAL e IS ORB:ECCENTRICITY.
	LOCAL f IS SQRT((1 - e) / (1 + e)).
	LOCAL e1 IS 2 * ARCTAN(f * TAN(orb:TRUEANOMALY / 2)).
	LOCAL e2 IS 2 * ARCTAN(f * TAN(a2 / 2)).
	LOCAL n IS 2 * pi / orb:PERIOD.
	LOCAL diff IS ((CONSTANT:DEGTORAD * e2 - e * SIN(e2)) / n)
	- ((CONSTANT:DEGTORAD * e1 - e * SIN(e1)) / n).
	IF diff < 0 {SET diff TO diff + orb:PERIOD.}
	ELSE IF diff > orb:PERIOD {SET diff TO diff - orb:PERIOD.}
	RETURN diff.
}

FUNCTION nodeAlignPlane {
	PARAMETER normT.
	// Returns node to align orbit planes with target
	// Accepts orbitables, orbits, or orbit-normal vectors
	LOCAL curTime IS TIME:SECONDS.
	LOCAL normS IS obtNrm(SHIP).
	IF normT:TYPENAME <> "Vector" {SET normT TO obtNrm(normT).}
	LOCAL inter IS VCRS(normS, normT):NORMALIZED.
	LOCAL peLoc IS POSITIONAT(SHIP, utPe()) - BODY:POSITION.
	LOCAL cLoc IS -BODY:POSITION.
	LOCAL peVel IS vAt(SHIP, utPe()).
	LOCAL tA IS VANG(inter, peLoc).
	IF VDOT(inter, peVel) < 0 {SET tA TO -tA.}
	LOCAL curTA IS VANG(cLoc, peLoc).
	IF VDOT(cLoc,peVel) < 0 {SET curTA TO -curTA.}
	LOCAL diff IS MOD(tA - curTA + 360, 360).
	IF diff > 180 {SET tA TO tA - 180.}
	LOCAL t IS timeToTruAnom(obt, tA).
	LOCAL inc IS VANG(normS, normT).
	IF VDOT(normT, vAt(SHIP, curTime + t))>0{SET inc TO -inc.}
	RETURN nodeInc(utOf(t), inc).
}

function orbitIntersects {
	PARAMETER obt1, obt2.
	// Returns a list: [status, time to intersect A, time to intersect B]
	// Assumes obt1 is performing maneuversand that orbits are co-planar.
	// Status will be -1, 0, or 1.
	// Status -1 : Orbit 1 too small, no intersect. Raise AP.
	// Status 0 : Intersections exist, other two options present
	// Status 1 : Orbit 1 too big, no intersect. Lower PE.
	LOCAL e1 IS obt1:ECCENTRICITY.
	LOCAL e2 IS obt2:ECCENTRICITY.
	LOCAL B IS obt1:SEMIMAJORAXIS / obt2:SEMIMAJORAXIS * (1 - e1 * e1) / (1 - e2 * e2).
	LOCAL delta IS obt2:ARGUMENTOFPERIAPSIS - obt1:ARGUMENTOFPERIAPSIS.
	LOCAL gamma IS ARCTAN2(e1 - B * e2 * COS(delta), -B * e2 * SIN(delta)).
	LOCAL S IS (1 - B) * COS(gamma) / B / e2 / SIN(delta).
	IF S > 0.99999 {RETURN LIST(1).}
	else IF S < -0.99999 {RETURN LIST(-1).}
	LOCAL beta1 IS ARCSIN(S) - gamma.
	LOCAL beta2 IS 180 - ARCSIN(S) - gamma.
	RETURN LIST(
		0, 
		timeToTruAnom(obt1, beta1),
		timeToTruAnom(obt1, beta2)
	).
}

function nodeMatchOrbits {
	PARAMETER tgt.
	// Returns node to match orbit with target, ignoring phasing
	// Accepts orbitable or orbit
	// Use nodeTouchObt first, requires intersects
	// THIS IS *NOT* A RENDEVOUS.
	IF tgt:TYPENAME <> "Orbit" {SET tgt TO tgt:OBT.}
	LOCAL l IS orbitIntersects(OBT, tgt).
	IF l[0] <> 0{RETURN l[0].}
	LOCAL t IS MIN(l[1], l[2]).
	LOCAL actual_vel IS vAt(SHIP, utOf(t)).
	LOCAL intersection_r IS rAt(SHIP, utOf(t)).
	LOCAL tgt_r IS BODY:POSITION - tgt:POSITION.
	LOCAL tgt_normal IS VCRS(tgt:VELOCITY:ORBIT, tgt_r).
	LOCAL side IS VCRS(tgt_normal, tgt_r).
	LOCAL true_anomaly IS VANG(intersection_r, tgt_r).
	IF VDOT(side, intersection_r) < 0 {SET true_anomaly TO -true_anomaly.}
	SET true_anomaly TO true_anomaly + tgt:OBT:TRUEANOMALY.
	LOCAL t2 IS timeToTruAnom(tgt:OBT, true_anomaly).
	LOCAL expected_vel IS vAt(tgt, utOf(t2)).
	RETURN vecToNode(utOf(t), expected_vel - actual_vel).
}

FUNCTION nodeMatchVel {
	PARAMETER t, tgt.
	// Blindly matches velocity with target at given time.
	RETURN vecToNode(t, vAt(tgt, t) - vAt(SHIP, t)).
}

FUNCTION nodeTouchObt {
	PARAMETER t, tgt.
	// Returns a node. Time t becomes an apsis, opposing apsis touches tgt orbit.
	// Accepts orbitables or orbits.
	IF tgt:TYPENAME <> "Orbit" {SET tgt TO tgt:OBT.}
	LOCAL nrm IS obtNrm(tgt).
	LOCAL LANVEC IS SOLARPRIMEVECTOR * ANGLEAXIS(tgt:LAN, V(0, -1, 0)).
	LOCAL periVec IS LANVEC * ANGLEAXIS(tgt:ARGUMENTOFPERIAPSIS, -nrm).
	LOCAL apsisVec IS VXCL(nrm, (rAt(SHIP, utOf(t)))):NORMALIZED.
	LOCAL tA IS VANG(periVec, apsisVec).
	IF VANG(apsisVec, VCRS(nrm, periVec)) > 90 {SET tA TO 360 - tA.}
	LOCAL e IS tgt:ECCENTRICITY.
	LOCAL apsisHeight IS (tgt:SEMIMAJORAXIS * ((1 - e^2)/(1 + e * COS(tA)))) - BODY:RADIUS.
	RETURN nodeMoveApsis(t,apsisHeight).
}

FUNCTION nodeIntercept {
	PARAMETER tgt.
	// Returns a node that intercepts tgt.
	// Assumes current orbit coplanar and of a lower altitude
	LOCAL tSMA IS tgt:OBT:SEMIMAJORAXIS.
	LOCAL sSMA IS OBT:SEMIMAJORAXIS.
	LOCAL nd IS NODE(TIME:SECONDS + 240, 0, 0, 0).
	LOCAL dist IS 1000.
	LOCAL prevDist IS 99999999999999999.
	ADD nd.
	LOCAL FUNCTION update {
		LOCAL n IS nodeTouchObt(nd:ETA, tgt).
		SET nd:PROGRADE TO n:PROGRADE.
		SET nd:NORMAL TO n:NORMAL.
		SET nd:RADIALOUT TO n:RADIALOUT.
		LOCAL t IS utOf(nd:ETA + nd:ORBIT:PERIOD / 2).
		SET dist TO (POSITIONAT(tgt, t)-POSITIONAT(SHIP, t)):MAG.
	}
	//Increase node ETA until ap position is correct
	LOCAL mul IS 1.
	LOCAL flips IS 0.
	LOCAL nextOrb IS 1.
	UNTIL dist < 400 {
		SET prevDist TO dist.
		SET nd:ETA TO nd:ETA + MIN(OBT:PERIOD / 36, dist / 2000) * mul.
		update().
		IF prevDist < dist AND dist < tSMA {
			IF dist < tSMA / 10 * MAX(tSMA / sSMA, sSMA / tSMA) {
				SET mul TO mul * -0.5.
				SET flips TO flips + 1.
			} ELSE SET mul TO mul * -1.
			IF flips = 6 BREAK.
		}
		IF nd:ETA < 240 {
			SET nd:ETA TO nd:ETA + OBT:PERIOD * nextOrb.
			SET prevDist TO 99999999999999999.
			SET flips TO 0.
			SET nextOrb TO nextOrb + 1.
		}
	}
	REMOVE nd.
	RETURN nd.
}
FUNCTION nodeApproach {
	RETURN 0.
}