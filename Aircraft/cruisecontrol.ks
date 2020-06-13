declare parameter speed.
run lib_PID.

if speed = 0 {Set speed TO floor(AIRSPEED).}

on AG1 {SET exit TO TRUE. PRESERVE.}.
on AG5 {
	SET speed TO floor(AIRSPEED).
	PRESERVE.
}.
on AG6 {set mult TO mult/10. PRESERVE.}.
on AG7 {set mult TO mult*10. PRESERVE.}.
on AG8 {set speed TO speed-mult. PRESERVE.}.
on AG9 {set speed TO speed+mult. PRESERVE.}.

ClearScreen.
Print "   Speed:".
Print "  Target:".
Print "    Mult:".
Print "AG 8/9 TO change target speed.".
Print "AG 6/7 TO change setpoint multiplier.".
Print "AG 5 TO set target TO current speed.".
Print "AG 1 TO exit.".

LOCAL T IS SHIP:CONTROL:PILOTMAINTHROTTLE.
LOCAL tPID IS pid_new(0.06,0.01,0.005).
pid_limits(tPID,0,1,0,1).
LOCAL oldTime IS MISSIONTIME.
LOCAL exit IS FALSE.
LOCAL mult IS 1.
UNTIL (exit) {
	if mult<0.1 {set mult TO 0.1.}.
	if mult>100 {set mult TO 100.}.
	
	LOCAL dT IS MISSIONTIME - oldTime.
	LOCAL oldTime IS MISSIONTIME.
	
	IF DT > 0 {
        SET T TO round(pid(tPID,speed - AIRSPEED),2).
		//SET ship:control:MAINTHROTTLE TO T.
		SET SHIP:CONTROL:PILOTMAINTHROTTLE TO T.
		
		// Print info
		Print round(AIRSPEED,0) + " m/s      " at (10,0).
		Print speed + " m/s      " at (10,1).
		Print mult + "      " at (10,2).
	}.
	wait 0.01.
}.
clearscreen.