# Tu Torneo Flash — Especificación para desarrollo

> Documento de arranque para Claude Code. Léelo completo antes de escribir código.
> Idioma de la app: **español (es-MX)**. Código, nombres de archivos y commits: **inglés**.

---

## 1. Visión del producto

App móvil (Android + iOS) para **organizar torneos deportivos locales amateurs**: crear el torneo, dar de alta equipos y jugadores (manual o con Excel), generar el calendario, capturar resultados y estadísticas, y mostrar tablas generales y líderes individuales.

La app tiene **dos caras**:

1. **Organizador** (requiere cuenta): crea y administra torneos.
2. **Espectador** (sin cuenta): descarga la app, busca un torneo (código, QR, nombre o cercanía) y consulta tablas, resultados, calendario y estadísticas.

Deportes en el MVP: **Fútbol** (incluye variantes fútbol 7 / rápido) y **Básquetbol**. La arquitectura debe permitir agregar más deportes (voleibol, béisbol) sin reescribir la lógica.

### 1.1 Concepto clave: Organizador → Torneos → Competencias

```
Organizador (cuenta)
 ├── Torneo: "Liga Petrolera de Básquetbol — Apertura 2026"   (categoría: Libre)
 │    ├── Equipos y jugadores del torneo (16 equipos)
 │    └── Competencias
 │         ├── Temporada regular      (tipo: Liga)
 │         ├── Playoffs               (tipo: Eliminación directa · lugares 1–8 de la regular)
 │         └── Copa Redención         (tipo: Eliminación directa · lugares 9–16 de la regular)
 ├── Torneo: "Veteranos +40 — 2026"                             (categoría: Veteranos +40)
 │    ├── Equipos y jugadores propios
 │    └── Competencias: Temporada regular, Liguilla
 └── Torneo: "Torneo Estatal Tabasco"                           (categoría: Estatal)
      ├── Equipos y jugadores propios
      └── Competencias: Fase de grupos + eliminatoria
```

- **Organizador:** puede tener **muchos torneos**, uno por categoría, rama, temporada, etc. (Libre, Veteranos +40, Femenil, Juvenil, Estatal…).
- **Torneo:** es la unidad que se comparte con el público, con **un código, un QR y un link**. **Es dueño de sus equipos y jugadores**, porque cada categoría tiene planteles distintos.
- **Competencia** (en la UI se llama así, o "apartado"): cada torneo tiene una o varias. Cada competencia es de **un solo tipo** (Liga, Cuadrangular, Eliminación directa, Grupos + eliminatoria), tiene un **nombre libre**, su propio calendario, tabla o bracket, estadísticas y **su propio campeón**.
  - La primera suele ser la "Temporada regular".
  - Las siguientes (Playoffs, Liguilla, Copa Redención, Cuadrangular final…) **toman equipos del mismo torneo**: por rango de posiciones de otra competencia o elegidos a mano.
  - Se pueden jugar **en paralelo**.
- **Atajo:** al crear un torneo nuevo se pueden **importar equipos y jugadores de otro torneo del mismo organizador**. Se copian, y a partir de ahí son independientes.

### 1.2 Caso piloto

La primera versión se probará **gratis** con la **Liga de la Industria Petrolera de Básquetbol** (Tabasco), con 16 equipos. Tiene temporada regular y, al terminar, **Playoffs** (1º–8º) y **Copa Redención** (9º–16º) en paralelo. Es la prueba de aceptación del MVP (§11). Aun así, **nada en el código debe asumir esos nombres**: son competencias genéricas con nombre libre.

---

## 2. Stack técnico

