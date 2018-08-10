@LAZYGLOBAL OFF.
FUNCTION vAt{
    PARAMETER ves,t.
    RETURN VELOCITYAT(ves,t):ORBIT.
}
FUNCTION rAt{
    PARAMETER ves,t.
    RETURN ves:BODY:POSITION - POSITIONAT(ves,t).
}
FUNCTION obtNrm{
    PARAMETER ves.
    RETURN VCRS(ves:OBT:VELOCITY:ORBIT,rAt(ves,TIME:SECONDS)):NORMALIZED.
}

FUNCTION utAp {RETURN TIME:SECONDS+ETA:APOAPSIS.}
FUNCTION utPe {RETURN TIME:SECONDS+ETA:PERIAPSIS.}
FUNCTION utOf {PARAMETER t. RETURN TIME:SECONDS + t.}

function vecToNode{
    PARAMETER t,dv.
    LOCAL pro_unit IS vAt(SHIP,t):NORMALIZED.
    LOCAL rad_unit IS -VXCL(pro_unit,rAt(ship,t)):NORMALIZED.
    LOCAL nor_unit IS VCRS(pro_unit,rad_unit).
    RETURN NODE(t,rad_unit * dv,nor_unit * dv,pro_unit * dv).
}

function nodeCirc{
    PARAMETER t.
    LOCAL r IS rAt(SHIP,t).
    LOCAL actual_vel IS vAt(SHIP,t).
    LOCAL expected_vel IS VXCL(r,actual_vel):NORMALIZED * SQRT(body:mu/r:mag).
    RETURN vecToNode(t,expected_vel - actual_vel).
}

FUNCTION nodeMoveApsis{ //T becomes apsis, height adjusts opposing apsis
    PARAMETER t,height.
    LOCAL r IS rAt(SHIP,t).
    LOCAL actual_vel IS vAt(SHIP,t).
    LOCAL expected_vel IS VXCL(r,actual_vel):NORMALIZED * 
	SQRT(body:mu * (2 / r:MAG - 1 / ((r:MAG+height+BODY:RADIUS) / 2))).
    RETURN vecToNode(t,expected_vel - actual_vel).
}

//function nodeInc{ //relative change; i.e orbit rotated by ang at t
//    PARAMETER t,ang.
//    LOCAL r IS rAt(SHIP,t).
//    LOCAL actual_vel IS vAt(SHIP,T).
//    LOCAL normal_vel IS VCRS(actual_vel,r):NORMALIZED*actual_vel:mag.
//    return vecToNode(t,actual_vel*(cos(ang)-1)+normal_vel*sin(ang)).
//}

function nodeInc{ //relative change; i.e orbit rotated by ang at t
    PARAMETER t,ang.
	LOCAL actual_vel IS vAt(SHIP,t).
	LOCAL expected_vel IS actual_vel * ANGLEAXIS(ang,-rAt(SHIP,t)).
    RETURN vecToNode(t,expected_vel - actual_vel).
}
