@LAZYGLOBAL OFF.
// #include "0:/lib/orientation"
FUNCTION weight {RETURN MASS*BODY:MU/BODY:POSITION:MAG^2.}
FUNCTION stageCheck {
	LOCAL englist IS 0.
	LIST ENGINES IN englist.
	IF STAGE:READY AND STAGE:NUMBER > 0 {
		FOR eng IN englist {
			IF ENG:FLAMEOUT OR MAXTHRUST = 0 {STAGE. WAIT 0.5. BREAK.}
		}
	}
}
FUNCTION partEvent {
	PARAMETER p, mn, e.
	LOCAL ret IS FALSE.
	IF p:MODULES:CONTAINS(mn){
		LOCAL m IS p:GETMODULE(mn).
		IF m:HASEVENT(e){m:DOEVENT(e). SET ret TO TRUE.}
	}
	RETURN ret.
}
FUNCTION doWarp {
	PARAMETER t.
	IF TIME:SECONDS < t {WARPTO(t). WAIT UNTIL TIME:SECONDS > t.}
}
FUNCTION nDv {PARAMETER nd. RETURN nd:DELTAV:MAG.}
FUNCTION accel {RETURN AVAILABLETHRUST / MASS.}
FUNCTION burnTime {PARAMETER dv. RETURN dv / accel().}
FUNCTION nBurnStart {PARAMETER nd. RETURN nd:ETA - burnTime(nDv(nd)) / 2.}
FUNCTION doNode {
	PARAMETER nd IS NEXTNODE.
	UNTIL MAXTHRUST <> 0 {stageCheck().}
	LOCAL throt IS 0.
	LOCAL totdv IS nDv(nd).
	//Print display?
	doWarp(TIME:SECONDS + nBurnStart(nd) - 130).
	SAS OFF.
	LOCAL steer IS LOOKDIRUP(nd:DELTAV, SHIP:FACING:UPVECTOR).
	LOCK STEERING TO steer.
	LOCK THROTTLE TO throt.
	waitForRot(steer).
	doWarp(TIME:SECONDS + nBurnStart(nd) - 5).
	until nDv(nd) < max(0.1, totdv * 0.0005) {
		stageCheck().
		SET steer TO LOOKDIRUP(steer:VECTOR * 3 + nd:DELTAV:NORMALIZED, SHIP:FACING:UPVECTOR).
		LOCAL steerErr IS VANG(steer:VECTOR, facing:vector).
		IF nBurnStart(nd) <= 0 {SET throt TO max((burnTime(nDv(nd)) * 2) / max(1, accel() / 10), 0.02).}
		IF steerErr > 5 {SET throt TO 0.}
		WAIT 0.
	}
	SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
	UNLOCK THROTTLE.
	UNLOCK STEERING.
	REMOVE nd.
}