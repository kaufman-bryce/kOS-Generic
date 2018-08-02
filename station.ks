//Station logic:
//Detect when in shadow, and toggle visibility lights? Use info from solars COMPLETE
//Resource management? PARTIAL
//-Automated loading/unloading via part tags? Emulate GS pumps? PARTIAL
//-Automatic IR solar panels COMPLETE
//-Automated on/off of recyclers? Uneeded?
//Find a way to count crew through LS usage? Not possible with converters.
//
//SHUTDOWN.
LOCAL res IS LIST().
LOCAL resNames IS LIST().
LOCAL sol IS SHIP:PARTSTAGGED("testSolar")[0]:GETMODULE("ModuleDeployableSolarPanel").
LOCAL panelAim IS FALSE.
LOCAL servoPart IS 0.
LOCAL servo IS 0.
IF NOT SHIP:PARTSTAGGED("SolarAligner"):EMPTY AND ADDONS:IR:AVAILABLE {
    SET servoPart TO SHIP:PARTSTAGGED("SolarAligner")[0].
    SET panelAim TO TRUE.
    FOR s IN ADDONS:IR:ALLSERVOS {IF s:NAME = "SolarAligner" SET servo TO s.}
}
LOCAL elem IS 0.
LOCAL prevElem IS 0.
LOCAL docked IS LIST().
LOCAL station IS LIST().
//Xfers: LIST(FROM,TO,RESOURCE,XFERHANDLE,oldPercent)
LOCAL xfers IS LIST().
LOCAL partCount IS 0.
LOCAL runtime IS 1.
LOCAL oldTime IS TIME:SECONDS.
LOCAL lifeSupport IS "None".

FUNCTION setLights {
    PARAMETER st.
    LOCAL pt IS 0.
    LOCAL m IS 0.
    LOCAL mods IS LIST("ModuleAnimateGeneric","ModuleLight").
    LOCAL ev IS LIST("lights off","lights on").
    FOR pt IN SHIP:PARTSTAGGED("lightSelf") {
        FOR m IN mods {
            IF pt:MODULES:CONTAINS(m) {
                LOCAL md IS pt:GETMODULE(m).
                IF md:HASEVENT(ev[st]){md:DOEVENT(ev[st]).}
            }
        }
    }
}
FUNCTION numFormat{
    PARAMETER n,d.
    LOCAL pre IS "".
    IF n >= 0 AND d > 0 {SET pre TO pre + " ".}
    SET d TO ABS(d)-1.
    LOCAL i IS 10^d.
    UNTIL i = 1{
        IF abs(n) < i {SET pre TO pre + " ".}
        SET i TO i/10.
    }
    RETURN pre+n.
}
FUNCTION dateFormat {
    PARAMETER t.
    LOCAL hours IS t/60/60.
    LOCAL days IS hours/6.
    IF hours <> 0 AND days <> 0 {
        RETURN numFormat(FLOOR(min(days,9999)),4)+"d"+floor(MOD(hours,6))+"h".
    } ELSE RETURN "    -d-h".
}
FUNCTION timeFormat {
    PARAMETER t.
    LOCAL minutes IS t/60.
    LOCAL hours IS minutes/60.
    IF hours <> 0 AND minutes <> 0 {
        RETURN numFormat(FLOOR(min(hours,999)),3)+"h"+numFormat(floor(MOD(minutes,60)),-2)+"m".
    } ELSE RETURN "   -h -m".
}
FUNCTION clearPrint {
    PARAMETER s,l,x,y.
    LOCAL i IS 1.
    LOCAL cl IS " ".
    UNTIL i = l {SET cl TO cl + " ". SET i TO i + 1.}
    PRINT cl AT (x,y).
    PRINT s AT (x,y).
}
FUNCTION inRange {
    PARAMETER n,l,h.
    IF max(l,min(h,n)) = n {RETURN TRUE.}
    ELSE {RETURN FALSE.}
}
FUNCTION perBar {
    PARAMETER percent,w.
    LOCAL s IS "".
    LOCAL i IS 0.
    LOCAL step IS 1/w.
    LOCAL hs IS step/4.
    UNTIL i >= 1-hs{
        SET i TO i + step.
        IF percent >= i - hs {SET s TO s + "=".}
        ELSE IF inRange(i,0.25-hs,0.25+hs) OR inRange(i,0.75-hs,0.75+hs) {
            SET s TO s + ".".
        }
        ELSE IF inRange(i,0.5-hs,0.5+hs) {SET s TO s + ":".}
        ELSE {SET s TO s + " ".}
    }
    RETURN s.
}
//Resource format:
//Two lists; res and resNames
//resNames is lookup table for res
//res contains resource info:
//   0       1       2      3         4              5               6           7
//Amount,Capacity,percent,rate,timeRemaining,LIST(containerParts),prevAmount,prevTime
//i.e. to get current amount of monoprop:
//Find ID of "monopropellant" in resnames
//res[id][0]
//
FUNCTION res_exists {PARAMETER s. IF resNames:CONTAINS(s) RETURN TRUE. ELSE RETURN FALSE.}
FUNCTION res_id {
    PARAMETER s.
    IF res_exists(s) {
        LOCAL i IS 0.
        UNTIL resNames[i] = s {SET i TO i+1.}
        RETURN i.
    } ELSE RETURN FALSE.
}
FUNCTION res_amount     {PARAMETER s. RETURN res[res_id(s)][0].}
FUNCTION res_capacity   {PARAMETER s. RETURN res[res_id(s)][1].}
FUNCTION res_percent    {PARAMETER s. RETURN res[res_id(s)][2].}
FUNCTION res_rate       {PARAMETER s. RETURN res[res_id(s)][3].}
FUNCTION res_eta        {PARAMETER s. RETURN res[res_id(s)][4].}
FUNCTION res_parts      {PARAMETER s. RETURN res[res_id(s)][5].}

