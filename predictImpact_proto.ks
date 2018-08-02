FUNCTION predictImpact {
	PARAMETER impactALT IS 0.
	LOCAL cutoff IS 25000.
	IF impactALT <> 0 {SET cutoff TO impactALT.}
	LOCAL willImpact IS FALSE.
	LOCAL impactGEO IS LATLNG(0,0).
	LOCAL impactTIME IS 0.
	IF PERIAPSIS < cutoff {
		LOCAL end IS ETA:PERIAPSIS.
		IF ALTITUDE > cutoff {
			UNTIL end - impactTIME < 1 { //Find possible collision sphere
				LOCAL mid IS (impactTIME + end) / 2.
				IF (POSITIONAT(SHIP,TIME:SECONDS + mid) - BODY:POSITION):MAG < cutoff + BODY:RADIUS {
					SET end TO mid.
				}
				ELSE {SET impactTIME TO mid.}
			}
		}
		IF impactALT <> 0 {
			LOCAL impactPos IS POSITIONAT(SHIP,TIME:SECONDS+impactTIME).
			SET ang TO MOD((BODY:GEOPOSITIONOF(impactPos):LNG - (360 * (impactTIME / BODY:ROTATIONPERIOD))) + 180,360) - 180.
			SET impactGEO TO LATLNG(BODY:GEOPOSITIONOF(impactPos):LAT,ang).
			RETURN LIST(TRUE,impactGEO,impactTIME,VELOCITYAT(SHIP,TIME:SECONDS+impactTIME):SURFACE).
		}
		LOCAL scan IS (ETA:PERIAPSIS - impactTIME) / 10.
		UNTIL impactTIME > ETA:PERIAPSIS OR scan < 0.05 {
			SET impactTIME TO impactTIME + scan.
			LOCAL impactPos IS POSITIONAT(SHIP,TIME:SECONDS+impactTIME).
			SET ang TO MOD((BODY:GEOPOSITIONOF(impactPos):LNG - (360 * (impactTIME / BODY:ROTATIONPERIOD))) + 180,360) - 180.
			SET impactGEO TO LATLNG(BODY:GEOPOSITIONOF(impactPos):LAT,ang).
			LOCAL altOff IS (impactPos - BODY:POSITION):MAG - impactGEO:TERRAINHEIGHT - BODY:RADIUS.
			IF  altOff < 0 {
				SET willImpact TO TRUE.
				IF altOff > -1 {BREAK.}
				SET impactTIME TO impactTIME - scan.
				SET scan TO scan / 2.
			}
		}
	}
	RETURN LIST(willImpact,impactGEO,impactTIME,VELOCITYAT(SHIP,TIME:SECONDS+impactTIME):SURFACE).
}
CLEARSCREEN.
PRINT "simT:".
PRINT " Lat:".
PRINT "Long:".
PRINT " Alt:".
PRINT "Time:".
PRINT " Vel:".
PRINT "Imp?:".
SET CrashVec TO VECDRAWARGS(V(0,0,0),V(0,0,0),CYAN,"I", 1, TRUE).
UNTIL TERMINAL:INPUT:HASCHAR AND TERMINAL:INPUT:GETCHAR() = TERMINAL:INPUT:ENTER {
	LOCAL oldTime IS TIME:SECONDS.
	LOCAL impact IS predictImpact(20000).
	PRINT round(TIME:SECONDS - oldTime,3) + " Seconds     " AT (6,0).
	PRINT round(impact[1]:LAT,5)+ "           " AT (6,1).
	PRINT round(impact[1]:LNG,5)+ "           " AT (6,2).
	PRINT round(impact[1]:TERRAINHEIGHT,1)+ "     " AT (6,3).
	PRINT round(impact[2],2)+ "           " AT (6,4).
	PRINT round(impact[3]:MAG,2)+ "           " AT (6,5).
	PRINT impact[0]+ "           " AT (6,6).

	if impact[0]= TRUE {
		SET CrashVec:START TO impact[1]:ALTITUDEPOSITION(impact[1]:TERRAINHEIGHT+1000).
		SET CrashVec:VEC TO impact[1]:ALTITUDEPOSITION(impact[1]:TERRAINHEIGHT-1000) - impact[1]:ALTITUDEPOSITION(impact[1]:TERRAINHEIGHT).
	}
	ELSE {
		SET CrashVec:START TO V(0,0,0).
		SET CrashVec:VEC TO V(0,0,0).
	}
}
CLEARVECDRAWS().