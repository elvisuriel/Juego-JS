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

- **Menú:** Jugar, Tienda, Récords y Ajustes (música, sonidos, vibración y controles).
- **Controles:** en PC el caballito nada hacia el mouse. En el celular, mantén el dedo hacia donde quieres ir,
  o activa el **joystick** en Ajustes.
- **Niveles:** recoge todos los diamantes antes de que se acabe el tiempo para pasar al siguiente.
  Cada nivel trae un mapa más grande y más enemigos. Las vidas y los puntos pasan de un nivel al otro.
- **Vidas:** empiezas con 3 corazones (máximo 5). Cada mordisco quita uno; con 0 se acaba la partida.
- **Enemigos:**
  - Tiburón normal: te persigue si te acercas.
  - Tiburón grande (desde el nivel 2): más lento, pero muerde de más lejos.
  - Tiburón rápido (desde el nivel 3): se detiene a apuntar y embiste en línea recta.
  - Pulpo (desde el nivel 2): te lanza tinta que tapa la pantalla.
- **Escondites:** dentro de los bosques de algas los tiburones no te ven.
- **Power-ups (burbujas):** turbo, escudo (aguanta un mordisco), corazón (+1 vida) y reloj (+10 s).
- **Minimapa:** muestra los escondites y, como radar, los diamantes (amarillo), tiburones (rojo) y pulpos (morado) cercanos.
- **Tienda:** cada diamante atrapado suma para comprar colores del caballito.
- **Récords:** los 5 mejores puntajes con tu nombre.
- **Pausa:** botón arriba a la derecha; también se pausa sola si sales de la app o entra una llamada.
