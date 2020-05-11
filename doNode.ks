RUNONCEPATH("/lib/orientation").
RUNONCEPATH("/lib/rocket").
RUNONCEPATH("/lib/node_basic").

LOCAL done IS FALSE.
LOCAL sp IS "      ".
LOCAL nd IS NEXTNODE.

CLEARSCREEN.
PRINT "Executing node for " + round(nDv(nd),1) + "dV.".
PRINT " Time to Node:".
PRINT " Time to Burn:".
PRINT "   Burn time :".
PRINT "   Burn DV   :".
PRINT "   Steer err :".

WHEN TRUE THEN {
	IF HASNODE AND nd = NEXTNODE{
		PRINT ROUND(nd:ETA,1) + sp at (15,1).
		PRINT ROUND(nBurnStart(nd),1) + sp at (15,2).
		PRINT ROUND(burnTime(nDv(nd)),1) + sp at (15,3).
		PRINT ROUND(nDv(nd),2) + sp at (15,4).
		PRINT ROUND(VANG(nd:DELTAV,facing:vector),1) + sp at (15,5).
	}
	IF done = FALSE {PRESERVE.}
}
doNode().
SET done TO TRUE.
PRINT "Burn complete, stabilizing rotation...".
SAS ON.