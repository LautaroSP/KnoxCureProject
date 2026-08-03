# Auditoría vanilla de Project Zomboid Build 42

Estado: completada contra la instalación local de Steam, build `24449119`.

Ruta auditada: `C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid`.

Esta auditoría fija los identificadores que puede usar el código. Si una futura
actualización de Build 42 los cambia, primero debe actualizarse este documento y
la lista blanca del mod.

## Clasificación

- **Directo**: se referencia el recurso vanilla sin copiarlo ni modificarlo.
- **Funcionalidad nueva**: el recurso visual sirve, pero Knox Cure aporta lógica.
- **Adaptable**: sirve como base y necesita icono, sonido o estado adicional.
- **Nuevo**: no se encontró un equivalente apropiado.

## Matriz de estaciones

| Estación | Recurso visual comprobado | Clasificación | Brecha |
|---|---|---|---|
| Camilla/banco médico | `Base.Mov_Gurney`, sprite `location_community_medical_01_72`; también existen las etiquetas moveable `Dentist_Patient_Chair`, `Patient_Chair`, `Hospital_Bed`, `Large_Medical_Bed` y `Stretcher_Bed` | Funcionalidad nueva | Menú, limpieza, autopsia y estado ocupado |
| Microscopio | `Base.Mov_Microscope`, sprite `location_community_medical_01_136` | Funcionalidad nueva | Examen de muestras y vínculo con proyecto |
| Centrífuga | Sin equivalente funcional apropiado | Nuevo | Modelo/sprite, icono y sonido propios |
| Frío | Refrigeradores y congeladores listados abajo | Funcionalidad nueva | Seguimiento acumulado de temperatura y caducidad |
| Analizador | Sin equivalente funcional apropiado | Nuevo | Modelo/sprite, icono y sonido propios |
| Sintetizador | Sin equivalente funcional apropiado | Nuevo | Modelo/sprite, icono y sonido propios |

Resultado: el máximo previsto se mantiene en **tres recursos visuales nuevos**:
centrífuga, analizador biológico y sintetizador. Durante el prototipo se permite
un sprite placeholder propio; los muebles vanilla siempre se referencian por ID.

## Muebles y sprites exactos

Los siguientes tipos proceden de los scripts generados de moveables de Build 42:

| Tipo de objeto | Sprite |
|---|---|
| `Base.Mov_DesktopComputer` | `appliances_com_01_72` |
| `Base.Mov_Microscope` | `location_community_medical_01_136` |
| `Base.Mov_Gurney` | `location_community_medical_01_72` |
| `Base.Mov_MetalStool` | `location_community_medical_01_10` |
| `Base.Mov_MobileBloodbag` | `location_community_medical_01_25` |
| `Base.Mov_MobileCounter` | `location_community_medical_01_49` |
| `Base.Mov_ScaleMedical` | `location_community_medical_01_9` |
| `Base.Mov_BlueFridge` | `appliances_refrigeration_01_4` |
| `Base.Mov_GreenFridge` | `appliances_refrigeration_01_12` |
| `Base.Mov_PopsicleFreezer` | `appliances_refrigeration_01_20` |
| `Base.Mov_IndustrialFridge` | `appliances_refrigeration_01_22` |
| `Base.Mov_FridgeMini` | `appliances_refrigeration_01_25` |
| `Base.Mov_PlainFridge` | `appliances_refrigeration_01_28` |
| `Base.Mov_RedFridge` | `appliances_refrigeration_01_32` |
| `Base.Mov_WhiteIndustrialFridge` | `appliances_refrigeration_01_40` |
| `Base.Mov_ChestFreezer` | `appliances_refrigeration_01_48` |
| `Base.Mov_WhiteFridge` | `appliances_refrigeration_01_0` |
| `Base.Mov_SteelFridge` | `appliances_refrigeration_01_8` |

Para muebles médicos multitile se usa primero el tipo moveable o la propiedad
`CustomName` en runtime; no se inventan números de sprite no comprobados.

## Objetos y protección reutilizables

Confirmados en los scripts/distribuciones vanilla: `Base.Scalpel`, tijeras
médicas, pinzas, portaagujas, lupa, mortero y mano, algodón, alcohol, vendas,
desinfectante, guantes, gafas de seguridad, respiradores, filtros, chaqueta de
médico, tanque de oxígeno, manguera de goma, chatarra electrónica, chatarra de
cobre, baterías y `Base.ScannerModule`.

No se encontró un disco duro/USB vanilla adecuado. Knox Cure define su propio
`ResearchDrive`. Tampoco se hallaron muestras biológicas genéricas aptas para el
flujo completo, por lo que las muestras y dosis son objetos propios. Existe
`Specimen_Brain` en loot científico y se conserva como ambientación, no como
sustituto de una muestra validada.

## Cadáveres y acciones

Implementaciones vanilla comprobadas:

- `media/lua/client/TimedActions/ISGrabCorpseAction.lua`: usa animación `Loot`,
  posición baja y `character:pickUpCorpse(body, "BwdDrag")`; conserva
  `lastPlayerGrabbed` en `modData`.
- `ISDropCorpseAction.lua` e `ISDropCorpseIntoContainer.lua`: soportan la
  mecánica nativa de arrastre.
