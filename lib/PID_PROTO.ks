//List values:
//0:kp
//1:ki
//2:kd
//3:I
//4:oldError
//5:lastruntime
//6:minI
//7:maxI
//8:minO
//9:maxO
FUNCTION pid {
    DECLARE PARAMETER l, input.
    LOCAL dT IS time:seconds - l[5].
    if dT > 0{
        LOCAL D IS 0.
        SET l[3] TO (l[3] + input*l[1]*dT).
        SET l[3] TO max(l[6],min(l[7],l[3])).
        IF l[10] = TRUE {
            SET D TO (l[11] - l[4]) / dT.
            SET l[4] TO l[11].
        }
        ELSE {
            SET D TO (input - l[4]) / dT.
            SET l[4] TO input.
        }
        SET l[5] TO time:seconds.
        RETURN max(l[8],min(l[9],input * l[0] + l[3] + D * l[2])).
    }
}
FUNCTION pid_new {
    PARAMETER kP,kI,kD.
    RETURN LIST(kP,kI,kD,0,0,time:seconds,-1,1,-1,1,FALSE,0).
}
FUNCTION pid_gains {
    PARAMETER l,kP,kI,kD.
    SET l[0] TO kP.
    SET l[1] TO kI.
    SET l[2] TO kD.
}
FUNCTION pid_limits {
    PARAMETER l,minI,maxI,minO,maxO.
    SET l[6] TO minI.
    SET l[7] TO maxI.
    SET l[8] TO minO.
    SET l[9] TO maxO.
}
FUNCTION pid_dOverride { //Use something other than the error as basis for D. Example: P is based off altitude, but D is based off vertical speed.
    PARAMETER l,d.
    SET l[10] TO TRUE.
    SET l[11] TO d.
}