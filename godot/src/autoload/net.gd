extends Node
# Net: the WebSocket to the relay (server.js), the message envelope and the reliable event channel (docs/PROTOCOL.md).
# Every game message: {"t", "e" epoch, "n" seq, "ra" last reliable id received, ...fields, "r": [events], "u": 1 (last key)}.
# Reliable events {"i": id, "k": kind, "d": {...}}: all data lives inside "d", never next to i / k. Applied once, in order.

signal opened                                  # the socket is open (relay control messages follow)
signal code_received(code: String)
signal peer_changed(on: bool, lag: bool, resume: bool)    # host side: the friend came, left, lags or came back
signal host_changed(on: bool, lag: bool, resume: bool)    # guest side
signal message(t: String, msg: Dictionary)     # an unreliable game message (st, s, start ...)
signal reliable(k: String, d: Dictionary)      # a reliable event, applied in order
signal line_lost                               # the socket closed or went silent
signal fatal(reason: String)                   # a close code that must not be retried (wrong code ...)

const RESEND := 0.22
const SILENT := 6.0
const BACKOFF_MAX := 15.0

var role := "none"                  # none | host | guest
var base_url := ""
var code := ""
var token := ""
var ws: WebSocketPeer = null
var is_open := false
var gave_up := false
var epoch := 0
var seq := 0
var rel_next := 1
var rel_out: Array = []             # unacknowledged events {i, k, d, sent}
var rel_in := 0                     # highest reliable id applied
var ack_due := -1.0
var last_rx := 0.0
var last_tx := 0.0
var retry_at := -1.0
var retry_n := 0
var closing := false
var rtt := 0.05
var jitter := 0.0
var stats := {"tx": 0, "rx": 0, "tx_bytes": 0, "rx_bytes": 0}

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func is_active() -> bool:
	return role != "none"

func _base() -> String:
	if OS.has_feature("web"):
		var host_ := str(JavaScriptBridge.eval("location.host"))
		var proto := "wss://" if str(JavaScriptBridge.eval("location.protocol")) == "https:" else "ws://"
		return proto + host_
	return "ws://127.0.0.1:%d" % Game.net_port

# connect as host (the relay only allows this from the PC itself) or as guest with the 6-digit code
func connect_as(r: String, c := "") -> void:
	role = r
	code = c
	token = ""
	gave_up = false
	closing = false
	retry_at = -1.0
	retry_n = 0
	base_url = _base()
	reset_reliable()
	seq = 0
	_open_socket(false)

# a new partner session starts the numbering over on both sides (a stale rel_in would swallow its events as duplicates)
func reset_reliable() -> void:
	rel_next = 1
	rel_out.clear()
	rel_in = 0
	ack_due = -1.0

func _open_socket(resume: bool) -> void:
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20
	var q := "/ws?role=" + role
	if role == "guest":
		q += "&code=" + code
		if token != "":
			q += "&token=" + token
	elif resume:
		q += "&resume=1"
	var err := ws.connect_to_url(base_url + q)
	if err != OK:
		push_warning("Net: connect failed (%d)" % err)
		_lost()
	is_open = false
	last_rx = now()

func leave() -> void:
	closing = true
	if ws != null:
		ws.close(4010, "leave")
		ws.poll()                         # (native: the close frame is only sent by poll(); the web build sends it at once)
	is_open = false
	role = "none"

func _process(_dt: float) -> void:
	if role == "none":
		return
	var t := now()
	if retry_at >= 0.0 and t >= retry_at:
		retry_at = -1.0
		_open_socket(role == "host")
	if ws == null:
		return
	ws.poll()
	match ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not is_open:
				is_open = true
				retry_n = 0
				opened.emit()
			while ws.get_available_packet_count() > 0:
				var pkt := ws.get_packet()
				last_rx = t
				stats.rx += 1
				stats.rx_bytes += pkt.size()
				_on_text(pkt.get_string_from_utf8())
			if role == "guest" and t - last_rx > SILENT:
				_force_close()
			_flush(t)
		WebSocketPeer.STATE_CLOSED:
			var c := ws.get_close_code()
			ws = null
			is_open = false
			if closing:
				return
			if c == 4001 or c == 4004 or c == 4002 or c == 4005:
				gave_up = true
				fatal.emit("close %d" % c)
				return
			_lost()

