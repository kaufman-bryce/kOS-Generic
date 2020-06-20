CORE:DOEVENT("Open Terminal").
IF NOT SHIP:PARTSTAGGED("control"):EMPTY {
	LOCAL p IS SHIP:PARTSTAGGED("control")[0].
	IF p:MODULES:CONTAINS("ModuleCommand"){p:GETMODULE("ModuleCommand"):DOEVENT("Control from here").}
	ELSE IF p:MODULES:CONTAINS("ModuleDockingNode"){p:GETMODULE("ModuleDockingNode"):DOEVENT("Control from here").}
}
DELETEPATH(SCRIPTPATH()).
SET CORE:BOOTFILENAME TO "".

RUN "0:/copy/rdvs".
COPYPATH("0:/autodock","1:/autodock").

CLEARSCREEN.
PRINT "Flight Computer initialized.".
PRINT " ".
PRINT "Proceed.".