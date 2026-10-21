# Darwin Core — Herbario Universidad de los Llanos (LLANOS)

Plataforma de registros de ocurrencia bajo el estándar Darwin Core, con generación de sobres de herbario en DOCX/PDF. Implementada según la "Especificación funcional consolidada — Plataforma Darwin Core".

## Stack

- Node.js 22.x, Express, EJS, sesiones de servidor.
- MySQL 8.x (ver `db/schema.sql`).
- Generación de documentos: `docx` (DOCX) y `pdfkit` (PDF).
- Import/export: `csv-parse`, `csv-stringify`, `exceljs`.

## Configuración local

1. `npm install`
2. Copiar `.env.example` a `.env` y completar credenciales de MySQL y `ADMIN_INITIAL_PASSWORD`.
3. Crear la base de datos primero (en hosting compartido tipo Hostinger, desde hPanel) y luego importar `db/schema.sql` **con esa base ya seleccionada** — el script no crea la base ni hace `USE`, solo crea las tablas dentro de la base activa.
4. `npm start` (o `npm run dev` para reinicio automático).

Al primer arranque, si no existe la cuenta `admin`, se crea automáticamente usando `ADMIN_INITIAL_PASSWORD`. Cambie esa contraseña después del primer ingreso; no queda registrada en el repositorio.

## Estructura

- `data/dwc-terms.json`: los 185 términos Darwin Core (sección, etiqueta, definición y ejemplo), extraídos de `Definiciones.csv`/`Plantilla.csv` y usados para el formulario, los globos de ayuda y la tabla `dwc_term_help`.
- `db/schema.sql`: esquema completo (usuarios, códigos de clase, registros de ocurrencia con los 185 campos, historial, tipos de organismo, generación de sobres).
- `src/`: aplicación Express (rutas, modelos, utilidades de validación/duplicados/importación/sobres, vistas EJS).
- `public/css/style.css`: estilos base, paleta clara y de bajo contraste.

## Decisiones e interpretaciones de la especificación

Algunos puntos de la especificación son ambiguos o, verificados con los datos de muestra reales (`Plantilla.csv`, `Definiciones.csv`), resultaban contradictorios. Se optó por lo siguiente, verificado con pruebas funcionales de extremo a extremo:

- **Duplicados (sección 6):** el texto menciona comparar `occurrenceID, license, recordNumber, fieldNotes` a la vez. Como `occurrenceID` lo asigna el sistema y es único (sección 7), dos registros activos nunca podrían coincidir en ese campo — aplicado literalmente, la regla nunca se dispara (se comprobó en pruebas). Se compara por `license`, `recordNumber` y `fieldNotes`, que es lo que el ejemplo narrativo de la sección 11 espera detectar.
- **occurrenceID en importación:** el estudiante no puede editar `occurrenceID` (sección 7). Al importar un archivo que ya trae valores en esa columna (como el propio `Plantilla.csv` de ejemplo), el sistema los ignora y asigna números nuevos del rango de la clase, igual que en el formulario individual. Un administrador sí puede aportar su propio `occurrenceID` (p. ej. para migrar datos históricos).
- **Coordenadas verbatim:** el texto de la sección 4 ejemplifica `verbatimLatitude`/`verbatimLongitude` con letra de hemisferio ("N 03° 43' 56.8''"), pero los datos reales de `Plantilla.csv` la omiten en esos dos campos (solo aparece combinada en `verbatimCoordinates`). El sistema acepta ambos formatos; si falta la letra, asume Norte/Oeste (hemisferio de esta colección). El sobre siempre imprime la letra.
- **Espacios sobrantes:** los valores se guardan tal como se escriben (sin recortar espacios), para poder advertir sobre ellos y para cumplir la sección 6 ("los valores se guardan tal como se escribieron").
- **"Campos mal usados" (sección 4):** no se implementó una detección genérica (no es automatizable sin reglas por campo); las demás advertencias de la tabla sí están implementadas (taxonomía, elevación, espacios).
- **Sobre (DOCX/PDF):** todo en Times New Roman 12 pt (en el PDF, la fuente estándar Times, de métricas idénticas, sin incrustar archivos de fuente). Las posiciones salen del modelo aprobado `SobresMusgos.docx` medido con Word: marcas de doblez en 3,70" y 7,53", etiqueta de 7,69" a 10,37" con posición absoluta (el modelo ignora el margen inferior), y "Det." centrado en 3,78" como en el modelo. DOCX y PDF se generan desde la misma especificación (`src/utils/envelope.js`) y coinciden con el modelo a ±0,03". La cursiva solo va en el nombre científico (no en la autoría ni en abreviaturas como "sp."). Si la localidad es larga y la última línea se acerca a 0,2" del borde, se reduce solo la letra de la localidad (mínimo 8 pt). Los resaltados amarillos del modelo son marcas de revisión de ese ejemplo y no se imprimen.

## Pruebas realizadas

Se validó end-to-end contra una base MySQL real (Docker, efímera): alta de administrador/profesor/estudiante, creación de código de clase y rangos (incluida la validación de solapamiento), vinculación de estudiante, creación de registros con bloqueos y advertencias, detección de duplicados, importación del `Plantilla.csv` real (bloquea las 10 filas de ejemplo por la inconsistencia año/mes/día frente a `eventDate`, tal como anticipa la sección 11), generación de sobres en DOCX/PDF, exportación CSV/XLSX y navegación de todas las páginas en los tres roles.
