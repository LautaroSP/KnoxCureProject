# Objetivo de diseño — Knox Cure Project

## Visión

Knox Cure Project convierte la búsqueda de una cura en una campaña científica
de endgame de aproximadamente dos a tres meses. El jugador debe reunir equipo,
desarrollar habilidades, practicar autopsias, conservar muestras, construir
instrumentos y completar experimentos sin depender de un bloqueo aleatorio.

## Laboratorio

El laboratorio se compone de seis estaciones:

1. Camilla o banco médico vanilla para autopsias.
2. Escritorio y microscopio vanilla para clasificar muestras.
3. Centrífuga propia.
4. Heladera o congelador vanilla para conservación.
5. Analizador biológico propio.
6. Sintetizador propio.

Una computadora vanilla funciona como terminal. Cada terminal posee un proyecto
independiente. Los resultados se comparten deliberadamente mediante discos
duros o registros escritos; nunca aparecen automáticamente en otro laboratorio.

## Autopsias

- Campaña estándar: 25 a 35 cadáveres útiles.
- Perfiles virales persistentes A, B, C y D.
- Fresco: menos de 24 horas; degradado: 24 a 72; putrefacto: más de 72.
- Cada cadáver entrega entre una y tres muestras y XP una sola vez.
- Tres manuales secuenciales habilitan entrenamiento hasta niveles 3, 6 y 10.
- La profesión Forense ignora los manuales de autopsia, pero no los protocolos
  científicos ni los planos de maquinaria.
- Tras 15 autopsias, un personaje común obtiene Forense experimentado.

### Cadena operativa aprobada

- Limpiar la camilla requiere alcohol desinfectante o líquido limpiador y un
  trapo limpio o esponja. La autopsia vuelve a ensuciarla.
- Autopsia y extracción exigen bisturí, guantes quirúrgicos y barbijo equipados.
- La extracción usa un recipiente estéril; durante la Fase 3 es un objeto
  genérico provisional sin modelo propio y su recurso definitivo se diseña en
  la Fase 4.
- El microscopio requiere Primeros Auxilios 3; la centrífuga, Primeros Auxilios
  4, electricidad y un contrapeso; analizar una fracción viral requiere Primeros
  Auxilios 5.
- Calibrar el analizador requiere Electricidad 3, energía y destornillador.
- Escribir un registro usa cuaderno y útil de escritura, sin electricidad. La
  exportación e importación usan una terminal energizada y un disco de
  investigación reutilizable.
- Operar el sintetizador requiere Primeros Auxilios 7, energía, fracción viral
  estabilizada, reactivos e inyector estéril. La cura real permanece reservada
  para la Fase 7.
- Las opciones permanecen visibles en rojo cuando falta un requisito y explican
  el nivel, herramienta, equipo, material o energía ausente.

## Investigación

El proyecto avanza mediante datos rutinarios y experimentos obligatorios:

1. Patología: 0–20%.
2. Caracterización: 20–45%.
3. Aislamiento: 45–70%.
4. Prototipo: 70–90%.
5. Estabilización: 90–100%.

El azar modifica pureza y rendimiento, pero nunca impide progresar. Distintos
personajes pueden aportar Primeros Auxilios, Electricidad y Metalistería.

## Respaldos

- Disco duro: rápido, reutilizable y dependiente de energía.
- Registro escrito: entre 30 minutos y 8 horas, sin electricidad e inmutable.
- Importar conserva el mayor porcentaje y une descubrimientos sin duplicarlos.
- Las copias divergen después de importarse.
- Destruir la terminal sin respaldo elimina el proyecto.

## Diagnóstico y cura

- Diagnóstico de laboratorio al 45%.
- Test portátil consumible al 70%.
- Fórmula de cura al 100%.
- Una síntesis de unas ocho horas produce una dosis.
- Cura a cualquier personaje infectado que continúe vivo; no vacuna.
- Una dosis usada sobre alguien sano se consume sin protegerlo.
- Secuelas: pérdida permanente de un nivel de Fuerza y de habilidades de
  conocimiento, más 48 horas de convalecencia exigente pero no letal.
- Estabilidad: 24 horas ambiente, 30 días refrigerada y 60 congelada.

## Reglas técnicas

- Exclusivo para Build 42.
- Estado persistente con `schemaVersion`.
- Consumos, XP, investigación y cura validados por el servidor.
- Compatibilidad con solitario, cooperativo y servidor dedicado.
- Reutilizar recursos vanilla por identificador; crear como máximo tres modelos
  principales salvo revisión explícita del objetivo.

## Decisiones provisionales de estaciones

- Los tres equipos nuevos usan el sistema vanilla de agarrar/colocar muebles.
- Pesos aprobados: centrífuga `20`, analizador biológico `35` y sintetizador
  `40` unidades de inventario.
- Las propiedades de tile correspondientes son `PickUpWeight = 200`, `350` y
  `400`, porque Build 42 divide ese valor por diez.
- Sólo pueden recogerse apagados y sin una operación activa.
- Requieren destornillador y Electricidad 1/2/4 respectivamente.
- Los tamaños 2x `128×256` y 1x `64×128` son provisionales hasta la prueba
  dentro del juego.
- Los estados visuales usan solamente LEDs estáticos: apagado, verde listo,
  ámbar trabajando y rojo averiado. Las pantallas no cambian.
- La centrífuga reutiliza sonidos vanilla de lavadora para inicio, trabajo y
  finalización. Su posible vibración visual queda diferida al trabajo final de
  animaciones.
- El gabinete 2x1 del sintetizador debe permanecer fijo para no abrir
  visualmente la unión entre baldosas.
