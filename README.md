# Vinyl Café — prototipo de jazz

Prototipo jugable para Godot 4. Incluye una intro sin textos caminando desde una parada de camión hacia Vinyl-Store, una tienda abandonada con ventanas rotas, calle exterior amplia con banqueta, parada de camión, árboles al fondo y cielo de noche, vinilos tirados en el suelo, puntos por acomodarlos, sala principal despejada con cuartos grandes alrededor al estilo croquis arquitectónico, puertas a ras de pared y letreros neón, una tornamesa con música y restauración gradual de las luces.

## Ejecutar

1. Instala Godot 4 desde https://godotengine.org/download/windows/
2. Abre Godot y selecciona **Importar**.
3. Elige el archivo `project.godot` de esta carpeta.
4. Presiona **F6** o el botón de reproducir.

## Controles

- Usa **WASD** para caminar y el **ratón** para mirar. Puedes salir y volver a entrar por la puerta principal.
- Pulsa **Q** mirando una funda de artista tirada en el suelo para tomar ese disco.
- Con un disco en la mano, pulsa **R** para alternar entre portada y contraportada.
- Con un disco en la mano, pulsa **Q** mirando la tornamesa para ponerlo.
- Con un disco en la tornamesa, pulsa **Q** mirando la tornamesa para retirarlo.
- Después de retirarlo, pulsa **Q** mirando su estante de género para devolverlo con animación y sonido antes de tomar otro.
- Pulsa **E** o clic para levantar vinilos de jazz del suelo, acomodarlos en su estante correcto y tocar los controles de la tornamesa.
- Pulsa **F** para prender o apagar la linterna.
- Pulsa **Esc** para liberar el cursor; haz clic en la ventana para capturarlo otra vez.
- Los cinco discos de jazz empiezan tirados en el suelo y deben colocarse de izquierda a derecha en su estante correcto. Cada acierto suma 100 puntos.
- Los discos de artistas también empiezan tirados; Abraham HDZ va en Regional Mexicano y 9 MONARCA va en Metalcore. Cada artista acomodado suma 150 puntos.

La pista incluida es únicamente una demostración sintetizada por código; no contiene música comercial ni material con derechos de terceros.





## Tornamesa y mezcladora

- Al colocar un disco, el vinilo gira y el brazo entra desde su descanso derecho hacia el borde exterior.
- Mientras avanza la canción, el brazo se mueve hacia el centro y al terminar regresa a su soporte.
- Mantén clic izquierdo sobre el fader frontal derecho y arrastra horizontalmente para controlar el volumen.
- Usa los botones frontales izquierdos para seleccionar 45 RPM (lenta), 33⅓ RPM (normal) o 78 RPM (rápida).


## Cuartos de género

La tienda incluye una sala principal despejada con cuartos distribuidos alrededor, no como columnas internas: Rock, Metalcore y Regional Mexicano quedan del lado izquierdo; Metal, Jazz y Rap y Hip Hop en la parte superior; Punk, Reguetón y Pop quedan del lado derecho. Cada cuarto es más amplio, tiene entradas más altas y anchas a ras de la pared, paredes bajas con colisión uniforme, techo bajo oscuro, letrero neón y repisas de vinilos montadas sobre la pared como tienda de discos. La entrada principal usa una puerta corrediza de vidrio que se abre al acercarte.

## Artistas independientes incluidos

- Abraham HDZ — **Hoy es diferente**
- 9 MONARCA — **Abyss 404**

Cada disco conserva su propia portada, canción y contraportada. Al traerlo en la mano, puedes inspeccionarlo con **R**. La tornamesa admite un solo disco: utiliza **Q** para retirar el actual antes de colocar otro.

## Modelos 3D de la tornamesa

- `assets/models/audio_technica_turntable_textured.glb`: modelo visible usado en el juego.
- `assets/models/audio_technica_turntable_segmented.glb`: versión segmentada conservada para futuras animaciones o sustitución de piezas.
- Los archivos `.glb` se administran con Git LFS por su tamaño.
- La colisión, el vinilo, la portada central, el brazo animado y los controles siguen siendo nodos independientes para conservar la interacción.