| Capa | Tecnología | Motivo |
|---|---|---|
| App | **Flutter 3.x (Dart 3, null safety)** | Un solo código para Android/iOS |
| Estado | **Riverpod** (`flutter_riverpod` + `riverpod_annotation`) | Testeable, sin contexto |
| Navegación | **go_router** | Deep links (`/t/:code`) |
| Modelos | **freezed** + **json_serializable** | Inmutables, `copyWith`, JSON |
| Backend | **Supabase** (PostgreSQL + Auth + Storage + Realtime + Edge Functions) | Rápido de levantar, SQL real, seguridad con RLS, tiempo real para marcadores en vivo |
| Excel | paquete `excel` + `file_picker` | Importar/exportar plantillas `.xlsx` en el dispositivo |
| Compartir | `share_plus`, `qr_flutter`, `mobile_scanner` | Compartir torneo por link/QR |
| Imágenes | `image_picker`, `cached_network_image` | Escudos y fotos |
| Notificaciones (fase 2) | Firebase Cloud Messaging | Avisos de resultados |
| i18n | `flutter_localizations` + `intl` (ARB) | Textos en español, listo para inglés |

> Alternativa de backend si se prefiere control total: API en **Laravel** + PostgreSQL. No usar en el MVP salvo que se pida; diseñar la capa de datos con repositorios para que el cambio sea posible.

---

## 3. Arquitectura

**Feature-first + capas limpias ligeras.**

```
lib/
  main.dart
  app/
    router.dart            # go_router, rutas y deep links
    theme.dart             # Material 3, modo claro/oscuro
    env.dart               # SUPABASE_URL / ANON_KEY vía --dart-define
  core/
    sports/                # Lógica por deporte (§5)
      sport.dart           # enum Sport + interfaz SportRules
      football_rules.dart
      basketball_rules.dart
    competition_types/     # Lógica por tipo de competencia (§6)
    fixtures/              # Round-robin y brackets
    standings/             # Tablas y desempates
    utils/ widgets/ errors/
  data/
    supabase_client.dart
    repositories/          # TournamentRepository, CompetitionRepository, TeamRepository, ...
    dto/
  features/
    auth/
    my_tournaments/        # Lista de torneos del organizador
    tournament_wizard/     # Crear torneo + equipos + primera competencia
    tournament_admin/      # Panel del torneo
    teams/
    players/               # incl. importación Excel
    competitions/          # Crear/gestionar competencias (regular, playoffs, ...)
    matches/               # Captura de resultados y estadísticas
    standings/
    bracket/
    stats/
    public_search/         # Cara espectador
    public_tournament/
supabase/
  migrations/              # SQL versionado
  seed.sql                 # datos del caso piloto (§11)
  functions/
test/
  core/                    # Pruebas unitarias de reglas, calendario, tablas y brackets
```

Reglas:
- La lógica de negocio (tablas, desempates, calendario, brackets, validación de Excel) vive en `core/` como **Dart puro**, sin Flutter ni Supabase, y con **pruebas unitarias**.
- Los widgets no llaman a Supabase directamente; siempre pasan por repositorios expuestos con providers.
- Nada de secretos en el repo. Las claves se pasan con `--dart-define-from-file=env.json` (incluido en `.gitignore`; se versiona un `env.example.json`).

---

## 4. Modelo de datos (PostgreSQL / Supabase)

