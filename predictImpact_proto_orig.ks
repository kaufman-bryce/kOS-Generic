// Current periapsis must be below sea level for this to work.
CLEARSCREEN.
PRINT "simT:".
PRINT " Lat:".
PRINT "Long:".
PRINT " Alt:".
PRINT "Time:".


FUNCTION predictImpact {
	PARAMETER impactALT IS 0.
	LOCAL impactGEO IS LATLNG(0,0).
	LOCAL impactTIME IS 0.
	LOCAL PeR IS BODY:RADIUS+PERIAPSIS.
	LOCAL PeT IS ETA:PERIAPSIS.
	LOCAL a IS OBT:SEMIMAJORAXIS.
	LOCAL Ecc IS OBT:ECCENTRICITY.
	LOCAL deg2Rad IS CONSTANT():PI / 180.
	//LOCAL rad2Deg IS 180 / CONSTANT():PI.
	LOCAL iter IS 5.
	IF impactALT <> 0 SET iter TO 1.
	FROM {LOCAL i IS 1.} UNTIL i = iter STEP {SET i TO i+1.} DO {
		if PERIAPSIS >= impactAlt OR
		(Ecc < 1 AND APOAPSIS <=impactAlt) OR
		(Ecc >= 1 AND PeT <= 0){
			RETURN FALSE.
		}
		IF Ecc > 0{
			//Refine prediction with result of last prediction.
			SET impactTheta TO -ARCCOS((PeR * (1 + Ecc) / (BODY:RADIUS + impactALT) - 1) / Ecc).
		}
		//This determines the time-offset from periapsis of the impact. Handles parabolic, elliptical, and hyperbolic orbits for all your launch-direct-to-landing needs.
		if (Ecc = 1.0) {
			SET D TO TAN(impactTheta / 2).
			SET M TO D + D * D * D / 3.0.
			SET timeOffset TO SQRT(2.0 * (PeR)^3 / BODY:MU) * M.
		} else if (a > 0) {
			SET cosTheta TO COS(impactTheta).
			SET cosE TO (Ecc + cosTheta) / (1.0 + Ecc * cosTheta).
			SET radE TO ARCCOS(cosE).
			SET M TO (radE * deg2Rad) - Ecc * SIN(radE).
			SET timeOffset TO (SQRT(A^3 / BODY:MU) * M).
		} else if (a < 0) {
			SET cosTheta TO COS(impactTheta).
			SET coshF TO ((Ecc + cosTheta) / (1.0 + Ecc * cosTheta)).
			SET radF TO LN(coshF + SQRT(coshF^2 - 1.0)). //AcosH of cosTheta
			SET M TO Ecc * (((CONSTANT():E^radF) - (CONSTANT():E^(-radF)))/2) - radF. //sinH(radF) - radF
			SET timeOffset TO (SQRT(-1 * A^3 / BODY:MU) * M).
		}
		SET impactTIME TO PeT - timeOffset. 
		
		SET impactPos TO BODY:GEOPOSITIONOF(POSITIONAT(ship,time:seconds+impactTIME)).
		LOCAL impactVEL IS VELOCITYAT(ship,time:seconds+impactTIME).
		//get body rotation until impact
		SET bodyrot TO 360 * (impactTIME / BODY:ROTATIONPERIOD).
		//calculate the impact longitude
		SET ang TO impactPos:LNG - bodyrot.
		SET ang TO MOD(ang + 180,360) - 180.
		//if (ang > 180) {
		//	SET ang TO ang -(360 * CEILING((ang - 180) / 360)).
		//} else if (ang <= -180) {
		//	SET ang TO ANG -(360 * FLOOR((ang + 180) / 360)).
		//}
		SET impactGEO TO LATLNG(impactPos:LAT,ang).
		SET impactALT TO impactGEO:TERRAINHEIGHT.
	}
	RETURN impactGEO.
}
LOCAL impactGEO IS predictImpact().
SET CrashVec TO VECDRAWARGS(V(0,0,0),V(0,0,0),CYAN,"I", 1, TRUE).
UNTIL TERMINAL:INPUT:HASCHAR AND TERMINAL:INPUT:GETCHAR() = TERMINAL:INPUT:ENTER {
	LOCAL oldTime IS TIME:SECONDS.
	LOCAL impactGEO IS predictImpact().
	if impactGEO:TYPENAME = "GeoCoordinates" {
		SET CrashVec:START TO impactGEO:ALTITUDEPOSITION(impactGEO:TERRAINHEIGHT+100).
		SET CrashVec:VEC TO impactGEO:ALTITUDEPOSITION(impactGEO:TERRAINHEIGHT-100) - impactGEO:ALTITUDEPOSITION(impactGEO:TERRAINHEIGHT).
		PRINT round(TIME:SECONDS - oldTime,3) + " Seconds     " AT (6,0).
		PRINT round(impactGEO:LAT,5)+ "   " AT (6,1).
		PRINT round(impactGEO:LNG,5)+ "   " AT (6,2).
		PRINT round(impactGEO:TERRAINHEIGHT,1)+ "   " AT (6,3).
		PRINT round(impactTIME,2)+ "   " AT (6,4).
	}
}
CLEARVECDRAWS().