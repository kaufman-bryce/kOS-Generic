LOCAL dAlt IS floor(ALT:RADAR)-10.
LOCAL vsMax IS 150.
LOCAL tPID IS PIDLOOP(0.4,0.1,0.005,0,1).
LOCAL mult IS 10.
LOCAL radar IS TRUE.
LOCAL exit IS FALSE.
LOCAL oldTime IS TIME:SECONDS.

ON AG1 { SET exit TO TRUE. }
ON AG4 {
	IF radar = FALSE {
		SET dAlt TO FLOOR(dAlt-(ALTITUDE-ALT:RADAR)).
		SET radar TO TRUE.
	} ELSE if radar = TRUE {
		SET dAlt TO FLOOR(dAlt+(ALTITUDE-ALT:RADAR)).
		SET radar TO FALSE.
	}
	PRESERVE.
}
ON AG5 {
	if radar = true {SET dAlt TO floor(ALT:RADAR).} else {SET dAlt TO floor(Altitude).}
	PRESERVE.
}
ON AG6 {SET mult TO mult/10. PRESERVE.}
ON AG7 {SET mult TO mult*10. PRESERVE.}
ON AG8 {SET dAlt TO dAlt-mult. PRESERVE.}
ON AG9 {SET dAlt TO dAlt+mult. PRESERVE.}

CLEARSCREEN.
PRINT "Hover Controller".
PRINT "Altitude:".
PRINT "  Target:".
PRINT "    Mult:".
PRINT "   Radar:".
PRINT "AG 8/9 to change target altitude.".
PRINT "AG 6/7 to change setpoint multiplier.".
PRINT "AG 5 to set target to current altitude.".
PRINT "AG 4 to switch between ASL and radar altitude.".
PRINT "AG 1 to exit.".

UNTIL (exit) {
	IF mult<1 {SET mult TO 1.}
	IF mult>1000 {SET mult TO 1000.}
	
	SET dT TO time:seconds - oldTime.
	SET oldTime TO time:seconds.
	
	IF dT > 0 {
		if radar {SET vAlt TO ALT:RADAR.} else {SET vAlt TO ALTITUDE.}
		LOCAL dVS IS (dAlt - vAlt)/10.
		SET dVS TO max(-vsMax,min(vsMax,dVS)).
		SET tPID:setpoint TO dVS.
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO tPID:UPDATE(TIME:SECONDS, VERTICALSPEED).
		// PRINT round(VERTICALSPEED,1)                 + " m      " AT (10,1).
		// PRINT dVS                          + " m      " AT (10,2).
		PRINT round(vAlt,1)                 + " m      " AT (10,1).
		PRINT dAlt                          + " m      " AT (10,2).
		PRINT mult                          + "      "   AT (10,3).
		PRINT radar                         + " "        AT (10,4).
		PRINT round(dVS-VERTICALSPEED,2)    + "      "   AT (10,20).
		PRINT round(tPID:pterm,2)           + "      "   AT (10,21).
		PRINT round(tPID:dterm,2)           + "      "   AT (10,22).
		PRINT round(tPID:errorsum,2)        + "      "   AT (10,23).
	}
	wait 0.
}
CLEARSCREEN.