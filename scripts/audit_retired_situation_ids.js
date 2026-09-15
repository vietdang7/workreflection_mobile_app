#!/usr/bin/env node
/*
 * Audit the explicit v2 retirement list against the active local catalog.
 *
 * The list deliberately lives outside lib/, test/, and assets/: it is a
 * release/data audit, not runtime classification data.  Historical rows are
 * never deleted by this check; it only verifies that retired codes are absent
 * from the active v2 asset.
 *
 * Usage:
 *   node scripts/audit_retired_situation_ids.js
 *   node scripts/audit_retired_situation_ids.js --json
 */

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SITUATIONS_ASSET = path.join(ROOT, 'assets/seed/wr_situations.json');

// Explicit retirement audit. Keep these values readable for release review.
const RETIRED_SITUATION_CODES = Object.freeze([
  'S1-06',
  'S1-09',
  'S2-04',
  'S2-09',
  'C1-08',
  'C2-08',
  'C2-09',
  'A1-06',
  'A1-08',
  'A3-07',
  'A3-10',
]);

function readRows(assetPath = SITUATIONS_ASSET) {
  const value = JSON.parse(fs.readFileSync(assetPath, 'utf8'));
  if (!Array.isArray(value)) {
    throw new Error('Situation asset must contain a JSON array');
  }
  return value;
}

function rowCode(row) {
  return row && typeof row === 'object' ? row.id ?? row.code : undefined;
}

function auditRetiredSituationIds({ assetPath = SITUATIONS_ASSET } = {}) {
  const rows = readRows(assetPath);
  const realRows = rows.filter((row) => row && row.custom !== true);
  const activeCodes = realRows.map(rowCode).filter(Boolean);
  const activeCodeSet = new Set(activeCodes);
  const duplicateActiveCodes = activeCodes.filter(
    (code, index) => activeCodes.indexOf(code) !== index,
  );
  const activeRetiredCodes = RETIRED_SITUATION_CODES.filter((code) =>
    activeCodeSet.has(code),
  );

  return {
    activeRealCount: realRows.length,
    customCount: rows.length - realRows.length,
    customCode: rows.find((row) => row && row.custom === true)
      ? rowCode(rows.find((row) => row && row.custom === true))
      : null,
    retiredCount: RETIRED_SITUATION_CODES.length,
    retiredCodes: [...RETIRED_SITUATION_CODES],
    activeRetiredCodes,
    duplicateActiveCodes: [...new Set(duplicateActiveCodes)],
    pass:
      activeRetiredCodes.length === 0 &&
      duplicateActiveCodes.length === 0 &&
      realRows.length === 72 &&
      rows.length - realRows.length === 1,
  };
}

function main() {
  const result = auditRetiredSituationIds();
  if (process.argv.includes('--json')) {
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } else {
    process.stdout.write(
      `${result.pass ? '[PASS]' : '[FAIL]'} retired=${result.retiredCount} ` +
        `active=${result.activeRealCount} custom=${result.customCount} ` +
        `activeRetired=${result.activeRetiredCodes.length}\n`,
    );
  }
  if (!result.pass) process.exitCode = 1;
}

if (require.main === module) main();

module.exports = { RETIRED_SITUATION_CODES, auditRetiredSituationIds };
