#!/usr/bin/env node
/*
 * Convert the supplied editorial situation file into the app's seed formats.
 *
 * SITUATIONS_v2.js is deliberately evaluated in a small VM instead of being
 * copied into another source file.  That keeps the editorial strings byte-for-
 * byte under the content team's control while producing the database aliases
 * used by the existing repositories.
 *
 * Usage:
 *   node scripts/import_situations_v2.js --source /path/to/SITUATIONS_v2.js
 *   WR_SITUATIONS_SOURCE=/path/to/SITUATIONS_v2.js node scripts/import_situations_v2.js
 */

'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..');
const SITUATIONS_OUT = path.join(ROOT, 'assets/seed/wr_situations.json');
const STORIES_OUT = path.join(ROOT, 'assets/seed/wr_stories.json');
const MIGRATION_OUT = path.join(
  ROOT,
  'supabase/migrations/20260914000000_wr_situations_v2.sql',
);

// English editorial content, keyed by situation id.
//
// SITUATIONS_v2.js is Vietnamese only, and the app renders English through
// `trDb(vi, en)`, which falls back to Vietnamese whenever the English value is
// null.  Generating the seeds from the source alone therefore produces a build
// where every chip, story, reflection question and aha message reads Vietnamese
// in English mode, silently and with all tests still green.  This file is the
// English side, and `editorialEnglish` below refuses to generate anything at
// all when a live situation is missing from it.
const TRANSLATIONS_IN = path.join(ROOT, 'scripts/situations_v2_en.json');

const MOODS = new Set(['stress', 'tired', 'foggy', 'outofsync', 'ok', 'happy']);
const VALENCES = new Set(['thach-thuc', 'tich-cuc']);
const PILLARS = new Set(['S', 'C', 'A']);
const CHALLENGE_SUBGROUPS = new Set(['S1', 'S2', 'C1', 'C2', 'A1', 'A3']);
const SUBGROUP_PILLARS = new Map([
  ['S1', 'S'],
  ['S2', 'S'],
  ['C1', 'C'],
  ['C2', 'C'],
  ['A1', 'A'],
  ['A3', 'A'],
  ['Sp', 'S'],
  ['Cp', 'C'],
  ['Ap', 'A'],
]);
const NEEDS = new Map([
  ['Structure', 'ro_rang'],
  ['Connection', 'ket_noi'],
  ['Adaptability', 'thich_nghi'],
  ['Phát triển', 'phat_trien'],
]);

function argument(name, fallback) {
  const index = process.argv.indexOf(name);
  return index >= 0 && process.argv[index + 1]
    ? process.argv[index + 1]
    : fallback;
}

function resolveSourcePath() {
  const sourcePath = argument('--source', process.env.WR_SITUATIONS_SOURCE);
  if (!sourcePath) {
    throw new Error(
      'Missing editorial source. Pass --source /path/to/SITUATIONS_v2.js or set WR_SITUATIONS_SOURCE.',
    );
  }
  return path.resolve(sourcePath);
}

function loadEditorialRows(sourcePath) {
  let source;
  try {
    source = fs.readFileSync(sourcePath, 'utf8');
  } catch (error) {
    throw new Error(
      `Unable to read editorial source "${sourcePath}". ` +
        'Pass --source /path/to/SITUATIONS_v2.js or set WR_SITUATIONS_SOURCE. ' +
        `Original error: ${error.message}`,
    );
  }
  const context = {};
  vm.createContext(context);
  vm.runInContext(
    `${source}\n;globalThis.__wrSituations = SITUATIONS;`,
    context,
    { filename: sourcePath },
  );
  if (!Array.isArray(context.__wrSituations)) {
    throw new Error('SITUATIONS_v2.js did not expose an array named SITUATIONS');
  }
  return Array.from(context.__wrSituations);
}

function compatibilityDimension(row) {
  if (row.custom) return null;
  if (row.valence === 'tich-cuc') {
    return row.mood === 'ok' ? 'P-STEADY' : 'P-ACHIEVE';
  }
  return row.subgroup;
}

