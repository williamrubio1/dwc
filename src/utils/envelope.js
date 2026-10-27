const {
  Document, Packer, Paragraph, TextRun, Tab, AlignmentType, TabStopType,
  FrameAnchorType, FrameWrap, HeightRule,
} = require('docx');
const PDFDocument = require('pdfkit');

// Medidas tomadas del modelo aprobado (SobresMusgos.docx), exportado con Word, en
// puntos desde la esquina superior izquierda de la hoja Carta. La etiqueta del modelo
// es un cuadro flotante con posicion absoluta (no respeta el margen inferior), asi que
// aqui tambien se coloca de forma absoluta: la hoja se dobla siempre por las mismas
// marcas y la etiqueta debe caer siempre en el mismo lugar.
const FONT = 'Times New Roman';
const PAGE_W = 612;
const PAGE_H = 792;
const TEXT_LEFT = 112.19; // 3 cm de margen + 19,95 pt de desplazamiento del cuadro + 7,2 pt de sangria
const TEXT_WIDTH = 386.1; // cuadro de 400,5 pt menos las dos sangrias
const TEXT_RIGHT = TEXT_LEFT + TEXT_WIDTH;
const TEXT_CENTER = TEXT_LEFT + TEXT_WIDTH / 2;
const DET_CENTER = TEXT_LEFT + 160; // en el modelo "Det." queda centrado en 3,78", no en el centro del cuadro
const ALIGN_RIGHT = 494.64; // 6,87": donde terminan la familia y la fecha en el modelo (borde derecho del cuadro: 6,92")
const BODY_SIZE = 12;
const FOLD_SIZE = 20;
const PITCH = 1.15; // interlineado sencillo de Times New Roman
const ASCENT = 0.891;
const BLOCK_TOP = 553.56; // arriba de la primera linea (7,69")
const CM = 28.3465;
// Marcas de doblez: la superior queda a 3,70" (igual al modelo); la inferior se subio 0,5 cm
// respecto al modelo (7,53" -> 7,33") y el texto de la etiqueta conserva su posicion (BLOCK_TOP).
const FOLD_TOPS = [255.6, 531.4 - 0.5 * CM];
const FOLD_LEFT_X = 95.0;
const FOLD_RIGHT_X = 506.9;
// Si la ultima linea pasa de aqui (0,2" del borde, un margen minimo de impresora) se
// reduce la letra de la localidad hasta que quepa.
const PRINT_BOTTOM_LIMIT = PAGE_H - 14.4;
const MIN_FIT_SIZE = 8;

const MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const twips = (pt) => Math.round(pt * 20);
const v = (x) => String(x ?? '').trim();
const seg = (t, o = {}) => ({ t, bold: !!o.bold, italic: !!o.italic });

function fechaLarga(iso) {
  if (!iso) return null;
  const [y, m, d] = String(iso).slice(0, 10).split('-').map(Number);
  if (!y || !m || !d) return null;
  return `${d} de ${MESES[m - 1]} de ${y}`;
}

// Abreviaturas de rango/determinacion que no van en cursiva (sp., cf., var., ...).
// Las iniciales de genero ("R. flexuosa") si van en cursiva.
const NO_ITALIC = /^(sp|spp|cf|aff|var|subsp|ssp|f|fo|nov|ined)\.$/;

function scientificSegs(name, authorship) {
  const words = v(name).split(/\s+/).filter(Boolean);
  const segs = [];
  words.forEach((w, i) => {
    const italic = !NO_ITALIC.test(w);
    const text = (i > 0 ? ' ' : '') + w;
    const last = segs[segs.length - 1];
    if (last && last.italic === italic) last.t += text;
    else segs.push(seg(text, { italic }));
  });
  if (v(authorship)) segs.push(seg(' ' + v(authorship)));
  return segs;
}

