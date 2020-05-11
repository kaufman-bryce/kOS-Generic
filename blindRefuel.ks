// Indescrimantely suck all non-electric resources into CPU element.
CLEARSCREEN.
LOCAL xfers IS LIST().
LIST ELEMENTS IN eList.
FOR el IN eList {
	IF el:UID <> CORE:ELEMENT:UID {
		FOR res IN el:RESOURCES {
			IF res:NAME <> "ElectricCharge" {
				xfers:ADD(TRANSFERALL(res:NAME,el,CORE:ELEMENT)).
				// xfers:ADD(TRANSFERALL(res:NAME,CORE:ELEMENT,el)).
			}
		}
	}
}
LOCAL xCount IS 0.
PRINT "Starting " + xfers:LENGTH + " transfers...".
UNTIL xfers:LENGTH = 0 {
	LOCAL iter IS xfers:ITERATOR.
	UNTIL NOT iter:NEXT {
		LOCAL x IS iter:VALUE.
		IF NOT x:ACTIVE SET x:ACTIVE TO TRUE.
		IF x:STATUS = "Finished" OR x:STATUS = "Failed" {
			SET x:ACTIVE TO FALSE.
			xfers:REMOVE(iter:INDEX).
			SET xCount TO xCount + 1.
			PRINT xCount + " transfers completed." AT (0,1).
			SET iter TO xfers:ITERATOR.
		}
	}
}
PRINT "All transferes complete.".