function compatibilityWave(row) {
  if (row.custom) return null;
  return ({
    A1: 1,
    A3: 1,
    C1: 1,
    C2: 1,
    S1: 2,
    S2: 3,
    Ap: 1,
    Cp: 1,
    Sp: 1,
  })[row.subgroup] || 1;
}

function databaseNeed(row) {
  if (row.need == null) return null;
  const mapped = NEEDS.get(row.need);
  if (mapped == null) throw new Error(`Unknown editorial need: ${row.need}`);
  return mapped;
}

// Editorial axis labels that leaked into a title in the source file.
//
// C1-10 ships as `Tôi cảm thấy an tâm khi làm việc cùng họ valence: tích cực`.
// That trailing fragment is classification metadata, not a sentence the user is
// meant to read, and `title` is displayed verbatim on the Notice chips, the
// Home "system noticed" card and inside Deep Reading paragraphs.  The axis is
// already carried by the `valence` field, so the text is stripped here rather
// than in the app: every consumer of the generated files then sees one clean
// title, and re-running this importer on an unfixed source cannot bring it
// back.  Only a trailing label is removed; nothing inside a sentence is
// touched.
const TITLE_AXIS_SUFFIX =
  /\s*(?:valence|pillar|subgroup|mood)\s*:\s*[^.!?]*$/iu;

function editorialTitle(row) {
  const title = row.title;
  if (typeof title !== 'string') return title;
  const cleaned = title.replace(TITLE_AXIS_SUFFIX, '').trim();
  return cleaned.length > 0 ? cleaned : title.trim();
}

const EDITORIAL_FIELDS = [
  'title',
  'story',
  'reflection',
  'selfReflection',
  'aha',
  'practice',
];

function loadTranslations() {
  const raw = JSON.parse(fs.readFileSync(TRANSLATIONS_IN, 'utf8'));
  delete raw._comment;
  return raw;
}

/// English row for [row], or null for the client-only custom option.
///
/// Throws when a live situation has no translation, or has one with a blank or
/// missing field. A Vietnamese-only English build is the exact failure this
/// importer exists to prevent, and it is invisible at runtime: the fallback in
/// `trDb` renders Vietnamese without any error.
function editorialEnglish(row, translations) {
  if (row.custom) return null;
  const entry = translations[row.id];
  if (entry == null) {
    throw new Error(
      `Missing English content for ${row.id}. Add it to scripts/situations_v2_en.json.`,
    );
  }
  for (const field of EDITORIAL_FIELDS) {
    const value = entry[field];
    if (typeof value !== 'string' || value.trim().length === 0) {
      throw new Error(
        `English content for ${row.id} is missing "${field}" in scripts/situations_v2_en.json.`,
      );
    }
  }
  return entry;
}

function toSituation(row, english) {
  const real = !row.custom;
  return {
    // Keep every editorial property in the generated asset.  The aliases below
    // are the names expected by the existing Supabase model/repository.
    id: row.id,
    pillar: row.pillar ?? null,
    subgroup: row.subgroup ?? null,
    mood: row.mood ?? null,
    valence: row.valence ?? null,
    need: row.need ?? null,
    title: editorialTitle(row),
    story: row.story ?? null,
    reflection: row.reflection ?? null,
    selfReflection: row.selfReflection ?? null,
    aha: row.aha ?? null,
    practice: row.practice ?? null,
    ...(row.custom ? { custom: true } : {}),
    code: row.id,
    text: editorialTitle(row),
    text_en: english?.title ?? null,
    sca_dimension: compatibilityDimension(row),
    human_need: databaseNeed(row),
    wave: compatibilityWave(row),
  };
}

