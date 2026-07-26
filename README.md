# FitPic

App movil Flutter MVP de estilista personal con IA. Guarda fotos, analisis, prendas y outfits solo en el dispositivo usando Hive.

## Ejecutar

El SDK Flutter de esta maquina no termino `flutter create` ni `dart format` durante la sesion, asi que si faltan carpetas nativas ejecuta:

```bash
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

## APIs

- Groq Vision analiza foto de armario y rostro.
- Puedes cambiar el modelo visual en `.env` con `GROQ_VISION_MODEL`; por defecto usa `qwen/qwen3.6-27b`.
- Groq usa `llama-3.3-70b-versatile` para generar 4 outfits.
- Open-Meteo obtiene clima actual sin API key.

## Estructura

- `lib/models`: modelos de prendas, outfits y clima.
- `lib/services`: Gemini, Groq, Open-Meteo, Hive e imagenes locales.
- `lib/screens`: onboarding, inicio, armario, sugerir, detalle y perfil.
- `lib/widgets`: botones, cards, loader lineal y mensajes de error.
- `lib/theme`: tema centralizado cafe/blanco sin bordes redondeados.
