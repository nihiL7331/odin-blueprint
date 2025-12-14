package utils

import utils "."

appNow :: utils.secondsSinceInit

now :: proc() -> f64 {
	coreContext := utils.getCoreContext()

	return coreContext.gameState.gameTimeElapsed
}
endTimeUp :: proc(endTime: f64) -> bool {
	return endTime == -1 ? false : now() >= endTime
}
timeSince :: proc(time: f64) -> f32 {
	if time == 0 {
		return 99999999.0
	}
	return f32(now() - time)
}
