declare parameter kind, p1, alt, speed.


if kind = "waypoint"{
	//SET dest TO WAYPOINT(p1):geoposition.
    SET dest TO allwaypoints()[p1]:geoposition.
	//if alt = 0 {set alt to WAYPOINT(p1):altitude.}
    if alt = 0 {set alt to allwaypoints()[p1]:altitude.}
	run planeAutoPilot(list(list(dest,alt,speed,allwaypoints()[p1]:NAME))).
}
if kind = "coords" {
	run planeAutoPilot(list(list(p1,alt,speed,"User coords"))).
}
IF kind = "route" {
    SWITCH TO 0.
    RUN routePlanner.
    SWITCH TO 1.
    LOCAL route IS planRoute(alt,speed).
    IF STATUS = "LANDED" OR STATUS = "PRELAUNCH"{
        route:INSERT(0,list(latlng(0,-74),1200,200,"Initial Climb")).
        route:INSERT(0,list(latlng(-0.05017,-74.498),250,150,"Takeoff")).
    }
    RUN planeAutoPilot(route).
}
if kind = "KSC" or kind = "ksc"{
	//Use parameter options for first leg of journey
	run planeAutoPilot(list(
        list(latlng(-0.0486,-74.719),alt,speed,"KSC"),
        list(latlng(0,-77.5),3000,300,"Start"),
        list(latlng(-0.05,-77),2000,200,"Approach1"),
        list(latlng(-0.05,-75.5),1000,120,"Approach2"),
        list(latlng(-0.0486,-75),250,90,"Approach3"),
        list(latlng(-0.0486,-74.719),90,70,"Runway"),
        list(latlng(-0.0494,-74.608),60,0,"Land")
    )).
}