-- ============================================================
-- Darwin Core - Herbario Universidad de los Llanos (LLANOS)
-- Esquema de base de datos (MySQL 8.x, InnoDB, utf8mb4)
-- Generado a partir de la Especificacion funcional consolidada
-- y de Plantilla.csv / Definiciones.csv (185 terminos Darwin Core)
-- ============================================================

-- En hosting compartido (p. ej. Hostinger) la base ya existe (se crea desde
-- hPanel con su propio nombre con prefijo, no aqui) y el usuario solo tiene
-- permisos sobre ella. Este script no crea ni cambia de base: importelo con
-- esa base ya seleccionada/abierta en phpMyAdmin (o con `mysql <basename> < schema.sql`).

-- ------------------------------------------------------------
-- Usuarios y perfiles (administrador, profesor, estudiante)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  role ENUM('administrador','profesor','estudiante') NOT NULL,
  username VARCHAR(100) NOT NULL UNIQUE,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  nombre VARCHAR(255) NULL,
  documento VARCHAR(50) NULL,
  dependencia_programa VARCHAR(255) NULL,
  telefono VARCHAR(50) NULL,
  programa VARCHAR(255) NULL,
  semestre VARCHAR(20) NULL,
  codigo_estudiantil VARCHAR(50) NULL,
  current_class_code_id INT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_email_dominio CHECK (
    role = 'administrador' OR email LIKE '%@unillanos.edu.co'
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Codigos de clase y rangos de occurrenceID (seccion 7)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS class_codes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  codigo_unico VARCHAR(50) NOT NULL UNIQUE,
  profesor_id INT NOT NULL,
  nombre_clase VARCHAR(255) NOT NULL,
  periodo_academico VARCHAR(50) NULL,
  estado ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
  prefijo_occurrence_id VARCHAR(100) NOT NULL,
  rango_inicial BIGINT NOT NULL,
  rango_final BIGINT NOT NULL,
  siguiente_numero BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_class_codes_profesor FOREIGN KEY (profesor_id) REFERENCES users(id),
  CONSTRAINT chk_rango CHECK (rango_final >= rango_inicial)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE users
  ADD CONSTRAINT fk_users_current_class FOREIGN KEY (current_class_code_id) REFERENCES class_codes(id);

-- ------------------------------------------------------------
-- Tipos de organismo segun phylum (seccion 9, editable por admin)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS organism_types (
  id INT AUTO_INCREMENT PRIMARY KEY,
  phylum VARCHAR(255) NOT NULL UNIQUE,
  tipo_impreso VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO organism_types (phylum, tipo_impreso) VALUES
  ('Bryophyta', 'Musgo'),
  ('Marchantiophyta', 'Hepática'),
  ('Anthocerotophyta', 'Antocero'),
  ('Ascomycota', 'Liquen'),
  ('Basidiomycota', 'Liquen')
ON DUPLICATE KEY UPDATE tipo_impreso = VALUES(tipo_impreso);

-- ------------------------------------------------------------
-- Configuracion general de la plataforma (textos editables)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app_settings (
  clave VARCHAR(100) PRIMARY KEY,
  valor TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO app_settings (clave, valor) VALUES
  ('sobre_encabezado', 'HERBARIO UNIVERSIDAD DE LOS LLANOS (LLANOS)')
ON DUPLICATE KEY UPDATE valor = VALUES(valor);

-- ------------------------------------------------------------
-- Ayuda por termino Darwin Core (globos informativos, seccion 3)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwc_term_help (
  term VARCHAR(100) PRIMARY KEY,
  seccion VARCHAR(100) NOT NULL,
  etiqueta VARCHAR(255) NOT NULL,
  definicion TEXT NULL,
  ejemplo TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO dwc_term_help (term, seccion, etiqueta, definicion, ejemplo) VALUES
('occurrenceID', 'Registro', 'ID del Registro biológico', 'Un identificador único del registro biológico (observación, ejemplar, fotografía, etc.). 

En ausencia de un identificador único global persistente, se recomienda construir uno a partir de la combinación:

Cuando pertenece a una observación: [código corto de la institución]:[palabra(s) clave del recurso]:[número de campo/número consecutivo] 
Cuando pertenece a una colección: [código corto de la institución]:[código de la colección]:[número de catálogo]. No debe contener espacios en blanco o caracteres especiales.

Si usted ya maneja en su conjunto de datos un identificador único por registros biológico, puede usarlo como identificador en el conjunto de datos.', 'Promigas:Compensacion-SanJuan:Fauna-00001
UCO:RESCATE_FAUNA_MULATOSII:1
UNIVALLE:CRM-UV:1974-001-1'),
('basisOfRecord', 'Ocurrencia', 'Base del registro', 'Denota el origen o evidencia específica de la que se deriva el organismo. Documente este elemento de acuerdo a las definiciones e indicaciones que acompañan el vocabulario controlado. Para este elemento se debe emplear el vocabulario controlado en inglés.

Sólo las colecciones biológicas pueden documentar PreservedSpecimen, si el registro corresponde a un espécimen depositado, pero el reporte no lo genera la colección biológica, se documenta HumanObservation y se documentan los elementos collectionCode, catalogNumber y disposition.', 'PreservedSpecimen
LivingSpecimen
HumanObservation
MachineObservation
MaterialSample
FossilSpecimen'),
('type', 'Ocurrencia', 'Tipo', 'Especifica el tipo de evidencia que da origen al registro, ampliando la información presente en el elemento basisOfRecord. Documente este elemento de acuerdo a las definiciones e indicaciones que acompañan el vocabulario controlado.', 'PhysicalObject
Event
StillImage
MovingImage
Sound'),
('institutionCode', 'Ocurrencia', 'Código de la institución', 'El nombre completo de la institución que custodia el espécimen o la información del registro; seguido por su acrónimo en paréntesis, si tiene.', 'Ministerio de Ambiente y Desarrollo Sostenible (MADS)
Universidad de Antioquia (UdeA)
Jardín Botánico de Bogotá José Celestino Mutis (JBB)'),
('institutionID', 'Ocurrencia', 'ID de la institución', 'Un identificador, preferiblemente el NIT, de la institución registrada en el elemento institutionCode.', '586.697.465-1
890.105.528-3
860.030.197-0'),
('collectionCode', 'Ocurrencia', 'Código de la colección', 'El nombre, acrónimo, código alfanumérico, o iniciales que identifican la colección o conjunto de datos del que procede el organismo. Aunque es válido el uso del acrónimo que implemente la colección internamente, se recomienda hacer uso del acrónimo registrado en:

- GBIF Registry of Scientific Collections (https://www.gbif.org/grscicoll/collection/search)
- Registro Único Nacional de Colecciones Biológicas-RNC (http://rnc.humboldt.org.co/admin/index.php/registros/colecciones)', 'COL
ANDES-E
FMB'),
('collectionID', 'Ocurrencia', 'ID de la colección', 'Un identificador de la colección registrada en el elemento collectionCode. Se recomienda hacer uso de los identificadores registrados en:

-  GBIF Registry of Scientific Collections (https://www.gbif.org/grscicoll/collection/search)
-  Registro Único Nacional de Colecciones Biológicas-RNC (http://rnc.humboldt.org.co/admin/index.php/registros/colecciones)', 'https://www.gbif.org/grscicoll/collection/0d0e813e-dc60-4357-82b1-810d0af640a5
RNC:250'),
('catalogNumber', 'Registro', 'Número de catálogo', 'Un identificador (preferiblemente único) asignado al espécimen, muestra o lote en la colección biológica. Puede repetirse en caso de que los especímenes están agrupados en la colección (Lote, Frasco, Caja, etc).

Debe documentarse de la misma forma que está en la etiqueta.', '00001
1974-001-1
1732a
ANDES-E0813
Lepid0784'),
('datasetName', 'Ocurrencia', 'Nombre del conjunto de datos', 'El nombre del conjunto de datos del cual se deriva el registro biológico.

Para documentar la información de permiso utilice la Extensión de permisos GGBN (GGBN Permit Extension).', 'Colombia Bio
Fondo Adaptación
Boyacá Bio
Proyecto elitros del campo
Cenipalma'),
('datasetID', 'Ocurrencia', 'ID del conjunto de datos', 'Un identificador del conjunto de datos del cual se deriva el registro biológico (observación, colecta o evento). 

Para documentar la información de permisio utiliice la Extensión de permisos GGBN (GGBN Permit Extension).', 'b15d4952-7d20-46f1-8a3e-556a512b04c5
doi.org/10.15472/zi9yqb
IAvH:CE16-062:8956:2016
SINCHI:CE17-845:2017'),
('modified', 'Ocurrencia', 'Modificado', 'La fecha más reciente en la que se haya modificado el registro. Debe estar documentada en el esquema de codificación ISO 8601 (AAAA-MM-DD o para un intervalo de fechas: AAAA-MM-DD/AAAA-MM-DD).', '2010
2010-01
2010-01-17
2009/2010
2009-02/2010-01
2009-02/10
2009-02-12/2009-10-08
2010-01-17/18'),
('language', 'Ocurrencia', 'Idioma', 'El idioma del conjunto de datos.

Documente este elemento de acuerdo al vocabulario controlado de la norma ISO 639-1 de 2 letras en minúscula, como se muestra a continuación:
es (=Para español)
en (=Para inglés)', 'es
en'),
('license', 'Ocurrencia', 'Licencia', 'Información sobre los derechos, licencias o permisos que establece el publicador sobre el uso del recurso. Se recomienda no documentar este elemento debido a que la licencia se especifica con mayor detalle en los metadatos que acompañan la publicación del conjunto de datos.', ''),
('rightsHolder', 'Ocurrencia', 'Titular de los derechos', 'El nombre de persona u organización propietaria o administradora de los derechos sobre el recurso.', 'Secretaria de Agricultura
Ministerio de Medio Ambiente
Secretaría Distrital de Ambiente'),
('accessRights', 'Ocurrencia', 'Derechos de acceso', 'Información sobre los derechos de acceso o restricciones basadas en políticas de privacidad, seguridad, u otras.', 'Sólo para uso no comercial.'),
('bibliographicCitation', 'Ocurrencia', 'Citación bibliográfica', 'Indica la manera de citar el registro cuando sea utilizado, incluyendo la referencia del recurso al que pertenece el registro. Se recomienda incluir el doi si se tiene junto con los detalles bibliográficos para identificar el recurso claramente.', 'Raz L, Agudelo H (2019). Herbario Nacional Colombiano (COL). Versión 13.12. Universidad Nacional de Colombia. Occurrence dataset https://doi.org/10.15472/ea8sek. occurrenceID: 1a399be0-9ca9-4efe-84be-b8974a5548fc'),
('references', 'Ocurrencia', 'Referencias', 'Una URL a un recurso asociado, el cual es de alguna forma referenciado o citado por el registro descrito.', 'http://arctos.database.museum/guid/MVZ:Mamm:165861
https://www.gbif.org/species/2474724'),
('ownerInstitutionCode', 'Ocurrencia', 'Código de la institución propietaria', 'El nombre completo (o acrónimo) de la institución que tiene la propiedad del objeto o de la información consignada en el registro. Usar sólo si la organización propietaria de los datos es diferente a la organización publicadora consignada en el elemento institutionCode.', 'Ministerio de Ambiente y Desarrollo Sostenible (MADS)
Celsia S.A. E.S.P.'),
('informationWithheld', 'Ocurrencia', 'Información retenida', 'Información adicional que existe sobre el registro, pero que no ha sido compartida en la publicación.', 'La información de ubicación no es provista para especies amenazadas
La identidad de los colectores es retenida
Pregunte acerca de muestras de tejido'),
('dataGeneralizations', 'Ocurrencia', 'Generalización de los datos', 'Medidas adoptadas para que los datos compartidos sean menos específicos o completos. Sugiere que los datos con mayor detalle existen y pueden estar disponibles bajo petición.', 'Coordenadas generalizadas a partir de las coordenadas originales del GPS a la celda más cercana de la grilla'),
('dynamicProperties', 'Ocurrencia', 'Propiedades dinámicas', 'Una lista de las medidas, hechos o características adicionales sobre el organismo. Su intención es proporcionar un mecanismo estructurado para la representación de los datos. Debe estar documentado en el esquema de codificación JSON {"Medida":"Valor"}. Por facilidad en la documentación se recomienda el uso de la extensión del estándar Darwin Core de Medidas y Hechos en lugar de este elemento.', '{"pesoEnGramos":"120", "evidenciaDeLaIdentificación": "secuencia de citocromo B"}
{"alturaEnMetros":"1.5", "distribuciónDelTaxón": "Amazonas, Colombia", "temperaturaDelAireEnCelsius": "22"}
{"naturalezaDelID":"identificación de experto"}'),
('recordNumber', 'Registro', 'Número del registro', 'Un identificador dado al registro biológico en el momento en que fue registrado, sirve como un vínculo entre las anotaciones de campo y el registro biológico. No es el mismo catalogNumber, el cual es usualmente asignado una vez el espécimen ingresa a la colección.', 'OPP 7107
JARM-0008
AFT 143'),
('recordedBy', 'Registro', 'Registrado por', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los nombres de las personas (observadores o recolectores) responsables de realizar el registro.

El colector u observador principal, especialmente si está asociado al recordNumber tomado en campo, se debe listar en primer lugar. Se debe mantener el mismo formato del nombre a lo largo de todos los registros y se recomienda evitar el uso de solo iniciales ya que esto genera ambigüedades para reconocer a las personas que realizaron el registro, de ser posible siempre escriba nombres completos. Documente el nombre de las personas y evite documentar nombres de grupos u organizaciones.', 'Eduardo Amat García
Javier Maldonado Ocampo
Mónica Andrea Sánchez Torres | Esteban Andrés Novoa López'),
('recordedByID', 'Registro', 'ID del colector', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los ID de las personas (observadores o recolectores), grupos u organizaciones responsables de realizar el registro. Estos identificadores deben corresponder al ORCID, Wikidata u algún otro identificador único controlado. El orden en este elemento no indica una prioridad en la citación ni ningún otro tipo de relación jerárquica.', 'https://orcid.org/0000-0001-6215-3617 | https://orcid.org/0000-0003-1691-239X
https://www.wikidata.org/entity/Q28913658'),
('organismID', 'Organismo', 'ID del organismo', 'Un identificador del organismo. Pretende facilitar el remuestreo del mismo individuo con fines generalmente de monitoreo. Aves anilladas, fotos de mamíferos acuáticos, árboles remuestreados, etc.', 'U.amer. 44
CC09477
Orca J 23'),
('individualCount', 'Registro', 'Número de individuos', 'Número de individuos presentes en el momento del registro biológico (observación, ejemplar, fotografía, etc.).
Utilice este elemento si todos los conteos corresponden a individuos, de lo contrario utilice organismQuantity y organismQuanitityType.', '1
25
282'),
('organismQuantity', 'Registro', 'Cantidad del organismo', 'Valor que representa una cantidad colectada u observada del organismo, expresada en un sistema de medida estándar para el organismo como cepas, células, porcentaje de biomasa, etc. Documentar este elemento junto con el elemento organismQuantityType.

El sistema de medida se debe documentar en el elemento organismQuantityType, como se muestra en el ejemplo a continuación:

Para el registro de cobertura de líquenes: organismQuantity: 30 / organismQuantityType: % de cobertura
Para la abundancia de fitoplancton: organismQuantity: 253 / organismQuantityType: Células/L
Para comunidades vegetales: organismQuantity: r / organismQuantityType: Escala Braun-Blanquet', '30
253
r'),
('organismQuantityType', 'Registro', 'Tipo de cantidad del organismo', 'Valor que representa una cantidad colectada u observada del organismo, expresada en un sistema de medida estándar para el organismo como cepas, células, porcentaje de biomasa, etc. Documentar este elemento junto con el elemento organismQuantityType.

La cantidad de organismos se debe documentar en el elemento organismQuantity, como se muestra a continuación:

Para el registro de cobertura de líquenes: organismQuantity: 30 / organismQuantityType: % de cobertura
Para la abundancia de fitoplancton: organismQuantity: 253 / organismQuantityType: Células/L
Para comunidades vegetales: organismQuantity: r / organismQuantityType: Escala Braun-Blanquet', 'Porcentaje de cobertura
Células/L
Escala Braun-Blanquet'),
('organismName', 'Organismo', 'Nombre del organismo', 'El nombre textual dado a un organismo en un estudio o el nombre en la etiqueta asignada originalmente.', 'Huberta
Willy la Ballena Asesina
Cheeta'),
('organismScope', 'Organismo', 'Alcance del organismo', 'Puede ser utilizado para indicar si la instancia del organismo representa un organismo discreto o un tipo particular de agregación. Se sugiere emplear un vocabulario controlado. Este elemento no está destinado a ser utilizado para especificar una categoría taxonómica.', 'Organismo multicelular
Manada
Clon
Colonia'),
('associatedOrganisms', 'Organismo', 'Organismos asociados', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los identificadores de otros organismos y su relación con el organismo documentado. Aplica para relaciones con organismos del mismo grupo taxonómico. Se recomienda hacer uso la extensión Resource Relationship para documentar en más detalle la relación entre los organismos asociados.', 'Hermano de: FMNH:Mamífero:1234 | Hermano de: FMNH:Mamífero:1235
Hijo de: MLS:sau:438'),
('previousIdentifications', 'Organismo', 'Identificaciones previas', 'Una lista (en una fila continua y separada por una barra vertical " | ") de asignaciones taxonómicas que se le han dado al organismo anteriormente. Puede contener la información de quién y cuándo realizó la identificación anterior. Se recomienda hacer uso de la extensión Identification (https://tools.gbif.org/dwca-validator/extension.do?id=dwc:Identification#Identification) para el caso de colecciones biológicas.', 'Pinus abies
Anthus sp., identificado en campo por G. Iglesias  | Anthus correndera, Identificado por el experto C. Cicero 2009-02-12 basado en morfología
Leptolyngbya cf. polysiphoniae | Leptolyngbya sp.'),
('organismRemarks', 'Organismo', 'Comentarios del organismo', 'Comentarios o anotaciones sobre el organismo registrado. Se recomienda que la longitud de la descripción no supere 20 palabras.', 'Uno de una camada de seis
Fruto inmaduro cubierto por un indumento rojizo'),
('sex', 'Registro', 'Sexo', 'El sexo de el(los) organismo(s) representado(s) en el registro. Si en un mismo registro cuenta con varios organismos de diferentes sexos, genere registros (filas) diferentes por cada sexo. 
Se recomienda el uso del vocabulario sugerido disponible para este elemento.', 'Hembra
Hermafrodita
Macho
Desconocido'),
('lifeStage', 'Registro', 'Etapa de desarrollo', 'La etapa de vida de el(los) organismo(s) en el momento del registro. Si en un mismo registro cuenta con varios organismos en diferentes etapas de vida, genere registros (filas) diferentes por cada etapa de vida. Se recomienda el uso del vocabulario sugerido disponible para este elemento.', 'Huevo
Juvenil
Adulto
Cigoto
Embrión
Larva
Esporófito
Espora
Gametofito
Gameto
Pupa
Plántula 
Floración
Fructificación'),
('reproductiveCondition', 'Registro', 'Condición reproductiva', 'Condición reproductiva de el(los) organismo(s) en el momento del registro. Se recomienda el uso de un vocabulario controlado.', 'No reproductiva
En gestación
Floración
Fructificación'),
('caste', 'Registro', 'Casta', 'La categorización de individuos para especies eusociales de algunos artrópodos. Se recomienda el uso de un vocabulario controlado para cada taxón específico.', 'Reina
Macho alado
Intercasta
Trabajador menor
Soldado
Ergatoide'),
('vitality', 'Registro', 'Estado de vitalidad', 'Indicación de la vitalidad del organismo en el momento de la colecta u observación (vivo o muerto). 

Se requiere el uso de un vocabulario controlado. Usar este elemento en registros documentados como PreservedSpecimen, MaterialSample, o HumanObservation en el elemento basisOfRecord.', 'Vivo
Muerto
Grupo mixto
Incierto
No evaluado'),
('behavior', 'Registro', 'Comportamiento', 'Descripción del comportamiento de el(los) organismo(s) en el momento del registro. Se recomienda el uso de un vocabulario controlado.', 'Posando
Alimentándose
Corriendo'),
('establishmentMeans', 'Registro', 'Medios de establecimiento', 'Una afirmación que de cuenta si un organismo ha sido introducido a un lugar y tiempo determinado a través de actividad humana directa o indirecta. Documente este elemento de acuerdo a las definiciones e indicaciones que acompañan el vocabulario controlado. Para este elemento se debe emplear el vocabulario controlado en inglés. Se recomienda documentar este elemento acompañado de los elementos degreeOfEstablishment y pathway.

Actualmente el estándar DwC no posee un elemento que permita documentar de manera adecuada la información de endemismos, este elemento es el más cercano para la documentación de esta información por lo cual se incluye el vocabulario ''Endémica''.', 'native
introduced
vagrant
uncertain
Endémica'),
('degreeOfEstablishment', 'Registro', 'Grado de establecimiento', 'El grado en cual el organismo sobrevive, se reproduce y expande su rango de distribución en un lugar y tiempo determinado. Documente este elemento de acuerdo a las definiciones e indicaciones que acompañan el vocabulario controlado. Para este elemento se debe emplear el vocabulario controlado en inglés. Se recomienda documentar este elemento acompañado de los elementos establishmentMeans y pathway.', 'native
cultivated
released
established
colonising
widespreadInvasive'),
('pathway', 'Registro', 'Ruta de introducción', 'El proceso por el cual un organismo llegó a un lugar y tiempo determinado. Documente este elemento de acuerdo a las definiciones e indicaciones que acompañan el vocabulario controlado. Para este elemento se debe emplear el vocabulario controlado en inglés. Se recomienda documentar este elemento acompañado de los elementos establishmentMeans y degreeOfEstablishment.', 'releasedForUse
otherEscape
transportContaminant
transportStowaway
corridor
unaided'),
('occurrenceStatus', 'Registro', 'Estado del registro biológico', 'Estado que da cuenta de la presencia o ausencia de un taxón en una ubicación. Documente este elemento de acuerdo a las definiciones e indicaciones que acompañan el vocabulario controlado. Para este elemento se debe emplear el vocabulario controlado en inglés.', 'present
absent'),
('preparations', 'Registro', 'Preparaciones', 'Una lista (en una fila continua y separada por una barra vertical " | ") de las preparaciones y los métodos de conservación de un ejemplar o una muestra del ejemplar.

Adicionalmente, si el espécimen fue colectado bajo un permiso de recolección de especímenes o acceso a recursos genéticos, debe indicar si fue una colecta temporal o una colecta definitiva seguido por el tipo de preparación.', 'Colecta definitiva: Animal completo (ETOH)
Colecta definitiva: Preparación de muestra microbiológica
Colecta temporal: Extracción de ADN
Piel | Cráneo | Esqueleto
Animal completo (ETOH) | Tejido (EDTA)
Fósil
Molde
Fotografía'),
('disposition', 'Registro', 'Disposición', 'El estado actual de un espécimen en relación a la colección identificada en collectionCode o collectionID. Se recomienda el uso de un vocabulario controlado. Si el espécimen fue colectado bajo un permiso de recolección de especímenes o acceso a recursos genéticos y fue entregado a una colección biológica se debe documentar "En colección", de lo contrario dejar vacío el elemento.', 'En colección
Extraviado
Ejemplar testigo
Duplicados en otro lugar'),
('verbatimLabel', 'Registro', 'Etiqueta original', 'Una lista (en una fila continua y separada por una barra vertical " | ") de números de catálogos anteriores o alternos, u otros identificadores usados por personas para el mismo registro biológico, ya sea en el actual o cualquier otro conjunto de datos o colección.

El contenido de este elemento no debe incluir ningún tipo de embellecimiento, prefijos, encabezados u otras adiciones al texto original. Las abreviaciones no deben ser extendidas y posibles errores de tipeo no deben ser corregidos. Las nuevas líneas presentes en la etiqueta se deben representar utilizando una barra vertical  | . La práctica recomendada es utilizar solamente caracteres en la codificación UTF-8 y poner el comentario "El elemento verbatimLabel es derivado de una transcripción humana" en el elemento occurrenceRemarks.', 'CARACTERIZACION DE LA FLORA DEL DEPARTAMENTO DEL CASANARE | PIPER* | Peperomia quadrangularis (J.V.Thmps.) A. Dietr. | Det: M.P. Córdoba /sep 2011 | Enredadera | COLOMBIA: Dpto Casanare, Mpio Tauramena, Vda La Urama, Localidad La Mata de la Urama Lat: 5° 03,19,2 N, Long: 72° 48 58,8 W . Altitud: 182 m s.n.m., 28 Enero 2011. | Col: M .P.Córdoba, R. Ávila, L.Miranda y C. Pérez. | No. Col.: M.P.Córdoba 6161 | GOBERNACIÓN DEL CASANARE-WWF-FUNDACIÓN OMACHA | 119'),
('otherCatalogNumbers', 'Registro', 'Otros números de catálogo', 'Una lista (en una fila continua y separada por una barra vertical " | ") de números de catálogos anteriores o alternos, u otros identificadores usados por personas para el mismo registro biológico, ya sea en el actual o cualquier otro conjunto de datos o colección.', 'FMNH:Mammal:1234
NPS YELLO6778 | MBG 33424
ICN- 47992, Field series JDL 21151'),
('associatedMedia', 'Registro', 'Medios asociados', 'Un identificador del conjunto de datos del cual se deriva el registro biológico (observación, colecta o evento). 

Para documentar la información de permisio utilice la Extensión de permisos GGBN (GGBN Permit Extension)', 'https://sinchi.org.co/ciacol/ficha/24/Hypoclinemus%20mentalis
https://ia801004.us.archive.org/0/items/staphylococcusaureus/Staphylococcus%20aureus.JPG | https://ia903100.us.archive.org/33/items/CMPUJH012-macro/CMPUJH012-anverso.jpg'),
('associatedOccurrences', 'Registro', 'Registros biológicos asociados', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los identificadores de otros registros biológicos y su relación con este registro. Aplica para relaciones con organismos de diferente grupo taxonómico y se recomiendo documentar junto a el elemento associatedTaxa. Se recomienda hacer uso de la extensión Resource Relationship para documentar en más detalle la relación entre los registros biológicos asociados.', 'http://arctos.database.museum/guid/MSB:Mamm:292063?seid=3175067 | http://arctos.database.museum/guid/MSB:Mamm:292063?seid=3177393
SELVA:Anillamiento:AA7330a'),
('associatedReferences', 'Registro', 'Referencias asociadas', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los identificadores (publicación, referencia bibliográfica, identificador único global, URI) de la literatura asociada al registro biológico. Se recomienda hacer uso de la extensión Literature References la cual cuenta con más elementos para describir la información de referencias asociada.', 'http://www.sciencemag.org/cgi/content/abstract/322/5899/261
Christopher J. Conroy, Jennifer L. Neuwald. 2008. Phylogeographic study of the California vole, Microtus californicus Journal of Mammalogy, 89(3):755-767.'),
('associatedSequences', 'Registro', 'Secuencias asociadas', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los identificadores (publicación, identificador único global, URI) de la información de la secuencia genética asociada al registro biológico. Se recomienda hacer uso de la extensión GGBN Amplification Extensión la cual cuenta con más elementos para describir la información de secuencia genética asociada.', 'https://www.ncbi.nlm.nih.gov/nuccore/U34853.1
https://www.boldsystems.org/index.php/Public_RecordView?processid=ABBAC141-12'),
('associatedTaxa', 'Registro', 'Taxones asociados', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los identificadores o nombres de taxones y su asociación con el registro biológico.', 'Huésped: Quercus alba
Parásito: Apis mellifera'),
('occurrenceRemarks', 'Registro', 'Comentarios del registro biológico', 'Comentarios o anotaciones sobre el registro biológico. Se recomienda que la longitud de la descripción no supere 20 palabras.', 'Muerto en la vía
Registrado en el campus de la Universidad'),
('materialSampleID', 'Muestra', 'ID de muestra del material', 'Un identificador para muestras de material (no hace referencia a muestras digitales sino físicas, como exicados o tejidos). En ausencia de un identificador único global persistente, puede construir uno usando una combinación a partir del occurrenceID, de tal forma que el materialSampleID sea globalmente único. Se recomienda hacer uso de la extensión GGBN Material Sample Extension para documentar en más detalle la información relacionada con la muestra.', 'IAvH:IAvH-CT-1:Tejido
06809dc5-f143-459a-be1a-6f03e63fc083
IAvH-ABJ788'),
('parentEventID', 'Evento', 'ID parental del evento', 'Un identificador único para la categoría superior del evento de muestreo. Por ejemplo, el identificador del muestreo de un cuadrante, parcela o transecto independientemente del tiempo o temporada cuando se realice el muestreo. Este identificador es más general que el eventID y puede agrupar varios eventID.

Este elemento debe estar acompañado siempre del elemento eventID, como se muestra en el ejemplo a continuación:

A1 como parentEventID para identificar una parcela, cada sub-parcela con su propio eventID (A1:1, A1:2, etc.)
BENTOS como parentEventID para identificar un evento de muestreo y cada parte del evento con su propio eventID( BENTOS:E-1, BENTOS:E-2, etc.)', 'A1
BENTOS'),
('eventID', 'Evento', 'ID del evento', 'Un identificador único para el Evento de muestreo  - que ocurre en un lugar y tiempo determinado. Por ejemplo, el identificador del muestreo de un cuadrante, parcela o transecto en un tiempo o temporada específicos. Este identificador es más específico que el parentEventID.

Este elemento puede estar acompañado del elemento parentEventID, como se muestra en el ejemplo a continuación:

A1:1 | A1:2 como eventID para identificar cada sub-parcela perteneciente a la parcela A1
BENTOS:E-1 | BENTOS:E-2 como EventID para identificar cada parte del evento de muestreo perteneciente al evento BENTOS', 'A1:1
BENTOS:E-1'),
('eventType', 'Evento', 'Tipo de evento', 'La naturaleza del evento. Se recomienda el uso de un vocabulario controlado.', 'Muestra
Observación
Visita al sitio
Interacción biótica
Bioblitz
Expedición
Encuesta
Proyecto'),
('samplingProtocol', 'Evento', 'Protocolo de muestreo', 'El nombre, la descripción o la referencia del método o protocolo de muestreo usado para realizar el muestreo. Se recomienda acompañar este elemento con el elemento samplingEffort. 

Si un mismo evento cuenta con varios protocolos de muestreo diferentes, la recomendación es generar un evento (filas) diferente por cada protocolo de muestreo. En el caso que el evento agrupe múltiples protocolos que no puedan ser atribuidos a un registro particular, la práctica recomendada es separar los protocolos por una barra vertical  | .', 'Colecta fortuita
Trampa de luz UV
Red de niebla
Arrastre de fondo
Observación ad hoc
Punto de conteo'),
('sampleSizeValue', 'Evento', 'Valor del tamaño de la muestra', 'Un valor numérico para una medición del tamaño (duración de tiempo, longitud, área o volumen) de una muestra en un evento de muestreo. Documentar este elemento junto con el elemento sampleSizeUnit. Se recomienda hacer uso del Sistema Internacional de Unidades (SI) cuando sea posible.', '5.5
10
1'),
('sampleSizeUnit', 'Evento', 'Unidad del tamaño de la muestra', 'La unidad de medida de la magnitud (tiempo de duración, longitud, área o volumen) de una muestra en un evento de muestreo. Documentar este elemento junto con el elemento sampleSizeValue.', 'm (= Metros)
h (= Horas)
Trampas-noche
Litros'),
('samplingEffort', 'Evento', 'Esfuerzo de muestreo', 'El esfuerzo de muestreo en tiempo y/o espacio realizado durante el evento de muestreo. Documentar este elemento junto con el elemento samplingProtocol.', '40 trampas-noche
10 horas-observador
10 km caminando
30 km en carro
7 días-trampa
5 horas muestra por 30 eventos de muestreo'),
('eventDate', 'Evento', 'Fecha del evento', 'La fecha o el intervalo durante el cual se produjo el evento de observación o colecta de un organismo o muestra. No es adecuado para una fecha en un contexto geológico. Debe estar documentada en el esquema de codificación ISO 8601 (AAAA-MM-DD o para un intervalo de fechas: AAAA-MM-DD/AAAA-MM-DD).', '2010
2010-01
2010-01-17
2009/2010
2009-02/10
2010-01-17/18
2009-02/2010-01
2009-08-08/2009-10-26'),
('startDayOfYear', 'Evento', 'Día inicial del año', 'Día inicial del evento, contando a partir del primer día del año del evento y documentado en formato de números ordinales (siendo "1" el primero de enero y "365" el 31 de diciembre en año no bisiesto).', '1
220
365'),
('endDayOfYear', 'Evento', 'Día final del año', 'Día final del evento, contando a partir del primer día del año del evento y documentado en formato de números ordinales (siendo "1" el primero de enero y "365" el 31 de diciembre en año no bisiesto).', '30
300
366'),
('year', 'Evento', 'Año', 'Los cuatro dígitos del año durante el cual se produjo el evento de observación o colecta de un organismo o muestra.

Si el rango de fechas presente en EventDate abarca varios años, no debe documentar este elemento:
eventDate:2021-02-01/2022-05-23
year:
month:
day:', '2008
1901'),
('month', 'Evento', 'Mes', 'El mes en números enteros en que ocurrió durante el cual se produjo el evento de observación o colecta de un organismo o muestra.

Si el rango de fechas presente en EventDate abarca más de un mes, no debe documentar este elemento:
eventDate:2022-02-10/05-23
year:2022
month:
day:', '01
11'),
('day', 'Evento', 'Día', 'El día en números enteros durante el cual se produjo el evento de observación o colecta de un organismo o muestra.

Si el rango de fechas presente en EventDate se encuentra dentro del mismo mes, no debe documentar este elemento:
eventDate:2022-02-12/15
year:2022
month:02
day:', '09
28'),
('verbatimEventDate', 'Evento', 'Fecha original del evento', 'La representación textual original (según la libreta de campo, formato de datos, o etiqueta de colección) de la información de fecha durante la cual se produjo el evento de observación o colecta de un organismo o muestra.', 'primavera 1910
4/11/2020
marzo 2002
1999-03-XX
17IV1934'),
('eventTime', 'Evento', 'Hora del evento', 'La hora o el intervalo de horas en la cual se produjo el evento de observación o colecta de un organismo o muestra. Debe estar documentado en el esquema de codificación ISO 8601.', '14:07
08:40:21
13:00:00/15:30:00'),
('habitat', 'Evento', 'Hábitat', 'Una categoría estandarizada o la descripción del hábitat en el que ocurrió el evento.', 'Sabana de roble
Estepa de la pre-cordillera'),
('fieldNumber', 'Evento', 'Número de campo', 'Un identificador dado al evento en campo. A menudo sirve como un vínculo entre las anotaciones de campo y el evento.', 'RV Sol 87-03-08
MBZ-067'),
('fieldNotes', 'Evento', 'Notas de campo', 'Un indicador sobre la existencia o referencia (publicación URI) a las notas de campo; o el texto de las notas tomadas en campo sobre el evento.', 'Notas disponibles en la Biblioteca Grinnell-Miller
Este espécimen fue colectado en un árbol de caracolí, una nota de campo fue descrita para mencionar este evento, eran depredados por Epicrates maurus'),
('eventRemarks', 'Evento', 'Comentarios del evento', 'Comentarios o anotaciones sobre el evento. Se recomienda que la longitud de la descripción no supere 20 palabras.', 'Después de las lluvias recientes, el río estuvo cercano a un estado de desbordamiento'),
('locationID', 'Ubicación', 'ID de la ubicación', 'Un identificador de la región geográfica, división político administrativa o del sitio específico donde se realizó el registro.

Se sugiere utilizar un identificador persistente, como el código de la División Política Administrativa de Colombia - DANE, (http://www.dane.gov.co/Divipola) precedida por "CO:" o utilizar MarineRegions (marineregions.org) para regiones marinas, como se muestra a continuación:

CO:15572 (Código Divipola para el Municipio de Puerto Boyacá en Boyacá)
CO:68 (Código Divipola para el Departamento de Santander)
http://marineregions.org/mrgid/32556 (Islas del Rosario)', 'CO:15572
CO:68
http://marineregions.org/mrgid/32556
geonames.org/3674545/'),
('higherGeography', 'Ubicación', 'Geografía superior', 'Una lista (en una fila continua y separada por una barra vertical " | ") de la geografía inmediatamente superior al sitio o ubicación donde se realizó el registro. Si hay modificaciones en la localidad para estandarizar su contenido puede documentar en este elemento los datos originales (sin estandarizar) de esos términos.

Este elemento debe estar acompañado de otros elementos del estándar, como se muestra en el ejemplo a continuación:

América | Sudamérica | Colombia | Región del Pacífico | Valle del Cauca | La Cumbre | Bitaco (Con los valores resultantes de América del Sur en continent, Colombia en country, Valle del Cauca en stateProvince, La Cumbre en county y Bitaco en municipality).', 'América | Sudamérica | Colombia | Región del Pacífico | Valle del Cauca | La Cumbre | Bitaco'),
('higherGeographyID', 'Ubicación', 'ID de la geografía superior', 'Un identificador de la región geográfica inmediatamente superior a la ubicación donde se realizó el registro. Este identificador debe ser acorde con la geografía superior documentada en el elemento higherGeography.

CO:15572 (Código Divipola para el Municipio de Puerto Boyacá en Boyacá)
CO:68 (Código Divipola para el Departamento de Santander)
TGN: 7005075 (San Agustín (Huila), Colombia)', 'CO:15572
CO:68
TGN: 7005075'),
('continent', 'Ubicación', 'Continente', 'El nombre del continente en el que tiene lugar la ubicación. Documente este elemento de acuerdo a las definiciones e indicaciones que acompañan el vocabulario controlado.', 'América del Sur
América del Norte
Europa
África
Asia
Oceanía
Antártida'),
('waterBody', 'Ubicación', 'Cuerpo de agua', 'El nombre y tipo del cuerpo de agua en el que tiene lugar la ubicación. Se recomienda usar este elemento solamente si el evento ocurrió en el cuerpo de agua propiamente dicho, no en cercanías de este.', 'Mar Caribe
Océano Pacífico
Río Lebrija
Golfo de Urabá
Caño Mojana'),
('islandGroup', 'Ubicación', 'Grupo de islas', 'El nombre del grupo de islas en que tiene lugar la ubicación.', 'Cayos de Albuquerque
Islas del Rosario'),
('island', 'Ubicación', 'Isla', 'El nombre de la isla en o cerca al lugar de la ubicación.', 'Isla de Providencia
Isla Gorgona
Isla de Tierra Bomba'),
('country', 'Ubicación', 'País', 'El nombre del país o unidad administrativa de mayor jerarquía de la ubicación. Se recomienda utilizar un identificador persistente de un vocabulario controlado como el Tesauro Getty de Nombres Geográficos o la norma ISO 3166. Se recomienda acompañar este elemento con el elemento countryCode. 

La práctica recomendada es dejar este elemento en blanco si la información presente en la sección Ubicación abarca múltiples entidades en este mismo nivel administrativo o si hay incertidumbre sobre la entidad a la que corresponden los datos. Esta información de multiplicidad e incertidumbre se puede documentar en los elementos higherGeography y locality. Por ejemplo, si hay dos entidades "Colombia y Brasil", la recomendación es dejar este elemento vacío y dejar el comentario en higherGeography y locality.', 'Colombia
España
Dinamarca'),
('countryCode', 'Ubicación', 'Código del país', 'El código estándar para el país de la ubicación.

La práctica recomendada es dejar este elemento en blanco si la información presente en la sección Ubicación abarca múltiples entidades en este mismo nivel administrativo o si hay incertidumbre sobre la entidad a la que corresponden los datos. Esta información de multiplicidad e incertidumbre se puede documentar en los elementos higherGeography y locality. Por ejemplo, si hay dos entidades "Colombia y Brasil", la recomendación es dejar este elemento vacío y dejar el comentario en higherGeography y locality.

Documente este elemento de acuerdo al vocabulario controlado de la norma ISO 3166-1-alfa-2 de códigos de países, como se muestra a continuación:

CO (=Para Colombia)
AR (=Para Argentina)', 'CO'),
('stateProvince', 'Ubicación', 'Departamento', 'El nombre completo y sin abreviar de la siguiente región administrativa de menor jerarquía que País de la ubicación (Departamento). Se recomienda usar los nombres asignados en la División Política Administrativa de Colombia - DANE, (http://www.dane.gov.co/Divipola). 

La práctica recomendada es dejar este elemento en blanco si la información presente en la sección Ubicación abarca múltiples entidades en este mismo nivel administrativo o si hay incertidumbre sobre la entidad a la que corresponden los datos. Esta información de multiplicidad e incertidumbre se puede documentar en los elementos higherGeography y locality. Por ejemplo, si hay dos entidades "Santander y Boyacá", la recomendación es dejar este elemento vacío y dejar el comentario en higherGeography y locality.', 'Antioquia
Atlántico
Bogotá, D.C.'),
('county', 'Ubicación', 'Municipio', 'El nombre completo y sin abreviar de la siguiente región administrativa de menor jerarquía que Departamento de la ubicación (Municipio). Se recomienda usar los nombres asignados en la División Política Administrativa de Colombia - DANE, (http://www.dane.gov.co/Divipola).

La práctica recomendada es dejar este elemento en blanco si la información presente en la sección Ubicación abarca múltiples entidades en este mismo nivel administrativo o si hay incertidumbre sobre la entidad a la que corresponden los datos. Esta información de multiplicidad e incertidumbre se puede documentar en los elementos higherGeography y locality. Por ejemplo, si hay dos entidades "San Juan del Cesar o Riohacha", la recomendación es dejar este elemento vacío y dejar el comentario en higherGeography y locality.', 'Medellín
Puerto Colombia
Bogotá, D.C.'),
('municipality', 'Ubicación', 'Cabecera municipal / Centro poblado', 'El nombre completo y sin abreviar de la siguiente región administrativa de menor jerarquía que Municipio de la ubicación. Puede ser un centro poblado, cabecera municipal, corregimiento o inspección de policía. No utilice este elemento para el nombre de un lugar cercano que no contiene la ubicación real. Se recomienda usar los nombres asignados en la División Política Administrativa de Colombia - DANE, (http://www.dane.gov.co/Divipola).

La práctica recomendada es dejar este elemento en blanco si la información presente en la sección Ubicación abarca múltiples entidades en este mismo nivel administrativo o si hay incertidumbre sobre la entidad a la que corresponden los datos. Esta información de multiplicidad e incertidumbre se puede documentar en los elementos higherGeography y locality. Por ejemplo, si hay dos entidades "San Luis o Punta Sur", la recomendación es dejar este elemento vacío y dejar el comentario en higherGeography y locality.', 'Palmitas
Puerto Colombia
Bogotá, Distrito Capital'),
('locality', 'Ubicación', 'Localidad', 'La información geográfica más específica de la ubicación. Información geográfica de menor especificidad puede ser provista en otros elementos geográficos (higherGeography, continent, country, stateProvince, county, municipality, waterBody, island, islandGroup). Este elemento puede contener información modificada de la original para corregir errores o estandarizar la descripción.', 'Ruta del Sol, kilómetro 25 entre Guaduas y La Dorada
Vereda Santa Ana
Quebrada Aguasclaras
Parque Nacional Natural Serranía de Chiribiquete'),
('verbatimLocality', 'Ubicación', 'Localidad original', 'La descripción textual original del lugar (como fue tomada en campo o documentada en el voucher).', 'km 25 Rutal del Sol, Guaduas-La Dorada
Vda Santa ana
Q. Aguasclaras
PNN Chiribiquete'),
('verbatimElevation', 'Ubicación', 'Elevación original', 'La descripción textual de la elevación (altitud, por lo general por encima del nivel del mar) de la ubicación.', '100-200 m
1560 msnm'),
('minimumElevationInMeters', 'Ubicación', 'Elevación mínima en metros', 'El límite inferior del rango de elevación (altitud, generalmente por encima del nivel del mar), no utilice ningún indicador de unidad (metros, m, msnm) ya que el elemento especifica que los valores anotados son en metros.', '100
1600'),
('maximumElevationInMeters', 'Ubicación', 'Elevación máxima en metros', 'El límite superior del rango de elevación (altitud, generalmente por encima del nivel del mar), no utilice ningún indicador de unidad (metros, m, msnm) ya que el elemento especifica que los valores anotados son en metros.', '200
3050'),
('verticalDatum', 'Ubicación', 'Datum vertical', 'El datum vertical usado como referencia para la obtención de los valores de elevación. Se recomienda usar un vocabulario controlado a partir de código epsg o el código del geoide de referencia.', 'GRS80
EGM84 
EGM96 
EGM2008 
epsg:7030
Desconocido'),
('verbatimDepth', 'Ubicación', 'Profundidad original', 'La descripción textual de la profundidad bajo la superficie local.', '0-20 m
-15 a -30'),
('minimumDepthInMeters', 'Ubicación', 'Profundidad mínima en metros', 'La menor profundidad de un rango de profundidad por debajo de la superficie local. No utilice ningún indicador de unidad (metros, m) ya que el elemento especifica que los valores anotados son en metros.', '0
10'),
('maximumDepthInMeters', 'Ubicación', 'Profundidad máxima en metros', 'La mayor profundidad de un rango de profundidad por debajo de la superficie local. No utilice ningún indicador de unidad (metros, m) ya que el campo especifica que los valores anotados son en metros.', '2
50'),
('minimumDistanceAboveSurfaceInMeters', 'Ubicación', 'Distancia mínima de la superficie en metros', 'La menor distancia en metros en un rango de distancias, desde una superficie de referencia en dirección vertical. Si las medidas de profundidad son proporcionadas, la superficie de referencia es la ubicación determinada por la profundidad, de lo contrario la superficie de referencia es la ubicación dada por la elevación.

Utilice valores positivos para las ubicaciones por encima de la superficie y valores negativos para ubicaciones por debajo, como se muestra a continuación:

-1.5 (Para un evento entre 1.5 metros y 4.5 metros desde el fondo de un lago)', '-1.5
2.8'),
('maximumDistanceAboveSurfaceInMeters', 'Ubicación', 'Distancia máxima de la superficie en metros', 'La mayor distancia en metros, en un rango de distancia desde una superficie de referencia en dirección vertical. Si las medidas de profundidad son proporcionadas, la superficie de referencia es la ubicación determinada por la profundidad, de lo contrario la superficie de referencia es la ubicación dada por la elevación.

Utilice valores positivos para las ubicaciones por encima de la superficie, valores negativos para las ubicaciones por debajo, como se muestra a continuación:

-4.5 (Para un evento entre 1.5 metros y 4.5 metros desde el fondo de un lago)', '-4.5
8.2'),
('locationAccordingTo', 'Ubicación', 'Ubicación de acuerdo con', 'La información sobre la fuente de la ubicación. Podría ser una publicación (gacetero), institución o grupo de individuos.', 'Tesauro Getty de Nombres Geográficos
GADM
Geonames
Google Earth'),
('locationRemarks', 'Ubicación', 'Comentarios de la ubicación', 'Comentarios o anotaciones sobre la ubicación. Se recomienda que la longitud de la descripción no supere 20 palabras.', 'Bajo agua desde 2005'),
('verbatimLatitude', 'Ubicación', 'Latitud original', 'La latitud original de la ubicación. El elipsoide de coordenadas, el datum geodésico o el sistema de referencia espacial completo (SRS) para estas coordenadas debe ser documentado en el elemento verbatimSRS, y el sistema de coordenadas en el elemento verbatimCoordinateSystem.', '41° 05'' 56.03" S
1631599'),
('verbatimLongitude', 'Ubicación', 'Longitud original', 'La longitud original de la ubicación. El elipsoide de coordenadas, datum geodésico o el sistema de referencia espacial completo (SRS) para estas coordenadas, debe ser documentado en el elemento verbatimSRS y el sistema de coordenadas en el elemento verbatimCoordinateSystem.', '75° 08'' 36.83" W
834549'),
('verbatimCoordinates', 'Ubicación', 'Coordenadas originales', 'Las coordenadas de la ubicación en su formato original. El elipsoide de las coordenadas, el datum geodésico, o el sistema de referencia espacial completo (SRS) para estas coordenadas, debe ser documentado en el elemento verbatimSRS, y el sistema de coordenadas en el elemento verbatimCoordinateSystem.', '4° 05'' 56.03" S, 75° 08'' 36.83" W
17T 1631599  834549'),
('verbatimCoordinateSystem', 'Ubicación', 'Sistema original de coordenadas', 'El sistema de coordenadas espaciales para verbatimLatitude y verbatinLongitude original o verbatimCoordinates de la ubicación. Se recomienda el uso del vocabulario sugerido disponible para este elemento.', 'Grados decimales
Grados, minutos decimales
Grados, minutos, segundos
UTM
Coordenadas planas
Coordenadas proyectadas'),
('verbatimSRS', 'Ubicación', 'SRS original', 'El elipsoide, datum geodésico, o sistema de referencia espacial (SRS) en el que se basan las coordenadas provistas en verbatimLatitude y verbatinLongitude o verbatimCoordinates. Se recomienda usar el código EPSG, si se conoce. Caso contrario, utilice un lenguaje controlado para el nombre o código del datum geodésico, o un vocabulario controlado para el nombre o código del elipsoide, si se conoce. Si ninguno de estos se conoce, utilice el valor "Desconocido".', 'EPSG: 4326
EPSG: 3116
WGS84
UTM zone 17T
MAGNA-SIRGAS origen Bogotá
MAGNA-SIRGAS origen Oeste
MAGNA-SIRGAS origen CTM-12
Desconocido'),
('decimalLatitude', 'Ubicación', 'Latitud decimal', 'La latitud geográfica (en grados decimales, utilizando el sistema de referencia espacial provisto en geodeticDatum) del centro geográfico de una ubicación. Los valores positivos se encuentran al norte del ecuador, los valores negativos están al sur del mismo. Los valores admitidos se encuentran entre -90 y 90.', '6.05486
12.584877'),
('decimalLongitude', 'Ubicación', 'Longitud decimal', 'La longitud geográfica (en grados decimales, mediante el sistema de referencia espacial provisto en geodeticDatum) del centro geográfico de una ubicación. Los valores positivos se encuentran al este del meridiano de Greenwich, los valores negativos se encuentran al oeste de la misma. Los valores admitidos se encuentran entre -180 y 180.', '-75.05486
-72.78945'),
('geodeticDatum', 'Ubicación', 'Datum geodésico', 'El elipsoide, datum geodésico, o sistema de referencia espacial (SRS) en el que se basan las coordenadas geográficas provistas en decimalLatitude y decimalLongitude. Se recomienda usar el código EPSG, si se conoce. Caso contrario, utilice un lenguaje controlado para el nombre o código del datum geodésico, o utilice un lenguaje controlado para el nombre o código del elipsoide, si se conoce. Si ninguno de estos se conoce, utilice el valor "Desconocido".

Aunque el estándar no es restrictivo en el datum a usar, desde el SiB Colombia se recomienda documentar las coordenadas decimales usando el datum WGS84 dado que facilita la espacialización de los datos publicados por diferentes organizaciones bajo un mismo sistema de referencia espacial, lo que minimiza el riesgo de desplazamiento de las coordenadas.', 'WGS84
EPSG:4326
Desconocido'),
('coordinateUncertaintyInMeters', 'Ubicación', 'Incertidumbre de las coordenadas en metros', 'La distancia horizontal (en metros) de la decimalLatitude y decimalLongitude provistas describiendo el círculo más pequeño que contiene la totalidad de la ubicación. Deje el valor vacío si la incertidumbre es desconocida, no se puede estimar, o no es aplicable (porque no hay coordenadas). Cero no es un valor válido para este elemento.

Documente este elemento de acuerdo a las siguientes explicaciones:

30 (límite inferior razonable de incertidumbre en metros para lecturas de GPS tomadas bajo buenas condiciones después de 2000-05-01, cuando la precisión no fue tomada en campo)
100 (Límite inferior razonable de incertidumbre en metros para lecturas de GPS tomadas bajo buenas condiciones antes de 2000-05-1, cuando la precisión no fue tomada en campo)
71 (Incertidumbre para coordenadas originales tomadas bajo el sistema de coordenadas UTM teniendo 100 metros de precisión y un sistema de referencia espacial conocido)', '30
100
71'),
('coordinatePrecision', 'Ubicación', 'Precisión de las coordenadas', 'Una representación decimal de la precisión de las coordenadas provistas en decimalLatitude y decimalLongitude.

Documente este elemento de acuerdo a las siguientes explicaciones:

0.00001 (Límite normal de GPS para grados decimales)
0.000278 (Para coordenadas reportadas al minuto más cercano. 1/3600)
0.01 (Para una coordenada decimal con dos grados decimales)
1.0 (Grado más próximo)', '0.00001
0.000278
0.01
1.0'),
('pointRadiusSpatialFit', 'Ubicación', 'Ajuste espacial del radio-punto', 'La relación entre el área del radio-punto (decimalLatitude, decimalLongitude y coordinateUncertaintyInMeters) y el área de la verdadera  representación espacial de la ubicación (original, o más específica). Los valores válidos son 0, 1, mayor que 1, o indefinido. Un valor de 1 es una coincidencia exacta o superposición de 100%. Un valor de 0 se debe utilizar si el radio-punto dado no contiene por completo la representación original. El Ajuste espacial del radio-punto no está definido (y se debe dejar en blanco) si la representación original es cualquier geometría sin área (un punto o polilínea) y la georreferencia asignada no corresponde a esa misma geometría (sin incertidumbre). Si tanto el original como la georreferencia dada están en el mismo punto el ajuste espacial del radio-punto es 1.', '0
1
1.5708
Indefinido'),
('footprintWKT', 'Ubicación', 'WKT footprint', 'Una representación Well-Known Text (WKT) de la forma (footprint, geometría) que define la ubicación. Una ubicación puede tener una representación de radio-punto (véase decimalLatitude) y una representación footprint, y pueden diferir entre sí.

Documente este elemento de acuerdo a las siguientes explicaciones:

POLYGON ((10 20, 11 20, 11 21, 10 21, 10 20)) (Para un cuadrante con esquinas opuestas (longitud=10, latitud=20) y (longitud=11, latitud=21))
LINESTRING (-74.139299 10.689195, -74.13791 10.689422) (Para un transecto de muestreo con coordenadas iniciales (longitud=-74.139299, latitud=10.689195) y finales (longitud=-74.13791, latitud=10.689422))', 'POLYGON ((10 20, 11 20, 11 21, 10 21, 10 20))
LINESTRING (-74.139299 10.689195, -74.13791 10.689422)'),
('footprintSRS', 'Ubicación', 'SRS footprint', 'El Elipsoide, datum geodésico o sistema de referencia espacial sobre el cual está referenciada la geometría en el elemento footprintWKT. 

Se recomienda usar un código EPSG para el sistema de referencia si este es conocido. De lo contrario usar un nombre del sistema de referencia, datum, o elipsoide (SRS) bajo un vocabulario controlado. También es permitida la representación en Well-Known Text (WKT) del sistema de referencia espacial (SRS). No utilice este elemento para describir el SRS de decimalLatitude y decimalLongitude, incluso si es la misma que para WKT footprint - utilice el geodeticDatum en su lugar.', 'EPSG:4326
WGS84
SRS GEOGCS["GCS_WGS_1984", DATUM["D_WGS_1984", SPHEROID["WGS_1984",6378137,298.257223563]], PRIMEM["Greenwich",0], UNIT["Degree",0.0174532925199433]]'),
('footprintSpatialFit', 'Ubicación', 'Ajuste espacial de footprint', 'La relación del área de footprint (WKT footprint) y el área de la verdadera representación espacial de la ubicación (original, o más específica). Los valores válidos son 0, 1, mayor que 1, o indefinido. Un valor de 1 es una coincidencia exacta o superposición de 100%. Un valor de 0 debe ser utilizado si el footprint dado no contiene la representación original completamente. El footprintSpatialFit es indefinido (y se debe dejar en blanco) si la representación original es cualquier geometría sin área (un punto o polilínea) y la georreferencia asignada no corresponde a esa misma geometría (sin incertidumbre). Si el original y la georreferencia dada son el mismo punto, el footprintSpatialFit es 1.', '0
1
1.5708
Indefinido'),
('georeferencedBy', 'Ubicación', 'Georreferenciado por', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los nombres de las personas, grupos u organizaciones que determinaron la georreferencia (representación espacial) para la ubicación.', 'Kristina Yamamoto (MVZ)
Miguel B.  |  María Isabel H.'),
('georeferencedDate', 'Ubicación', 'Fecha de georreferenciación', 'La fecha en que fue georreferenciada la ubicación. Debe estar documentada en el esquema de codificación ISO 8601 (AAAA-MM-DD o para un intervalo de fechas: AAAA-MM-DD/AAAA-MM-DD).', '2010
2010-01
2010-01-17
2009/2010
2009-02/2010-01
2009-02/10
2009-02-12/2009-10-08
2010-01-17/18'),
('georeferenceProtocol', 'Ubicación', 'Protocolo de georreferenciación', 'Una descripción o referencia a los métodos utilizados para determinar el footprint espacial, coordenadas, e incertidumbres.', 'Chapman AD & Wieczorek JR (2020) Georeferencing Best Practices. Copenhagen: GBIF Secretariat. https://doi.org/10.15468/doc-gg7h-s853 
MaNIS/HerpNet/ORNIS Georeferencing Guidelines
BioGeomancer'),
('georeferenceSources', 'Ubicación', 'Fuentes de georreferenciación', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los mapas, gaceteros, u otros recursos utilizados para georreferenciar la ubicación, lo suficientemente específica como para permitir que cualquier persona en el futuro utilice los mismos recursos.', 'USGS 1:24000 Florence Montana Quad
Google. (n.d.). Jardín Botánico de la Universidad de Caldas. Recuperado de:  https://goo.gl/maps/zPCiUySVnZ7CN2Vs7
IGAC. Cartografía básica 1:100000. Plancha 124
Google Maps, 2020, maps.google.com'),
('georeferenceVerificationStatus', 'Ubicación', 'Estado de la verificación de la georreferenciación', 'Una descripción categórica sobre la verificación de la georreferencia usada para representar la descripción espacial de la ubicación del registro. Se recomienda el uso del vocabulario sugerido disponible para este elemento.', 'Inviable para georreferenciar
Requiere georreferenciación
Requiere verificación
Verificado por el custodio de los datos
Verificado por el proveedor de los datos'),
('georeferenceRemarks', 'Ubicación', 'Comentarios de la georreferenciación', 'Comentarios o anotaciones acerca de la determinación de la descripción espacial, los supuestos hechos que explican las adiciones formalizadas en el método referido en  georeferenceProtocol. Se recomienda que la longitud de la descripción no supere 20 palabras.', 'Distancia asumida a partir de la carretera (Autopista 101)'),
('geologicalContextID', 'Contexto geológico', 'ID del contexto geológico', 'Un identificador para el conjunto de la información asociada con un contexto geológico (la ubicación dentro de un contexto geológico, tal como estratigrafía). Puede ser un identificador único global o un identificador específico para el conjunto de datos.', 'https://opencontext.org/subjects/e54377f7-4452-4315-b676-40679b10c4d9'),
('earliestEonOrLowestEonothem', 'Contexto geológico', 'Eón temprano o eonotema inferior', 'El nombre completo del eón geocronológico más temprano o el eratema cronoestratigráfico más bajo, o el nombre informal ("Precámbrico") atribuible al horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Fanerozoico
Proterozoico'),
('latestEonOrHighestEonothem', 'Contexto geológico', 'Eón tardío o eonotema superior', 'El nombre completo del eón geocronológico más tardío o el eratema cronoestratigráfico más alto posible, o el nombre informal ("Precámbrico") atribuible al horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Fanerozoico
Proterozoico'),
('earliestEraOrLowestErathem', 'Contexto geológico', 'Era temprana o eratema inferior', 'El nombre completo de la era geocronológica más temprana o el eratema cronoestratigráfico más bajo, atribuible al horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Cenozoico
Mesozoico'),
('latestEraOrHighestErathem', 'Contexto geológico', 'Era tardía o eratema superior', 'El nombre completo de la era geocronológica más tardía o el eratema cronoestratigráfico más alto posible, atribuible al horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Cenozoico
Mesozoico'),
('earliestPeriodOrLowestSystem', 'Contexto geológico', 'Periodo temprano o sistema inferior', 'El nombre completo del periodo geocronológico más temprano posible o el sistema cronoestratigráfico más bajo, atribuible al horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Neógeno
Terciario
Cuaternario'),
('latestPeriodOrHighestSystem', 'Contexto geológico', 'Periodo tardío o sistema superior', 'El nombre completo del período geocronológico más tardío posible o del sistema cronoestratigráfico más alto, atribuible al horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Neógeno
Terciario
Cuaternario'),
('earliestEpochOrLowestSeries', 'Contexto geológico', 'Época temprana o serie inferior', 'El nombre completo de la época geocronológica más temprana o la serie cronoestratigráfica más baja posible, atribuible al horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Holoceno
Pleistoceno
Serie Ibexian'),
('latestEpochOrHighestSeries', 'Contexto geológico', 'Época tardía o serie superior', 'El nombre completo de la época geocronológica más tardía posible o la serie cronoestratigráfica más alta, atribuible al horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Holoceno
Pleistoceno
Serie Ibexian'),
('earliestAgeOrLowestStage', 'Contexto geológico', 'Edad temprana o piso inferior', 'El nombre completo de la edad geocronológica más temprana posible o piso cronoestratigráfico más bajo, atribuible al horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Atlántico
Boreal'),
('latestAgeOrHighestStage', 'Contexto geológico', 'Edad tardía o piso superior', 'El nombre completo de la edad geocronológica más tardía posible o piso cronoestratigráfico más alto, atribuible al horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Atlántico
Boreal'),
('lowestBiostratigraphicZone', 'Contexto geológico', 'Zona bioestratigráfica inferior', 'El nombre completo de la zona geológica bioestratigráfica más baja posible del horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Maastrichtiense'),
('highestBiostratigraphicZone', 'Contexto geológico', 'Zona bioestratigráfica superior', 'El nombre completo de la zona geológica bioestratigráfica más alta posible del horizonte estratigráfico donde se recolectó el objeto catalogado.', 'Blancan'),
('lithostratigraphicTerms', 'Contexto geológico', 'Términos litoestratigráficos', 'La combinación de todos los nombres litoestratigráficos de la roca de donde se colectó el objeto catalogado.', 'Pleistoceno-Weichseliense'),
('group', 'Contexto geológico', 'Grupo', 'El nombre completo del grupo litoestratigráfico del cual se colectó el objeto catalogado.', 'Grupo Bathurst'),
('formation', 'Contexto geológico', 'Formación', 'El nombre completo de la formación litoestratigráfica de la cual se colectó el objeto catalogado.', 'Formación Notch Peak
Formación Fillmore'),
('member', 'Contexto geológico', 'Miembro', 'El nombre completo del miembro litoestratigráfico del cual se colectó el elemento catalogado.', 'Miembro Hellnmaria'),
('bed', 'Contexto geológico', 'Capa', 'El nombre completo de la capa litoestratigráfica de la cual se colectó el elemento catalogado.', 'Carbón Harlem'),
('identificationID', 'Identificación', 'ID de la identificación', 'Un identificador para la identificación (el cuerpo de la información asociada con la asignación de un nombre científico) del organismo. Puede ser un identificador único global o un identificador específico para el conjunto de datos.', '1231135
10560964'),
('identifiedBy', 'Identificación', 'Identificado por', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los nombres de las personas responsables de identificar el organismo. 

Se debe mantener el mismo formato del nombre a lo largo de todos los registros y se recomienda evitar el uso de solo iniciales ya que esto genera ambigüedades para reconocer a las personas que realizaron la identificación, de ser posible siempre escriba nombres completos. Documente el nombre de las personas y evite documentar nombres de grupos u organizaciones.', 'Luis Gabriel Pérez Salamanca
Jennifer Andrea Parra Ortíz | Jaime Enrique Correa Sánchez'),
('identifiedByID', 'Identificación', 'ID del identificador', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los identificadores (ORCID o Wikidata) de las personas que identificaron el organismo. Mantenga el mismo orden de las personas documentadas en el elemento identifiedBy; el orden en este campo no indica una prioridad en la citación ni ningún otro tipo de relación jerárquica.', 'https://orcid.org/0000-0001-6215-3617 | https://orcid.org/0000-0003-1691-239X
https://www.wikidata.org/entity/Q28913658'),
('dateIdentified', 'Identificación', 'Fecha de la identificación', 'La fecha o el intervalo durante el cual  fue identificado taxonómicamente la observación, colecta o muestra. Debe estar documentada en el esquema de codificación ISO 8601 (AAAA-MM-DD o para un intervalo de fechas: AAAA-MM-DD/AAAA-MM-DD).', '2010
2010-01
2010-01-17
2009/2010
2009-02/10
2010-01-17/18
2009-02/2010-01
2009-08-08/2009-10-26'),
('identificationReferences', 'Identificación', 'Referencias de la identificación', 'Una lista (en una fila continua y separada por una barra vertical " | ")  de las referencias (publicación, identificador único global, URI) usadas en la identificación.', 'Aves del Noroeste Patagónico. Christie et al. 2004'),
('identificationVerificationStatus', 'Identificación', 'Estado de la verificación de la identificación', 'Un indicador sobre el nivel de verificación de la identificación taxonómica. Puede ser un valor categórico o un porcentaje para los registros identificados con métodos genéticos.

Se recomienda el uso de categorías claras o un vocabulario controlado como el de HISPID/ABCD (https://hiscom.rbg.vic.gov.au/wiki/Talk:HISPID/ABCD_Workshop_Executive_Summary#Verification_Level_Flag_.28vlev.29), como se muestra a continuación:

0 - El nombre del registro no ha sido revisado por ninguna autoridad (del vocabulario HISPID/ABCD)
1 - El nombre del registro se determinó por medio de comparación contra otro ejemplar (del vocabulario HISPID/ABCD)
2 - El nombre del registro fue determinado por un taxónomo usando material de una colección (del vocabulario HISPID/ABCD)
3 - El nombre del registro fue determinado por un taxónomo involucrado en la revisión sistemática del grupo (del vocabulario HISPID/ABCD)
4 - El registros es derivado de forma asexual de un material tipo (del vocabulario HISPID/ABCD)
Verificado', '0
1
2
3
4
Verificado
No verificado
97.3% a género'),
('typeStatus', 'Identificación', 'Tipo nomeclatural', 'Una lista (en una fila continua y separada por una barra vertical " | ") de los tipos de nomenclatura (estado del tipo, nombre científico tipificado, publicación) aplicados al organismo. Se recomienda el uso del vocabulario sugerido disponible para este elemento con traducción a español (https://tools.gbif.org/dwca-validator/vocabulary.do?id=http://rs.gbif.org/vocabulary/gbif/type_status).', 'Holotipo de Ctenomys sociabilis. Pearson O. P.; y M. I. Christie. 1985. Historia Natural; 5(37):388
Paratipo
Alotipo
Isotipo
Neotipo
Plastotipo
Sintipo
Topotipo'),
('verbatimIdentification', 'Identificación', 'Identificación original', 'La identificación original del organismo (como fue tomada en campo o documentada en el voucher). Este elemento permite documentar la identificación o determinación original inalterada, incluidos los calificadores de identificación, fórmulas híbridas, incertidumbres, etc.', 'Peromyscus sp.
Ministrymon sp. nov. 1 
Anser anser X Branta canadensis
Pachyporidae?'),
('identificationRemarks', 'Identificación', 'Comentarios de la identificación', 'Comentarios o anotaciones sobre la identificación. Se recomienda que la longitud de la descripción no supere 20 palabras.', 'Se distingue entre Anthus correndera y Anthus hellmayri basado en las longitudes comparativas de las uñas
Amplificación del gen 16S rRNA | Identificación bioquímica'),
('identificationQualifier', 'Identificación', 'Calificador de la identificación', 'El grado de incertidumbre de la identificación puede indicarse agregando varios términos, como aff. y cf. al nombre científico. El calificador se aplica a la parte del nombre que sigue inmediatamente al calificador y se pueden colocar delante de cualquier elemento del nombre.

cf.  del latín confer significa comparado con. Su uso indica que no hay certeza de la identidad de la especie (o rango taxonómico superior) hasta que se pueda hacer una comparación más detallada, por ejemplo, con algún tipo o material de referencia. 

aff. del latín affinis significa similar o limítrofe. Su uso indica que el material o la evidencia disponible sugiere que la especie propuesta está relacionada, tiene afinidad, pero no es idéntica, a la especie o taxón que le sigue.

Documente este elemento de acuerdo a las siguientes explicaciones:

cf. agrifolia  (Para Quercus cf. agrifolia, con valores acompañantes scientificName: Quercus , genus: Quercus, taxonRank: Género.) 

aff. Sparassidae (Para aff. Sparassidae, con valores acompañantes  scientificName: Araneae, order: Araneae, taxonRank: Orden.)', 'cf. agrifolia
aff. Sparassidae'),
('scientificName', 'Taxón', 'Nombre científico', 'El nombre científico canónico (sin la autoría) correspondiente a la categoría taxonómica a la que se logró la determinación del organismo observado o colectado. El nombre debe ser congruente con el elemento taxonRank, de modo que se informe a que nivel (especie, género, familia, etc.) se encuentra el nombre documentado.

Para tener en cuenta:
- El nombre científico puede pertenecer a cualquier categoría taxonómica (reino, filo, clase, orden, familia, género, especie entre otros), en ningún caso es obligatorio la identificación a nivel de especie.
- No debe documentar la autoría del taxón en este elemento, para ello utilice el elemento scientificNameAuthorship.
- No debe documentar calificadores de identificación (cf., aff., etc.), para ello utilice el elemento identificationQualifier y deje en el nombre científico la categoría superior sobre la cual se tiene certeza.
- No debe documentar abreviaciones que no dan cuenta de el nombre específico o hacen referencia  a morfotipos (sp., sp1., spp.), para ello utilice el elemento verbatimTaxonRank.
- Nombres de híbridos para algas, hongos y plantas deberían seguir las reglas del Código Internacional de Nomenclatura para algas, hongos y plantas (Schenzhen Code Articles H.1, H.2 and H.3). Utilizando el signo de multiplicación × (Unicode U+00D7, HTML ×) para identificar un híbrido, evitando usar una "x" o "X".

*Aunque oficialmente scientificName se define como el "nombre científico completo, con información de autoría y fecha si se conoce", desde el SiB Colombia se recomienda documentar solo el nombre canónico ya que hemos notado un detrimento de la calidad de este elemento por errores de tipeo cuando se incluye siguiendo la definición oficial.', 'Coleoptera
Bacteria
Ctenomys sociabilis
Abrus pulchellus subsp. tenuiflorus'),
('scientificNameAuthorship', 'Taxón', 'Autoría del nombre científico', 'La información de autoría correspondiente al scientificName, usando el formato acorde a las convenciones del Código Nomenclatural aplicable.', '(Torr.) J.T. Howell
(Martinovský) Tzvelev
(Györfi, 1952)'),
('taxonID', 'Taxón', 'ID del Taxón', 'Un identificador único global del taxón (datos asociados a la clasificación del Taxón) de acuerdo al nombre científico documentado en el elemento scientificName. Puede ser un identificador único global o un identificador específico para el conjunto de datos.
Este puede ser obtenido de bases de datos o catálogos taxonómicos globales.', 'gbif.org/species/3056437
urn:lsid:marinespecies.org:taxname:124821
urn:lsid:gbif.org:usages:32567
8fa58e08-08de-4ac1-b69c-1235340b7001'),
('scientificNameID', 'Taxón', 'ID del nombre científico', 'Un identificador de los detalles de la nomenclatura (no taxonómica) de acuerdo al nombre científico documentado en el elemento scientificName.
Este puede ser obtenido de catálogos taxonómicos globales.', 'urn:lsid:ipni.org:names:37829-1:1.3
urn:lsid:marinespecies.org:taxname:493567'),
('higherClassification', 'Taxón', 'Clasificación superior', 'Una lista de los nombres de los taxones inmediatamente superiores a la categoría del taxón del scientificName. Se recomienda ordenar la lista comenzando con la categoría más alta y separando los nombres de cada categoría, con una barra vertical " | ". Permite documentar categorías taxonómicas que no incluye el estándar (suborden, superfamilia, etc).', 'Animalia | Chordata | Vertebrata | Mammalia | Theria | Eutheria | Rodentia | Hystricognatha | Hystricognathi | Ctenomyidae | Ctenomyini | Ctenomys
Animalia | Arthropoda | Arachnida | Araneae | Paratropididae | Paratropis'),
('kingdom', 'Taxón', 'Reino', 'El nombre científico completo del reino al que pertenece el taxón.', 'Animalia
Plantae
Bacteria
Chromista
Fungi
Protozoa
Archaea'),
('phylum', 'Taxón', 'Filo', 'El nombre científico completo del filo o división al que pertenece el taxón.', 'Chordata
Bryophyta'),
('class', 'Taxón', 'Clase', 'El nombre científico completo de la clase al que pertenece el taxón.', 'Mammalia
Hepaticopsida'),
('order', 'Taxón', 'Orden', 'El nombre científico completo del orden al que pertenece el taxón.', 'Carnivora
Monocleales'),
('family', 'Taxón', 'Familia', 'El nombre científico completo de la familia al que pertenece el taxón.', 'Felidae
Monocleaceae'),
('subfamily', 'Taxón', 'Subfamilia', 'El nombre científico completo de la subfamilia al que pertenece el taxón.', 'Periptyctinae
Orchidoideae
Sphindociinae'),
('tribe', 'Taxón', 'Tribu', 'El nombre científico completo de la tribu a la que pertenece el taxón.', 'Ortaliini
Arethuseae'),
('subtribe', 'Taxón', 'Subtribu', 'El nombre científico completo de la subtribu a la que pertenece el taxón.', 'Plotinini
Typhaeini'),
('genus', 'Taxón', 'Género', 'El nombre científico completo del género al que pertenece el taxón.', 'Puma
Monoclea'),
('genericName', 'Taxón', 'Nombre genérico', 'El nombre científico completo del género no aceptado al que pertenece el taxón.

El elemento genericName solo debe usarse para combinaciones como se muestra a continuación:

Felis (para el scientificName "Felis concolor", con los valores correspondientes de "Puma concolor" en acceptNameUsage y "Puma" en genus).', 'Felis'),
('subgenus', 'Taxón', 'Subgénero', 'El nombre científico completo del subgénero al que pertenece el taxón. Se debe incluir el género para evitar la confusión de homonimia.', 'Strobus (Pinus)
Puma (Puma)
Loligo (Amerigo)
Hieracium subgen. Pilosella'),
('infragenericEpithet', 'Taxón', 'Epíteto infragenérico', 'El nombre científico del epíteto infragenérico (por encima, de la especie pero por debajo del género) al que pertenece el taxón.

Se usa por ejemplo para secciones en botánica como se muestra a continuación:

Cracca (para scientificName Vicia sect. Cracca)', 'Cracca'),
('specificEpithet', 'Taxón', 'Epíteto Específico', 'El nombre del epíteto específico presente en el scientificName cuando la determinación se hizo hasta especie u otra categoría menor.', 'concolor
gottschei'),
('infraspecificEpithet', 'Taxón', 'Epíteto infraespecífico', 'El nombre del epíteto infraespecífico presente en el scientificName cuando la determinación se hizo con la categoría de taxón más baja o más especifica por debajo del epíteto específico (parte terminal del nombre), excluyendo cualquier otra denominación de categoría. 

En botánica, los nombres en la literatura y las identificaciones pueden tener múltiples rangos infraespecíficos. De acuerdo al Código Internacional de Nomenclatura para algas, hongos y plantas (Schenzhen Code Articles 6.7 & Art. 24.1), los nombres válidos tienen solamente dos epítetos, con el rango más bajo presente en infraspecificEpithet. Por ejemplo el epíteto infraespecífico para Indigofera charlieriana subsp. sessilis var. scaberrima es "scaberrima".', 'concolor
oxyadenia
sayi'),
('cultivarEpithet', 'Taxón', 'Epíteto cultivar', 'El nombre de un cultivar, grupo de cultivares, o grex (horticultura) que sigue al nombre científico.

De acuerdo con las Reglas del Código de Plantas Cultivadas, el nombre de un cultivar consiste en un nombre botánico seguido de un epíteto de cultivar.

Documentar de acuerdo a como se muestra a continuación:

King Edward (para el scientificName "Solanum tuberosum ''King Edward''" y taxonRank "cultivar")
Mishmiense (para el scientificName "Rhododendron boothii Mishmiense Group" y taxonRank "grupo de cultivares")
Atlantis (para scientificName "Paphiopedilum Atlantis grex" y taxonRank "grex")', 'King Edward
Mishmiense
Atlantis'),
('taxonRank', 'Taxón', 'Categoría del taxón', 'La categoría taxonómica del nombre más específico presente en el scientificName. Se recomienda el uso del vocabulario sugerido disponible para este elemento.', 'Reino
Subreino
Filo
División
Subfilo
Subdivisión
Clase
Subclase
Orden
Suborden
Familia
Subfamilia
Tribu
Subtribu
Género
Subgénero
Nothogénero
Sección
Subsección
Serie
Subserie
Especie
Nothoespecie
Subespecie
Nothosubespecie
Variedad
Subvariedad
Forma
Subforma'),
('verbatimTaxonRank', 'Taxón', 'Categoría original del taxón', 'La categoría taxonómica del nombre más específico tal y como aparece en el registro original. Se utiliza para documentar abreviaciones que dan cuenta de incertidumbres o morfotipos en el registro.', 'sp1.
sp2.
Morfotipo1.
sub-lesus
prole
apomict
spp.'),
('vernacularName', 'Taxón', 'Nombre común', 'El nombre o nombres comunes del taxón (en una fila continua y separada por una barra vertical " | ").', 'Cóndor Andino
Águila Americana
Buitre | Chulo'),
('taxonomicStatus', 'Taxón', 'Estado taxonómico', 'El estado taxonómico que define el uso del scientificName de acuerdo a un árbol taxonómico u opinión de experto.', 'Inválido
Válido
Aceptado
Sinónimo
Sinónimo homotípico
Sinónimo heterotípico
Ambiguo
Mal aplicado'),
('acceptedNameUsage', 'Taxón', 'Nombre aceptado usado', 'El nombre completo, con autoría e información de fecha si se conoce, del taxón actualmente válido (zoológico) o aceptado (botánico) cuando el nombre documentado en scientificName no corresponda al nombre válido o aceptado.', 'Tamias minimus Bachman, 1839'),
('acceptedNameUsageID', 'Taxón', 'ID del nombre aceptado usado', 'Un identificador para el acceptedNameUsage (significado del nombre, documentado de acuerdo con alguna fuente) del taxón actualmente válido (zoológico) o aceptado (botánico).

Este elemento debe usarse cuando el elemento scientificName hace referencia a un sinónimo o a un nombre ambiguo mal aplicado, para dar claridad sobre el taxón válido al que hace referencia. 

Este puede ser obtenido de bases de datos o catálogos taxonómicos globales.', 'gbif.org/species/2435099
tsn:552479
urn:lsid:ipni.org:names:320035-2'),
('parentNameUsage', 'Taxón', 'Nombre parental usado', 'El nombre completo, con autoría e información de fecha si se conoce, del taxón parental directo válido (zoológico) o aceptado (botánico), más próximo de nivel superior (en una clasificación) del elemento más específico presente en el scientificName.', 'Rubiaceae
Arcytophyllum Willd.
Testudinae'),
('parentNameUsageID', 'Taxón', 'ID del Nombre Parental usado', 'Un identificador para el uso del nombre (significado del nombre, documentado de acuerdo con alguna fuente) del taxón parental directo del taxón indicado en el scientificName.

Por ejemplo si el scientificName corresponde a una especie, el parentNameUsageID corresponder al nombre científico del género si este hace referencia a un sinónimo o a un nombre ambiguo mal aplicado

Este puede ser obtenido de bases de datos o catálogos taxonómicos globales.', 'gbif.org/species/2435099
tsn:552479
urn:lsid:ipni.org:names:320035-2'),
('originalNameUsage', 'Taxón', 'Nombre original usado', 'El nombre del taxón, con autoría e información de fecha si se conoce, tal como apareció originalmente cuando se estableció por primera vez bajo las reglas del nomenclaturalCode asociado. El basiónimo (botánica) o basónimo (bacteriología) correspondiente al scientificName o el homónimo anterior de los nombres sustituidos.', 'Gasterosteus saltatrix Linnaeus 1768'),
('originalNameUsageID', 'Taxón', 'ID del Nombre original usado', 'Un identificador para el uso del nombre (significado del nombre, documentado de acuerdo con alguna fuente) en el que se estableció originalmente el scientificName, bajo las reglas del nomenclaturalCode asociado (el protónimo en zoología, basiónimo en botánica). 

Este puede ser obtenido de bases de datos o catálogos taxonómicos globales.', 'gbif.org/species/2435099
tsn:552479
urn:lsid:ipni.org:names:320035-2'),
('nameAccordingTo', 'Taxón', 'Nombre de acuerdo con', 'La referencia a la fuente en la que está definida o implícita la definición conceptual del taxón, tradicionalmente representado por el Latín "sensu" o "sec." (de secundum, que significa "según"). Para los taxones que resultan de las identificaciones, una referencia a las claves, monografías, expertos y otras fuentes debe ser provista.', 'Franz NM, Cardona-Duque J (2013) Description of two new species and phylogenetic reassessment of Perelleschus Wibmer & OBrien, 1986 (Coleoptera: Curculionidae), with a complete taxonomic concept history of Perelleschus sec. Franz & Cardona-Duque, 2013. Syst Biodivers. 11: 209236'),
('nameAccordingToID', 'Taxón', 'ID del nombre de acuerdo con', 'Un identificador de la fuente/publicación en la que está definida o implícita la definición conceptual del taxón específico. Véase nameAccordingTo.

Este término debe usarse para referirse al ID de taxón de un registro de taxón que representa la combinación original del nombre (el protónimo en zoología, el basiónimo en botánica).', 'doi:10.1016/S0269-915X(97)80026-2
19thcenturyscience.org/HMSC/HMSC-Reports/Zool-40/README.htm'),
('namePublishedIn', 'Taxón', 'Nombre publicado en', 'Una referencia para la publicación en que se estableció originalmente el taxón presente en el scientificName, bajo las reglas del nomeclaturalCode asociado. 

La citación de la primera publicación del nombre científico documentado en este registro, no el basónimo/nombre original. Las recombinaciones usualmente no se publican en zoología, en ese caso namePublishedIn debe estar vacío.', 'Pearson O. P., and M. I. Christie. 1985. Historia Natural, 5(37):388; Forel, Auguste, Diagnosies provisoires de quelques espèces nouvelles de fourmis de Madagascar, récoltées par M. Grandidier., Annales de la Societe Entomologique de Belgique, Comptes-rendus des Seances 30, 1886'),
('namePublishedInID', 'Taxón', 'ID del nombre publicado en', 'Un identificador de la publicación en que se estableció originalmente el taxón presente en el scientificName, bajo las reglas del nomeclaturalCode asociado. 

La citación de la primera publicación del nombre científico documentado en este registro, no el basónimo/nombre original. Las recombinaciones usualmente no se publican en zoología, en ese caso namePublishedIn debe estar vacío.', 'doi:10.1016/S0269-915X(97)80026-2
19thcenturyscience.org/HMSC/HMSC-Reports/Zool-40/README.htm'),
('namePublishedInYear', 'Taxón', 'Nombre publicado en el año', 'El año de cuatro dígitos en el que se publicó el taxón presente en el scientificName.', '1915
2008'),
('taxonConceptID', 'Taxón', 'ID del concepto del taxón', 'Un identificador para el concepto taxonómico al que se refiere el registro, no para los detalles de nomenclatura de un taxón.', 'urn:lsid:zoobank.org:act:040832DB-2A58-4EFE-B234-AEBF222586FC'),
('nomenclaturalCode', 'Taxón', 'Código nomenclatural', 'El código nomenclatural (o códigos en el caso de un nombre ambireinal) en virtud del cual se construye el scientificName. Se recomienda el uso del vocabulario sugerido disponible para este elemento.', 'ICN
ICZN
BC
ICNCP
BioCode
PhyloCode'),
('nomenclaturalStatus', 'Taxón', 'Estado nomenclatural', 'typeStatus (Tipo nomenclatural)', 'nom. ambig.
nom. illeg.
nom. subnud.'),
('taxonRemarks', 'Taxón', 'Comentarios del taxón', 'Comentarios o anotaciones sobre el taxón o nombre. Se recomienda que la longitud de la descripción no supere 20 palabras.', 'Este nombre está mal escrito en uso común
Sin estado de amenaza reportada')
ON DUPLICATE KEY UPDATE
  seccion = VALUES(seccion),
  etiqueta = VALUES(etiqueta),
  definicion = VALUES(definicion),
  ejemplo = VALUES(ejemplo);

-- ------------------------------------------------------------
-- Registros de ocurrencia Darwin Core (seccion 3, 5)
-- Los 185 terminos + metadatos administrativos
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS occurrences (
  id INT AUTO_INCREMENT PRIMARY KEY,

  -- Metadatos administrativos (seccion 5)
  usuario_creador_id INT NOT NULL,
  class_code_id INT NULL,
  profesor_id INT NULL,
  version INT NOT NULL DEFAULT 1,
  estado_validacion ENUM('incompleto','con_advertencias','completo_para_sobre') NOT NULL DEFAULT 'incompleto',
  eliminado BOOLEAN NOT NULL DEFAULT FALSE,
  eliminado_en DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  -- Termino Darwin Core identificador (unico, no se reutiliza)
  `occurrenceID` VARCHAR(255) NOT NULL UNIQUE,

  -- 184 terminos Darwin Core restantes
  `basisOfRecord` TEXT NULL,
  `type` TEXT NULL,
  `institutionCode` TEXT NULL,
  `institutionID` TEXT NULL,
  `collectionCode` TEXT NULL,
  `collectionID` TEXT NULL,
  `catalogNumber` TEXT NULL,
  `datasetName` TEXT NULL,
  `datasetID` TEXT NULL,
  `modified` DATETIME NULL,
  `language` TEXT NULL,
  `license` TEXT NULL,
  `rightsHolder` TEXT NULL,
  `accessRights` TEXT NULL,
  `bibliographicCitation` TEXT NULL,
  `references` TEXT NULL,
  `ownerInstitutionCode` TEXT NULL,
  `informationWithheld` TEXT NULL,
  `dataGeneralizations` TEXT NULL,
  `dynamicProperties` TEXT NULL,
  `recordNumber` TEXT NULL,
  `recordedBy` TEXT NULL,
  `recordedByID` TEXT NULL,
  `organismID` TEXT NULL,
  `individualCount` INT NULL,
  `organismQuantity` TEXT NULL,
  `organismQuantityType` TEXT NULL,
  `organismName` TEXT NULL,
  `organismScope` TEXT NULL,
  `associatedOrganisms` TEXT NULL,
  `previousIdentifications` TEXT NULL,
  `organismRemarks` TEXT NULL,
  `sex` TEXT NULL,
  `lifeStage` TEXT NULL,
  `reproductiveCondition` TEXT NULL,
  `caste` TEXT NULL,
  `vitality` TEXT NULL,
  `behavior` TEXT NULL,
  `establishmentMeans` TEXT NULL,
  `degreeOfEstablishment` TEXT NULL,
  `pathway` TEXT NULL,
  `occurrenceStatus` TEXT NULL,
  `preparations` TEXT NULL,
  `disposition` TEXT NULL,
  `verbatimLabel` TEXT NULL,
  `otherCatalogNumbers` TEXT NULL,
  `associatedMedia` TEXT NULL,
  `associatedOccurrences` TEXT NULL,
  `associatedReferences` TEXT NULL,
  `associatedSequences` TEXT NULL,
  `associatedTaxa` TEXT NULL,
  `occurrenceRemarks` TEXT NULL,
  `materialSampleID` TEXT NULL,
  `parentEventID` TEXT NULL,
  `eventID` TEXT NULL,
  `eventType` TEXT NULL,
  `samplingProtocol` TEXT NULL,
  `sampleSizeValue` TEXT NULL,
  `sampleSizeUnit` TEXT NULL,
  `samplingEffort` TEXT NULL,
  `eventDate` DATE NULL,
  `startDayOfYear` SMALLINT NULL,
  `endDayOfYear` SMALLINT NULL,
  `year` SMALLINT NULL,
  `month` TINYINT NULL,
  `day` TINYINT NULL,
  `verbatimEventDate` TEXT NULL,
  `eventTime` TEXT NULL,
  `habitat` TEXT NULL,
  `fieldNumber` TEXT NULL,
  `fieldNotes` TEXT NULL,
  `eventRemarks` TEXT NULL,
  `locationID` TEXT NULL,
  `higherGeography` TEXT NULL,
  `higherGeographyID` TEXT NULL,
  `continent` TEXT NULL,
  `waterBody` TEXT NULL,
  `islandGroup` TEXT NULL,
  `island` TEXT NULL,
  `country` TEXT NULL,
  `countryCode` TEXT NULL,
  `stateProvince` TEXT NULL,
  `county` TEXT NULL,
  `municipality` TEXT NULL,
  `locality` TEXT NULL,
  `verbatimLocality` TEXT NULL,
  `verbatimElevation` TEXT NULL,
  `minimumElevationInMeters` DECIMAL(10,2) NULL,
  `maximumElevationInMeters` DECIMAL(10,2) NULL,
  `verticalDatum` TEXT NULL,
  `verbatimDepth` TEXT NULL,
  `minimumDepthInMeters` DECIMAL(10,2) NULL,
  `maximumDepthInMeters` DECIMAL(10,2) NULL,
  `minimumDistanceAboveSurfaceInMeters` DECIMAL(10,2) NULL,
  `maximumDistanceAboveSurfaceInMeters` DECIMAL(10,2) NULL,
  `locationAccordingTo` TEXT NULL,
  `locationRemarks` TEXT NULL,
  `verbatimLatitude` TEXT NULL,
  `verbatimLongitude` TEXT NULL,
  `verbatimCoordinates` TEXT NULL,
  `verbatimCoordinateSystem` TEXT NULL,
  `verbatimSRS` TEXT NULL,
  `decimalLatitude` DECIMAL(10,6) NULL,
  `decimalLongitude` DECIMAL(10,6) NULL,
  `geodeticDatum` TEXT NULL,
  `coordinateUncertaintyInMeters` DECIMAL(10,2) NULL,
  `coordinatePrecision` DECIMAL(10,6) NULL,
  `pointRadiusSpatialFit` TEXT NULL,
  `footprintWKT` TEXT NULL,
  `footprintSRS` TEXT NULL,
  `footprintSpatialFit` TEXT NULL,
  `georeferencedBy` TEXT NULL,
  `georeferencedDate` TEXT NULL,
  `georeferenceProtocol` TEXT NULL,
  `georeferenceSources` TEXT NULL,
  `georeferenceVerificationStatus` TEXT NULL,
  `georeferenceRemarks` TEXT NULL,
  `geologicalContextID` TEXT NULL,
  `earliestEonOrLowestEonothem` TEXT NULL,
  `latestEonOrHighestEonothem` TEXT NULL,
  `earliestEraOrLowestErathem` TEXT NULL,
  `latestEraOrHighestErathem` TEXT NULL,
  `earliestPeriodOrLowestSystem` TEXT NULL,
  `latestPeriodOrHighestSystem` TEXT NULL,
  `earliestEpochOrLowestSeries` TEXT NULL,
  `latestEpochOrHighestSeries` TEXT NULL,
  `earliestAgeOrLowestStage` TEXT NULL,
  `latestAgeOrHighestStage` TEXT NULL,
  `lowestBiostratigraphicZone` TEXT NULL,
  `highestBiostratigraphicZone` TEXT NULL,
  `lithostratigraphicTerms` TEXT NULL,
  `group` TEXT NULL,
  `formation` TEXT NULL,
  `member` TEXT NULL,
  `bed` TEXT NULL,
  `identificationID` TEXT NULL,
  `identifiedBy` TEXT NULL,
  `identifiedByID` TEXT NULL,
  `dateIdentified` TEXT NULL,
  `identificationReferences` TEXT NULL,
  `identificationVerificationStatus` TEXT NULL,
  `typeStatus` TEXT NULL,
  `verbatimIdentification` TEXT NULL,
  `identificationRemarks` TEXT NULL,
  `identificationQualifier` TEXT NULL,
  `scientificName` TEXT NULL,
  `scientificNameAuthorship` TEXT NULL,
  `taxonID` TEXT NULL,
  `scientificNameID` TEXT NULL,
  `higherClassification` TEXT NULL,
  `kingdom` TEXT NULL,
  `phylum` TEXT NULL,
  `class` TEXT NULL,
  `order` TEXT NULL,
  `family` TEXT NULL,
  `subfamily` TEXT NULL,
  `tribe` TEXT NULL,
  `subtribe` TEXT NULL,
  `genus` TEXT NULL,
  `genericName` TEXT NULL,
  `subgenus` TEXT NULL,
  `infragenericEpithet` TEXT NULL,
  `specificEpithet` TEXT NULL,
  `infraspecificEpithet` TEXT NULL,
  `cultivarEpithet` TEXT NULL,
  `taxonRank` TEXT NULL,
  `verbatimTaxonRank` TEXT NULL,
  `vernacularName` TEXT NULL,
  `taxonomicStatus` TEXT NULL,
  `acceptedNameUsage` TEXT NULL,
  `acceptedNameUsageID` TEXT NULL,
  `parentNameUsage` TEXT NULL,
  `parentNameUsageID` TEXT NULL,
  `originalNameUsage` TEXT NULL,
  `originalNameUsageID` TEXT NULL,
  `nameAccordingTo` TEXT NULL,
  `nameAccordingToID` TEXT NULL,
  `namePublishedIn` TEXT NULL,
  `namePublishedInID` TEXT NULL,
  `namePublishedInYear` SMALLINT NULL,
  `taxonConceptID` TEXT NULL,
  `nomenclaturalCode` TEXT NULL,
  `nomenclaturalStatus` TEXT NULL,
  `taxonRemarks` TEXT NULL,

  CONSTRAINT fk_occ_usuario FOREIGN KEY (usuario_creador_id) REFERENCES users(id),
  CONSTRAINT fk_occ_clase FOREIGN KEY (class_code_id) REFERENCES class_codes(id),
  CONSTRAINT fk_occ_profesor FOREIGN KEY (profesor_id) REFERENCES users(id),
  INDEX idx_occ_usuario (usuario_creador_id),
  INDEX idx_occ_clase (class_code_id),
  INDEX idx_occ_eliminado (eliminado),
  INDEX idx_occ_recordnumber (recordNumber(100)),
  INDEX idx_occ_license (license(100)),
  INDEX idx_occ_fieldnotes (fieldNotes(100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Historial de modificaciones (seccion 5)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS occurrence_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  occurrence_id INT NOT NULL,
  usuario_id INT NOT NULL,
  fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  campo VARCHAR(100) NOT NULL,
  valor_anterior TEXT NULL,
  valor_nuevo TEXT NULL,
  version_resultante INT NOT NULL,
  CONSTRAINT fk_hist_occ FOREIGN KEY (occurrence_id) REFERENCES occurrences(id),
  CONSTRAINT fk_hist_usuario FOREIGN KEY (usuario_id) REFERENCES users(id),
  INDEX idx_hist_occ (occurrence_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Trazabilidad de generacion de sobres (seccion 10)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS envelope_generations (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  modalidad ENUM('individual','consolidado') NOT NULL,
  formato ENUM('docx','pdf') NOT NULL,
  tamano_hoja VARCHAR(50) NOT NULL DEFAULT 'Carta',
  registros_incluidos JSON NOT NULL,
  CONSTRAINT fk_gen_usuario FOREIGN KEY (usuario_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
