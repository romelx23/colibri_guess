# Colibrí · Cultura general

App Flutter de cultura general con retroalimentación estilo Duolingo: micro-sesiones,
racha diaria, exámenes cronometrados, repaso inteligente y duelos 1 vs 1 en vivo.

- **Front:** Flutter (Riverpod + go_router + flutter_animate + confetti)
- **Backend:** repo hermano `colibri-backend` — API Node/Postgres + WebSocket de duelos

## Funciones

- **Practicar** — arma tu sesión: varias categorías, dificultad, fuente universitaria,
  cantidad de preguntas, modo normal (feedback inmediata) o cronometrado.
- **Quiz** — 233 preguntas locales con explicación de cada opción y análisis por alternativa.
- **Resultados** — confeti, mascota animada, desglose por categoría y repaso de errores.
- **Repaso** — plan de repaso espaciado (SRS) de las preguntas que fallaste.
- **Ranking** — semanal, mensual e histórico desde la API, con tu posición resaltada.
- **Perfil** — XP, rachas, precisión por categoría y sincronización con el servidor.
- **Duelo en vivo** — salas por código de 6 dígitos, resultados en tiempo real.
- **Motion graphics** — transiciones fade+slide entre rutas, mascota con moods
  (contenta, triste, pensando, celebrando) y micro-animaciones.

## Requisitos

- Flutter SDK `^3.11.5`
- Backend corriendo en local (ver README de `colibri-backend`)

## Ejecutar

```bash
flutter pub get

# Emulador Android (la URL por defecto es http://10.0.2.2:4000)
flutter run -d emulator-5554

# Dispositivo físico en la misma red
flutter run --dart-define=API_URL=http://192.168.1.x:4000

# Web / iOS simulator
flutter run -d chrome --dart-define=API_URL=http://127.0.0.1:4000
```

La única configuración es `API_URL` (`lib/core/config/app_config.dart`); no hay
archivos `.env` ni claves en el repositorio.

## Tests

```bash
flutter analyze                                   # 0 issues
flutter test                                      # unit + widget tests
flutter test test/api_live_test.dart --dart-define=API_URL=http://127.0.0.1:4000
```

`api_live_test` habla con el API real; si el servidor no responde, el test se
omite en lugar de fallar.

## Estructura

```
lib/
├── main.dart / app.dart      # arranque y MaterialApp.router
├── core/
│   ├── config/               # AppConfig (API_URL)
│   ├── providers/            # session, progreso, repositorios (Riverpod)
│   ├── router/               # go_router + transiciones fadeSlideRoute
│   ├── theme/                # colores y gradientes de marca
│   └── widgets/              # mascota Colibrí, tarjetas, anillos de progreso
├── data/                     # ApiClient, SessionStore, ProgressStore, QuestionRepository
├── models/                   # Question, Player, ProgressState, QuizConfig
├── logic/                    # XP, repaso espaciado, reglas del quiz
└── features/                 # home, practice, quiz, results, review,
                              # leaderboard, profile, duel
test/                         # tests unitarios, de widget y de integración
assets/questions/*.json       # banco de preguntas (233)
```

## Construir release

```bash
flutter build apk --release --dart-define=API_URL=https://tu-api.com
```
