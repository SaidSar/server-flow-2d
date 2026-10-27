# Server Flow 2D — guía para Claude Code

Proyecto escolar del equipo **NEXUS CODE** (UAdeO, Lic. en Ingeniería de Software, materia Videojuegos 2D, prof. Julio Alberto Camacho Félix).
Integrantes: Jesús Cervantes López, Lucio Adrián Martínez Pérez, Said Eduardo Sarmiento Santillanes (arquitecto del proyecto y dueño del repo), Carlos David Ponce Gamboa.

**Antes de proponer cambios grandes, lee `docs/CONTEXTO.md`**: ahí están las decisiones de diseño, el sistema de arte y lo que está en progreso.

## Reglas de trabajo
- Responde y explica en **español**. Código, nombres de archivos, nodos y clases en **inglés** (snake_case para archivos, PascalCase para `class_name`). Textos del juego en español.
- Godot **4.6** (el equipo usa 4.6.3), GDScript con **tipado estático**, renderer Compatibility. Plataformas: Windows y Android en horizontal.
- Ramas: `main` (solo versiones probadas, por PR), `develop` (integración), `feature/<nombre>` o `fix/<nombre>` saliendo de `develop`. Commits: `feat:`, `fix:`, `art:`, `test:`, `docs:`, `refactor:`, `build:`, `chore:`, `balance:`.
- **No hagas merge** de PRs ni push a `main` sin que el integrante lo pida explícitamente.
- Si `project.godot` aparece modificado solo por abrir el editor, haz commit aparte `chore: normalizar project.godot` antes de cambiar de rama.
- Antes de abrir un PR corre, sin errores ni warnings (salvo el intencional `mesa/no_existe` de las pruebas):
  `godot --headless --path . --import`, `--quit`, `-s res://tests/test_simulation.gd`, `-s res://tests/smoke_test.gd` (y las demás pruebas de `tests/`).
- Los números de balance van en recursos `.tres`, nunca fijos en el código. Rutas en `paths.gd`.
- La simulación (`Simulation`) no conoce la interfaz: solo emite señales.
- Arte: no edites PNGs del cuarto a mano; vienen de los scripts de Blender en `source_art/blender/`. Respeta los offsets de los JSON (múltiplos de 8 px, lienzo a 2x, nodo raíz a escala 0.5).
- Al publicar una versión, sube `version/name` y `version/code` en `export_presets.cfg`.
- No subas keystores, contraseñas ni builds (`build/` está excluido).
