DECLARE PARAMETER arg.
CLEARSCREEN.
PRINT "Displaying " + arg:length + " waypoints.".

AG1 OFF.
LOCAL oldPos IS V(0,0,0).
LOCAL draw IS LIST().
LOCAL iter IS arg:ITERATOR.
UNTIL NOT iter:NEXT {
    draw:ADD(VECDRAW()).
}
FOR d IN draw {
    SET d:COLOR TO GREEN.
    SET d:SCALE TO 1.
}
iter:RESET.
UNTIL AG1 {
    UNTIL NOT iter:NEXT {
        LOCAL id IS iter:INDEX.
        LOCAL dest IS iter:VALUE.
        LOCAL pos IS dest[0]:ALTITUDEPOSITION(dest[1]).
        SET draw[id]:START TO oldPos.
        SET draw[id]:VEC TO pos-oldPos.
        SET draw[id]:LABEL TO dest[3].
        SET draw[id]:SHOW TO TRUE.
        SET oldPos TO pos.
    }
    iter:RESET.
}
for d IN draw {
    SET d:SHOW TO FALSE.
}