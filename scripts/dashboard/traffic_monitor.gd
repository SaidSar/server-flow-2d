class_name TrafficMonitor
extends Control
## Monitor de tráfico: Clientes → [Firewall] → [Load Balancer] → Servidores Web → Base de datos.
## Las tarjetas son TrafficNode; las líneas y los paquetes se dibujan en _draw() con un pool fijo.
## Los paquetes son representativos: su cantidad y color salen de las tasas del último tick.
## Un paquete viaja solo por los tramos visibles (del borde de una tarjeta al borde de la siguiente)
## y cruza cada tarjeta al instante, como si el nodo lo procesara.

const TRAFFIC_NODE_SCENE := preload("res://scenes/dashboard/traffic_node.tscn")

const MAX_PACKETS := 150
## Paquetes por segundo: MIN + FACTOR × √(req/s), con tope.
const MIN_PACKETS_PER_SECOND := 4.0
const PACKETS_PER_SQRT_RPS := 4.0
const MAX_PACKETS_PER_SECOND := 36.0
## Segundos que tarda un paquete en cruzar el monitor; la latencia lo hace más lento.
const BASE_TRAVEL_SECONDS := 1.6
const TRAVEL_SECONDS_PER_LATENCY_MS := 1.0 / 400.0
## La animación sigue la velocidad de la simulación hasta este tope.
const MAX_VISUAL_SPEED := 3.0
const PACKET_RADIUS := 6.0
const PACKET_GLOW_RADIUS := 12.0
const LINK_WIDTH := 4.0
## Posición horizontal (fracción del ancho) de cada columna.
const COLUMN_X := {
	&"clients": 0.08,
	&"firewall": 0.255,
	&"lb": 0.43,
	&"servers": 0.65,
	&"db": 0.875,
}
## Con más de MAX_SERVERS_PER_COLUMN servidores se usan dos columnas de tarjetas compactas.
const MAX_SERVERS_PER_COLUMN := 3
const SERVER_COLUMNS_X: Array[float] = [0.59, 0.715]
const SERVER_GAP := 14.0
## Ancho de las tarjetas sin barras (Clientes, Firewall, Load Balancer).
const SMALL_CARD_WIDTH := 230.0
## Margen vertical libre para el aviso de cuello de botella (arriba) y la leyenda (abajo).
const TOP_MARGIN := 70.0
const BOTTOM_MARGIN := 70.0

enum Route {
	## Petición atendida: llega hasta la base de datos.
	TO_DB,
	## Falla o tráfico malicioso: se queda en el servidor.
	TO_SERVER,
	## Tráfico malicioso que el firewall descarta.
	BLOCKED,
}

var _clients: TrafficNode
var _firewall: TrafficNode
var _load_balancer: TrafficNode
var _db: TrafficNode
var _servers: Array[TrafficNode] = []

# Pool de paquetes (arreglos paralelos; se elimina cambiando por el último).
var _packet_count := 0
var _packet_route := PackedInt32Array()
var _packet_server := PackedInt32Array()
var _packet_distance := PackedFloat32Array()
var _packet_color := PackedColorArray()
## Ruta (route * 100 + servidor) → tramos visibles como pares de puntos [inicio0, fin0, inicio1, fin1...].
## Se recalcula al cambiar el layout.
var _route_cache: Dictionary[int, PackedVector2Array] = {}
var _route_lengths: Dictionary[int, float] = {}
var _spawn_accumulator := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	UiTheme.changed.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_packet_route.resize(MAX_PACKETS)
	_packet_server.resize(MAX_PACKETS)
	_packet_distance.resize(MAX_PACKETS)
	_packet_color.resize(MAX_PACKETS)
	_rng.randomize()

	_clients = _add_node("Clientes", SMALL_CARD_WIDTH)
	_firewall = _add_node("Firewall", SMALL_CARD_WIDTH)
	_load_balancer = _add_node("Load Balancer", SMALL_CARD_WIDTH)
	_db = _add_node("Base de datos")
	_db.add_metric(&"db", "Consultas")
	_db.add_metric(&"disk", "Disco")
	_db.add_metric(&"cache", "Caché", true)

	resized.connect(_layout)
	Simulation.infrastructure_changed.connect(rebuild)
	Simulation.tick.connect(_on_tick)
	# Al cambiar de fase (fin de oleada, nueva etapa) no hay tick: se refresca aquí.
	Simulation.phase_changed.connect(_on_phase_changed)
	Simulation.bottleneck_changed.connect(_on_bottleneck_changed)
	rebuild()