function toStory(row, english) {
  if (row.custom) return null;
  return {
    // Keep the source-shaped fields beside the established story schema so a
    // future importer can validate this file without reconstructing the JS.
    id: row.id,
    pillar: row.pillar,
    subgroup: row.subgroup,
    mood: row.mood,
    valence: row.valence,
    need: row.need,
    story: row.story,
    reflection: row.reflection,
    selfReflection: row.selfReflection,
    aha: row.aha,
    practice: row.practice,
    story_id: row.id,
    title: editorialTitle(row),
    sca_dimension: compatibilityDimension(row),
    human_need: databaseNeed(row),
    situation: editorialTitle(row),
    emotion_tags: [],
    behavior_tags: [],
    career_stages: [],
    difficulty_level: null,
    story_content: row.story,
    reflection_question: row.reflection,
    self_reflection: row.selfReflection,
    aha_message: row.aha,
    practice_action: row.practice,
    title_en: english.title,
    story_content_en: english.story,
    reflection_question_en: english.reflection,
    self_reflection_en: english.selfReflection,
    aha_message_en: english.aha,
    practice_action_en: english.practice,
  };
}

function sql(value) {
  if (value == null) return 'NULL';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return String(value);
  if (Array.isArray(value)) {
    if (value.length === 0) return "ARRAY[]::text[]";
    return `ARRAY[${value.map(sql).join(', ')}]`;
  }
  return `'${String(value).replaceAll("'", "''")}'`;
}

