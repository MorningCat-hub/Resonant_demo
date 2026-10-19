class_name GameConfig
extends RefCounted
## One tuning surface for the whole demo.  Frame data is in seconds and is the
## first thing to edit when playtesting; nothing else contains magic timings.

const GRAVITY := 2250.0
const MAX_FALL := 1250.0
const RUN_SPEED := 350.0
const GROUND_ACCEL := 3000.0
const AIR_ACCEL := 2200.0
const GROUND_FRICTION := 3400.0
const JUMP_VELOCITY := -785.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.13
const DODGE_SPEED := 790.0
const DODGE_TIME := 0.18
const DODGE_IFRAMES := 0.26
const DODGE_COOLDOWN := 0.34
const PLAYER_MAX_HP := 100.0
const PLAYER_HIT_IFRAMES := 0.72
const PLAYER_AIR_DODGES := 1

const ATTACKS := {
	"light": {
		"label": "快速斩击",
		"key": "K",
		"startup": 0.060,
		"active": 0.100,
		"recovery": 0.150,
		"damage": 10.0,
		"combo_damage": [10.0, 11.0, 15.0],
		"reach": 100.0,
		"half_height": 54.0,
		"offset": 48.0,
		"poise": 12.0,
		"knockback": 170.0,
		"lift": -40.0,
		"hitstop": 0.045,
		"shake": 2.4,
		"lunge": 0.0,
		"swing_sfx": "swing_light",
		"hit_sfx": "hit_light",
		"color": Color("8fb8ff"),
	},
	"heavy": {
		"label": "低音重击",
		"key": "J",
		"startup": 0.270,
		"active": 0.120,
		"recovery": 0.460,
		"damage": 30.0,
		"combo_damage": [30.0],
		"reach": 124.0,
		"half_height": 72.0,
		"offset": 55.0,
		"poise": 48.0,
		"knockback": 360.0,
		"lift": -90.0,
		"hitstop": 0.13,
		"shake": 8.0,
		"lunge": 70.0,
		"swing_sfx": "swing_heavy",
		"hit_sfx": "hit_heavy",
		"color": Color("ff8a6b"),
	},
	"thrust": {
		"label": "音波突刺",
		"key": "L",
		"startup": 0.105,
		"active": 0.120,
		"recovery": 0.270,
		"damage": 16.0,
		"combo_damage": [16.0],
		"reach": 196.0,
		"half_height": 40.0,
		"offset": 82.0,
		"poise": 16.0,
		"knockback": 210.0,
		"lift": -20.0,
		"hitstop": 0.05,
		"shake": 3.2,
		"lunge": 840.0,
		"swing_sfx": "swing_thrust",
		"hit_sfx": "hit_thrust",
		"color": Color("ffd166"),
	},
	"launcher": {
		"label": "挑空攻击",
		"key": "I",
		"startup": 0.155,
		"active": 0.130,
		"recovery": 0.335,
		"damage": 14.0,
		"combo_damage": [14.0],
		"reach": 110.0,
		"half_height": 88.0,
		"offset": 40.0,
		"poise": 20.0,
		"knockback": 90.0,
		"lift": -730.0,
		"hitstop": 0.065,
		"shake": 4.0,
		"lunge": 120.0,
		"swing_sfx": "swing_launch",
		"hit_sfx": "hit_launch",
		"color": Color("63f5d2"),
	},
}

const ENEMIES := {
	"note": {
		"label": "音符兽",
		"hp": 30.0,
		"poise": 14.0,
		"speed": 148.0,
		"gravity": 2100.0,
		"damage": 8.0,
		"attack_range": 62.0,
		"windup": 0.36,
		"active": 0.16,
		"recovery": 0.52,
		"cooldown": 0.55,
		"knockback_res": 1.0,
		"color": Color("63f5d2"),
		"death_sfx": "death_note",
	},
	"guard": {
		"label": "重拍守卫",
		"hp": 112.0,
		"poise": 70.0,
		"speed": 74.0,
		"gravity": 2200.0,
		"damage": 15.0,
		"attack_range": 90.0,
		"windup": 0.62,
		"active": 0.20,
		"recovery": 0.90,
		"cooldown": 0.8,
		"knockback_res": 0.25,
		"color": Color("ff8a6b"),
		"death_sfx": "death_guard",
		"armor": true,
	},
	"sprite": {
		"label": "高音精灵",
		"hp": 38.0,
		"poise": 12.0,
		"speed": 112.0,
		"gravity": 0.0,
		"damage": 9.0,
		"attack_range": 340.0,
		"windup": 0.42,
		"active": 0.1,
		"recovery": 1.35,
		"cooldown": 1.4,
		"knockback_res": 1.3,
		"color": Color("b28dff"),
		"death_sfx": "death_sprite",
		"flying": true,
		"hover": 126.0,
	},
	"dissonant": {
		"label": "失谐者",
		"hp": 76.0,
		"poise": 28.0,
		"speed": 186.0,
		"gravity": 2200.0,
		"damage": 12.0,
		"attack_range": 82.0,
		"windup": 0.28,
		"active": 0.15,
		"recovery": 0.38,
		"cooldown": 0.45,
		"knockback_res": 1.2,
		"color": Color("ff5f6d"),
		"death_sfx": "death_dissonant",
		"unstable": true,
	},
}

const BOSS := {
	"name": "失序指挥家",
	"subtitle": "THE DISSONANT CONDUCTOR",
	"hp": 620.0,
	"phase_2": 0.66,
	"phase_3": 0.33,
	"body_damage_scale": 0.22,
	"core_damage_scale": 1.35,
}

const STAGES := [
	{
		"title": "第一乐章 · 失序回廊",
		"subtitle": "I. 找回节拍",
		"goal": "让每一次命中落在节拍上",
		"color": Color("63f5d2"),
	},
	{
		"title": "第一乐章 · 失序回廊",
		"subtitle": "II. 建立旋律",
		"goal": "用低音重击击碎重拍守卫的护甲",
		"color": Color("8fb8ff"),
	},
	{
		"title": "第一乐章 · 失序回廊",
		"subtitle": "III. 失序区域",
		"goal": "在失谐的节奏里活下来",
		"color": Color("ff8a6b"),
	},
	{
		"title": "第一乐章 · 失序回廊",
		"subtitle": "IV. 终章演奏",
		"goal": "击败失序指挥家，完成终章",
		"color": Color("ffd166"),
	},
]

const FINALE_SEQUENCE := [
	{"beat": 1, "action": "light", "key": "K", "label": "快速斩击"},
	{"beat": 3, "action": "thrust", "key": "L", "label": "音波突刺"},
	{"beat": 5, "action": "launcher", "key": "I", "label": "挑空攻击"},
	{"beat": 7, "action": "heavy", "key": "J", "label": "低音重击"},
]


static func attack(id: String) -> Dictionary:
	return ATTACKS.get(id, ATTACKS["light"])


static func enemy(kind: String) -> Dictionary:
	return ENEMIES.get(kind, ENEMIES["note"])
