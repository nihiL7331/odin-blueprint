package gmath

import "core:math"

EaseName :: enum {
	Linear,
	InSine,
	OutSine,
	InOutSine,
	InQuad,
	OutQuad,
	InOutQuad,
	InCubic,
	OutCubic,
	InOutCubic,
	InQuart,
	OutQuart,
	InOutQuart,
	InQuint,
	OutQuint,
	InOutQuint,
	InExpo,
	OutExpo,
	InOutExpo,
	InCirc,
	OutCirc,
	InOutCirc,
	InBack,
	OutBack,
	InOutBack,
	InElastic,
	OutElastic,
	InOutElastic,
	InBounce,
	OutBounce,
	InOutBounce,
}

ease :: proc(name: EaseName, t: f32) -> f32 {
	switch name {
	case .Linear:
		return t
	case .InSine:
		return inSine(t)
	case .OutSine:
		return outSine(t)
	case .InOutSine:
		return inOutSine(t)
	case .InQuad:
		return inQuad(t)
	case .OutQuad:
		return outQuad(t)
	case .InOutQuad:
		return inOutQuad(t)
	case .InCubic:
		return inCubic(t)
	case .OutCubic:
		return outCubic(t)
	case .InOutCubic:
		return inOutCubic(t)
	case .InQuart:
		return inQuart(t)
	case .OutQuart:
		return outQuart(t)
	case .InOutQuart:
		return inOutQuart(t)
	case .InQuint:
		return inQuint(t)
	case .OutQuint:
		return outQuint(t)
	case .InOutQuint:
		return inOutQuint(t)
	case .InExpo:
		return inExpo(t)
	case .OutExpo:
		return outExpo(t)
	case .InOutExpo:
		return inOutExpo(t)
	case .InCirc:
		return inCirc(t)
	case .OutCirc:
		return outCirc(t)
	case .InOutCirc:
		return inOutCirc(t)
	case .InBack:
		return inBack(t)
	case .OutBack:
		return outBack(t)
	case .InOutBack:
		return inOutBack(t)
	case .InElastic:
		return inElastic(t)
	case .OutElastic:
		return outElastic(t)
	case .InOutElastic:
		return inOutElastic(t)
	case .InBounce:
		return inBounce(t)
	case .OutBounce:
		return outBounce(t)
	case .InOutBounce:
		return inOutBounce(t)
	case:
		return t
	}
}

// via easings.net<3
inSine :: proc(x: f32) -> f32 {
	return 1 - math.cos_f32((x * math.PI) / 2)
}
outSine :: proc(x: f32) -> f32 {
	return math.sin_f32((x * math.PI) / 2)
}
inOutSine :: proc(x: f32) -> f32 {
	return -(math.cos_f32(math.PI * x) - 1) / 2
}

inQuad :: proc(x: f32) -> f32 {
	return x * x
}
outQuad :: proc(x: f32) -> f32 {
	return 1 - (1 - x) * (1 - x)
}
inOutQuad :: proc(x: f32) -> f32 {
	return x < 0.5 ? 2 * x * x : 1 - math.pow_f32(-2 * x + 2, 2) / 2
}

inCubic :: proc(x: f32) -> f32 {
	return x * x * x
}
outCubic :: proc(x: f32) -> f32 {
	return 1 - math.pow_f32(1 - x, 3)
}
inOutCubic :: proc(x: f32) -> f32 {
	return x < 0.5 ? 4 * x * x * x : 1 - math.pow_f32(-2 * x + 2, 3) / 2
}

inQuart :: proc(x: f32) -> f32 {
	return x * x * x * x
}
outQuart :: proc(x: f32) -> f32 {
	return 1 - math.pow_f32(1 - x, 4)
}
inOutQuart :: proc(x: f32) -> f32 {
	return x < 0.5 ? 8 * x * x * x * x : 1 - math.pow_f32(-2 * x + 2, 4) / 2
}