// Formato del modelo: N 04°09'12,8'' W 73°39'21,0'' (sin espacios, coma decimal, comillas dobles de apostrofe).
const DMS_PRINT = /^\s*(?:([NSEW])\s*)?(\d{1,3})\s*[°oO]\s*(\d{1,2})\s*['′´]\s*(\d{1,2}(?:[.,]\d+)?)\s*(?:''|"|″)?\s*$/i;

function formatCoordinate(raw, defaultHemi) {
  const s = v(raw);
  const m = s.match(DMS_PRINT);
  if (!m) return /^[NSEW]\b/i.test(s) ? s : `${defaultHemi} ${s}`;
  const hemi = (m[1] || defaultHemi).toUpperCase();
  const deg = String(Number(m[2])).padStart(2, '0');
  const min = m[3].padStart(2, '0');
  const [si, sd] = m[4].replace(',', '.').split('.');
  const sec = si.padStart(2, '0') + (sd !== undefined ? ',' + sd : '');
  return `${hemi} ${deg}°${min}'${sec}''`;
}

// La base guarda las elevaciones como DECIMAL ("589.00"); en el sobre se imprimen sin ceros sobrantes.
const metros = (x) => (Number.isFinite(Number(v(x))) ? String(Number(v(x))) : v(x));

function altitud(record) {
  if (v(record.verbatimElevation)) return `${v(record.verbatimElevation)} msnm.`;
  if (v(record.minimumElevationInMeters) && v(record.maximumElevationInMeters)) {
    return `${metros(record.minimumElevationInMeters)}–${metros(record.maximumElevationInMeters)} msnm.`;
  }
  return null;
}

// Seccion 9: arma las filas del sobre en el orden y agrupacion del modelo (una linea en
// blanco entre grupos). Los datos vacios omiten su linea, y el grupo si queda sin lineas.
function buildEnvelopeRows(record, { organismTypeByPhylum, encabezado }) {
  const groups = [];

  const g1 = [{ type: 'text', align: 'center', segs: [seg(v(encabezado), { bold: true })] }];
  if (v(record.family)) g1.push({ type: 'text', align: 'right', segs: [seg(v(record.family).toUpperCase())] });
  if (v(record.scientificName)) {
    g1.push({ type: 'text', align: 'left', segs: scientificSegs(record.scientificName, record.scientificNameAuthorship) });
  }
  groups.push(g1);

  if (v(record.identifiedBy)) {
    groups.push([{ type: 'text', align: 'det', segs: [seg(`Det.  ${v(record.identifiedBy)}`)] }]);
  }

  const tipo = v(record.phylum) ? organismTypeByPhylum[v(record.phylum)] : null;
  if (tipo) groups.push([{ type: 'text', align: 'left', segs: [seg(`${tipo}.`)] }]);

  const g4 = [];
  const country = v(record.country);
  const rest = [record.stateProvince, record.municipality, record.locality].map(v).filter(Boolean).join(', ');
  if (country || rest) {
    const segs = [];
    if (country) segs.push(seg(country.toUpperCase() + (rest ? ', ' : ''), { bold: true }));
    segs.push(seg(rest ? (/[.!?]$/.test(rest) ? rest : `${rest}.`) : '.'));
    g4.push({ type: 'text', align: 'justify', fit: true, segs });
  }
  if (v(record.verbatimLatitude) && v(record.verbatimLongitude)) {
    // verbatimLatitude/verbatimLongitude suelen venir sin letra de hemisferio: se asume Norte/Oeste.
    const lat = formatCoordinate(record.verbatimLatitude, 'N');
    const lon = formatCoordinate(record.verbatimLongitude, 'W');
    g4.push({ type: 'text', align: 'left', segs: [seg(`Coordenadas ${lat} ${lon}`)] });
  }
  if (g4.length) groups.push(g4);

  const alt = altitud(record);
  const fecha = fechaLarga(record.eventDate);
  if (alt || fecha) {
    if (alt && fecha) {
      groups.push([{ type: 'text', align: 'lr', segs: [seg('Alt', { bold: true }), seg(`. ${alt}`)], rightSegs: [seg(fecha)] }]);
    } else if (alt) {
      groups.push([{ type: 'text', align: 'left', segs: [seg('Alt', { bold: true }), seg(`. ${alt}`)] }]);
    } else {
      groups.push([{ type: 'text', align: 'right', segs: [seg(fecha)] }]);
    }
  }

  // Ultima linea: numero de colecta (parte numerica final de recordNumber, en negrita) seguido
  // de recordedBy completo tal como esta guardado (solo se limpian espacios sobrantes).
  const colectores = v(record.recordedBy).replace(/\s+/g, ' ');
  if (v(record.recordNumber) || colectores) {
    const match = v(record.recordNumber).match(/(\d+)\s*$/);
    const numero = match ? match[1] : v(record.recordNumber);
    const segs = [];
    if (numero) segs.push(seg(numero, { bold: true }));
    if (colectores) segs.push(seg((numero ? ' ' : '') + colectores));
    groups.push([{ type: 'text', align: 'left', fit: true, segs }]);
  }

  const rows = [];
  groups.forEach((g, i) => {
    if (i > 0) rows.push({ type: 'blank' });
    rows.push(...g);
  });
  return rows;
}

// ---- Medicion con las metricas de Times (iguales a las de Times New Roman) ----
let measureDoc = null;
function fontName(s) {
  if (s.bold && s.italic) return 'Times-BoldItalic';
  if (s.bold) return 'Times-Bold';
  if (s.italic) return 'Times-Italic';
  return 'Times-Roman';
}
function textWidth(text, style, size) {
  if (!measureDoc) measureDoc = new PDFDocument({ size: 'LETTER' });
  return measureDoc.font(fontName(style)).fontSize(size).widthOfString(text, { lineBreak: false });
}

function tokenize(segs) {
  const tokens = [];
  for (const s of segs) {
    for (const part of s.t.split(/(\s+)/)) {
      if (part === '') continue;
      tokens.push({ t: part, bold: s.bold, italic: s.italic, space: /^\s+$/.test(part) });
    }
  }
  return tokens;
}

function mergeTokens(tokens) {
  const segs = [];
  for (const t of tokens) {
    const last = segs[segs.length - 1];
    if (last && last.bold === t.bold && last.italic === t.italic) last.t += t.t;
    else segs.push(seg(t.t, t));
  }
  return segs;
}

function wrapSegs(segs, size, width) {
  const lines = [];
  let cur = [];
  let curW = 0;
  for (const tk of tokenize(segs)) {
    const w = textWidth(tk.t, tk, size);
    if (!tk.space && curW + w > width && cur.length) {
      while (cur.length && cur[cur.length - 1].space) cur.pop();
      lines.push(cur);
      cur = [];
      curW = 0;
    }
    if (tk.space && !cur.length) continue;
    cur.push(tk);
    curW += w;
  }
  while (cur.length && cur[cur.length - 1].space) cur.pop();
  if (cur.length) lines.push(cur);
  return lines.length ? lines : [[]];
}

// Posiciona cada linea. Devuelve las lineas con su "top"; cada fila ajustable queda con su letra en row.size.
// Si la ultima linea se acerca al borde, baja la letra de las filas ajustables (localidad y colectores)
// que ocupan mas de una linea; las de una sola linea no se tocan.
function layoutEnvelope(record, options) {
  const rows = buildEnvelopeRows(record, options);
  const flex = new Set(rows.filter((r) => r.fit && wrapSegs(r.segs, BODY_SIZE, TEXT_WIDTH).length > 1));
  let fitSize = BODY_SIZE;
  for (;;) {
    const lines = [];
    let top = BLOCK_TOP;
    for (const row of rows) {
      if (row.type === 'blank') {
        top += BODY_SIZE * PITCH;
        continue;
      }
      const size = flex.has(row) ? fitSize : BODY_SIZE;
      row.size = size;
      const wrapped = row.align === 'lr' ? [tokenize(row.segs)] : wrapSegs(row.segs, size, TEXT_WIDTH);
      wrapped.forEach((tokens, i) => {
        const isLast = i === wrapped.length - 1;
        lines.push({
          align: row.align === 'justify' && isLast ? 'left' : row.align,
          size,
          top,
          tokens,
          rightSegs: row.rightSegs,
        });
        top += size * PITCH;
      });
    }
    const last = lines[lines.length - 1];
    const bottom = last ? last.top + last.size * PITCH : BLOCK_TOP;
    if (bottom <= PRINT_BOTTOM_LIMIT || fitSize <= MIN_FIT_SIZE || !flex.size) return { rows, lines, fitSize, bottom };
    fitSize -= 0.5;
  }
}

// ---- DOCX: marcos con posicion absoluta respecto a la hoja, como el cuadro del modelo ----
function frame(xPt, yPt, wPt) {
  return {
    type: 'absolute',
    position: { x: twips(xPt), y: twips(yPt) },
    width: twips(wPt),
    height: 300,
    rule: HeightRule.ATLEAST,
    anchor: { horizontal: FrameAnchorType.PAGE, vertical: FrameAnchorType.PAGE },
    wrap: FrameWrap.AROUND,
  };
}

function runs(segs, size) {
  return segs.map((s) => new TextRun({ text: s.t, bold: s.bold, italics: s.italic, font: FONT, size: Math.round(size * 2) }));
}

function docxParagraph(row, blockFrame) {
  if (row.type === 'blank') return new Paragraph({ frame: blockFrame, children: [] });
  const size = row.size || BODY_SIZE;
  const base = { frame: blockFrame, children: runs(row.segs, size) };
  switch (row.align) {
    case 'center': return new Paragraph({ ...base, alignment: AlignmentType.CENTER });
    case 'right':
      return new Paragraph({ ...base, alignment: AlignmentType.RIGHT, indent: { right: twips(TEXT_RIGHT - ALIGN_RIGHT) } });
    case 'justify': return new Paragraph({ ...base, alignment: AlignmentType.JUSTIFIED });
    case 'det':
      return new Paragraph({ ...base, alignment: AlignmentType.CENTER, indent: { right: twips(2 * (TEXT_CENTER - DET_CENTER)) } });
    case 'lr':
      return new Paragraph({
        frame: blockFrame,
        tabStops: [{ type: TabStopType.RIGHT, position: twips(ALIGN_RIGHT - TEXT_LEFT) }],
        children: [
          ...runs(row.segs, size),
          new TextRun({ children: [new Tab()], font: FONT, size: Math.round(size * 2) }),
          ...runs(row.rightSegs, size),
        ],
      });
    default: return new Paragraph(base);
  }
}

// Ajuste (pt) entre la posicion pedida y la que Word dibuja, medido contra el modelo.
const DOCX_Y_ADJUST = 0;

async function generateEnvelopeDocx(records, options) {
  const sections = records.map((record) => {
    const { rows } = layoutEnvelope(record, options);
    const blockFrame = frame(TEXT_LEFT, BLOCK_TOP + DOCX_Y_ADJUST, TEXT_WIDTH);
    const plus = (x, top) => new Paragraph({
      frame: frame(x, top + DOCX_Y_ADJUST, 24),
      children: [new TextRun({ text: '+', font: FONT, size: FOLD_SIZE * 2 })],
    });
    return {
      properties: {
        page: {
          size: { width: twips(PAGE_W), height: twips(PAGE_H) },
          margin: { top: 1418, bottom: 1418, left: 1701, right: 1701 },
        },
      },
      children: [
        plus(FOLD_LEFT_X, FOLD_TOPS[0]),
        plus(FOLD_RIGHT_X, FOLD_TOPS[0]),
        plus(FOLD_LEFT_X, FOLD_TOPS[1]),
        plus(FOLD_RIGHT_X, FOLD_TOPS[1]),
        ...rows.map((row) => docxParagraph(row, blockFrame)),
        new Paragraph({ children: [] }),
      ],
    };
  });

  const doc = new Document({
    styles: {
      default: {
        document: {
          run: { font: FONT, size: BODY_SIZE * 2 },
          paragraph: { spacing: { before: 0, after: 0 } },
        },
      },
    },
    sections,
  });
  return Packer.toBuffer(doc);
}

// ---- PDF: mismas posiciones, dibujadas linea por linea ----
function generateEnvelopePdf(records, options) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'LETTER', margin: 0, info: { Title: 'Sobres de herbario' } });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    const draw = (text, style, size, x, baseline) => {
      doc.font(fontName(style)).fontSize(size).text(text, x, baseline, { lineBreak: false, baseline: 'alphabetic' });
    };
    const widthOf = (tokens, size) => tokens.reduce((a, tk) => a + textWidth(tk.t, tk, size), 0);

    records.forEach((record, idx) => {
      if (idx > 0) doc.addPage();
      const { lines } = layoutEnvelope(record, options);

      for (const top of FOLD_TOPS) {
        const baseline = top + ASCENT * FOLD_SIZE;
        draw('+', {}, FOLD_SIZE, FOLD_LEFT_X, baseline);
        draw('+', {}, FOLD_SIZE, FOLD_RIGHT_X, baseline);
      }

      for (const ln of lines) {
        const baseline = ln.top + ASCENT * ln.size;
        const w = widthOf(ln.tokens, ln.size);
        if (ln.align === 'justify') {
          const gaps = ln.tokens.filter((t) => t.space).length;
          const extra = gaps ? (TEXT_WIDTH - w) / gaps : 0;
          let x = TEXT_LEFT;
          for (const tk of ln.tokens) {
            const tw = textWidth(tk.t, tk, ln.size);
            if (!tk.space) draw(tk.t, tk, ln.size, x, baseline);
            x += tw + (tk.space ? extra : 0);
          }
          continue;
        }
        let x = TEXT_LEFT;
        if (ln.align === 'center') x = TEXT_CENTER - w / 2;
        else if (ln.align === 'det') x = DET_CENTER - w / 2;
        else if (ln.align === 'right') x = ALIGN_RIGHT - w;
        let cx = x;
        for (const s of mergeTokens(ln.tokens)) {
          draw(s.t, s, ln.size, cx, baseline);
          cx += textWidth(s.t, s, ln.size);
        }
        if (ln.align === 'lr' && ln.rightSegs) {
          const rt = tokenize(ln.rightSegs);
          let rx = ALIGN_RIGHT - widthOf(rt, ln.size);
          for (const s of mergeTokens(rt)) {
            draw(s.t, s, ln.size, rx, baseline);
            rx += textWidth(s.t, s, ln.size);
          }
        }
      }
    });

    doc.end();
  });
}

module.exports = { buildEnvelopeRows, layoutEnvelope, generateEnvelopeDocx, generateEnvelopePdf };
