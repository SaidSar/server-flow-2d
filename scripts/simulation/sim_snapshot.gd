class_name SimSnapshot
extends RefCounted
## Lo que pasó en un paso de simulación. La vista lo lee para dibujar; no lo modifica.

var wave_time := 0.0
var wave_duration := 0.0
## Peticiones por segundo legítimas y maliciosas que llegaron (antes del firewall).
var legit_rps := 0.0
var malicious_rps := 0.0
## Tráfico malicioso que bloqueó el firewall (req/s).
var blocked_rps := 0.0
var latency_ms := 0.0
## Utilización más alta entre servidores y BD.
var u_total := 0.0

## Fracciones de las peticiones legítimas de este paso (suman 1).
var green_ratio := 1.0
var yellow_ratio := 0.0
var red_ratio := 0.0

## Recurso cuello de botella (&"" si nada pasa del umbral) y nodo donde está.
var bottleneck: StringName = &""
var bottleneck_node: StringName = &""
