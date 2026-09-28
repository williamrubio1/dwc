# Especificación funcional consolidada – Plataforma Darwin Core

Soluctia SAS · Herbario Universidad de los Llanos (LLANOS) · Sep 27, 2026 · @Willam

## 1. Propósito y principios

La plataforma gestiona registros de ocurrencia bajo el estándar Darwin Core para el Herbario Universidad de los Llanos (LLANOS). A partir de esos registros genera sobres de herbario descargables en DOCX y PDF.

- Los datos almacenados son la única fuente de verdad; los documentos se generan bajo demanda y no se guardan.
- La vista previa representa el documento que se descargará, con la plantilla documental configurada.
- La plataforma conserva los datos y la información necesaria para reconstruir cualquier documento.
- La aplicación es abierta: su alcance final no está cerrado, por lo que la estructura debe admitir campos y reglas nuevas sin rediseño.

## 2. Perfiles, autenticación y datos de perfil

Hay tres perfiles: Administrador, Profesor y Estudiante. Solo se admiten cuentas con correo @unillanos.edu.co, salvo la del administrador.

| Perfil | Cómo se crea | Datos pedidos al crear la cuenta | Permisos principales |
| --- | --- | --- | --- |
| Administrador | Cuenta única precargada, usuario `admin` | — | Gestiona usuarios y roles, crea o habilita profesores, activa e inactiva códigos de clase, edita la plantilla del sobre, la tabla de tipos de organismo y los textos de ayuda, consulta, importa y exporta toda la base |
| Profesor | Lo crea o habilita el administrador | Nombre, documento, dependencia o programa, teléfono | Crea códigos de clase y rangos de `occurrenceID`, consulta y exporta los registros de sus clases (solo lectura) |
| Estudiante | Autorregistro con correo institucional | Nombre, documento, programa, semestre, código estudiantil, teléfono | Crea, edita y elimina sus propios registros sin aprobación; exporta y genera sobres de sus registros |

- **Administrador exento de reglas:** no le aplican la restricción de dominio, la vinculación a clase, los bloqueos de validación ni los de duplicados. Ve las advertencias, pero puede guardar igual.
- **Contraseña del administrador:** la contraseña inicial se entrega por canal privado, no en este documento. Se almacena cifrada (hash), como todas las contraseñas del sistema.
- **Datos de perfil:** los datos institucionales complementarios viven en el perfil del usuario y no forman parte del registro Darwin Core.
- **Estudiante sin código:** puede crear su cuenta, pero no puede registrar datos hasta vincular un código de clase activo.

## 3. Plantilla de datos Darwin Core

`Plantilla.csv` define la estructura estándar: 185 términos Darwin Core, con sus nombres técnicos originales. Ningún campo es obligatorio, porque los datos se completan por fases.

- **Formulario:** muestra los 185 campos, agrupados en secciones plegables según las clases Darwin Core: Registro, Ocurrencia, Organismo, Muestra, Evento, Ubicación, Contexto geológico, Identificación y Taxón.
- **Globos informativos:** cada campo tiene un globo con la definición oficial de Darwin Core en español y un ejemplo del formato esperado. El administrador puede editar estos textos.
- **Plantilla descargable:** disponible para todos los perfiles. Lleva los 185 encabezados y filas de ejemplo con datos ficticios o con el tipo de dato esperado en cada columna.
- **Importación:** acepta CSV y XLSX. El CSV se lee en UTF-8 con separador `;`; también se aceptan archivos en Latin-1 (ISO-8859-1), como el `Plantilla.csv` actual.
- **Exportación:** CSV en UTF-8 con separador `;` (se abre en Excel en español sin dañar las tildes) y XLSX.
- **Campos derivados automáticamente:** `year`, `month` y `day` (desde `eventDate`), `decimalLatitude` y `decimalLongitude` (desde las coordenadas textuales) y `modified` (fecha de última modificación).

## 4. Validaciones

Las fechas y las coordenadas bloquean el guardado hasta que se corrijan. Las demás inconsistencias solo generan advertencias.

| Validación | Regla | Efecto |
| --- | --- | --- |
| `eventDate` | Se guarda y exporta en formato ISO yyyy-mm-dd (2025-03-04); en pantalla se muestra dd/mm/aaaa | Bloquea si la fecha no es válida |
| `year`, `month`, `day` | Se calculan desde `eventDate`; en importación, si no coinciden, se pide corregir | Bloquea |
| Coordenadas textuales | `verbatimLatitude` y `verbatimLongitude` en grados, minutos y segundos, p. ej. N 03° 43' 56.8'' W 073° 50' 35.7''. Latitud 0–90°, longitud 0–180°, minutos y segundos menores de 60 | Bloquea si están mal escritas o fuera de rango |
| Coordenadas decimales | Se calculan desde las textuales: punto decimal, negativo para Oeste y Sur (3.73244, -73.84325) | Bloquea si están fuera de rango |
| Taxonomía inconsistente | Epíteto con nombre completo, género distinto al de `scientificName`, mayúsculas | Advertencia |
| Elevación | `verbatimElevation` distinta del rango mínimo–máximo | Advertencia |
| Espacios sobrantes | Espacios al inicio, al final o dobles | Advertencia |
| Campos mal usados | Valor que no corresponde a la definición del término | Advertencia |