```sql
-- Perfiles (1:1 con auth.users)
profiles(id uuid pk references auth.users, display_name text, avatar_url text, created_at timestamptz)

-- ===== Torneo: unidad pública, dueño de equipos y jugadores =====
tournaments(
  id uuid pk default gen_random_uuid(),
  owner_id uuid references profiles not null,
  name text not null,                 -- 'Liga Petrolera de Básquetbol'
  sport text check (sport in ('football','basketball')) not null,
  sport_variant text,                 -- 'football_11','football_7','futsal','basketball_5','basketball_3x3'
  category text,                      -- texto libre con sugerencias: 'Libre','Veteranos +40','Femenil','Juvenil','Estatal'
  season_label text,                  -- 'Apertura 2026'
  city text, state text, venue_default text,
  logo_url text, cover_url text,
  visibility text check (visibility in ('public','unlisted','private')) default 'public',
  public_code char(6) unique not null, -- código para espectadores, p. ej. 'K7Q2MX'
  default_settings jsonb not null default '{}', -- reglas base que heredan sus competencias (§5.3)
  status text check (status in ('draft','in_progress','finished')) default 'draft',
  created_at timestamptz default now()
)

tournament_staff(
  tournament_id uuid references tournaments on delete cascade,
  user_id uuid references profiles,
  role text check (role in ('admin','scorer')),
  primary key (tournament_id, user_id)
)

teams(
  id uuid pk, tournament_id uuid fk on delete cascade,
  name text not null, short_name varchar(4), logo_url text,
  primary_color text, captain_name text,
  copied_from_team_id uuid null,      -- si se importó de otro torneo
  created_at timestamptz,
  unique (tournament_id, name)
)

players(
  id uuid pk, team_id uuid fk on delete cascade,
  first_name text not null, last_name text,
  jersey_number int, position text, photo_url text,
  birth_date date,                   -- PRIVADO; útil para validar categorías por edad (+40)
  is_active boolean default true,
  unique (team_id, jersey_number)
)

-- ===== Competencias (apartados) dentro del torneo =====
competitions(
  id uuid pk, tournament_id uuid fk on delete cascade,
  name text not null,                 -- nombre libre: 'Temporada regular', 'Playoffs', 'Copa Redención'
  type text check (type in ('league','quadrangular','knockout','groups_knockout')) not null,
  sort_order int not null,
  source_competition_id uuid references competitions null,  -- de dónde salen los equipos
  source_rank_from int null, source_rank_to int null,       -- p. ej. 1–8 o 9–16
  settings jsonb not null default '{}',  -- override de tournaments.default_settings
  status text check (status in ('draft','in_progress','finished')) default 'draft',
  champion_team_id uuid references teams null,
  is_featured boolean default false   -- la que se abre por defecto en la vista pública
)

competition_teams(
  competition_id uuid fk on delete cascade, team_id uuid fk,
  group_id uuid null, seed int,
  primary key (competition_id, team_id)
)

groups(id uuid pk, competition_id uuid fk, name text, sort_order int)

rounds(id uuid pk, competition_id uuid fk, number int, name text)  -- 'Jornada 3', 'Semifinal'

matches(
  id uuid pk, competition_id uuid fk, round_id uuid fk,
  home_team_id uuid fk null, away_team_id uuid fk null,   -- null = por definir en el bracket
  bracket_slot text, next_slot text,   -- 'QF1' → 'SF1'
  leg int default 1,                   -- ida/vuelta o juego N de una serie
  scheduled_at timestamptz, venue text, referee text,
  status text check (status in ('scheduled','live','finished','postponed','cancelled','forfeit')) default 'scheduled',
  home_score int, away_score int,
  home_penalties int, away_penalties int,
  period_scores jsonb,                 -- básquet: [{"q":1,"h":20,"a":18}, ...]
  forfeit_winner_id uuid null,
  notes text, updated_at timestamptz
)

player_match_stats(
  match_id uuid fk on delete cascade, player_id uuid fk, team_id uuid fk,
  stat_key text not null,     -- 'goals','assists','points','three_pointers','rebounds',...
  value int not null default 0,
  primary key (match_id, player_id, stat_key)
)

match_events(id uuid pk, match_id uuid fk, team_id uuid, player_id uuid, related_player_id uuid,
             type text, minute int, created_at timestamptz)   -- opcional, modo en vivo de fútbol

sanctions(id uuid pk, tournament_id uuid, player_id uuid, reason text, matches_suspended int,
          created_at timestamptz)     -- fase 2; las sanciones son del torneo y cruzan competencias
```