FUNCTION update {
    LIST ELEMENTS IN elem.
    IF elem:LENGTH <> prevElem {
        SET station TO LIST().
        SET docked TO LIST().
        FOR e IN elem {
            IF e:NAME = SHIP:NAME station:ADD(e).
            ELSE docked:ADD(e).
        }
        LOCAL i IS 0.
        UNTIL i =9 {
            PRINT "                                -           " AT (5,25+i).
            SET i TO i+1.
        }
    }
    SET prevElem TO elem:LENGTH.
    FOR re IN res {
        SET re[2] TO re[0]/re[1].                       //Percentage
        SET re[3] TO (re[0]-re[6])/(TIME:SECONDS-re[7]).//Flow rate
        IF re[3] > 0 {                                  //ETA
            SET re[4] TO (re[1]-re[0])/ABS(re[3]).
        } ELSE IF re[3] < 0 {
            SET re[4] TO re[0]/ABS(re[3]).
        } ELSE SET re[4] TO 0.
        SET re[6] TO re[0].                             //Set prevAmount/time
        SET re[7] TO TIME:SECONDS.
        SET re[0] TO 0.                                 //Clear amount/cap/parts
        SET re[1] TO 0.
        SET re[5] TO LIST().
    }
    SET partCount TO 0.
    FOR e IN station {
        SET partCount TO partCount + e:PARTS:LENGTH.
        FOR re IN e:RESOURCES {
            LOCAL n IS re:NAME.
            IF res_exists(n) {
                LOCAL id IS res_id(n).
                SET res[id][0] TO res[id][0] + re:AMOUNT.
                SET res[id][1] TO res[id][1] + re:CAPACITY.
                FOR p IN re:PARTS {res[id][5]:ADD(p).}
            } ELSE {
                res:ADD(LIST(re:AMOUNT,re:CAPACITY,0,0,0,re:PARTS,re:AMOUNT,TIME:SECONDS-1)).
                resNames:ADD(n).
            }
        }
    }
    IF res_exists("Food") {
        IF lifeSupport <> "TACLS" {
            SET lifeSupport TO "TACLS".
            PRINT "   Food:|          |        " AT (2,12).
            PRINT "  Water:|          |        " AT (2,13).
            PRINT " Oxygen:|          |        " AT (2,14).
            PRINT "    CO2:|          |        " AT (2,15).
            PRINT "  Waste:|          |        " AT (2,16).
            PRINT " WWater:|          |        " AT (2,17).
        }
    }ELSE IF res_exists("Supplies"){
        IF lifeSupport <> "USI" {
            SET lifeSupport TO "USI".
            PRINT "Suplies:|          |        " AT (2,12).
            PRINT "  Mulch:|          |        " AT (2,13).
            PRINT " Frtlzr:|          |        " AT (2,14).
            PRINT "                            " AT (2,15).
            PRINT "                            " AT (2,16).
            PRINT "                            " AT (2,17).
        }
    }ELSE IF lifeSupport <> "None"{
        SET lifeSupport TO "None".
        PRINT "                            " AT (2,12).
        PRINT "                            " AT (2,13).
        PRINT "-[No Life support detected]-" AT (2,14).
        PRINT "                            " AT (2,15).
        PRINT "                            " AT (2,16).
        PRINT "                            " AT (2,17).
    }
}
FUNCTION drawScreen {
    CLEARSCREEN.
    RUN printLabel.
    //<TERMPREVIEW>
    //               1         2         3         4
    //     01234567890123456789012345678901234567890123456789
    //INT "                                                  ".// 0
    //INT "     ─│┌┐└┘├┤┬┴┼╭╮╯╰╱╳                            ".// 1
    //INT "                                                  ".// 2
    //INT "                                                  ".// 3
    //INT "                 STATION LOGO                     ".// 4
    //INT "                                                  ".// 5
    //INT "                                                  ".// 6
    //INT "                                                  ".// 7
    //INT "                                                  ".// 8
    //INT "                                                  ".// 9
    PRINT " ╭───────────────────────────────────────────────╮ ".//10
    PRINT " │       Life Support   time  │    Statistics    │".//11
    PRINT " │                            │   Parts:         │".//12
    PRINT " │                            │ Modules:         │".//13
    PRINT " │-[No Life support detected]-│ Runtime:         │".//14
    PRINT " │                            │                  │".//15
    PRINT " │                            ├──────────────────┤".//16
    PRINT " │                            │   Fuel Reserves  │".//17
    PRINT " ├────────────────────────────┤ MP:|          |  │".//18
    PRINT " │    Solar Panels & Power    | LF:|          |  │".//19
    PRINT " │ EC:|              |        | OX:|          |  │".//20
    PRINT " │ Exposure:      Flow:       | KA:|          |  │".//21
    PRINT " │ Status:                    | KB:|          |  │".//22
    PRINT " ├───────────────────────────────────────────────┤".//23
    PRINT " │    Docked Vessels                    Status   │".//24
    PRINT " │ 1:                                -           │".//25
    PRINT " │ 2:                                -           │".//26
    PRINT " │ 3:                                -           │".//27
    PRINT " │ 4:                                -           │".//28
    PRINT " │ 5:                                -           │".//29
    PRINT " │ 6:                                -           │".//30
    PRINT " │ 7:                                -           │".//31
    PRINT " │ 8:                                -           │".//32
    PRINT " │ 9:                                -           │".//33
    PRINT " ╰───────────────────────────────────────────────╯".//34
    //</TERMPREVIEW>
}

