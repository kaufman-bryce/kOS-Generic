@LAZYGLOBAL OFF.
FUNCTION LAZcalc {
	DECLARE PARAMETER Ap.
	DECLARE PARAMETER Inc.
	LOCAL curLat IS SHIP:LATITUDE.
	IF ABS(Inc) < ABS(curLat) {SET Inc TO ABS(curLat).}
	ELSE IF ABS(Inc) > (180 - ABS(curLat)) {SET Inc TO (180 - ABS(curLat)).}
	LOCAL tOrbV IS SQRT(BODY:MU / (Ap + BODY:RADIUS)).
	LOCAL inAzi IS ARCSIN(COS(ABS(Inc)) / COS(curLat)).
	LOCAL azi IS ARCTAN(((tOrbV * SIN(inAzi)) - (((2 * CONSTANT():PI * BODY:RADIUS) / BODY:ROTATIONPERIOD) * COS(curLat))) / (tOrbV * COS(inAzi))).
	IF Inc < 0 {SET azi TO 180 - azi.}
	IF azi < 0 {SET azi TO 360 + azi.}
	RETURN azi.
}