**Vistas y funciones SQL**
- `v_player_leaders(competition_id, stat_key)` y `v_player_leaders_tournament(tournament_id, stat_key)` (todas las competencias). Solo cuentan partidos `finished`.
- La **tabla general se calcula en Dart** (`core/standings`) a partir de los partidos terminados.
- `generate_public_code()`: 6 caracteres sin ambigüedad (sin 0/O/1/I).
- RPC `create_competition(tournament_id, payload jsonb)`: crea la competencia, inscribe los equipos (por rango o lista), asigna la siembra y genera el calendario o bracket en una sola transacción.
- RPC `copy_teams_from_tournament(source_tournament_id, target_tournament_id, team_ids[])`.

**Row Level Security (obligatorio)**
- `SELECT` público (rol `anon`) en todo lo que cuelga de un torneo `public` o `unlisted`. Para jugadores, exponer al público una **vista** sin `birth_date`.
- Escritura: solo el `owner_id` del torneo o un miembro de `tournament_staff`. Los `scorer` solo pueden actualizar `matches`, `player_match_stats` y `match_events`.
- Búsqueda pública: solo `visibility = 'public'`. Los `unlisted` solo se abren por código, QR o link.

---

## 5. Lógica por deporte

### 5.1 Interfaz

```dart
abstract class SportRules {
  Sport get sport;
  List<StatDefinition> get playerStats;
  bool get allowsDraws;
  StandingsPoints defaultPoints();
  List<TiebreakerType> defaultTiebreakers();
  List<String> get standingsColumns;
  MatchResultValidation validate(Match m, List<PlayerMatchStat> stats);
}
```

### 5.2 Defaults

**Fútbol**
- Puntos: victoria 3, empate 1, derrota 0. Opcional: punto extra en penales tras empate.
- Columnas: PJ, PG, PE, PP, GF, GC, DIF, PTS.
- Desempates: puntos → diferencia de goles → goles a favor → resultado directo → fair play → sorteo.
- Estadísticas: `goals`, `assists`, `yellow_cards`, `red_cards`, `own_goals`, `clean_sheets`, `mvp`.
- Validación: la suma de goles de cada equipo, más los autogoles del rival, debe coincidir con el marcador. Si no coincide, mostrar advertencia y dejar guardar.

**Básquetbol** (confirmado con la tabla real del piloto)
- Sin empates.
- Puntos: **victoria 2, derrota 1**, default (no presentarse) 0. Ejemplo: 14-1 → 29 pts.
- Columnas (como las usa la liga): **POS, EQUIPO, JJ, JG, JP, PF, PC, DIF, PTS**. Opcionales: %V y forma reciente.
- Desempates por defecto: puntos → resultado directo → **diferencia de puntos (DIF)** → puntos a favor.
- Estadísticas: `points`, `three_pointers`, `free_throws`, `rebounds`, `assists`, `steals`, `blocks`, `fouls`.
- Marcador por cuartos opcional.

### 5.3 Settings (jsonb, herencia torneo → competencia)

```json
{
  "double_round_robin": false,
  "points": {"win": 2, "draw": 0, "loss": 1, "forfeit_loss": 0},
  "tiebreakers": ["points","head_to_head","point_diff","points_for"],
  "rank_by": "points",
  "final_after_round_robin": true,
  "knockout": {"legs": 1, "series_best_of": 1, "third_place": false, "seeding": "by_rank"},
  "groups": {"count": 2, "advance_per_group": 2},
  "max_players_per_team": 15,
  "age_rule": {"min_age": 40, "reference_date": "2026-01-01"},
  "track_stats": ["points","three_pointers","rebounds","assists"]
}
```

- `rank_by`: `"points"` (default) o `"win_pct"`. En ligas amateurs es común que **los equipos lleven distinto número de juegos** por partidos pendientes. En el piloto, LIZARDS SLB va 11-1 con 12 JJ y queda debajo de RIVAL, que va 10-5 con 15 JJ. Con `win_pct` la tabla es más justa a media temporada. La app debe mostrar un aviso cuando haya diferencias de JJ.
- `age_rule`: opcional. Al dar de alta o importar jugadores, si no cumplen la regla, mostrar advertencia (útil para Veteranos +40 y categorías juveniles).

