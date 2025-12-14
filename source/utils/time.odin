package utils

import utils "."
import "core:time"

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

initTime: time.Time // this time doesn't stop compared to coreContext.gameState.gameTimeElapsed
secondsSinceInit :: proc() -> f64 {
	if initTime._nsec == 0 {
		initTime = time.now()
		return 0
	}
	return time.duration_seconds(time.since(initTime))
}
