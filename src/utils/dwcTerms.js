const fs = require('fs');
const path = require('path');

const TERMS = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', '..', 'data', 'dwc-terms.json'), 'utf8')
);

const FIELD_NAMES = TERMS.map((t) => t.name);

const SECTION_ORDER = [
  'Registro',
  'Ocurrencia',
  'Organismo',
  'Muestra',
  'Evento',
  'Ubicación',
  'Contexto geológico',
  'Identificación',
  'Taxón',
];

// Campos que calcula el sistema automaticamente (seccion 3): no se editan a mano.
const DERIVED_FIELDS = new Set(['year', 'month', 'day', 'decimalLatitude', 'decimalLongitude', 'modified']);

// Campos que imprime el sobre (seccion 9): usados para el estado "Incompleto" (seccion 5).
const ENVELOPE_FIELDS = [
  'family',
  'scientificName',
  'identifiedBy',
  'phylum',
  'country',
  'verbatimLatitude',
  'verbatimLongitude',
  'eventDate',
  'recordNumber',
  'recordedBy',
];

function groupedBySection() {
  const groups = {};
  for (const section of SECTION_ORDER) groups[section] = [];
  for (const term of TERMS) {
    if (!groups[term.section]) groups[term.section] = [];
    groups[term.section].push(term);
  }
  return groups;
}

module.exports = {
  TERMS,
  FIELD_NAMES,
  SECTION_ORDER,
  DERIVED_FIELDS,
  ENVELOPE_FIELDS,
  groupedBySection,
};
