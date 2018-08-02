@LAZYGLOBAL OFF.
//DEPENDS{/lib/node_basic}

function timeToTruAnom {
    parameter orb,a2.
    local pi is constant():pi.
    local e is orb:eccentricity.
    local f is sqrt((1-e)/(1+e)).
    local e1 is 2*arctan(f*tan(orb:trueanomaly/2)).
    local e2 is 2*arctan(f*tan(a2/2)).
    local n is 2*pi/orb:PERIOD.
    local diff is ((pi/180*e2-e*sin(e2))/n)-((pi/180*e1-e*sin(e1))/n).
    if diff<0{set diff to orb:PERIOD+diff.}
    ELSE IF diff>orb:PERIOD{set diff to diff-orb:PERIOD.}
    RETURN diff.
}
FUNCTION nodeAlignPlane {
    PARAMETER other.
    LOCAL curT IS TIME:SECONDS.
    LOCAL normS is obtNrm(SHIP).
	LOCAL normO is other.
	IF other:TYPENAME <> "Vector" {SET normO TO obtNrm(other).}
    LOCAL inter is VCRS(normS,normO):NORMALIZED.
    LOCAL peLoc IS POSITIONAT(SHIP,TIME:SECONDS+ETA:PERIAPSIS)-BODY:POSITION.
    LOCAL cLoc IS SHIP:POSITION-BODY:POSITION.
    LOCAL peVel is vAt(SHIP,TIME:SECONDS+ETA:PERIAPSIS).
    LOCAL tA is VANG(inter,peLoc).
    if VDOT(inter,peVel)<0{set tA to -tA.}
    local curTA is VANG(cLoc,peLoc).
    if VDOT(cLoc,peVel)<0{set curTA to -curTA.}
    local diff is MOD(tA-curTA+360,360).
    if diff>180{set tA to tA-180.}
    local t is timeToTruAnom(obt,tA).
    local inc is VANG(normS,normO).
    if VDOT(normO,vAt(SHIP,time:seconds+t))>0{set inc to -inc.}
    return nodeInc(utOf(t),inc).
}

// This function takes two orbits CONTAINED IN THE SAME PLANE and returns
// a list of at most three elements:
// - first one is a "status" - if it's equal to -1, then obt1 is fully
// contained within obt2, vice versa for +1. Otherwise, it is equal to
// 0 and the list contains two more elements
// - two other elements, existing only if orbits cross at some points,
// represent the time remaining until ship orbiting obt1 will pass common
// orbit point. This should be the point at which you would do the burn
// to randez-vous
function orbitIntersects {
    parameter obt1,obt2.
    local e1 is obt1:ECCENTRICITY.
    local e2 is obt2:ECCENTRICITY.
    local B is obt1:SEMIMAJORAXIS/obt2:SEMIMAJORAXIS*(1-e1*e1)/(1-e2*e2).
    local delta is obt2:ARGUMENTOFPERIAPSIS-obt1:ARGUMENTOFPERIAPSIS.
    local gamma is arctan2(e1-B*e2*cos(delta), -B*e2*sin(delta)).
    local S is (1-B)*cos(gamma)/B/e2/sin(delta).
    if S > 1-0.00001{return list(1).}
    else if S < -1+0.00001{return list(-1).}
    local beta1 is arcsin(S)-gamma.
    local beta2 is 180-arcsin(S)-gamma.
    return list(
        0, 
        timeToTruAnom(obt1,beta1),
        timeToTruAnom(obt1,beta2)
    ).
}
function nodeMatchOrbits {
    parameter tgt.
    local l is orbitIntersects(obt,tgt:obt).
    if l[0]<>0{return 0.}
    local t is l[1].
    if l[2]<t{set t to l[2].}
    local actual_vel is vAt(ship,utOf(t)).
    local intersection_r is rAt(ship,utOf(t)).
    local tgt_r is body:position-tgt:position.
    local tgt_normal is VCRS(tgt:velocity:orbit,tgt_r).
    local side is VCRS(tgt_normal,tgt_r).
    local true_anomaly is VANG(intersection_r,tgt_r).
    if VDOT(side,intersection_r)<0{set true_anomaly to -true_anomaly.}
    set true_anomaly to true_anomaly+tgt:obt:trueanomaly.
    local t2 is timeToTruAnom(tgt:obt,true_anomaly).
    local expected_vel is vAt(tgt,utOf(t2)).
    return vecToNode(utOf(t),expected_vel-actual_vel).
}
FUNCTION nodeMatchVel {
    PARAMETER t,tgt.
    RETURN vecToNode(t,vAt(tgt,t)-vAt(SHIP,t)).
}
FUNCTION nodeTouchObt {//Determine altitude of target orbit at position opposite of node.
    PARAMETER t,tgt.
    LOCAL orb IS tgt:OBT.
    LOCAL nrm IS obtNrm(tgt).
	LOCAL LANVEC IS SOLARPRIMEVECTOR * ANGLEAXIS(orb:LAN, v(0,-1,0)).
	LOCAL periVec IS LANVEC * ANGLEAXIS(orb:ARGUMENTOFPERIAPSIS, -nrm).
    LOCAL apsisVec IS VXCL(nrm,(rAt(SHIP,utOf(t)))):NORMALIZED.
    LOCAL tA IS VANG(periVec,apsisVec).
    IF VANG(apsisVec,VCRS(nrm,periVec)) > 90 {SET tA TO 360-tA.}
    LOCAL e IS orb:ECCENTRICITY.
    LOCAL apsisHeight IS (orb:SEMIMAJORAXIS * ((1-e^2)/(1+e*COS(tA))))-BODY:RADIUS.
    RETURN nodeMoveApsis(t,apsisHeight).
}
FUNCTION nodeIntercept {
    PARAMETER tgt.
	LOCAL tSMA IS tgt:OBT:SEMIMAJORAXIS.
	LOCAL sSMA IS OBT:SEMIMAJORAXIS.
    LOCAL nd IS NODE(TIME:SECONDS+240,0,0,0).
    LOCAL dist IS 1000.
    LOCAL prevDist IS 99999999999999999.
    ADD nd.
    LOCAL FUNCTION update {
        LOCAL n IS nodeTouchObt(nd:ETA,tgt).
        SET nd:PROGRADE TO n:PROGRADE.
        SET nd:NORMAL TO n:NORMAL.
        SET nd:RADIALOUT TO n:RADIALOUT.
        LOCAL t IS utOf(nd:ETA + nd:ORBIT:PERIOD / 2).
        SET dist TO (POSITIONAT(tgt,t)-POSITIONAT(SHIP,t)):MAG.
    }
    //Increase node ETA until ap position is correct
    LOCAL mul IS 1.
    LOCAL flips IS 0.
    LOCAL nextOrb IS 1.
    UNTIL dist < 400 {
		SET prevDist TO dist.
		SET nd:ETA TO nd:ETA + MIN(OBT:PERIOD/36,dist/2000)*mul.
		update().
        IF prevDist < dist AND dist < tSMA {
            IF dist < tSMA/10 * MAX(tSMA/sSMA,sSMA/tSMA) {
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