---

## 6. Tipos de competencia (`core/competition_types`)

| Tipo | Qué es | Vista principal | Campeón |
|---|---|---|---|
| `league` — **Liga / Temporada regular** | Todos contra todos, a una o dos vueltas | Tabla | 1º de la tabla (opcional: no coronar si hay fases posteriores) |
| `quadrangular` — **Cuadrangular** (triangular, pentagonal) | 3 a 6 equipos, todos contra todos a una vuelta; final opcional entre 1º y 2º | Tabla + final | 1º o ganador de la final |
| `knockout` — **Eliminación directa** (Playoffs, Liguilla, Copa) | Bracket; partido único, ida y vuelta o serie al mejor de 3/5 | Bracket | Ganador de la final |
| `groups_knockout` — **Grupos + eliminatoria** | Grupos todos contra todos y después bracket | Tablas por grupo + bracket | Ganador de la final |

### 6.1 Round-robin (liga, cuadrangular, grupos)
- **Método del círculo.** Con número impar de equipos se agrega un "descanso" (BYE).
- Opción de ida y vuelta, con localía alternada y balanceada.

### 6.2 Eliminación directa
- Siembra por posición en la competencia de origen (default), aleatoria o manual (arrastrar).
- Si el número de equipos no es potencia de 2, los mejores sembrados reciben BYE.
- Se generan todos los slots desde el inicio; los partidos sin equipo quedan "Por definir".
- **Avance automático** al terminar el partido, la serie o el global.

### 6.3 Crear una competencia posterior ("Agregar competencia")
Desde el panel del torneo → **Agregar competencia**:
1. **Nombre libre** ("Playoffs", "Liguilla", "Copa Redención", "Copa de Plata"…).
2. **Tipo**.
3. **Equipos**: por **rango de posiciones** de otra competencia del mismo torneo ("del 1º al 8º de Temporada regular") o **marcando a mano**.
4. **Siembra** (vista previa editable).
5. **Reglas**: heredan las del torneo y se puede cambiar lo que haga falta, por ejemplo serie al mejor de 3 solo en la final.

Reglas:
- Se pueden crear **varias competencias desde la misma**, y pueden jugarse **en paralelo**. El calendario del torneo las muestra juntas, con una etiqueta de color por competencia.
- Si la competencia de origen no ha terminado, avisar que la tabla puede cambiar, y permitir **"Actualizar equipos desde la tabla"** mientras la nueva competencia no haya empezado.
- Si dos competencias posteriores comparten equipos, mostrar advertencia.
- **Plantillas rápidas** al crear el torneo o al agregar competencia: "Liga + Playoffs", "Liga + Playoffs + Copa de consolación" (pide nombre, p. ej. Copa Redención) y "Cuadrangular".

### 6.4 Pruebas
- Round-robin con 4, 5, 8, 11 y 16 equipos: nadie juega dos veces en la misma jornada, cada par se enfrenta exactamente 1 o 2 veces y la localía queda balanceada.
- Bracket con 4, 6, 8 y 16 equipos: BYEs, avance automático, series y global.
- Selección por rango respetando desempates.
- **Test de tabla con los datos del piloto** (§11.1): dados esos JG/JP/PF/PC, el orden debe ser exactamente el de la tabla real con `rank_by = points` y desempate por DIF.

---

## 7. Importación de jugadores por Excel

**Plantilla descargable** (`plantilla_jugadores.xlsx`), hoja `Jugadores`:

| equipo* | nombre* | apellido | dorsal | posicion | fecha_nacimiento |
|---|---|---|---|---|---|
| CODITRYSA | Juan | Pérez | 10 | Escolta | 1985-05-14 |

`*` = obligatorio. Se incluye una segunda hoja `Instrucciones`.

