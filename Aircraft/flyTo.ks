declare parameter kind is "none".
declare parameter p1, dAlt, speed.


if kind = "waypoint" {
	// SET dest TO WAYPOINT(p1):geoposition.
	LOCAL dest IS allwaypoints()[p1]:geoposition.
	// if dAlt = 0 {set dAlt to WAYPOINT(p1):altitude.}
	if dAlt = 0 {set dAlt to allwaypoints()[p1]:altitude.}
	run planeAutoPilot(list(list(dest, dAlt, speed, allwaypoints()[p1]:NAME))).
}
else if kind = "coords" {
	run planeAutoPilot(list(list(p1, dAlt, speed, "User coords"))).
}
else IF kind = "route" {
	SWITCH TO 0.
	RUN routePlanner.
	SWITCH TO 1.
	LOCAL route IS planRoute(dAlt, speed).
	IF STATUS = "LANDED" OR STATUS = "PRELAUNCH" {
		// TODO: Reconfigure to dynamically create waypoints based on current position
		//     This will permit takeoff from any location.
		route:INSERT(0, list(latlng(0, -74), 1200, 200, "Initial Climb")).
		route:INSERT(0, list(latlng(-0.05017, -74.498), 250, 150, "Takeoff")).
	}
	RUN planeAutoPilot(route).
}
else if kind:tolower = "ksc"{
	//Use parameter options for first leg of journey
	run planeAutoPilot(list(
		list(latlng(-0.0486, -74.719), dAlt, speed, "KSC"),
		list(latlng(-0.0486, -77.5  ), 3000, 300  , "Start"),
		list(latlng(-0.0486, -77    ), 2000, 200  , "Approach1"),
		list(latlng(-0.0486, -75.5  ), 1000, 120  , "Approach2"),
		list(latlng(-0.0486, -75    ), 250 , 90   , "Approach3"),
		list(latlng(-0.0486, -74.719), 90  , 70   , "Runway"),
		list(latlng(-0.0494, -74.608), 60  , 0    , "Land")
	)).
}
// TODO: Add island and desert runways