func _process(delta: float) -> void:
	var visual_delta := delta * minf(Simulation.get_effective_speed(), MAX_VISUAL_SPEED)
	if Simulation.phase == Simulation.Phase.RUNNING and not Simulation.paused:
		_spawn_accumulator += visual_delta * _get_spawn_rate()
		while _spawn_accumulator >= 1.0:
			_spawn_accumulator -= 1.0
			_spawn_packet()
	else:
		visual_delta *= 2.0 # Sin oleada, los paquetes que quedan se van rápido.

	var speed := _get_packet_speed()
	var i := _packet_count - 1
	while i >= 0:
		_packet_distance[i] += speed * visual_delta
		if _packet_distance[i] >= _route_length(_packet_route[i], _packet_server[i]):
			_remove_packet(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for points: PackedVector2Array in _get_link_polylines():
		draw_polyline(points, DashboardColors.LINK, LINK_WIDTH, true)
	for i in _packet_count:
		var position_on_route := _point_on_route(_packet_route[i], _packet_server[i], _packet_distance[i])
		draw_circle(position_on_route, PACKET_GLOW_RADIUS, Color(_packet_color[i], 0.25))
		draw_circle(position_on_route, PACKET_RADIUS, _packet_color[i])


## Vuelve a armar las tarjetas según la infraestructura (servidores, LB y firewall).
func rebuild() -> void:
	var server_count := Simulation.servers.size()
	while _servers.size() < server_count:
		var server_node := _add_node("Servidor Web #%d" % (_servers.size() + 1))
		server_node.add_metric(&"cpu", "CPU")
		server_node.add_metric(&"ram", "RAM")
		server_node.add_metric(&"net", "Red")
		_servers.append(server_node)
	while _servers.size() > server_count:
		_servers.pop_back().queue_free()
	_firewall.visible = Simulation.has_firewall
	_load_balancer.visible = Simulation.has_load_balancer()
	_packet_count = 0
	_refresh_cards()
	_layout.call_deferred()


func get_server_count() -> int:
	return _servers.size()


func get_packet_count() -> int:
	return _packet_count


## Paquetes en pantalla de un color (p. ej. DashboardColors.MALICIOUS, los morados del DDoS).
func get_packet_count_by_color(color: Color) -> int:
	var count := 0
	for i in _packet_count:
		if _packet_color[i] == color:
			count += 1
	return count


func _add_node(title: String, width: float = 0.0) -> TrafficNode:
	var node := TRAFFIC_NODE_SCENE.instantiate() as TrafficNode
	if width > 0.0:
		node.custom_minimum_size.x = width
	add_child(node)
	node.setup(title)
	return node


func _layout() -> void:
	var usable_top := TOP_MARGIN
	var usable_height := maxf(size.y - TOP_MARGIN - BOTTOM_MARGIN, 100.0)
	var center_y := usable_top + usable_height * 0.5
	for column: StringName in [&"clients", &"firewall", &"lb", &"db"]:
		var node: TrafficNode = {&"clients": _clients, &"firewall": _firewall, &"lb": _load_balancer, &"db": _db}[column]
		node.scale = Vector2.ONE
		node.reset_size()
		node.position = Vector2(size.x * COLUMN_X[column], center_y) - node.size * 0.5

	if not _servers.is_empty():
		_layout_servers(center_y, usable_height)
	_route_cache.clear()
	_route_lengths.clear()


## Una columna con hasta 3 servidores; con más, dos columnas de tarjetas compactas.
func _layout_servers(center_y: float, usable_height: float) -> void:
	var two_columns := _servers.size() > MAX_SERVERS_PER_COLUMN
	var columns: Array[float] = [COLUMN_X[&"servers"]]
	if two_columns:
		columns = SERVER_COLUMNS_X
	var rows := ceili(float(_servers.size()) / columns.size())
	for server_node: TrafficNode in _servers:
		server_node.set_compact(two_columns)
		server_node.scale = Vector2.ONE
		server_node.reset_size()
	var card_size := _servers[0].get_combined_minimum_size()
	var total_height := card_size.y * rows + SERVER_GAP * (rows - 1)
	var card_scale := minf(1.0, usable_height / total_height)
	if two_columns:
		var column_width := size.x * (SERVER_COLUMNS_X[1] - SERVER_COLUMNS_X[0]) - SERVER_GAP
		card_scale = minf(card_scale, column_width / card_size.x)
	var top := center_y - total_height * card_scale * 0.5
	for i in _servers.size():
		var server_node := _servers[i]
		var column := i % columns.size()
		var row := floori(float(i) / columns.size())
		server_node.scale = Vector2(card_scale, card_scale)
		server_node.position = Vector2(
			size.x * columns[column] - card_size.x * card_scale * 0.5,
			top + row * (card_size.y + SERVER_GAP) * card_scale)


func _on_tick(_snapshot: SimSnapshot) -> void:
	_refresh_cards()


func _on_phase_changed(_phase: Simulation.Phase) -> void:
	_refresh_cards()


func _refresh_cards() -> void:
	var snapshot := Simulation.last_snapshot
	var display_scale := Simulation.config.display_scale
	var subtitle := "%s req/s" % NumberFormat.traffic(snapshot.legit_rps, display_scale)
	if snapshot.malicious_rps > 0.0:
		subtitle += " · %s maliciosas" % NumberFormat.traffic(snapshot.malicious_rps, display_scale)
	_clients.set_subtitle(subtitle)
	if Simulation.has_firewall:
		if Simulation.firewall_on:
			_firewall.set_subtitle("Bloqueando %s req/s" % NumberFormat.traffic(snapshot.blocked_rps, display_scale))
		else:
			_firewall.set_subtitle("Apagado")
	_load_balancer.set_subtitle("Round-robin · %d servidores" % _servers.size())
	for i in _servers.size():
		var state := Simulation.servers[i]
		_servers[i].set_subtitle("%s req/s" % NumberFormat.traffic(state.load_rps, display_scale))
		_servers[i].set_metric(&"cpu", state.u_cpu)
		_servers[i].set_metric(&"ram", state.u_ram)
		_servers[i].set_metric(&"net", state.u_net)
	_db.set_subtitle("%.1f / %.0f GB" % [Simulation.db.disk_gb_used, Simulation.db.disk_gb_cap])
	_db.set_metric(&"db", Simulation.db.u_db)
	_db.set_metric(&"disk", Simulation.db.get_disk_fill())
	_db.set_metric(&"cache", Simulation.db.cache_hit)


func _on_bottleneck_changed(_resource: StringName, node: StringName) -> void:
	for server_node: TrafficNode in _servers:
		server_node.set_alert(node == Simulation.NODE_WEB)
	_db.set_alert(node == Simulation.NODE_DB)


#region Paquetes

func _get_spawn_rate() -> float:
	var snapshot := Simulation.last_snapshot
	var total_rps := snapshot.legit_rps + snapshot.malicious_rps
	return minf(MIN_PACKETS_PER_SECOND + PACKETS_PER_SQRT_RPS * sqrt(total_rps), MAX_PACKETS_PER_SECOND)


func _get_packet_speed() -> float:
	var travel_seconds := BASE_TRAVEL_SECONDS + Simulation.last_snapshot.latency_ms * TRAVEL_SECONDS_PER_LATENCY_MS
	return _route_length(Route.TO_DB, 0) / travel_seconds if not _servers.is_empty() else 0.0


func _spawn_packet() -> void:
	if _packet_count >= MAX_PACKETS or _servers.is_empty():
		return
	var snapshot := Simulation.last_snapshot
	var total_rps := snapshot.legit_rps + snapshot.malicious_rps
	if total_rps <= 0.0:
		return
	var route := Route.TO_DB
	var color := DashboardColors.OK
	if _rng.randf() < snapshot.malicious_rps / total_rps:
		color = DashboardColors.MALICIOUS
		route = Route.TO_SERVER
		if snapshot.malicious_rps > 0.0 and _rng.randf() < snapshot.blocked_rps / snapshot.malicious_rps:
			route = Route.BLOCKED
	else:
		var roll := _rng.randf()
		if roll >= snapshot.green_ratio + snapshot.yellow_ratio:
			color = DashboardColors.DANGER
			route = Route.TO_SERVER
		elif roll >= snapshot.green_ratio:
			color = DashboardColors.WARNING
	var active_servers := _servers.size() if Simulation.has_load_balancer() else 1
	var i := _packet_count
	_packet_route[i] = route
	_packet_server[i] = _rng.randi_range(0, active_servers - 1)
	_packet_distance[i] = 0.0
	_packet_color[i] = color
	_packet_count += 1


func _remove_packet(index: int) -> void:
	var last := _packet_count - 1
	_packet_route[index] = _packet_route[last]
	_packet_server[index] = _packet_server[last]
	_packet_distance[index] = _packet_distance[last]
	_packet_color[index] = _packet_color[last]
	_packet_count = last


## Tarjetas por las que pasa una ruta, en orden.
func _get_route_nodes(route: int, server_index: int) -> Array[TrafficNode]:
	var nodes: Array[TrafficNode] = [_clients]
	if _firewall.visible:
		nodes.append(_firewall)
	if route != Route.BLOCKED:
		if _load_balancer.visible:
			nodes.append(_load_balancer)
		nodes.append(_servers[mini(server_index, _servers.size() - 1)])
		if route == Route.TO_DB:
			nodes.append(_db)
	return nodes


## Tramos visibles de la ruta: del borde de cada tarjeta al borde de la siguiente.
func _get_route(route: int, server_index: int) -> PackedVector2Array:
	var key := route * 100 + server_index
	if not _route_cache.has(key):
		var nodes := _get_route_nodes(route, server_index)
		var segments := PackedVector2Array()
		var length := 0.0
		for i in range(1, nodes.size()):
			var start := nodes[i - 1].get_edge_toward(nodes[i].get_center())
			var end := nodes[i].get_edge_toward(nodes[i - 1].get_center())
			segments.append(start)
			segments.append(end)
			length += start.distance_to(end)
		_route_cache[key] = segments
		_route_lengths[key] = length
	return _route_cache[key]


func _route_length(route: int, server_index: int) -> float:
	_get_route(route, server_index)
	return _route_lengths[route * 100 + server_index]


func _point_on_route(route: int, server_index: int, distance: float) -> Vector2:
	var segments := _get_route(route, server_index)
	var remaining := distance
	for i in range(0, segments.size(), 2):
		var segment := segments[i].distance_to(segments[i + 1])
		if remaining <= segment:
			return segments[i].lerp(segments[i + 1], remaining / segment if segment > 0.0 else 1.0)
		remaining -= segment
	return segments[segments.size() - 1]


## Líneas de conexión: de centro a centro (quedan debajo de las tarjetas), una por servidor.
func _get_link_polylines() -> Array[PackedVector2Array]:
	var polylines: Array[PackedVector2Array] = []
	for i in _servers.size():
		var points := PackedVector2Array()
		for node: TrafficNode in _get_route_nodes(Route.TO_DB, i):
			points.append(node.get_center())
		polylines.append(points)
	return polylines

#endregion