Flujo (siempre dentro de un torneo):
1. "Importar desde Excel" (`.xlsx` o `.csv`).
2. Se parsea en el dispositivo y los encabezados se normalizan (minúsculas, sin acentos ni espacios).
3. **Vista previa** con validación fila por fila: faltan campos obligatorios, el equipo no existe (opción de crearlo), dorsal duplicado, se excede el máximo de jugadores y no cumple `age_rule` (advertencia).
4. Insert en lote en una sola transacción (RPC `import_players(tournament_id, rows jsonb)`).
5. Resumen y descarga de errores.

También se puede **exportar** a Excel: equipos, calendario, tabla y estadísticas.

---

## 8. Pantallas

### Cara pública / espectador (sin login)
1. **Inicio**: buscador, "Escanear QR", torneos seguidos (favoritos locales) y torneos cercanos.
2. **Búsqueda**: por nombre, código, ciudad o estado, deporte y categoría.
3. **Torneo (vista pública)**:
   - Encabezado con logo, nombre, categoría y **selector de competencia** (chips: Temporada regular · Playoffs · Copa Redención), con los campeones arriba.
   - Las pestañas dependen del tipo de competencia:
     - Liga / cuadrangular: **Tabla · Jornadas · Estadísticas · Equipos**.
     - Eliminación directa: **Bracket · Partidos · Estadísticas · Equipos**.
     - Grupos + eliminatoria: **Grupos · Bracket · Partidos · Estadísticas · Equipos**.
   - Estadísticas: filtro por competencia o "Todo el torneo".
   - Equipo: plantel (sin datos privados), partidos en todas las competencias y forma reciente.
   - **Tabla compartible como imagen**, con el estilo de la tabla que hoy publica la liga: logo, colores del torneo y columnas POS · EQUIPO · JJ · JG · JP · PF · PC · DIF · PTS.
4. **Deep link** `https://tutorneoflash.app/t/{code}`: abre el torneo. Con `?c={competitionId}` abre una competencia específica.

### Cara organizador (con login: email/contraseña, Google, Apple)
5. **Mis torneos**: tarjetas con logo, categoría, estado y competencias activas. Botón "Crear torneo".
6. **Asistente "Crear torneo"** (corto):
   1. Deporte y variante.
   2. Nombre, **categoría**, temporada, ciudad, logo y colores.
   3. **Equipos**: número de equipos → alta rápida (nombre + logo), **importar Excel** o **copiar de otro de mis torneos**.
   4. Jugadores: manual, Excel o después (se puede saltar).
   5. **Primera competencia**: tipo (por defecto Liga, "Temporada regular") o una plantilla rápida (§6.3), y reglas con defaults del deporte.
   6. Visibilidad y resumen → **Crear**. Se genera el calendario y se muestra el código para compartir.
7. **Panel del torneo**: competencias (estado, campeón, progreso), próximos partidos, botón "Compartir" (link + QR) y **"Agregar competencia"**.
8. **Equipos y jugadores** del torneo: CRUD e importación Excel.
9. **Competencia**: calendario o bracket, edición, reprogramación, estados (pospuesto, cancelado, default) y reglas.
10. **Captura de resultado**: marcador con botones +/- grandes, contadores por jugador y validación.
11. **Staff**: invitar coorganizadores o capturistas.
12. **Ajustes del torneo**: reglas base, visibilidad, finalizar torneo, duplicar torneo para la siguiente temporada (copia equipos y planteles).

---

## 9. Requisitos no funcionales

- **Offline first en la captura**: el resultado se guarda localmente (`drift` o `hive`) y se sincroniza después.
- **Tiempo real**: la vista pública se suscribe con Supabase Realtime a los `matches` de la competencia abierta.
- **Rendimiento**: listas paginadas e imágenes comprimidas (máx. 512 px para escudos).
- **Accesibilidad**: contraste AA, tamaños táctiles ≥ 48 dp, texto grande.
- **Privacidad**: fecha de nacimiento y contacto nunca son públicos. Incluir aviso de privacidad.
- **Calidad**: `flutter analyze` sin warnings, cobertura ≥ 80 % en `core/` y pruebas de widgets en los flujos clave.
- **CI**: GitHub Actions con analyze + test en cada PR.