function situationSql(rows) {
  const real = rows.filter((row) => !row.custom);
  const values = real
    .map(
      (row) =>
        `  (${sql(row.code)}, ${sql(row.text)}, ${sql(row.text_en)}, ${sql(
          row.sca_dimension,
        )}, ${sql(row.human_need)}, ${sql(row.wave)}, ${sql(row.pillar)}, ${sql(
          row.subgroup,
        )}, ${sql(row.mood)}, ${sql(row.valence)})`,
    )
    .join(',\n');
  const codes = real.map((row) => sql(row.code)).join(', ');
  return `-- Generated from SITUATIONS_v2.js. Do not hand-edit this block.
-- The custom "other" option is intentionally client-side and is not inserted.

alter table public.wr_situations
  add column if not exists retired_at timestamptz;

-- The English column predates this migration, but guard it anyway: without a
-- value here every situation renders Vietnamese in English mode, and nothing
-- in the app reports that as an error.
alter table public.wr_situations
  add column if not exists text_en text;

alter table public.wr_situations
  add column if not exists pillar text;
alter table public.wr_situations
  add column if not exists subgroup text;
alter table public.wr_situations
  add column if not exists mood text;
alter table public.wr_situations
  add column if not exists valence text;

alter table public.wr_situations
  drop constraint if exists wr_situations_pillar_check;
alter table public.wr_situations
  add constraint wr_situations_pillar_check
  check (pillar is null or pillar in ('S', 'C', 'A'));

alter table public.wr_situations
  drop constraint if exists wr_situations_subgroup_check;
alter table public.wr_situations
  add constraint wr_situations_subgroup_check
  check (subgroup is null or subgroup in ('S1', 'S2', 'C1', 'C2', 'A1', 'A3', 'Sp', 'Cp', 'Ap'));

alter table public.wr_situations
  drop constraint if exists wr_situations_mood_check;
alter table public.wr_situations
  add constraint wr_situations_mood_check
  check (mood is null or mood in ('stress', 'tired', 'foggy', 'outofsync', 'ok', 'happy'));

alter table public.wr_situations
  drop constraint if exists wr_situations_valence_check;
alter table public.wr_situations
  add constraint wr_situations_valence_check
  check (valence is null or valence in ('thach-thuc', 'tich-cuc'));

-- Stories carry the same explicit axes when the deployed schema supports them.
-- The app still uses the local catalog if this migration has not run yet.
alter table public.wr_stories
  add column if not exists pillar text,
  add column if not exists subgroup text,
  add column if not exists mood text,
  add column if not exists valence text;

alter table public.wr_stories
  add column if not exists title_en text,
  add column if not exists story_content_en text,
  add column if not exists reflection_question_en text,
  add column if not exists self_reflection_en text,
  add column if not exists aha_message_en text,
  add column if not exists practice_action_en text;

alter table public.wr_stories
  drop constraint if exists wr_stories_pillar_check;
alter table public.wr_stories
  add constraint wr_stories_pillar_check
  check (pillar is null or pillar in ('S', 'C', 'A'));
alter table public.wr_stories
  drop constraint if exists wr_stories_subgroup_check;
alter table public.wr_stories
  add constraint wr_stories_subgroup_check
  check (subgroup is null or subgroup in ('S1', 'S2', 'C1', 'C2', 'A1', 'A3', 'Sp', 'Cp', 'Ap'));
alter table public.wr_stories
  drop constraint if exists wr_stories_mood_check;
alter table public.wr_stories
  add constraint wr_stories_mood_check
  check (mood is null or mood in ('stress', 'tired', 'foggy', 'outofsync', 'ok', 'happy'));
alter table public.wr_stories
  drop constraint if exists wr_stories_valence_check;
alter table public.wr_stories
  add constraint wr_stories_valence_check
  check (valence is null or valence in ('thach-thuc', 'tich-cuc'));

-- Keep every historical row for foreign keys and old Career Memory links, but
-- stop offering anything outside the v2 catalog.
update public.wr_situations
   set retired_at = coalesce(retired_at, now())
 where code not in (${codes});

insert into public.wr_situations
  (code, text, text_en, sca_dimension, human_need, wave, pillar, subgroup, mood, valence)
values
${values}
on conflict (code) do update set
  text          = excluded.text,
  text_en       = excluded.text_en,
  sca_dimension = excluded.sca_dimension,
  human_need    = excluded.human_need,
  wave          = excluded.wave,
  pillar        = excluded.pillar,
  subgroup      = excluded.subgroup,
  mood          = excluded.mood,
  valence       = excluded.valence,
  retired_at    = null;

-- Every live v2 situation has an exact story id. Existing historical stories
-- remain available for old memory records but are never offered by the picker.
insert into public.wr_stories
  (story_id, title, sca_dimension, human_need, situation,
   pillar, subgroup, mood, valence,
   emotion_tags, behavior_tags, career_stages, difficulty_level,
   story_content, reflection_question, self_reflection, aha_message, practice_action,
   title_en, story_content_en, reflection_question_en, self_reflection_en,
   aha_message_en, practice_action_en)
values
${real
  .map(
    (row) =>
      `  (${sql(row.story_id)}, ${sql(row.title)}, ${sql(row.sca_dimension)}, ${sql(
        row.human_need,
      )}, ${sql(row.situation)}, ${sql(row.pillar)}, ${sql(row.subgroup)}, ${sql(
        row.mood,
      )}, ${sql(row.valence)}, ${sql(row.emotion_tags)}, ${sql(
        row.behavior_tags,
      )}, ${sql(row.career_stages)}, ${sql(row.difficulty_level)}, ${sql(
        row.story_content,
      )}, ${sql(row.reflection_question)}, ${sql(row.self_reflection)}, ${sql(
        row.aha_message,
      )}, ${sql(row.practice_action)}, ${sql(row.title_en)}, ${sql(
        row.story_content_en,
      )}, ${sql(row.reflection_question_en)}, ${sql(
        row.self_reflection_en,
      )}, ${sql(row.aha_message_en)}, ${sql(row.practice_action_en)})`,
  )
  .join(',\n')}
on conflict (story_id) do update set
  title              = excluded.title,
  sca_dimension      = excluded.sca_dimension,
  human_need         = excluded.human_need,
  situation          = excluded.situation,
  pillar             = excluded.pillar,
  subgroup           = excluded.subgroup,
  mood               = excluded.mood,
  valence            = excluded.valence,
  emotion_tags       = excluded.emotion_tags,
  behavior_tags      = excluded.behavior_tags,
  career_stages      = excluded.career_stages,
  difficulty_level   = excluded.difficulty_level,
  story_content      = excluded.story_content,
  reflection_question = excluded.reflection_question,
  self_reflection    = excluded.self_reflection,
  aha_message        = excluded.aha_message,
  practice_action    = excluded.practice_action,
  title_en           = excluded.title_en,
  story_content_en   = excluded.story_content_en,
  reflection_question_en = excluded.reflection_question_en,
  self_reflection_en = excluded.self_reflection_en,
  aha_message_en     = excluded.aha_message_en,
  practice_action_en = excluded.practice_action_en;
`;
}

