DELETEPATH(SCRIPTPATH()).
SHIP:MODULESNAMED("kOSProcessor")[0]:DOEVENT("Open Terminal").
CLEARSCREEN.
PRINT "Clearing carrier craft...".
WAIT 10.
PANELS ON.
FOR m IN SHIP:MODULESNAMED("ModuleDeployableAntenna") {
    IF m:HASEVENT("Extend Antenna") {m:DOEVENT("Extend Antenna").}
}
PRINT "Deploying...".
WAIT 3.
RUN comSat("nbCom",4,2500000).