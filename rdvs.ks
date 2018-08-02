//DEPENDS:{/lib/rocket,/lib/node_basic,/lib/node_rdvs,/lib/orientation}
PARAMETER mode is 0.
SET tgt TO TARGET.
IF BODY <> tgt:OBT:BODY {PRINT "Target must orbit same body as current vessel.".}
ELSE {
RUNONCEPATH("/lib/orientation").
RUNONCEPATH("/lib/rocket").
RUNONCEPATH("/lib/node_basic").
RUNONCEPATH("/lib/node_rdvs").
//RUN lib_node_xfer.

IF mode > 0 {//1, plane alignment
   CLEARSCREEN.
   ADD nodeAlignPlane(tgt).
   IF NEXTNODE:DELTAV:MAG > 5 {
       PRINT "Performing plane alignment...".
       doNode(NEXTNODE).
       } ELSE REMOVE NEXTNODE.
}
IF mode > 1 {//2, plot intercept transfer + match vel
   PRINT "Performing intercept burn...".
   ADD nodeIntercept(tgt).
   doNode(NEXTNODE).
   PRINT "Matching vel at ap...".
   ADD nodeMatchVel(utAP(),tgt).
   doNode(NEXTNODE).
}
IF mode > 2 {//3, final approach
    SET dist TO (tgt:POSITION - SHIP:POSITION):MAG.
    IF dist > 500 {
        PRINT "Final approach...".
        LOCAL t IS utOf(150).
        ADD vecToNode(t,((POSITIONAT(tgt,t)-POSITIONAT(SHIP,t)):NORMALIZED * (dist/100)) - vAT(SHIP,t)).
        doNode(NEXTNODE).
        ADD nodeMatchVel(utOf((dist*0.9)/(tgt:VELOCITY:ORBIT-SHIP:VELOCITY:ORBIT):MAG),tgt).
        doNode(NEXTNODE).
    }
    PRINT "Rendezvous complete.".
}
IF mode > 3 {//4
    IF mode = 5 {SET SHIP:NAME TO tgt:NAME.}
    IF NOT tgt:PARTSTAGGED("dockhere"):EMPTY {
        SET targ TO tgt:PARTSTAGGED("dockhere")[0].
        RUN autodock(targ).
    }
}
}