declare parameter speed is 0.
if speed = 0 {set speed TO floor(AIRSPEED).}

// LOCAL tPID IS pid_new(0.06,0.01,0.005).
LOCAL tPID IS PIDLOOP(0.4, 0.01, 0.2, 0, 1).
LOCAL exit IS FALSE.
LOCAL mult IS 1.

on AG1 {set exit TO TRUE. PRESERVE.}.
on AG5 {
	set speed TO floor(AIRSPEED).
	PRESERVE.
}.
on AG6 {set mult TO mult / 10. PRESERVE.}.
on AG7 {set mult TO mult * 10. PRESERVE.}.
on AG8 {set speed TO speed - mult. PRESERVE.}.
on AG9 {set speed TO speed + mult. PRESERVE.}.

CLEARSCREEN.
PRINT "   Speed:".
PRINT "  Target:".
PRINT "    Mult:".
PRINT "AG 8/9 TO change target speed.".
PRINT "AG 6/7 TO change setpoint multiplier.".
PRINT "AG 5 TO set target TO current speed.".
PRINT "AG 1 TO exit.".

LOCAL oldTime IS TIME:seconds.
UNTIL (exit) {
	if mult < 0.1 {set mult TO 0.1.}.
	if mult > 100 {set mult TO 100.}.
	
	LOCAL dT IS TIME:seconds - oldTime.
	set oldTime TO TIME:seconds.
	
	IF DT > 0 {
		set tPID:setpoint to speed.
		LOCAL T IS round(tPID:update(TIME:seconds, AIRSPEED), 2).
		//set ship:control:MAINTHROTTLE TO T.
		set SHIP:CONTROL:PILOTMAINTHROTTLE TO T.
		
		// PRINT info
		PRINT round(AIRSPEED, 0) + " m/s      " at (10, 0).
		PRINT speed              + " m/s      " at (10, 1).
		PRINT mult               + "      "     at (10, 2).
	}.
	wait 0.01.
}.
clearscreen.