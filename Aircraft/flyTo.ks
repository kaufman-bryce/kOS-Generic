declare parameter kind.
PARAMETER p1 is 0.
PARAMETER dAlt is 0.
PARAMETER speed is 0.

local runways is LEXICON(
	"KSC 09"   , LEXICON(
		"start"   , latlng(-0.0486, -74.7264),
		"end"     , latlng(-0.0501, -74.4908),
		"altitude", 69.01,
		"glideslope", 3
	),
	"Island 09", LEXICON(
		"start"   , latlng(-1.5173, -71.9654),
		"end"     , latlng(-1.5159, -71.8524),
		"altitude", 133.17,
		"glideslope", 3
	),
	"Dessert 18", LEXICON(
		"start"   , latlng(-6.4482, -144.0381),
		"end"     , latlng(-6.5993, -144.0405),
		"altitude", 822,
		"glideslope", 3
	),
	"KSC 27"   , LEXICON(
		"start"   , latlng(-0.0501, -74.4908),
		"end"     , latlng(-0.0486, -74.7264),
		"altitude", 69.01,
		"glideslope", 3
	),
	"Island 27", LEXICON(
		"start"   , latlng(-1.5159, -71.8524),
		"end"     , latlng(-1.5173, -71.9654),
		"altitude", 133.17,
		"glideslope", 3
	),
	"Dessert 36", LEXICON(
		"start"   , latlng(-6.5993, -144.0405),
		"end"     , latlng(-6.4482, -144.0381),
		"altitude", 822,
		"glideslope", 3
	)
).

function planLanding {
	PARAMETER runway.
	local route is list().
	local rwAlt is runways[runway]:altitude.
	local start is runways[runway]:start:altitudeposition(rwAlt).
	local end is runways[runway]:end:altitudeposition(rwAlt).
	local dir is (start - end):normalized.
	local glideslope is runways[runway]:glideslope.
	local bodypos is BODY:POSITION.
	local glideslopeVec is dir * ANGLEAXIS(glideslope, VCRS(start - bodypos, end - bodypos)).
	local cruiseVec is dir * ANGLEAXIS(glideslope * 2, VCRS(start - bodypos, end - bodypos)).
	local function getAlt {
		PARAMETER inVec.
		return (inVec - BODY:POSITION):mag - BODY:radius.
	}
	local apprAlt is getAlt(start + glideslopeVec * 15000).
	local cruiseAlt is max(apprAlt, dAlt) - apprAlt.
	local cruiseMul is 0.
	if cruiseAlt > 0 {set cruiseMul to cruiseAlt / SIN(glideslope * 2).}
	
	route:add(list(
		BODY:geopositionof(start + glideslopeVec * 15000 + cruiseVec * cruiseMul),
		dAlt,
		speed,
		"Cruise to " + runway
	)).
	route:add(list(
		BODY:geopositionof(start + glideslopeVec * 15000),
		apprAlt,
		200,
		runway + " Appr. 1",
		true
	)).
	route:add(list(
		BODY:geopositionof(start + glideslopeVec * 7500),
		getAlt(start + glideslopeVec * 7500),
		100,
		runway + " Appr. 2",
		true
	)).
	route:add(list(
		BODY:geopositionof(start + glideslopeVec * 1000),
		getAlt(start + glideslopeVec * 1000),
		70,
		runway + " Final Appr.", 
		true
	)).
	route:add(list(runways[runway]:start, rwAlt - 5, 40, runway, true)).
	route:add(list(runways[runway]:end, rwAlt - 5, 0, "Touchdown")).
	RETURN route.
}

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
else if kind = "route" {
	SWITCH TO 0.
	RUNONCEPATH("/lib/routePlanner").
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
else if kind = "land" {
	LOCAL route is LIST().
	if p1 = "nearest" {
		// TODO: Iterate runways and determine which start point is closest
	} else set route to planLanding(p1).
	run planeAutoPilot(route).
}
else if kind = "takeoff" {
	IF STATUS = "LANDED" OR STATUS = "PRELAUNCH" {
		LOCAL route IS list().
		// TODO: Reconfigure to dynamically create waypoints based on current position
		//     This will permit takeoff from any location.
		route:INSERT(0, list(latlng(0, -74), 1200, 200, "Initial Climb")).
		route:INSERT(0, list(latlng(-0.0501, -74.4908), 250, 150, "Takeoff")).
		RUN planeAutoPilot(route).
	}
}
else if kind = "test" {
	set dAlt to 6000.
	set speed to 300.
	LOCAL route is planLanding("KSC 27").
	// route:INSERT(0, list(latlng(1, -71), 6000, 300, "Divert")).
	route:INSERT(0, list(latlng(2, -72), 3000, 300, "Initial Climb")).
	route:INSERT(0, list(latlng(-0.0501, -74.2), 250, 150, "Takeoff")).
	run planeAutoPilot(route).
}
// TODO: Add island and desert runways, make function to generate landing waypoints automatically.
// Baikerbanur 0.657222 -146.420556
// Woomerang 45.29 136.11
// Dessert Base -6.599444 -144.040556