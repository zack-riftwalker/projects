extends Node
# Audio: sound effects (a pool of players, the same minimum gap per name as the JS game) and looping music with a crossfade.

const SFX := ["jump", "djump", "walljump", "land", "swipe", "swipeBig", "hit", "clang", "squish", "kill", "hurt", "die", "token", "spark", "heal", "dash", "spring", "crumble", "brk", "checkpoint", "shoot", "bossHit", "explode", "bigExplode", "uiMove", "uiOk", "uiBack", "text", "textLow", "textSys", "key", "gate", "agent", "agentHit", "warn", "charge", "laser", "drip", "splash", "thud", "roar", "glitch", "tick", "tock", "pause", "flap", "logo", "stamp", "modem", "kbd", "hdd", "degauss", "chirp", "fw_ding", "fw_ok200", "fw_deny", "fw_tock", "fw_hiss", "fw_whoosh", "fw_tapestop", "rc_bell1", "rc_bell2", "rc_bell3", "rc_crash", "rc_rattle", "rc_fall", "rc_chain", "rc_whirr", "rc_thunk", "rc_shot", "rc_creak", "rc_eye", "rc_key", "rc_lock", "rc_anchor", "rc_pin"]
const VOICE := ["crawler_intro", "crawler_p2", "crawler_p3", "crawler_die", "firewall_refused", "firewall_sorry", "firewall_intro", "firewall_reveal", "firewall_p3", "firewall_plead", "firewall_die", "firewall_fine", "race_intro", "race_p2", "race_alone", "race_alone_tock", "race_die"]
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
var music_index := {}                # assets/music/index.json, read on the first song
var amb: AudioStreamPlayer           # the ambience channel: a terminal's fan (MVB1-14); its own volume, it follows the music setting
var amb_vol := 0.0                   # 0..1, smoothed
var calm_db := 0.0                   # the music is quieter near a terminal's bench (smoothed)
var music_tw: Tween = null          # the running crossfade: a new music change ends it (its stop callback must not hit the new song)

func _ready() -> void:
	for n in SFX:
		var s = load("res://assets/sfx/%s.wav" % n)
		if s != null:
			streams[n] = s
	for n in VOICE:                                  # spoken lines play like sounds (and reach the guest the same way)
		if ResourceLoader.exists("res://assets/voice/%s.ogg" % n):
			var v = load("res://assets/voice/%s.ogg" % n)
			if v is AudioStreamOggVorbis:
				v.loop = false
			streams[n] = v
	for i in range(12):
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	add_child(music_a)
	add_child(music_b)
	amb = AudioStreamPlayer.new()
	add_child(amb)
	if ResourceLoader.exists("res://assets/audio/amb_fan.wav"):
		var fan = load("res://assets/audio/amb_fan.wav")
		if fan is AudioStreamWAV:
			fan.loop_mode = AudioStreamWAV.LOOP_FORWARD
			fan.loop_begin = 0
			fan.loop_end = fan.data.size() / (2 if fan.format == AudioStreamWAV.FORMAT_16_BITS else 1)
		amb.stream = fan

var room_ctx = null                 # the room being simulated right now (RoomManager.tick sets it)
var listen_room = null              # the local player's room: only its sounds play here
var other_room_skipped := 0         # (counted for the tests)

func sfx(sfx_name: String, opts := {}) -> void:
	if room_ctx != null:
		room_ctx.rec_sound(sfx_name, opts)          # (the guest in that room hears it too)
		if listen_room != null and room_ctx != listen_room:
			other_room_skipped += 1
			return                    # a sound of the partner's room, simulated on this PC: not for this player's ears
	if Game.mute or Game.vol_sfx <= 0 or not streams.has(sfx_name):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(sfx_name, -1000)) < MIN_GAP_MS:
		return
	last_play[sfx_name] = now
	for p in pool:
		if not p.playing:
			p.stream = streams[sfx_name]
			p.volume_db = linear_to_db(maxf(0.001, float(opts.get("vol", 1.0)) * Game.vol_sfx / 10.0)) + duck_db
			p.play()
			if first_sfx_msec < 0:
				first_sfx_msec = now
			return

