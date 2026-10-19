class_name Rhythm
extends RefCounted
## Pure timing maths.  Kept free of nodes so it can be unit tested headlessly.

const BPM := 120.0
const BEAT := 60.0 / BPM          # 0.5 s
const BAR := BEAT * 4.0           # 2.0 s
const BEATS_PER_BAR := 4
const PERFECT_WINDOW := 0.050
const GREAT_WINDOW := 0.100
const GOOD_WINDOW := 0.180
const FINALE_WINDOW := 0.205

enum Grade { PERFECT, GREAT, GOOD, OFF }

const GRADE_NAMES := ["PERFECT", "GREAT", "GOOD", "普通"]
const GRADE_NAMES_CN := ["完美", "精彩", "良好", "偏移"]
const GRADE_COLORS := [
	Color("ffd166"),
	Color("63f5d2"),
	Color("8fb8ff"),
	Color("8791a6"),
]
const ATTACK_NAMES := {
	"light": "快速斩击",
	"heavy": "低音重击",
	"thrust": "音波突刺",
	"launcher": "挑空攻击",
	"finale": "终章",
}


static func grade_for_delta(delta: float, window_scale: float = 1.0) -> int:
	var d := absf(delta)
	if d <= PERFECT_WINDOW * window_scale:
		return Grade.PERFECT
	if d <= GREAT_WINDOW * window_scale:
		return Grade.GREAT
	if d <= GOOD_WINDOW * window_scale:
		return Grade.GOOD
	return Grade.OFF


static func delta_to_beat(time: float) -> float:
	## Signed distance to the nearest beat.
	var beat_index := roundf(time / BEAT)
	return time - beat_index * BEAT


static func abs_delta_to_beat(time: float) -> float:
	return absf(delta_to_beat(time))


static func judge_at(time: float, window_scale: float = 1.0) -> Dictionary:
	var delta := delta_to_beat(time)
	var grade := grade_for_delta(delta, window_scale)
	return {
		"grade": grade,
		"delta": delta,
		"delta_ms": delta * 1000.0,
		"abs_delta_ms": absf(delta) * 1000.0,
	}


static func beat_info(time: float) -> Dictionary:
	var beat_float := time / BEAT
	var beat_index := int(floor(beat_float))
	var bar_index := int(floor(beat_float / BEATS_PER_BAR))
	var phase := fposmod(beat_float, 1.0)
	return {
		"time": time,
		"beat": beat_index,
		"bar": bar_index,
		"beat_in_bar": beat_index % BEATS_PER_BAR,
		"phase": phase,
		"to_next_beat": (1.0 - phase) * BEAT,
		"bar_phase": fposmod(time, BAR) / BAR,
	}


static func grade_weight(grade: int) -> float:
	match grade:
		Grade.PERFECT:
			return 1.0
		Grade.GREAT:
			return 0.78
		Grade.GOOD:
			return 0.5
		_:
			return 0.08


static func grade_name(grade: int) -> String:
	return GRADE_NAMES[clampi(grade, 0, 3)]


static func grade_name_cn(grade: int) -> String:
	return GRADE_NAMES_CN[clampi(grade, 0, 3)]


static func grade_color(grade: int) -> Color:
	return GRADE_COLORS[clampi(grade, 0, 3)]


static func grade_is_clean(grade: int) -> bool:
	return grade <= Grade.GOOD


static func signed_ms(delta: float) -> String:
	var ms := delta * 1000.0
	return ("+%d ms" % int(round(ms))) if ms >= 0.0 else ("%d ms" % int(round(ms)))
