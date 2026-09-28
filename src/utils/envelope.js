const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, AlignmentType, WidthType, BorderStyle } = require('docx');
const PDFDocument = require('pdfkit');

const MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

function fechaLarga(iso) {
  if (!iso) return null;
  const [y, m, d] = iso.split('-').map(Number);
  return `${d} de ${MESES[m - 1]} de ${y}`;
}

function nombreCientifico(record) {
  if (!record.scientificName) return null;
  const autoria = record.scientificNameAuthorship ? ` ${record.scientificNameAuthorship}` : '';
  return { cursiva: record.scientificName, resto: autoria };
}

function localidad(record) {
  const partes = [record.stateProvince, record.municipality, record.locality].filter(Boolean);
  if (!record.country && partes.length === 0) return null;
  return { pais: record.country ? record.country.toUpperCase() : null, resto: partes.join(', ') };
}

function altitud(record) {
  if (record.verbatimElevation) return `${record.verbatimElevation} msnm`;
  if (record.minimumElevationInMeters && record.maximumElevationInMeters) {
    return `${record.minimumElevationInMeters}–${record.maximumElevationInMeters} msnm`;
  }
  return null;
}

function numeroYColector(record) {
  if (!record.recordNumber && !record.recordedBy) return null;
  const match = String(record.recordNumber || '').match(/(\d+)\s*$/);
  const numero = match ? match[1] : record.recordNumber || '';
  const primerColector = String(record.recordedBy || '')
    .split(/[,;]/)[0]
    .trim();
  return { numero, colector: primerColector };
}

// Seccion 9: arma las lineas del sobre a partir del registro. Las lineas cuyo
// dato de origen esta vacio se omiten (regla explicita de la especificacion).
function buildEnvelopeModel(record, { organismTypeByPhylum, encabezado }) {
  const lines = [];

  lines.push({ kind: 'encabezado', text: encabezado });

  if (record.family) lines.push({ kind: 'familia', text: record.family.toUpperCase() });

  const cientifico = nombreCientifico(record);
  if (cientifico) lines.push({ kind: 'cientifico', ...cientifico });

  if (record.identifiedBy) lines.push({ kind: 'det', text: record.identifiedBy });

  const tipo = record.phylum ? organismTypeByPhylum[record.phylum] : null;
  if (tipo) lines.push({ kind: 'tipo', text: `${tipo}.` });

  const loc = localidad(record);
  if (loc) lines.push({ kind: 'localidad', ...loc });

  if (record.verbatimLatitude && record.verbatimLongitude) {
    // verbatimLatitude/verbatimLongitude normalmente no traen la letra de hemisferio
    // (ver Plantilla.csv); el sobre siempre la muestra, asumiendo Norte/Oeste si falta.
    const lat = /^[NS]/i.test(record.verbatimLatitude.trim()) ? record.verbatimLatitude : `N ${record.verbatimLatitude}`;
    const lon = /^[EW]/i.test(record.verbatimLongitude.trim()) ? record.verbatimLongitude : `W ${record.verbatimLongitude}`;
    lines.push({ kind: 'coordenadas', text: `${lat} ${lon}` });
  }

  const alt = altitud(record);
  if (alt) lines.push({ kind: 'alt', text: alt });

  const fecha = fechaLarga(record.eventDate);
  if (fecha) lines.push({ kind: 'fecha', text: fecha });

  const numColector = numeroYColector(record);
  if (numColector) lines.push({ kind: 'numero_colector', ...numColector });

  return lines;
}

const CM_TO_TWIP = 566.929;
const CM_TO_PT = 28.3465;