- `zombie.iso.objects.IsoDeadBody`: posee ID de objeto, `modData`, identidad de
  zombi/jugador y serialización. La hora de muerte no ofrece un getter Lua
  público estable, así que Knox Cure registra `deathHours` en `OnZombieDead`.
- `Events.OnZombieDead` permite sellar el momento y perfil del cadáver. Cadáveres
  anteriores a la instalación se clasifican conservadoramente como degradados.

La autopsia no elimina el cadáver. El servidor marca el ID/modData del cuerpo
como utilizado antes de otorgar muestra o XP. Toda petición vuelve a comprobar
distancia, herramientas, estación y estado del cuerpo.

## Animaciones reutilizables

| Uso Knox Cure | Animación vanilla |
|---|---|
| Preparar, limpiar, extraer, cargar, reparar | `CharacterActionAnims.Bandage` o `Loot` |
| Leer protocolos y libros | `CharacterActionAnims.Read` |
| Escribir registro | patrón de `ISWriteSomething` con `Read` |
| Investigar planos | patrón de `ISResearchRecipe` con `Loot` |
| Arrastrar cadáver | sistema nativo `BwdDrag` |

No existe una animación dedicada a autopsia, centrífuga, terminal o sintetizador.
En v0.x se reutilizan Bandage/Loot/Read; una animación propia sólo se incorpora si
la prueba visual demuestra una brecha suficientemente visible.

## Sonidos reutilizables

Confirmados por los scripts vanilla:

- `FirstAidApplyBandage`, `FirstAidRemoveFromWound`, `FirstAidApplyStitch`,
  `FirstAidApplyAlcohol`, `FirstAidApplyWipes`, `FirstAidCleanRag`.
- `GeneratorRepair` para calibración/reparación mecánica.
- `OpenBook`, `CloseBook`, `PageFlipBook`, `OpenMagazine`.
- `OpenFridge`, `CloseFridge`, `PutItemInFridge`.
- `FridgeHumA` a `FridgeHumF` para frío energizado.
- `FactoryMachineAmbiance` como placeholder de maquinaria.

No se encontró un sonido específico para computadora, centrífuga o equipamiento
médico. Los tres equipos nuevos requieren sonidos propios antes de v1.0 si el
placeholder industrial resulta audible fuera de contexto.

## Profesiones, libros, recetas y planos

Build 42 define profesiones mediante `character_profession_definition`. Casos
comparables comprobados: Doctor (`Doctor=6`, `SmallBlade=1`), Nurse
(`Doctor=3`, más aptitudes físicas), Electrician (`Electricity=5`) y Metalworker
(`MetalWelding=4`). La profesión Forense puede definirse con costo `-2`,
`Doctor=4`, `SmallBlade=1`, `Butchering=1` y `GrantedRecipes` limitadas a
autopsias.

Los planos de Build 42 usan `Researchablerecipes` y la acción
`ISResearchRecipe`. Los libros secuenciales de autopsia necesitan lógica propia
para prerequisitos y límite de XP. No deben regalar protocolos científicos a la
profesión.

Distribuciones procedurales comprobadas:

- Sala `laboratory`: `Chemistry`, `ScienceMisc`, `TestingLab`; refrigeración
  médica mediante `FridgeMedical`.
- También existen `LaboratoryBooks`, `LaboratoryGasStorage` y
  `LaboratoryLockers`.
- Hospitales y clínicas pueden recibir libros/protocolos mediante sus listas
  médicas; universidades y bibliotecas mediante listas de libros; electrónica
  mediante distribuciones de tienda/taller electrónico.

La inserción se hará con `ProceduralDistributions.list.<nombre>.items` para que
funcione en mundos nuevos y en contenedores aún no explorados.

## Infección, persistencia y red

Referencias oficiales:

- [`BodyDamage`](https://projectzomboid.com/modding/zombie/characters/BodyDamage/BodyDamage.html):
  `isInfected`, `setInfected`, `setInfectionLevel`, tiempos/crecimiento y estado
  de infección falsa.
- [`IsoDeadBody`](https://projectzomboid.com/modding/zombie/iso/objects/IsoDeadBody.html):
  identidad, objeto, item, zombi/jugador y persistencia.

Patrones Lua comprobados:

- Cliente a servidor: `sendClientCommand`; recepción en
  `Events.OnClientCommand`.
- Servidor a cliente: `sendServerCommand`; recepción en
  `Events.OnServerCommand`.
- Datos globales: `ModData.getOrCreate` más transmisión/migración explícita.
- Datos de objetos: `object:getModData()` y `object:transmitModData()`.

Decisión: el progreso vive en la terminal/proyecto bajo una estructura con
`schemaVersion`. El cliente sólo solicita operaciones; el servidor valida y
consume cadáveres, muestras y dosis, y después replica el resultado. SP ejecuta
la misma ruta lógica. Las importaciones usan máximo de porcentaje y unión de
sets, nunca suma.

## Brechas confirmadas

1. Tres sprites/modelos propios: centrífuga, analizador y sintetizador.
2. Iconos propios para muestras, disco, registro, test y dosis.
3. Sonidos propios opcionales para los tres equipos nuevos antes de v1.0.
4. Acciones temporizadas y UI de proyecto completamente nuevas.
5. Seguimiento de frescura, temperatura y caducidad propio.
6. Validación servidor-autoritativa y bloqueo de operaciones propio.

No se redistribuirá ningún recurso vanilla: todos se referencian por nombre,
sprite o API.
