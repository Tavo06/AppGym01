# FitProgress

Aplicación Flutter de gimnasio: ejercicios, rutinas, entrenamientos (por rutina
o libres), récords personales y estadísticas, con Firebase (Authentication y
Cloud Firestore) como backend. Funciona en Android, Web y Windows, con tema
claro, oscuro o del sistema.

## Requisitos

- Flutter 3.x (probado con 3.47) y Android SDK / Android Studio.
- Para Windows: Visual Studio con "Desarrollo de escritorio con C++".
- Proyecto de Firebase `fitprogress-f232f` (ya configurado en
  `lib/firebase_options.dart` para Android, Web y Windows).

## Firebase

- **Authentication**: habilitar *Correo/contraseña* y *Google*.
- **Firestore**: publicar las reglas de `firestore.rules`
  (`firebase deploy --only firestore:rules --project fitprogress-f232f`).
  Cada usuario solo accede a `users/{uid}` y sus subcolecciones
  (`exercises`, `routines`, `workouts`, `personal_records`, `weekly_progress`).
- Las contraseñas las gestiona solo Firebase Authentication; nunca se guardan
  en Firestore.
- Para reconfigurar plataformas: `flutterfire configure --project=fitprogress-f232f`.

### Google Sign-In

- **Web**: ventana emergente de Firebase (funciona en `localhost`).
- **Android**: registrar en Firebase la huella SHA-1 de cada clave de firma
  (`keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`)
  y volver a descargar `android/app/google-services.json`.
- **Windows**: el plugin no lo soporta; el botón se oculta.

## Flujo de registro

Login → Crear cuenta → verificar el correo → modal "Crear contraseña" sobre el
Login → el correo queda escrito → iniciar sesión → Inicio.

## Firma de release (Android)

Crear `android/key.properties` (no se sube al repositorio):

```properties
storeFile=C:/ruta/a/tu-clave.jks
storePassword=...
keyAlias=...
keyPassword=...
```

Sin ese archivo la versión release se firma con la clave de depuración.
Registra también la SHA-1 de la clave release en Firebase para Google Sign-In.

## Compilar y ejecutar

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome        # Web
flutter run -d windows       # Windows
flutter emulators --launch Pixel_7 && flutter run   # Android
```

## Estructura del proyecto

- `lib/core` – tema claro/oscuro (`AppTheme`, `AppPalette`), constantes,
  validadores, formato y rutas (GoRouter).
- `lib/models` – usuario, ejercicios, rutinas, sesiones, series, récords y
  progreso.
- `lib/providers` – estado con `provider`: autenticación, entrenamiento,
  progreso y tema.
- `lib/services` – Firebase Auth, Cloud Firestore y Google Sign-In
  (`AppFirebase` centraliza el acceso y permite simularlo en pruebas).
- `lib/widgets` – componentes reutilizables (botones, campos, diálogos,
  tarjetas, estados de carga/vacío/error, diseño adaptable).
- `lib/screens` – autenticación, inicio, rutinas, ejercicios, entrenamiento,
  progreso y perfil.
- `test/` – pruebas unitarias, de widgets y de pantallas completas con
  Firebase simulado (`fake_cloud_firestore`, `firebase_auth_mocks`).

## Nota técnica

`android/gradle.properties` desactiva la compilación incremental de Kotlin
(`kotlin.incremental=false`): en Windows falla cuando el proyecto y la caché de
pub están en unidades distintas.
