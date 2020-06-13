@LAZYGLOBAL OFF.
FUNCTION planRoute {
	PARAMETER dAlt, speed.
	LOCAL ksc IS latlng(-0.0486,-74.719).
	LOCAL startTime IS time:seconds.
	LOCAL STARTPOS IS SHIP:GEOPOSITION.
	LOCAL clockspeed IS CONFIG:IPU.
	LOCAL points IS LIST().
	LOCAL waypoints IS LIST().
	
	FOR wp IN ALLWAYPOINTS() {
		IF wp:BODY = BODY {
			points:ADD(wp:GEOPOSITION).
			waypoints:ADD(wp).
		}
	}
	
	FUNCTION getDist {
		PARAMETER geo1, geo2.
		RETURN (geo1:POSITION - geo2:POSITION):MAG.
	}
	FUNCTION totLength {
		PARAMETER l.
		LOCAL len IS 0.
		LOCAL i IS 0.
		UNTIL i = l:LENGTH{
			LOCAL wp1 IS 0.
			IF i = 0 {SET wp1 TO STARTPOS.}
			ELSE {SET wp1 TO points[l[i - 1]].}
			SET len TO len + getDist(wp1,points[l[i]]).
			SET i TO i + 1.
		}
		SET len TO len + getDist(ksc,points[l:LENGTH - 1]).
		RETURN len.
	}
	FUNCTION pathSwap { // Take everything between i1 and i2 and move it to i3
		PARAMETER l, i1, i2, i3.
		LOCAL new IS l:COPY.
		LOCAL sub IS new:SUBLIST(i1, i2).
		UNTIL new:LENGTH = l:LENGTH - sub:LENGTH {
			new:REMOVE(i1).
		}
		LOCAL sub2 IS LIST().
		LOCAL i IS sub:LENGTH - 1.
		UNTIL sub2:LENGTH = sub:LENGTH { // Sub2 is the reverse of sub
			sub2:ADD(sub[i]).
			SET i TO i - 1.
		}
		IF i3 > i1 {SET i3 TO i3 - i2.}
		FOR id IN sub2 {
			IF i3 = -1 {new:ADD(id).}
			ELSE {new:INSERT(i3, id).}
		}
		RETURN NEW.
	}
	FUNCTION factorial {
		PARAMETER n.
		LOCAL fac IS 0.
		UNTIL n = 2{
			SET FAC to n * (n - 1).
			SET n TO n - 1.
		}
		RETURN FAC.
	}
	
	
	CLEARSCREEN.
	PRINT "Planning route...".
	PRINT "0%" AT (0,1).
	SET CONFIG:IPU TO 5000.
	
	LOCAL route1 IS LIST().
	UNTIL route1:LENGTH = waypoints:LENGTH {
		LOCAL shortest IS 0.
		LOCAL shortestD IS 99999999999999999999.
		LOCAL id IS 0.
		LOCAL st IS STARTPOS.
		IF route1:LENGTH > 0 {
			SET st TO points[route1[route1:LENGTH - 1]].
		}
		UNTIL id = points:LENGTH {
			LOCAL wp IS points[id].
			IF NOT route1:CONTAINS(id) {
				LOCAL d IS getDist(wp,st).
				IF d < shortestD AND d > 10{
					SET shortestD TO d.
					SET shortest TO id.
				}
			}
			SET id TO id + 1.
		}
		route1:ADD(shortest).
		PRINT round((route1:LENGTH/waypoints:LENGTH)*100) + "%" AT(0,1).
	}
	LOCAL route1Total IS totLength(route1).
	PRINT "Nearest Neighbour route distance " + round(route1Total).
	PRINT "Performing 2-opt swaps:".
	PRINT "       Current minimum: " + round(route1Total).
	PRINT "    Fruitless Attempts:".
	
	LOCAL noChange IS 0.
	LOCAL swaps IS 0.
	LOCAL attempts IS list().
	LOCAL maxAttempts IS points:LENGTH * 50.
	UNTIL noChange = maxAttempts { // Random 2-opt swaps until nothing changes for a while.
		IF attempts:LENGTH > factorial(points:LENGTH - 1) / 2 {BREAK.}
		LOCAL r1 IS round(random() * (route1:LENGTH - 1)).
		LOCAL r2 IS round(random() * (route1:LENGTH - r1)).
		IF r1 + r2 > route1:LENGTH - 1{SET r2 TO route1:LENGTH - r1.}
		LOCAL r3 IS round(random() * (route1:LENGTH - 1)).
		IF r3 > r1 AND r3 < r1+r2+1 {SET r3 TO r1 + r2 + 1.}
		IF r3 >= route1:LENGTH - 1 {SET r3 TO -1.}
		LOCAL attemptID IS r1*1000000 + r2*1000 + r3. // supports up to 1000 waypoints
		IF NOT attempts:CONTAINS(attemptID){ // If we've already tried this combo, don't do it again.
			attempts:ADD(attemptID).
			LOCAL tryout IS pathSwap(route1,r1,r2,r3).
			LOCAL tryLen IS totLength(tryout).
			IF tryLen - route1Total < -10 {
				SET route1 TO tryout.
				SET route1Total TO tryLen.
				SET noChange TO 0.
				attempts:CLEAR().
				PRINT round(tryLen) + "         " AT (24, 3).
			} ELSE SET noChange TO noChange + 1.
			SET swaps TO swaps + 1.
			PRINT swaps AT (24,2).
			PRINT noChange + "    " AT (24, 4).
		}
	}
	PRINT "Time elapsed: " + round(time:seconds - starttime).
	SET CONFIG:IPU TO clockspeed.
	
	LOCAL route IS list().
	FOR id IN route1 {
		LOCAL wp IS waypoints[id].
		route:ADD(LIST(wp:GEOPOSITION,dAlt,speed,wp:NAME)).
	}
	// route:ADD(LIST(ksc,alt,speed,"KSC")).
	WAIT 1.
	RETURN route.
}