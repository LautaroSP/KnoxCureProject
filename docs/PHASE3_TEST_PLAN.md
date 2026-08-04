# Fase 3 — Implementación y pruebas

## Alcance implementado

La Fase 3 incorpora acciones temporizadas sin animaciones específicas. El
personaje camina hasta una posición adyacente y permanece quieto durante la
operación. Caminar, correr, apuntar, recibir daño, perder un requisito o cortar
la electricidad cancela la acción.

Las operaciones usan un bloqueo por estación con `schemaVersion = 1`. En
multijugador, el cliente solicita inicio, cancelación y finalización; el servidor
vuelve a validar estación, distancia, habilidad, inventario, protección, cadáver,
energía y token antes de modificar datos o consumir objetos. Los materiales sólo
se consumen al completar, por lo que cancelar no entrega resultados ni descuenta
insumos.

El recipiente de muestras de esta fase es provisional, reutiliza el icono
vanilla de un frasco y no tiene modelo propio. Su recurso definitivo queda
reservado para la Fase 4.

## Flujo provisional comprobable

1. Limpiar una camilla vacía consume `0.10 L` de alcohol o líquido limpiador. Un
   trapo limpio pasa a estar sucio; la esponja se conserva.
2. Una autopsia exige camilla limpia, cadáver zombi adyacente, bisturí, guantes y
   barbijo equipados. Ensucia la camilla, desgasta un punto del bisturí y habilita
   una muestra provisional.
3. Extraer consume un recipiente y produce una muestra cruda.
4. El microscopio, con Primeros Auxilios 3, produce una muestra clasificada.
5. La centrífuga, con Primeros Auxilios 4, electricidad y contrapeso, produce una
   fracción viral.
6. Calibrar el analizador exige Electricidad 3 y destornillador. Analizar exige
   Primeros Auxilios 5 y produce una fracción estabilizada.
7. La terminal puede escribir un registro con cuaderno y útil de escritura,
   exportar a un disco e importar el mismo disco.
8. El sintetizador exige Primeros Auxilios 7, energía, fracción estabilizada,
   reactivos e inyector. Produce sólo un lote experimental sin efecto médico.

Los rendimientos finales, perfiles virales, frescura, investigación real,
respaldos con porcentaje y cura quedan fuera de esta fase.

## Preparación de prueba

1. Iniciar Build 42 en modo debug con Knox Cure habilitado.
2. Colocar o localizar las estaciones.
3. Hacer clic derecho en cualquiera de ellas y usar
   `Knox Cure > Pruebas de Fase 3 (debug)`.
4. Añadir el kit completo y fijar Primeros Auxilios 7/Electricidad 3.
5. Equipar manualmente los guantes y el barbijo.
6. Matar un zombi y arrastrar su cadáver hasta una casilla junto a la camilla.

## Matriz manual en solitario

- [ ] Todas las opciones aparecen; las inválidas están en rojo y explican cada
  requisito faltante.
- [ ] Quitar y recuperar un nivel requerido actualiza la opción del microscopio,
  centrífuga, analizador o sintetizador.
- [ ] La limpieza consume líquido sólo al completar y convierte el trapo en
  trapo sucio; la esponja no se consume.
- [ ] Cancelar la limpieza antes de terminar conserva todos los insumos.
- [ ] La autopsia no comienza sin guantes, barbijo, bisturí, camilla limpia y
  cadáver zombi.
- [ ] Completar la autopsia ensucia la camilla y desgasta el bisturí exactamente
  una vez.
- [ ] Un cadáver no concede más de una muestra provisional.
- [ ] Microscopio, centrífuga y analizador transforman exactamente un objeto en
  el siguiente sin duplicarlo.
- [ ] La centrífuga inicia, mantiene y finaliza sus sonidos; cancelarla detiene el
  sonido de trabajo.
- [ ] Calibrar exige destornillador y Electricidad 3; el análisis posterior exige
  Primeros Auxilios 5.
- [ ] El registro consume un cuaderno, conserva el bolígrafo/lápiz y entrega un
  registro científico.
- [ ] No se puede importar un disco antes de exportarlo; el disco se conserva en
  ambas operaciones.
- [ ] El sintetizador consume sus tres entradas sólo al completar y entrega un
  lote experimental sin efecto de cura.
- [ ] Caminar, correr, apuntar, recibir daño, retirar una herramienta y cortar la
  electricidad cancelan donde corresponda.
- [ ] El personaje permanece quieto y sin animación específica durante todas las
  acciones nuevas.

## Matriz manual multijugador

- [ ] Un cliente puede completar cada operación y recibe el resultado del
  servidor.
- [ ] Los jugadores cercanos oyen inicio, funcionamiento, finalización y
  cancelación de las máquinas sin reproducir el sonido dos veces.
- [ ] Dos jugadores intentando usar la misma estación no obtienen resultados
  duplicados.
- [ ] Si un jugador cancela, el bloqueo se libera para el segundo jugador.
- [ ] Alterar o retirar insumos durante una operación provoca rechazo al terminar
  y no crea el resultado.
- [ ] Desconectar durante una operación no consume materiales; el bloqueo expira
  automáticamente como máximo una hora de mundo después.
- [ ] Los estados de limpieza, calibración y cadáver usado sobreviven
  guardado/carga y son visibles para clientes reconectados.