inQuint :: proc(x: f32) -> f32 {
	return x * x * x * x * x
}
outQuint :: proc(x: f32) -> f32 {
	return 1 - math.pow_f32(1 - x, 5)
}
inOutQuint :: proc(x: f32) -> f32 {
	return x < 0.5 ? 16 * x * x * x * x * x : 1 - math.pow_f32(-2 * x + 2, 5) / 2
}

inExpo :: proc(x: f32) -> f32 {
	return x == 0 ? 0 : math.pow_f32(2, 10 * x - 10)
}
outExpo :: proc(x: f32) -> f32 {
	return x == 1 ? 1 : 1 - math.pow_f32(2, -10 * x)
}
inOutExpo :: proc(x: f32) -> f32 {
	return(
		x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? math.pow_f32(2, 20 * x - 10) / 2 : (2 - math.pow_f32(2, -20 * x + 10)) / 2 \
	)
}

inCirc :: proc(x: f32) -> f32 {
	return 1 - math.sqrt_f32(1 - math.pow_f32(x, 2))
}
outCirc :: proc(x: f32) -> f32 {
	return math.sqrt_f32(1 - math.pow_f32(x - 1, 2))
}
inOutCirc :: proc(x: f32) -> f32 {
	return(
		x < 0.5 ? (1 - math.sqrt_f32(1 - math.pow_f32(2 * x, 2))) / 2 : (math.sqrt_f32(1 - math.pow_f32(-2 * x + 2, 2)) + 1) / 2 \
	)
}

inBack :: proc(x: f32) -> f32 {
	c1 :: 1.70158
	c3 :: c1 + 1

	return c3 * x * x * x - c1 * x * x
}
outBack :: proc(x: f32) -> f32 {
	c1 :: 1.70158
	c3 :: c1 + 1

	return 1 + c3 * math.pow_f32(x - 1, 3) + c1 * math.pow_f32(x - 1, 2)
}
inOutBack :: proc(x: f32) -> f32 {
	c1 :: 1.70158
	c2 :: c1 * 1.525

	return(
		x < 0.5 ? (math.pow_f32(2 * x, 2) * ((c2 + 1) * 2 * x - c2)) / 2 : (math.pow_f32(2 * x - 2, 2) * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2 \
	)
}

inElastic :: proc(x: f32) -> f32 {
	c4 :: (2 * math.PI) / 3

	return(
		x == 0 ? 0 : x == 1 ? 1 : -math.pow_f32(2, 10 * x - 10) * math.sin_f32((x * 10 - 10.75) * c4) \
	)
}
outElastic :: proc(x: f32) -> f32 {
	c4 :: (2 * math.PI) / 3

	return(
		x == 0 ? 0 : x == 1 ? 1 : math.pow_f32(2, -10 * x) * math.sin_f32((x * 10 - 0.75) * c4) + 1 \
	)
}
inOutElastic :: proc(x: f32) -> f32 {
	c5 :: (2 * math.PI) / 4.5

	return(
		x == 0 ? 0 : x == 1 ? 1 : x < 0.5 ? -(math.pow_f32(2, 20 * x - 10) * math.sin_f32((20 * x - 11.125) * c5)) / 2 : (math.pow_f32(2, -20 * x + 10) * math.sin((20 * x - 11.125) * c5)) / 2 + 1 \
	)
}

inBounce :: proc(x: f32) -> f32 {
	return 1 - outBounce(1 - x)
}
outBounce :: proc(x: f32) -> f32 {
	n1 :: 7.5625
	d1 :: 2.75

	if x < 1 / d1 {
		return n1 * x * x
	} else if (x < 2 / d1) {
		return n1 * (x - 1.5 / d1) * (x - 1.5 / d1) + 0.75
	} else if (x < 2.5 / d1) {
		return n1 * (x - 2.25 / d1) * (x - 2.25 / d1) + 0.9375
	} else {
		return n1 * (x - 2.625 / d1) * (x - 2.625 / d1) + 0.984375
	}
}
inOutBounce :: proc(x: f32) -> f32 {
	return x < 0.5 ? (1 - outBounce(1 - 2 * x)) / 2 : (1 + outBounce(2 * x - 1)) / 2
}
