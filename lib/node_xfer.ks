@LAZYGLOBAL OFF.
// #include "0:\\lib\node_basic.ks"
// #include "0:\\lib\node_rdvs.ks"

FUNCTION errDir {
	PARAMETER err.
	IF err < 0 {RETURN -1.}
	else {RETURN 1.}
}

FUNCTION nodeMoon {
	PARAMETER moon.
	// Creates and adds not to xfer from parking orbit to moon of current body
	// TODO: Use deterministic math; will probably be smaller, less error checking.
	LOCAL dAlt IS 0.
	if moon:ATM:EXISTS{SET dAlt TO moon:ATM:HEIGHT * 1.05.}
	else {SET dAlt TO 25000.}
	LOCAL xfer IS NODE(TIME:SECONDS+240,0,0,0).
	ADD xfer.
	
	FUNCTION makeAp {
		LOCAL n IS nodeTouchObt(xfer:ETA,moon).
		SET xfer:PROGRADE TO n:PROGRADE.
		SET xfer:NORMAL TO n:NORMAL.
		SET xfer:RADIALOUT TO n:RADIALOUT.
		IF xfer:ETA < 240 SET xfer:ETA TO xfer:ETA + OBT:PERIOD.
	}
	makeAp().
	LOCAL exit IS FALSE.
	until exit {
		SET xfer:ETA TO xfer:ETA + OBT:PERIOD / 180.
		if xfer:ETA > OBT:PERIOD*1.5 {PRINT "Unable to solve transfer.". REMOVE xfer. RETURN.}
		makeAp().
		IF ENCOUNTER <> "None"{IF ENCOUNTER:BODY = moon {SET exit TO TRUE.}}
	}
	LOCAL oldDir IS 1.
	LOCAL mul IS 50.
	SET exit TO FALSE.
	until exit {
		wait 0.
		LOCAL err IS ENCOUNTER:periapsis-dAlt.
		LOCAL ed IS errDir(err).
		if ENCOUNTER = "None" {
			LOCAL ENC IS FALSE.
			until ENC {
				SET xfer:ETA TO xfer:ETA + ed*mul*0.5.
				makeAp().
				wait 0.
				IF ENCOUNTER <> "None" {IF ENCOUNTER:BODY = moon {SET ENC TO TRUE.}}
			}
		} ELSE {
			IF abs(ENCOUNTER:periapsis-dAlt)<2000 AND ENCOUNTER:BODY = moon {
				SET exit TO TRUE.
			} ELSE {
				if ed <> oldDir {SET mul TO mul/2.}
				SET oldDir to ed.
				SET xfer:ETA TO xfer:ETA + ed*mul.
				makeAp().
			}
		}
	}
}