---

## 10. Plan de entregas (milestones)

Un milestone a la vez. Al terminar cada uno: pruebas, commit y resumen de pendientes.

- **M0 · Base**: proyecto, estructura, tema, router, i18n, Riverpod, Supabase, migraciones + RLS, CI.
- **M1 · Auth + torneos + equipos**: login, "Mis torneos", asistente (pasos 1–4), equipos con logo, jugadores, Excel y copiar equipos de otro torneo.
- **M2 · Competencia tipo Liga**: crear "Temporada regular", round-robin (+ pruebas), calendario editable y estados de partido.
- **M3 · Resultados y estadísticas**: captura de marcador y estadísticas por jugador, y validaciones.
- **M4 · Tablas y líderes**: motor de tabla, desempates, `rank_by`, aviso por JJ distintos, líderes y **test con datos del piloto**.
- **M5 · Competencias posteriores**: "Agregar competencia", selección por rango, siembra, eliminación directa (bracket, series, avance), cuadrangular, grupos + eliminatoria, plantillas rápidas y campeones.
- **M6 · Cara pública**: búsqueda, QR, deep links, selector de competencias, favoritos, tiempo real y tabla como imagen.
- **M7 · Piloto y publicación**: offline, iconos y splash, aviso de privacidad, prueba de aceptación §11, builds y fichas de tienda.

**Empieza por M0.** Antes de codificar, propón la lista de paquetes con versiones y el SQL de la migración inicial para revisión.

---

## 11. Caso piloto: Liga de la Industria Petrolera de Básquetbol

### 11.1 Datos de ejemplo (`seed.sql` y pruebas)

Torneo: **"Liga de la Industria Petrolera de Básquetbol"**. Básquetbol, categoría Libre, Tabasco. Competencia "Temporada regular" (Liga). Tabla real a media temporada; nota que los JJ son distintos por partidos pendientes:

| POS | EQUIPO | JJ | JG | JP | PF | PC | DIF | PTS |
|---|---|---|---|---|---|---|---|---|
| 1 | CODITRYSA | 15 | 14 | 1 | 798 | 611 | 187 | 29 |
| 2 | RIVAL | 15 | 10 | 5 | 624 | 587 | 37 | 25 |
| 3 | LIZARDS SLB | 12 | 11 | 1 | 549 | 405 | 144 | 23 |
| 4 | INEGI | 13 | 8 | 5 | 639 | 487 | 152 | 21 |
| 5 | INSTALACIONES | 11 | 10 | 1 | 554 | 474 | 80 | 21 |
| 6 | SAMARIA OIL | 14 | 6 | 8 | 515 | 566 | -51 | 20 |
| 7 | ADTM | 12 | 7 | 5 | 437 | 412 | 25 | 19 |
| 8 | BAKER HUGHES | 12 | 7 | 5 | 514 | 493 | 21 | 19 |
| 9 | BRONCOS GSM | 13 | 6 | 7 | 410 | 428 | -18 | 19 |
| 10 | INGENIO SERV | 14 | 5 | 9 | 438 | 483 | -45 | 19 |
| 11 | OILERS | 13 | 5 | 8 | 526 | 484 | 42 | 18 |
| 12 | HALLIBURTON | 13 | 5 | 8 | 451 | 485 | -34 | 18 |
| 13 | VIASUR | 11 | 4 | 7 | 388 | 403 | -15 | 15 |
| 14 | LLERGO ASOC | 12 | 3 | 9 | 443 | 536 | -93 | 15 |
| 15 | OPEX | 13 | 1 | 12 | 359 | 568 | -209 | 14 |
| 16 | CARGOWELD | 13 | 0 | 13 | 361 | 536 | -175 | 13 |