drawScreen().
update().

UNTIL false{
    IF runtime > 10 {
        SET runtime TO 1.
        //drawScreen().
    }
    update().
    //Self Illumination
    IF sol:GETFIELD("status") = "Direct Sunlight" {setLights(0).} ELSE{setLights(1).}
    //Life Support
    IF lifeSupport = "TACLS" {
        PRINT perBar(res_percent("Food"),10)            AT (11,12).
        PRINT dateFormat(res_ETA("Food"))               AT (22,12).
        PRINT perBar(res_percent("Water"),10)           AT (11,13).
        PRINT dateFormat(res_ETA("Water"))              AT (22,13).
        PRINT perBar(res_percent("Oxygen"),10)          AT (11,14).
        PRINT dateFormat(res_ETA("Oxygen"))             AT (22,14).
        PRINT perBar(res_percent("CarbonDioxide"),10)   AT (11,15).
        PRINT dateFormat(res_ETA("CarbonDioxide"))      AT (22,15).
        PRINT perBar(res_percent("Waste"),10)           AT (11,16).
        PRINT dateFormat(res_ETA("Waste"))              AT (22,16).
        PRINT perBar(res_percent("WasteWater"),10)      AT (11,17).
        PRINT dateFormat(res_ETA("WasteWater"))         AT (22,17).
    } ELSE IF lifeSupport = "USI"{
        PRINT perBar(res_percent("Supplies"),10)        AT (11,12).
        PRINT dateFormat(res_ETA("Supplies"))           AT (22,12).
        IF res_exists("Mulch"){
            PRINT perBar(res_percent("Mulch"),10)       AT (11,13).
            PRINT dateFormat(res_ETA("Mulch"))          AT (22,13).
        } ELSE {
            PRINT "   ----   "                          AT (11,13).
            PRINT "  ----  "                            AT (22,13).
        }
        IF res_exists("Fertilizer"){
            PRINT perBar(res_percent("Fertilizer"),10)  AT (11,14).
            PRINT dateFormat(res_ETA("Fertilizer"))     AT (22,14).
        } ELSE {
            PRINT "   ----   "                          AT (11,14).
            PRINT "  ----  "                            AT (22,14).
        }
    }
    //Fuel
    LOCAL fuels IS LIST("MonoPropellant","LiquidFuel","Oxidizer","Karbonite","Karborundum").
    LOCAL fuelAbv IS LIST("MP","LF","OX","KA","KB").
    LOCAL i IS 0.
    UNTIL i = fuels:LENGTH {
        LOCAL s IS " ".
        IF res_exists(fuels[i]){SET s TO s + fuelAbv[i]+":|"+perBar(res_percent(fuels[i]),10)+"|".}
        clearPrint(s,18,31,18+i).
        SET i TO i+1.
    }
    //Power
    PRINT perBar(res_percent("ElectricCharge"),14) AT (7,20).
    PRINT timeFormat(res_ETA("ElectricCharge")) AT (22,20).
    LOCAL expose IS round(sol:GETFIELD("sun exposure"),2).
    clearPrint(expose,4,13,21).
    clearPrint(numFormat(ROUND(max(-99.99,min(99.99,res_rate("ElectricCharge"))),2),2),6,23,21).
    IF  expose = 1 OR expose = 0 OR panelAim = FALSE {clearPrint(sol:GETFIELD("status"),18,11,22).}
    ELSE {clearPrint("Orienting...",18,11,22).}
    IF panelAim = TRUE {
        LOCAL err IS 90-VANG(servoPart:FACING:STARVECTOR,SUN:POSITION).
        if ROUND(ABS(err)) > 1 {
            LOCAL spd IS min(0.3,ABS(err)/300).
            SET servo:SPEED TO servo:SPEED + min(0.05,max(-0.05,spd-servo:SPEED)).
            IF err > 0 {servo:MOVELEFT().}
            IF err < 0 {servo:MOVERIGHT().}

        }ELSE servo:STOP().
    }
    
    //Docked Vessels
    LOCAL i IS 0.
    LOCAL xferRemove IS LIST().
    FOR e IN docked {
        LOCAL n IS e:NAME.
        LOCAL status IS "IDLE".
        LOCAL fill IS LIST().
        LOCAL fillRes IS LIST().
        LOCAL supply IS LIST().
        LOCAL supplyRes IS LIST().
        FOR p IN e:PARTS {
            IF p:TAG = "fillMe" AND NOT fill:CONTAINS(p){
                fill:ADD(p).
                FOR re IN p:RESOURCES {
                    IF res_exists(re:NAME){
                        IF re:AMOUNT < re:CAPACITY * 0.999 AND res_amount(re:NAME) > 0 {
                            IF NOT fillRes:CONTAINS(re:NAME) fillRes:ADD(re:NAME).
                        }
                    }
                }
            }
            IF p:TAG = "resupply" AND NOT supply:CONTAINS(p){
                supply:ADD(p).
                FOR re IN p:RESOURCES {
                    IF res_exists(re:NAME){
                        IF re:AMOUNT > 0 AND res_percent(re:NAME)<0.999 {
                            IF NOT supplyRes:CONTAINS(re:NAME) supplyRes:ADD(re:NAME).
                        }
                    }
                }
            }
        }
        FOR re IN fillRes {
            LOCAL newXF IS TRUE.
            FOR xf IN xfers{
                IF xf[1] = n AND xf[2] = re {SET newXF TO FALSE.}
            }
            IF newXF = TRUE {xfers:ADD(LIST("self",n,re,TRANSFERALL(re,res_parts(re),fill),-1)).}
            SET status TO "LOADING".
        }
        FOR re IN supplyRes {
            LOCAL newXF IS TRUE.
            FOR xf IN xfers{
                IF xf[0] = n AND xf[2] = re {SET newXF TO FALSE.}
            }
            IF newXF = TRUE {xfers:ADD(LIST(n,"self",re,TRANSFERALL(re,supply,res_parts(re)),-1)).}
            IF status = "IDLE" SET status TO "UNLOADING".
            ELSE SET status TO "BI-DIRECT".
        }
        LOCAL iter IS xfers:ITERATOR.
        UNTIL NOT iter:NEXT {
            LOCAL xf IS iter:VALUE.
            IF NOT xf[3]:ACTIVE SET xf[3]:ACTIVE TO TRUE.
            IF xf[3]:TRANSFERRED = xf[4] AND NOT xferRemove:CONTAINS(iter:INDEX) xferRemove:ADD(iter:INDEX).
            SET xf[4] TO xf[3]:TRANSFERRED.
        }
        clearPrint(n,32,5,25+i).
        clearPrint(status,9,39,25+i).
        SET i TO i+1.
    }
    IF NOT xferRemove:EMPTY {
        IF xferRemove:LENGTH > 1{
            //Bubble sort
            LOCAL iter IS xferRemove:ITERATOR.
            UNTIL NOT iter:NEXT {
                IF iter:INDEX < 1 iter:NEXT.
                LOCAL tmp IS 0.
                LOCAL id IS iter:INDEX-1.
                IF iter:VALUE > xferRemove[id] {
                    SET tmp TO xferRemove[id].
                    SET xferRemove[id] TO iter:VALUE.
                    SET xferRemove[id+1] TO tmp.
                    iter:RESET.
                }
            }
        }
        FOR id IN xferRemove {
            SET xfers[id][3]:ACTIVE TO FALSE.
            xfers:REMOVE(id).
        }
    }
    //Stats
    clearPrint(partCount,7,41,12).
    clearPrint(station:LENGTH,7,41,13).
    clearPrint(round(TIME:SECONDS-oldTime,2),8,41,14).
    SET oldTime TO TIME:SECONDS.
    SET runtime TO runtime + 1.
    WAIT 0.
}