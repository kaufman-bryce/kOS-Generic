CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
IF NOT SHIP:PARTSTAGGED("control"):EMPTY {
    LOCAL p IS SHIP:PARTSTAGGED("control")[0].
    IF p:MODULES:CONTAINS("ModuleCommand"){p:GETMODULE("ModuleCommand"):DOEVENT("Control from here").}
    IF p:MODULES:CONTAINS("ModuleDockingNode"){p:GETMODULE("ModuleDockingNode"):DOEVENT("Control from here").}
}
DELETEPATH(SCRIPTPATH()).
SET CORE:BOOTFILENAME TO "".
RUN "0:/copy/rdvs".
COPYPATH("0:/autolandAt","1:/autolandAt").
COPYPATH("0:/lib/predictImpact.ksm","1:/lib/predictImpact.ksm").
LOCAL qt IS char(34).
LOCAL pth IS "COPYPATH("+qt+"0:/autolandAt"+qt+","+qt+"1:/autolandAt"+qt+").".
LOG pth TO "1:/test.ks".
//LOG "RUN autolandAt(latlng(9,172))." TO "1:/test.ks".
LOG "RUN autolandAt(latlng(2.46373581886292,81.5251212255859))." TO "1:/test.ks".

CLEARSCREEN.
PRINT "Flight Computer initialized.".
PRINT " ".
PRINT "Proceed.".