function validate(rows) {
  const real = rows.filter((row) => !row.custom);
  if (rows.length !== 73 || real.length !== 72) {
    throw new Error(`Expected 72 real rows plus custom, got ${real.length} + ${rows.length - real.length}`);
  }
  const ids = real.map((row) => row.id);
  if (new Set(ids).size !== ids.length) throw new Error('Duplicate situation id');
  if (real.filter((row) => row.valence === 'thach-thuc').length !== 48) {
    throw new Error('Expected 48 challenge situations');
  }
  if (real.filter((row) => row.valence === 'tich-cuc').length !== 24) {
    throw new Error('Expected 24 positive situations');
  }
  for (const row of real) {
    if (!PILLARS.has(row.pillar)) throw new Error(`Invalid pillar for ${row.id}`);
    if (!SUBGROUP_PILLARS.has(row.subgroup)) throw new Error(`Invalid subgroup for ${row.id}`);
    if (SUBGROUP_PILLARS.get(row.subgroup) !== row.pillar) {
      throw new Error(`Subgroup/pillar mismatch for ${row.id}`);
    }
    if (!MOODS.has(row.mood)) throw new Error(`Invalid mood for ${row.id}`);
    if (!VALENCES.has(row.valence)) throw new Error(`Invalid valence for ${row.id}`);
    if (!row.title || !row.story || !row.reflection || !row.selfReflection || !row.aha || !row.practice) {
      throw new Error(`Missing editorial field for ${row.id}`);
    }
    if (row.valence === 'thach-thuc' && !CHALLENGE_SUBGROUPS.has(row.subgroup)) {
      throw new Error(`Invalid challenge subgroup for ${row.id}`);
    }
  }
  for (const mood of MOODS) {
    if (real.filter((row) => row.mood === mood).length !== 12) {
      throw new Error(`Expected 12 rows for mood ${mood}`);
    }
  }
  for (const subgroup of CHALLENGE_SUBGROUPS) {
    if (real.filter((row) => row.subgroup === subgroup && row.valence === 'thach-thuc').length !== 8) {
      throw new Error(`Expected 8 challenge rows for subgroup ${subgroup}`);
    }
  }
  if (rows.filter((row) => row.custom).length !== 1 || rows.find((row) => row.custom).id !== 'other') {
    throw new Error('Expected exactly one custom other row');
  }
}

function main() {
  const sourcePath = resolveSourcePath();
  const editorial = loadEditorialRows(sourcePath);
  const translations = loadTranslations();
  const english = new Map(
    editorial.map((row) => [row.id, editorialEnglish(row, translations)]),
  );
  const situations = editorial.map((row) =>
    toSituation(row, english.get(row.id)),
  );
  validate(situations);
  const stories = editorial
    .map((row) => toStory(row, english.get(row.id)))
    .filter(Boolean);

  fs.writeFileSync(SITUATIONS_OUT, `${JSON.stringify(situations, null, 2)}\n`);
  fs.writeFileSync(STORIES_OUT, `${JSON.stringify(stories, null, 2)}\n`);

  // The SQL converter consumes the same normalized rows, so the generated
  // migration and JSON assets cannot drift in field mapping.
  const sqlRows = stories.map((story) => ({
    ...story,
    code: story.story_id,
    text: story.title,
    text_en: story.title_en,
    sca_dimension: story.sca_dimension,
    human_need: story.human_need,
    wave: compatibilityWave(editorial.find((row) => row.id === story.story_id)),
    pillar: story.pillar,
    subgroup: story.subgroup,
    mood: story.mood,
    valence: story.valence,
  }));
  fs.writeFileSync(MIGRATION_OUT, situationSql(sqlRows));

  process.stderr.write(
    `[OK] converted ${situations.length} situation rows and ${stories.length} stories\n` +
      `[OK] ${path.relative(ROOT, SITUATIONS_OUT)}\n` +
      `[OK] ${path.relative(ROOT, STORIES_OUT)}\n` +
      `[OK] ${path.relative(ROOT, MIGRATION_OUT)}\n`,
  );
}

if (require.main === module) {
  main();
}

module.exports = {
  argument,
  loadEditorialRows,
  resolveSourcePath,
  validate,
};
