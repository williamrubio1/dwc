// Validaciones y campos derivados (seccion 4 de la especificacion funcional).

function pad2(n) {
  return String(n).padStart(2, '0');
}

// Acepta dd/mm/aaaa (pantalla) o yyyy-mm-dd (ISO/importacion). Bloquea si no es una fecha real.
function parseEventDate(input) {
  if (!input || !String(input).trim()) return { iso: null, error: null };
  const raw = String(input).trim();
  let y, m, d;
  let match = raw.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (match) {
    [, y, m, d] = match.map(Number);
  } else {
    match = raw.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (match) {
      d = Number(match[1]);
      m = Number(match[2]);
      y = Number(match[3]);
    } else {
      return { iso: null, error: `Fecha "${raw}" no tiene un formato reconocido (dd/mm/aaaa o yyyy-mm-dd).` };
    }
  }
  const date = new Date(Date.UTC(y, m - 1, d));
  const valid =
    date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d && m >= 1 && m <= 12 && d >= 1;
  if (!valid) {
    return { iso: null, error: `Fecha "${raw}" no es una fecha valida.` };
  }
  return { iso: `${y}-${pad2(m)}-${pad2(d)}`, error: null };
}

function isoToDisplay(iso) {
  if (!iso) return '';
  const [y, m, d] = iso.split('-');
  return `${d}/${m}/${y}`;
}

function deriveYearMonthDay(iso) {
  if (!iso) return { year: null, month: null, day: null };
  const [y, m, d] = iso.split('-').map(Number);
  return { year: y, month: m, day: d };
}

// Coordenadas verbatim en grados/minutos/segundos. El ejemplo de la especificacion
// ("N 03° 43' 56.8''") trae la letra de hemisferio, pero la Plantilla.csv real la
// omite en verbatimLatitude/verbatimLongitude (solo aparece combinada en
// verbatimCoordinates) y usa variantes de comilla (´ en vez de ' , " en vez de '').
// Por eso la letra es opcional aqui: si no se escribe, se asume Norte/Oeste, que es
// el hemisferio de esta coleccion (Herbario LLANOS, Villavicencio, Meta).
const DMS_RE = /^\s*(?:([NSEW])\s*)?(\d{1,3})[°oO]\s*(\d{1,2})['′´]\s*(\d{1,2}(?:[.,]\d+)?)\s*(?:''|"|″)?\s*$/i;

function parseDMS(input, axis) {
  if (!input || !String(input).trim()) return { decimal: null, error: null };
  const raw = String(input).trim();
  const m = raw.match(DMS_RE);
  if (!m) {
    return { decimal: null, error: `Coordenada "${raw}" no tiene el formato esperado (p. ej. 03° 43' 56.8'', opcionalmente con N/S/E/W al inicio).` };
  }
  const defaultHemi = axis === 'lat' ? 'N' : 'W';
  const hemi = m[1] ? m[1].toUpperCase() : defaultHemi;
  const deg = Number(m[2]);
  const min = Number(m[3]);
  const sec = Number(m[4].replace(',', '.'));

  const expectedHemis = axis === 'lat' ? ['N', 'S'] : ['E', 'W'];
  if (!expectedHemis.includes(hemi)) {
    return { decimal: null, error: `Hemisferio "${hemi}" no valido para ${axis === 'lat' ? 'latitud' : 'longitud'}.` };
  }
  const maxDeg = axis === 'lat' ? 90 : 180;
  if (deg > maxDeg) return { decimal: null, error: `Grados fuera de rango (0-${maxDeg}).` };
  if (min >= 60) return { decimal: null, error: 'Minutos deben ser menores de 60.' };
  if (sec >= 60) return { decimal: null, error: 'Segundos deben ser menores de 60.' };

  let decimal = deg + min / 60 + sec / 3600;
  if (hemi === 'S' || hemi === 'W') decimal = -decimal;
  if (Math.abs(decimal) > maxDeg) return { decimal: null, error: `Coordenada fuera de rango (0-${maxDeg}).` };

  return { decimal: Number(decimal.toFixed(6)), error: null };
}

function collapseSpacesForCompare(value) {
  return String(value ?? '')
    .trim()
    .replace(/\s+/g, ' ');
}

function hasSpacingIssue(value) {
  if (value == null) return false;
  const s = String(value);
  return s !== s.trim() || /\s{2,}/.test(s);
}

function normalizeForDuplicate(value) {
  return collapseSpacesForCompare(value)
    .toUpperCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
}

// Advertencias no bloqueantes (seccion 4): taxonomia, elevacion, espacios.
function collectWarnings(record) {
  const warnings = [];

  if (record.specificEpithet && /\s/.test(record.specificEpithet.trim())) {
    warnings.push({ field: 'specificEpithet', message: 'El epíteto específico parece contener el nombre completo, no solo el epíteto.' });
  }
  if (record.genus && record.scientificName) {
    const firstWord = record.scientificName.trim().split(/\s+/)[0];
    if (firstWord && firstWord.toLowerCase() !== record.genus.trim().toLowerCase()) {
      warnings.push({ field: 'genus', message: `El género ("${record.genus}") no coincide con el primer término de scientificName ("${firstWord}").` });
    }
  }
  for (const field of ['genus', 'family', 'kingdom', 'phylum', 'class', 'order']) {
    const v = record[field];
    if (v && v !== v.charAt(0).toUpperCase() + v.slice(1).toLowerCase()) {
      warnings.push({ field, message: `"${v}" no sigue el uso convencional de mayúsculas para nombres taxonómicos.` });
    }
  }

  const vElev = parseFloat(String(record.verbatimElevation ?? '').replace(',', '.'));
  const minElev = record.minimumElevationInMeters != null ? parseFloat(record.minimumElevationInMeters) : null;
  const maxElev = record.maximumElevationInMeters != null ? parseFloat(record.maximumElevationInMeters) : null;
  if (!Number.isNaN(vElev) && minElev != null && maxElev != null && !Number.isNaN(minElev) && !Number.isNaN(maxElev)) {
    if (vElev < minElev || vElev > maxElev) {
      warnings.push({ field: 'verbatimElevation', message: `La elevación (${vElev}) está fuera del rango ${minElev}-${maxElev}.` });
    }
  }

  for (const [field, value] of Object.entries(record)) {
    if (typeof value === 'string' && hasSpacingIssue(value)) {
      warnings.push({ field, message: 'Contiene espacios sobrantes al inicio, al final o dobles.' });
    }
  }

  return warnings;
}

module.exports = {
  parseEventDate,
  isoToDisplay,
  deriveYearMonthDay,
  parseDMS,
  collapseSpacesForCompare,
  hasSpacingIssue,
  normalizeForDuplicate,
  collectWarnings,
};