function buildEnvelopeDocxSection(lines) {
  const children = [];
  for (const line of lines) {
    switch (line.kind) {
      case 'encabezado':
        children.push(new Paragraph({
          alignment: AlignmentType.CENTER,
          children: [new TextRun({ text: line.text, bold: true, font: 'Arial', size: 24 })],
        }));
        break;
      case 'familia':
        children.push(new Paragraph({
          alignment: AlignmentType.RIGHT,
          children: [new TextRun({ text: line.text, font: 'Times New Roman', size: 22 })],
        }));
        break;
      case 'cientifico':
        children.push(new Paragraph({
          children: [
            new TextRun({ text: line.cursiva, italics: true, font: 'Times New Roman', size: 22 }),
            new TextRun({ text: line.resto, font: 'Times New Roman', size: 22 }),
          ],
        }));
        break;
      case 'localidad':
        children.push(new Paragraph({
          children: [
            line.pais ? new TextRun({ text: line.pais, bold: true, font: 'Times New Roman', size: 22 }) : null,
            line.resto ? new TextRun({ text: (line.pais ? ', ' : '') + line.resto, font: 'Times New Roman', size: 22 }) : null,
          ].filter(Boolean),
        }));
        break;
      case 'fecha':
        children.push(new Paragraph({
          alignment: AlignmentType.RIGHT,
          children: [new TextRun({ text: line.text, font: 'Times New Roman', size: 22 })],
        }));
        break;
      case 'numero_colector':
        children.push(new Paragraph({
          children: [
            new TextRun({ text: line.numero, bold: true, font: 'Times New Roman', size: 22 }),
            new TextRun({ text: ` ${line.colector}`, font: 'Times New Roman', size: 22 }),
          ],
        }));
        break;
      default:
        children.push(new Paragraph({
          children: [new TextRun({ text: line.text, font: 'Times New Roman', size: 22 })],
        }));
    }
  }
  return children;
}

function foldMarksRow() {
  return new TableRow({
    children: [
      new TableCell({ width: { size: 50, type: WidthType.PERCENTAGE }, children: [new Paragraph({ children: [new TextRun('+')] })], borders: noBorders() }),
      new TableCell({ width: { size: 50, type: WidthType.PERCENTAGE }, children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun('+')] })], borders: noBorders() }),
    ],
  });
}

function noBorders() {
  const none = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
  return { top: none, bottom: none, left: none, right: none };
}

// Genera un documento DOCX con un sobre por pagina (hoja Carta, seccion 9-10).
async function generateEnvelopeDocx(records, options) {
  const sections = records.map((record, idx) => {
    const lines = buildEnvelopeModel(record, options);
    const content = buildEnvelopeDocxSection(lines);
    return {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 2.5 * CM_TO_TWIP, bottom: 2.5 * CM_TO_TWIP, left: 3 * CM_TO_TWIP, right: 3 * CM_TO_TWIP },
        },
      },
      children: [
        new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: [foldMarksRow()] }),
        new Paragraph({ text: '' }),
        new Paragraph({ text: '' }),
        new Paragraph({ text: '' }),
        new Paragraph({ text: '' }),
        new Paragraph({ text: '' }),
        ...content,
      ],
    };
  });

  const doc = new Document({ sections });
  return Packer.toBuffer(doc);
}

// Genera un PDF con un sobre por pagina, replicando el mismo contenido que el DOCX.
function generateEnvelopePdf(records, options) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'LETTER', margins: {
      top: 2.5 * CM_TO_PT, bottom: 2.5 * CM_TO_PT, left: 3 * CM_TO_PT, right: 3 * CM_TO_PT,
    }});
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    records.forEach((record, idx) => {
      if (idx > 0) doc.addPage();
      const lines = buildEnvelopeModel(record, options);

      doc.font('Helvetica').fontSize(10).text('+', doc.page.margins.left - 20, doc.page.margins.top - 20);
      doc.text('+', doc.page.width - doc.page.margins.right, doc.page.margins.top - 20);

      let y = doc.page.margins.top + 10;
      const left = doc.page.margins.left;
      const width = doc.page.width - doc.page.margins.left - doc.page.margins.right;

      for (const line of lines) {
        switch (line.kind) {
          case 'encabezado':
            doc.font('Helvetica-Bold').fontSize(13).text(line.text, left, y, { width, align: 'center' });
            break;
          case 'familia':
            doc.font('Times-Roman').fontSize(11).text(line.text, left, y, { width, align: 'right' });
            break;
          case 'cientifico':
            doc.font('Times-Italic').fontSize(11).text(line.cursiva + line.resto, left, y, { width, continued: false });
            break;
          case 'localidad':
            doc.font('Times-Bold').fontSize(11).text((line.pais || '') + (line.resto ? (line.pais ? ', ' : '') + line.resto : ''), left, y, { width });
            break;
          case 'fecha':
            doc.font('Times-Roman').fontSize(11).text(line.text, left, y, { width, align: 'right' });
            break;
          case 'numero_colector':
            doc.font('Times-Bold').fontSize(11).text(`${line.numero} ${line.colector}`, left, y, { width });
            break;
          default:
            doc.font('Times-Roman').fontSize(11).text(line.text, left, y, { width });
        }
        y = doc.y + 4;
      }
    });

    doc.end();
  });
}

module.exports = { buildEnvelopeModel, generateEnvelopeDocx, generateEnvelopePdf };