- Los campos con formato especial muestran un globo informativo con el formato esperado y un ejemplo.
- En la importación masiva se listan, antes de guardar, la fila, el campo y el motivo de cada error. El usuario corrige y vuelve a validar.

## 5. Registros, estados e historial

Cada registro guarda sus datos Darwin Core separados de los metadatos administrativos. El estudiante edita sus registros sin aprobación.

**Metadatos administrativos:** identificador interno único, usuario creador, clase y profesor asociados al crearlo, fecha y hora de creación, fecha y hora de última modificación, versión de datos, estado de validación y marca de eliminación lógica.

**Estados de validación.** Los asigna el sistema automáticamente. Su significado aparece en una leyenda visible en el listado de registros y en un globo junto a cada estado.

| Estado | Significado |
| --- | --- |
| Incompleto | Falta al menos uno de los campos que imprime el sobre |
| Con advertencias | Tiene los campos del sobre, pero presenta inconsistencias permitidas (sección 4) |
| Completo para sobre | Tiene todos los campos del sobre y ninguna advertencia |

**Historial de modificaciones:** cada cambio guarda la fecha y hora, el usuario y, por cada campo modificado, el valor anterior y el nuevo. Toda edición incrementa la versión de datos y actualiza `modified`.

**Eliminación:** es lógica. Antes de eliminar, el sistema advierte si el registro pertenece a una clase o participó en generaciones anteriores. El registro eliminado desaparece de las vistas y exportaciones, pero se conserva para auditoría. Su `occurrenceID` no se reutiliza.

## 6. Detección de duplicados

Un registro es posible duplicado cuando coinciden a la vez `occurrenceID`, `license`, `recordNumber` y `fieldNotes`, comparados contra toda la base.

1. **Cuándo se evalúa:** solo si al menos uno de los cuatro campos tiene valor. Así los registros en fase inicial, con los cuatro vacíos, no se marcan entre sí.
2. **Vacíos:** una vez evaluado, vacío contra vacío cuenta como coincidencia.
3. **Normalización para comparar:** ignora espacios sobrantes (al inicio, al final y dobles), mayúsculas y tildes. Los valores se guardan tal como se escribieron.
4. **Alcance:** toda la base de registros activos. En importación, también contra las filas anteriores del mismo archivo.
5. **Importación:** los duplicados exactos dentro de una misma carga se bloquean.
6. **Aviso al usuario:** antes de completar la operación se muestran el número de fila, los campos coincidentes y el identificador del registro existente. El usuario puede cancelar o revisar.
7. **Administrador:** ve el aviso, pero puede guardar.

`license` contiene el nombre de la profesora, por decisión institucional. Si los datos se publican en SiB Colombia o GBIF, ese campo deberá llevar una licencia real (p. ej. CC-BY-4.0); el titular ya consta en `rightsHolder`.

## 7. Clases, rangos de occurrenceID y vinculación

Cada clase tiene un rango de números de catálogo definido por su profesor. La plataforma asigna el `occurrenceID` automáticamente al crear cada registro.

**Código de clase:** identificador interno, código único de vinculación, profesor propietario, nombre de la clase o asignatura, fecha de creación, estado (activo o inactivo), periodo académico y rango de `occurrenceID`.

**Rango de `occurrenceID`:**

- El profesor define el prefijo (p. ej. `UniLlanos:LLANOS:`), el número inicial y el número final. El prefijo puede corresponder a cualquier herbario del país.
- El sistema impide que dos rangos con el mismo prefijo se superpongan, en toda la base.
- Cada registro nuevo toma el siguiente número libre del rango de su clase. El estudiante no puede editarlo; el administrador sí.
- Si el rango se agota, el estudiante no puede crear registros hasta que el profesor lo amplíe.
- Los números de registros eliminados no se reutilizan.

**Vinculación del estudiante:**

1. El estudiante ingresa el código en su perfil.
2. El sistema valida que exista, esté activo, pertenezca a un profesor registrado y admita nuevas vinculaciones.
3. Desde ese momento, sus registros nuevos quedan asociados a esa clase y a ese profesor.
4. Si cambia de código, sus registros anteriores conservan la clase original. No se reasignan en ningún sentido.

## 8. Seguimiento del profesor y exportación

El profesor consulta en modo de solo lectura los registros de las clases que creó. La exportación entrega únicamente los campos Darwin Core de la tabla.

**Consultas del profesor:** sus códigos activos e inactivos; registros filtrados por código de clase, fecha de creación, fecha de modificación y `recordNumber`; estudiantes vinculados y búsqueda por correo institucional; detalle e historial de cada registro.

**Exportación:**

