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
- Puedes cambiar el modelo visual en `.env` con `GROQ_VISION_MODEL`; por defecto usa `qwen/qwen3.8-27b`.
- Gemini (`gemini-3.5-flash-lite`) funciona como respaldo de visión si configuras `GEMINI_API_KEY`.
- Groq usa `openai/gpt-oss-20b` para generar outfits; configurable con `GROQ_MODEL`.
- Si falla la identificación, se conserva la foto y se pueden completar nombre, color y categoría manualmente. En cada prenda, el botón de editar permite volver a identificarla con IA.
- Las fotos nuevas se guardan y muestran completas, sin recorte ni conversión a cuadrados. Solo se reduce una copia en memoria para las APIs de identificación; el archivo original no se modifica.
- La vista del outfit presenta las prendas juntas sobre blanco, con complementos más pequeños y ampliación al tocar cada foto. Las transparencias se muestran sobre blanco; los fondos opacos de las fotos se conservan.
- Open-Meteo obtiene clima actual sin API key.

## Verificación

`flutter test` comprueba el respaldo de APIs, respuestas inválidas, proporciones de imágenes y el scroll horizontal y vertical. Las pruebas reales se habilitan con la variable de entorno `FITPIC_LIVE_AI=1`; usan las imágenes de `assets/ropa/` y las claves locales de `.env`.

`python tool/check_ai.py` consulta los modelos disponibles sin mostrar credenciales. Para probar una foto de ejemplo: `python tool/check_ai.py groq qwen/qwen3.8-27b camisa.png`.

## Estructura

- `lib/models`: modelos de prendas, outfits y clima.
- `lib/services`: Gemini, Groq, Open-Meteo, Hive e imagenes locales.
- `lib/screens`: onboarding, inicio, armario, sugerir, detalle y perfil.
- `lib/widgets`: botones, cards, loader lineal y mensajes de error.
- `lib/theme`: tema centralizado cafe/blanco sin bordes redondeados.
