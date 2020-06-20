CLEARSCREEN.
CORE:DOEVENT("Open Terminal").
PRINT "Loading, please wait..." AT (6,16).
COPYPATH("0:/boot/station","1:/boot/station").
COPYPATH("0:/station","1:/station").
IF EXISTS("0:/stationlabels/" + SHIP:NAME) {
	COPYPATH("0:/stationlabels/" + SHIP:NAME, "1:/printLabel").
} ELSE COPYPATH("0:/stationlabels/other/", "1:/printLabel").
WAIT 1.
RUN STATION.