# A sound only this page hears (the cartographer's typing, a jar's beep): it is not recorded for the partner, who has its own copy of the room.
func local_sfx(sfx_name: String, vol: float) -> void:
	if Game.mute or Game.vol_sfx <= 0 or not streams.has(sfx_name) or vol <= 0.02:
		return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(sfx_name, -1000)) < MIN_GAP_MS:
		return
	last_play[sfx_name] = now
	for p in pool:
		if not p.playing:
			p.stream = streams[sfx_name]
			p.volume_db = linear_to_db(maxf(0.001, vol * Game.vol_sfx / 10.0)) + duck_db
			p.play()
			return

func music(music_key: String) -> void:
	if Game.mute or music_key == music_name:
		return
	music_name = music_key
	var path := "res://assets/music/%s.ogg" % music_key
	if not ResourceLoader.exists(path):
		return
	var st: AudioStreamOggVorbis = load(path)
	if music_index.is_empty():
		music_index = JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/index.json"))
	var info: Dictionary = music_index.get(music_key, {})
	st.loop = not info.get("once", false)
	st.loop_offset = float(info.get("loop_start", 0.0))
	# crossfade 0.5 s: a fades out, b fades in
	var old := music_a
	music_a = music_b
	music_b = old
	music_a.stream = st
	music_a.volume_db = -60.0
	music_a.play()
	_end_fade()
	var tw := create_tween().set_parallel(true)
	music_tw = tw
	tw.tween_property(music_a, "volume_db", _music_db(), 0.5)
	if music_b.playing:
		tw.tween_property(music_b, "volume_db", -60.0, 0.5)
		tw.chain().tween_callback(music_b.stop)

# one fade at a time: a fade-out that kept running after a new song started faded the new song to silence (the boss music,
# which starts less than a second after entering the arena, whose room has no song of its own)
func _end_fade() -> void:
	if music_tw != null and music_tw.is_valid():
		music_tw.kill()
	music_tw = null

func stop_music(fade := 0.0) -> void:
	music_name = ""
	_end_fade()
	if fade <= 0.0:
		music_a.stop()
		music_b.stop()
		return
	var tw := create_tween().set_parallel(true)
	music_tw = tw
	for pl in [music_a, music_b]:
		if pl.playing:
			tw.tween_property(pl, "volume_db", -60.0, fade)
	tw.chain().tween_callback(func():
		if music_name == "":
			music_a.stop()
			music_b.stop())

# pause menu: music a bit quieter
func duck(db: float) -> void:
	duck_db = db
	if music_a.playing:
		music_a.volume_db = _music_db()

func _music_db() -> float:
	return linear_to_db(maxf(0.0005, MUSIC_LINEAR * Game.vol_music / 10.0)) + duck_db + calm_db

# ---- terminals (MVB1-14): a fan that fades in as you come near, and calmer music. Sound is only extra: nothing depends on hearing it.
const FAN_FULL := 6.0                # tiles: full volume within this distance of a terminal's bench
const FAN_FAR := 20.0                # tiles: silent from here
const CALM_R := 8.0                  # tiles: the music is 6 dB quieter within this distance
const CALM_DB := -6.0

static func fan_volume(is_terminal: bool, dist_tiles: float) -> float:
	if not is_terminal:
		return 0.0
	return clampf((FAN_FAR - dist_tiles) / (FAN_FAR - FAN_FULL), 0.0, 1.0)

static func calm_target(is_terminal: bool, dist_tiles: float) -> float:
	return CALM_DB if is_terminal and dist_tiles < CALM_R else 0.0

# every step the local player's room runs (RoomManager.tick)
func update_terminal(room, player, dt: float) -> void:
	var term := false
	var dist := 1e9
	if room != null and player != null and bool(room.def.get("terminal", false)):
		term = true
		for c in room.cps:
			dist = minf(dist, Vector2(player.x + 5.0 - float(c.x), player.y + 5.0 - float(c.y)).length() / 16.0)
	amb_vol = move_toward(amb_vol, fan_volume(term, dist), dt * 1.0)
	var want_calm := calm_target(term, dist)
	if calm_db != want_calm:
		calm_db = move_toward(calm_db, want_calm, dt * 12.0)
		if music_a.playing and (music_tw == null or not music_tw.is_valid()):
			music_a.volume_db = _music_db()
	if amb.stream == null or Game.mute:
		return
	if amb_vol > 0.01:
		amb.volume_db = linear_to_db(maxf(0.0005, 0.45 * amb_vol * Game.vol_music / 10.0))
		if not amb.playing:
			amb.play()
	elif amb.playing:
		amb.stop()

# settings: the volume slider changed
func refresh_music_volume() -> void:
	if music_a.playing:
		music_a.volume_db = _music_db()
