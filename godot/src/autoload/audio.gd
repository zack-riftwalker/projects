extends Node
# Audio: sound effects (a pool of players, the same minimum gap per name as the JS game) and looping music with a crossfade.

const SFX := ["jump", "djump", "walljump", "land", "swipe", "swipeBig", "hit", "clang", "squish", "kill", "hurt", "die", "token", "spark", "heal", "dash", "spring", "crumble", "brk", "checkpoint", "shoot", "bossHit", "explode", "bigExplode", "uiMove", "uiOk", "uiBack", "text", "textLow", "textSys", "key", "gate", "agent", "agentHit", "warn", "charge", "laser", "drip", "splash", "thud", "roar", "glitch", "tick", "tock", "pause", "flap", "logo", "stamp"]
const MIN_GAP_MS := 28
const MUSIC_LINEAR := 0.7

var streams := {}
var pool: Array = []
var last_play := {}
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var music_name := ""
var first_sfx_msec := -1       # when the first sound actually started (debug overlay)
var first_touch_msec := -1
var duck_db := 0.0

func _ready() -> void:
	for n in SFX:
		var s = load("res://assets/sfx/%s.wav" % n)
		if s != null:
			streams[n] = s
	for i in range(12):
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	add_child(music_a)
	add_child(music_b)

func sfx(sfx_name: String, opts := {}) -> void:
	if Game.mute or not streams.has(sfx_name):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(sfx_name, -1000)) < MIN_GAP_MS:
		return
	last_play[sfx_name] = now
	for p in pool:
		if not p.playing:
			p.stream = streams[sfx_name]
			p.volume_db = linear_to_db(maxf(0.001, float(opts.get("vol", 1.0)))) + duck_db
			p.play()
			if first_sfx_msec < 0:
				first_sfx_msec = now
			return

func music(music_key: String) -> void:
	if Game.mute or music_key == music_name:
		return
	music_name = music_key
	var path := "res://assets/music/%s.ogg" % music_key
	if not ResourceLoader.exists(path):
		return
	var st: AudioStreamOggVorbis = load(path)
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/index.json"))
	var info: Dictionary = idx.get(music_key, {})
	st.loop = not info.get("once", false)
	st.loop_offset = float(info.get("loop_start", 0.0))
	# crossfade 0.5 s: a fades out, b fades in
	var old := music_a
	music_a = music_b
	music_b = old
	music_a.stream = st
	music_a.volume_db = -60.0
	music_a.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(music_a, "volume_db", linear_to_db(MUSIC_LINEAR) + duck_db, 0.5)
	if music_b.playing:
		tw.tween_property(music_b, "volume_db", -60.0, 0.5)
		tw.chain().tween_callback(music_b.stop)

func stop_music() -> void:
	music_name = ""
	music_a.stop()
	music_b.stop()

# pause menu: music a bit quieter
func duck(db: float) -> void:
	duck_db = db
	if music_a.playing:
		music_a.volume_db = linear_to_db(MUSIC_LINEAR) + db