Uso:
- **Test unitario de standings**: con estos totales, `rank_by = points` + desempate DIF produce exactamente este orden. Verificar también PTS = JG×2 + JP×1. Con `rank_by = win_pct`, el orden cambia (LIZARDS e INSTALACIONES suben); el test debe documentar ese orden.
- **Seed**: generar partidos ficticios cuyos resultados sumen estos totales (o, si se complica, cargar los 16 equipos con jugadores ficticios y un calendario de 15 jornadas parcialmente jugado).
- Los logos de la liga no se incluyen en el repo; usar placeholders.

### 11.2 Prueba de aceptación (de punta a punta en la app)

1. El organizador crea su cuenta y el torneo con los **16 equipos** y logos; los jugadores entran con **un solo Excel**.
2. Se crea "Temporada regular" (Liga, una vuelta). Se capturan resultados y estadísticas, se deja un partido **pospuesto** y se reprograma después.
3. La tabla coincide en formato y cálculo con la que publica la liga (§11.1), y se comparte como imagen.
4. Un espectador sin cuenta encuentra el torneo **por código o QR** y ve la tabla, las jornadas y los máximos encestadores.
5. Con la plantilla "Liga + Playoffs + Copa de consolación" se crean:
   - **Playoffs**: eliminación directa, lugares 1–8 (1 vs 8, 2 vs 7, 3 vs 6, 4 vs 5).
   - **Copa Redención**: eliminación directa, lugares 9–16 (9 vs 16, 10 vs 15, 11 vs 14, 12 vs 13).
6. Ambas se juegan en paralelo, los ganadores avanzan solos y cada una corona a **su campeón**.
7. Prueba de multi-torneo: el mismo organizador crea **"Veteranos +40"** copiando 4 equipos y juega un **Cuadrangular**, sin mezclar datos con la liga.

---

## 12. Backlog (post-MVP)

- Bracket visual interactivo con zoom y animaciones.
- Estadísticas de carrera del jugador entre temporadas.
- Sanciones automáticas (acumulación de faltas o amarillas → suspensión, aviso al capturar).
- Credencial digital del jugador con QR, con validación de edad por categoría.
- Generador de imágenes para redes (resultado de jornada, goleador o encestador, campeón).
- Notificaciones push por equipo seguido.
- Árbitros, canchas y horarios con detección de choques.
- Inscripciones y pagos por equipo.
- Votación de MVP de la jornada.
- Página pública del organizador o liga con todos sus torneos y su historial.
- Patrocinadores por torneo y plan freemium. El piloto es gratuito.
- Más deportes: voleibol (sets), béisbol/softbol.
- Versión web (Flutter Web) solo de consulta.

---

## 13. Convenciones para Claude Code

- Commits pequeños con Conventional Commits.
- Nada de lógica de negocio en widgets. Cada regla nueva lleva su prueba unitaria.
- Cambios de esquema siempre en una migración nueva.
- Ante una ambigüedad de reglas deportivas, usar los defaults de §5 y dejar `// TODO(product):`.
- Textos de UI en archivos ARB.
- **No hardcodear** nombres como "Temporada regular", "Playoffs" o "Copa Redención" en la lógica: son nombres libres. Solo pueden aparecer como sugerencias en las plantillas rápidas.
## Supabase
- Todo cambio de esquema se escribe primero como archivo en supabase/migrations/
  y después se aplica con la herramienta apply_migration del MCP. Nunca uses execute_sql para crear o alterar tablas.
- Usa execute_sql solo para consultas de lectura o pruebas.
- Pide confirmación antes de cualquier DROP, DELETE o TRUNCATE.
- Después de cada migración, corre los advisors de seguridad y verifica que todas las tablas tengan RLS.