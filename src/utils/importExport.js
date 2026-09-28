const { parse } = require('csv-parse/sync');
const { stringify } = require('csv-stringify/sync');
const ExcelJS = require('exceljs');
const iconv = require('iconv-lite');
const { FIELD_NAMES } = require('./dwcTerms');

// Seccion 3: exportacion en CSV UTF-8 separador ';' (con BOM para que Excel en
// español detecte la codificacion y no dañe las tildes) y XLSX.
function toCsv(rows) {
  const csv = stringify(rows, { header: true, columns: FIELD_NAMES, delimiter: ';' });
  return '﻿' + csv;
}

async function toXlsx(rows) {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Registros');
  sheet.columns = FIELD_NAMES.map((f) => ({ header: f, key: f }));
  sheet.addRows(rows);
  return workbook.xlsx.writeBuffer();
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

// exceljs entrega tipos nativos por celda (Date, formulas, hipervinculos), no solo
// texto. Si no se distinguen, Date termina como "Thu Apr 03 2025 00:00:00 GMT..."
// (toString por defecto) en vez de la fecha que el usuario ve en la hoja.
function cellToString(cell) {
  if (cell == null) return '';
  if (cell instanceof Date) {
    return `${cell.getUTCFullYear()}-${pad2(cell.getUTCMonth() + 1)}-${pad2(cell.getUTCDate())}`;
  }
  if (typeof cell === 'object') {
    if (cell.text != null) return String(cell.text);
    if (cell.result != null) return cellToString(cell.result);
  }
  return String(cell);
}

// Seccion 3: importacion acepta CSV (UTF-8 o Latin-1/ISO-8859-1, separador ';') y XLSX.
async function parseImportBuffer(buffer, filename) {
  const lower = filename.toLowerCase();
  if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(buffer);
    const sheet = workbook.worksheets[0];
    const [headerRow, ...dataRows] = sheet.getRows(1, sheet.rowCount) || [];
    const headers = (headerRow ? headerRow.values : []).map((v) => cellToString(v).trim());
    return dataRows
      .filter((row) => row.values.some((v) => v != null && cellToString(v).trim() !== ''))
      .map((row) => {
        const record = {};
        headers.forEach((h, idx) => {
          if (!h) return;
          record[h] = cellToString(row.values[idx]).trim();
        });
        return record;
      });
  }

  let text = buffer.toString('utf8');
  const hasReplacementChars = text.includes('�');
  if (hasReplacementChars) {
    text = iconv.decode(buffer, 'latin1');
  }
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);

  const records = parse(text, {
    columns: true,
    delimiter: ';',
    skip_empty_lines: true,
    trim: false,
    relax_column_count: true,
  });
  return records;
}

module.exports = { toCsv, toXlsx, parseImportBuffer };
