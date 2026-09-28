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

// Seccion 3: importacion acepta CSV (UTF-8 o Latin-1/ISO-8859-1, separador ';') y XLSX.
async function parseImportBuffer(buffer, filename) {
  const lower = filename.toLowerCase();
  if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(buffer);
    const sheet = workbook.worksheets[0];
    const [headerRow, ...dataRows] = sheet.getRows(1, sheet.rowCount) || [];
    const headers = (headerRow ? headerRow.values : []).map((v) => (v == null ? '' : String(v).trim()));
    return dataRows
      .filter((row) => row.values.some((v) => v != null && String(v).trim() !== ''))
      .map((row) => {
        const record = {};
        headers.forEach((h, idx) => {
          if (!h) return;
          const cell = row.values[idx];
          record[h] = cell == null ? '' : String(cell.text != null ? cell.text : cell).trim();
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