| Perfil | Alcance | Filtros |
| --- | --- | --- |
| Estudiante | Sus propios registros | Fecha, `recordNumber`, clase |
| Profesor | Registros de sus clases | Fecha, `recordNumber`, clase, estudiante |
| Administrador | Toda la base | Todos |

- Formatos: XLSX y CSV (UTF-8, separador `;`).
- Columnas: los 185 términos Darwin Core con sus nombres técnicos y los valores tal como se guardaron. No incluye metadatos administrativos ni registros eliminados.
- La exportación es independiente de la generación de sobres.

## 9. Plantilla documental del sobre

El sobre replica `SobresMusgos.docx`: hoja Carta (21,6 × 27,9 cm), un sobre por hoja, con marcas de doblez (+) y la etiqueta en la mitad inferior.

**Formato:** márgenes de 2,5 cm arriba y abajo y 3 cm a los lados, como en el modelo. Título en fuente sin serifa, negrita y centrado; cuerpo en fuente con serifa. Las dos fuentes se incrustan en el PDF para que coincida con el DOCX.

**Mapeo de campos:**

| Línea del sobre | Origen | Presentación |
| --- | --- | --- |
| HERBARIO UNIVERSIDAD DE LOS LLANOS (LLANOS) | Texto configurable por el administrador | Negrita, centrado |
| Familia | `family` | Mayúsculas, alineada a la derecha |
| Nombre científico | `scientificName` + `scientificNameAuthorship` | Nombre en cursiva, autoría completa tal como está guardada |
| Det. | `identifiedBy` | Todos los nombres registrados |
| Tipo de organismo | Derivado de `phylum` (tabla siguiente) | Seguido de punto, p. ej. "Musgo." |
| Localidad | `country`, `stateProvince`, `municipality`, `locality` | País en mayúsculas y negrita, resto separado por comas |
| Coordenadas | `verbatimLatitude`, `verbatimLongitude` | Formato N 04°09'12,8'' W 73°39'21,0'' |
| Alt. | `verbatimElevation`; si está vacío, `minimumElevationInMeters`–`maximumElevationInMeters` | "583 msnm" |
| Fecha | `eventDate` | Formato largo, p. ej. "4 de marzo de 2025", a la derecha |
| Número y colector | Parte numérica final de `recordNumber` + primer nombre de `recordedBy` | Número en negrita, p. ej. **2381** M. Medina |

Si un campo está vacío, su línea se omite en el sobre.

**Tipo de organismo según `phylum`** (tabla editable por el administrador, que puede agregar, modificar o eliminar filas):

| phylum | Tipo impreso |
| --- | --- |
| Bryophyta | Musgo |
| Marchantiophyta | Hepática |
| Anthocerotophyta | Antocero |
| Ascomycota | Liquen |
| Basidiomycota | Liquen |

## 10. Generación, vista previa y trazabilidad

Los sobres se generan bajo demanda en DOCX o PDF, siempre con los datos vigentes, y no se almacenan.

- **Modalidades:** un sobre individual, o un documento consolidado con los registros seleccionados (un sobre por página).
- **Vista previa:** muestra el documento que se descargará. Desde ella el usuario puede volver al registro, corregirlo y regenerar.
- **Registros incompletos:** se pueden generar; la vista previa advierte que el registro está en estado Incompleto.
- **Metadatos de cada generación:** identificador, usuario, fecha y hora, registros incluidos con su versión de datos, modalidad, formato y tamaño de hoja.
- **Trazabilidad:** con esos metadatos se puede saber qué registros y versiones se usaron en una generación anterior, sin conservar el archivo.
- Editar un registro no genera documentos automáticamente.

## 11. Advertencias sobre los datos de ejemplo

Si las 10 filas de `Plantilla.csv` se cargan tal como están, la plataforma bloqueará varias hasta que se corrijan.

| Dato | Problema | Efecto al importar |
| --- | --- | --- |
| `eventDate` 2025-03-04 con `month` 4 y `day` 3 | Día y mes no coinciden con la fecha | Bloquea |
| `decimalLongitude` 73,84… | Positiva, con coma decimal; debe ser -73.84… | Se recalcula desde las coordenadas textuales |
| `verbatimCoordinates` "N 33°" y "W 0,73°" | Errores de digitación | Bloquea |
| `decimalLongitude` "73.84130." | Punto final sobrante | Se recalcula desde las coordenadas textuales |
| `specificEpithet`, `genus` | Nombre completo en el epíteto; "Leptugium" frente a "leptogium" | Advertencia |
| Elevación 589 frente a rango 589–750 | Inconsistente | Advertencia |
| "CO ", "Fungi ", "Aceptado " | Espacios sobrantes | Advertencia |
| `higherGeographyID` | Contiene una ruta de texto, no un identificador | Advertencia |

El comentario del modelo del sobre ("3 registros para 1095, SD") muestra que en la base anterior hay duplicados por número de colector. Si esos datos se migran, la regla de la sección 6 los detectará.
