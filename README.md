# Atlantis 🐴🌊

Mi primer juego: un caballito de mar que explora el fondo del mar buscando 30 diamantes antes de que se acabe el tiempo.

## Versiones

| Carpeta | Motor | Para qué |
|---|---|---|
| `/` (raíz) | Phaser 2 (JS) | Versión web original, mejorada. Abre `index.html` con un servidor local. |
| `godot/` | Godot 4.7 | Versión actual: escritorio, web y **Android (APK)**. |

## Godot

1. Abre Godot 4.7 → **Importar** → elige `godot/project.godot`.
2. Dale **F5** para jugar.

## APK para Android

Cada push a `master` que toque `godot/` compila el APK en GitHub Actions:
**Actions → "Build APK Android (Godot)" → Artifacts → `Atlantis-apk`**.
También se puede lanzar a mano con **Run workflow**.

Es un APK de debug: se instala directo en el celular (activando "instalar apps de origen desconocido").
Para Play Store hay que firmarlo con una keystore de release.

## Cómo se juega

- Toca la pantalla para empezar.
- **PC:** el caballito nada hacia donde apuntes con el mouse. **Celular:** mantén el dedo hacia donde quieres ir.
- El mapa es grande y cambia en cada partida. El minimapa (abajo a la derecha) te muestra dónde estás y,
  como un radar, los diamantes que tienes cerca.
- 100 puntos por diamante + 50 por cada segundo que te sobre si los recoges todos.
- Tu récord queda guardado.
