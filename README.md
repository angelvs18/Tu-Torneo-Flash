# Tu Torneo Flash

App móvil (Android + iOS) para organizar y seguir torneos deportivos locales.
La especificación completa está en [`docs/SPEC.md`](docs/SPEC.md).

## Requisitos

- Flutter 3.47.x (Dart 3.13)
- Node.js (para `npx supabase`)
- Docker Desktop, solo si quieres levantar Supabase en local

## Configuración

1. Copia `env.example.json` a `env.json` y llena la URL y la *publishable key*
   (Supabase → Project Settings → API Keys). `env.json` no se versiona.
2. Instala dependencias y genera código:

   ```sh
   flutter pub get
   dart run build_runner build -d
   ```

3. Ejecuta la app:

   ```sh
   flutter run --dart-define-from-file=env.json
   ```

## Base de datos (Supabase)

- Las migraciones viven en `supabase/migrations/`. Cada cambio de esquema va en una migración nueva.
- Aplicar al proyecto remoto:

  ```sh
  npx supabase login
  npx supabase link --project-ref <project-ref>
  npx supabase db push
  ```

- Pruebas de RLS (pgTAP, requieren Docker): `npx supabase db start && npx supabase test db`.

## Calidad

```sh
flutter analyze --fatal-infos
flutter test --coverage
```

CI (`.github/workflows/ci.yml`) corre analyze + tests de Flutter y las migraciones + pruebas pgTAP en cada PR.
