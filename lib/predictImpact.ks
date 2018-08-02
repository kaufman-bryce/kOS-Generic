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