func _force_close() -> void:
	if ws != null:
		ws.close(4000, "silent")
	_lost()
	ws = null

func _lost() -> void:
	if closing or gave_up:
		return
	is_open = false
	line_lost.emit()
	retry_n += 1
	retry_at = now() + minf(0.5 * pow(2.0, retry_n - 1), BACKOFF_MAX)

# ---------------------------------------------------------------- receiving
func _on_text(text: String) -> void:
	var m = JSON.parse_string(text)
	if typeof(m) != TYPE_DICTIONARY:
		return
	var t: String = m.get("t", "")
	match t:
		"code":
			code = String(m.v)
			code_received.emit(code)
			return
		"tok":
			token = String(m.v)
			return
		"peer":
			peer_changed.emit(bool(m.get("on", false)), bool(m.get("lag", false)), bool(m.get("resume", false)))
			return
		"host":
			host_changed.emit(bool(m.get("on", false)), bool(m.get("lag", false)), bool(m.get("resume", false)))
			return
		"hb":
			return
	# a game message: acknowledgements, events, then the message itself
	if m.has("ra"):
		var ra := int(m.ra)
		while not rel_out.is_empty() and int(rel_out[0].i) <= ra:
			rel_out.pop_front()
	if m.has("r"):
		var evs: Array = m.r
		evs.sort_custom(func(a, b): return int(a.i) < int(b.i))
		for ev in evs:
			var i := int(ev.i)
			if i == rel_in + 1:
				rel_in = i
				ack_due = now() + 0.25
				reliable.emit(String(ev.k), ev.get("d", {}))
			elif i <= rel_in:
				ack_due = now() + 0.05            # a duplicate: tell the sender again
	if t != "ack":
		message.emit(t, m)

# ---------------------------------------------------------------- sending
func _raw(d: Dictionary) -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var text := JSON.stringify(d, "", false)      # sort_keys false: "u" must stay the last key
	ws.send_text(text)
	last_tx = now()
	stats.tx += 1
	stats.tx_bytes += text.length()

# events that were never sent, or are older than RESEND, ride along
func _pending_events(t: float) -> Array:
	var out: Array = []
	if rel_out.is_empty():
		return out
	var due: bool = rel_out[0].sent < 0.0 or t - float(rel_out[0].sent) > RESEND
	for e in rel_out:
		if due or e.sent < 0.0:
			out.append({"i": e.i, "k": e.k, "d": e.d})
			e.sent = t                      # (only what went out: a new event must not postpone the retransmit of an older one)
	return out

func send_msg(msg_type: String, fields := {}, droppable := false) -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if droppable and ws.get_current_outbound_buffered_amount() > 4096:
		return
	seq += 1
	var d := {"t": msg_type, "e": epoch, "n": seq, "ra": rel_in}
	for k in fields:
		d[k] = fields[k]
	var ev := _pending_events(now())
	if not ev.is_empty():
		d["r"] = ev
	if droppable and ev.is_empty():
		d["u"] = 1
	_raw(d)
	ack_due = -1.0

func rel(kind: String, data := {}) -> void:
	rel_out.append({"i": rel_next, "k": kind, "d": data, "sent": -1.0, "t0": now()})
	rel_next += 1

func _flush(t: float) -> void:
	var need := false
	if not rel_out.is_empty():
		need = rel_out[0].sent < 0.0 or t - float(rel_out[0].sent) > RESEND
	if need or (ack_due >= 0.0 and t >= ack_due):
		send_msg("ack")
