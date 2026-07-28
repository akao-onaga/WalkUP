/* ------------------------------------------------------------------
   web/data.js から台本の種を作り、index.html へ埋め込み直す。

   **手で書き写さない。** 31場面を目で写すと必ずどこかで1字ずれるし、
   ずれても誰も気付かない（下書き場の文が実装と違っていても画面は壊れない）。
   data.js を実際に評価して組み立てれば、写し間違いは起こり得ない。

   使い方: node tools/scenewright/build-seed.mjs
   data.js の文章を直したら、これを回して index.html を更新する。
------------------------------------------------------------------ */

import fs from 'node:fs';

const ROOT = new URL('../../', import.meta.url).pathname;
const data = fs.readFileSync(ROOT + 'web/data.js', 'utf8');
const D = new Function(data + '; return { PROLOGUE, TUTORIAL, STORY_SCENES, VITALITY_SCENES, SHOTS, Master, HERO };')();

/* ---- 行 ---------------------------------------------------------- */

const conv = (l) => {
  if (typeof l === 'string') return { type: 'n', text: l };
  if (l.kind === 'hold') return { type: 'hold', ms: l.ms };
  if (l.kind === 'sys') return { type: 'sys', text: l.text };
  if (l.kind === 's') {
    if (l.who === D.HERO) return { type: 'hero', text: l.text };
    if (l.who === 'ダルモン') return { type: 'darumon', text: l.text };
    return { type: 'npc', who: l.who, text: l.text };
  }
  return { type: 'n', text: l.text };
};

/* ---- 演出メモ ----------------------------------------------------
   **いま実際に起きていること**を書く。「※」で始まる行は未着手の気付き。
   場面は `台本キー / 場面番号 / 行番号`、場面全体は行番号を省く。
------------------------------------------------------------------ */

const MEMO = {
  'prologue/0': '街から活気が抜けていく（fall）。灯りが消え、粒が灰になり、色が抜ける。ダルモンは行ごとに増える',
  'prologue/0/0': 'まだ灯りは全部点いている。ここが世界のいちばん明るい所',
  'prologue/0/1': '「もたれ」＝モタレ、「うずくまった」＝ウズクマリ。文が名指しした物を画面にも出す',
  'prologue/0/4': '生気が 0 になる。ここが本編の出発点',
  'prologue/1': '前の場面で引いた世界から、ただ一人へ絞り込む',
  'prologue/1/0': '主人公が歩いて入る。「足は動いた」を絵の側でも動かす（走る絵→立ち姿へ持ち替え）',
  'prologue/1/2': '答えの出ない問いなので、答えないまま置く',

  'tutorial/0/0': 'ダラリは崩れた姿のまま置く。待機の揺れは与えない——揺れていたら、もう動いている',
  'tutorial/0/3': '返事が無いことを、返事が無い長さで見せる。ここは間そのものが本文',
  'tutorial/0/5': 'ここで初めて身じろぎする。気付いただけなので、起き上がらせない',
  'tutorial/2/0': '※いまは主人公と文字だけ。直前の戦闘で見せた溶けた跡を、同じ場所に置く余地がある',
  'tutorial/3/0': '900ms 後に歩数と紋章が回り始める ／ ※行に同期していないので、読む速さによってはこの行の途中でレベルアップが鳴る',
  'tutorial/3/2': '※「／」で二つ教えている',
  'tutorial/5/0': '工房の主はにじみ出て入る（戸の内側にいる人なので歩いて来ない） ／ ※シャッターは第2章の意匠で、第2章の扉と同じビートになっている',
  'tutorial/5/1': '喋っている者だけに光が足される',
  'tutorial/5/3': '説明は人に言わせる。地の文で書くと取扱説明書になる',
  'tutorial/5/4': '読み終えると施設の札「工房が開いた」が出て、ボタンで装備画面へ ／ ※強化せずに閉じても何も言われない',
  'tutorial/7/2': '導入画面の「実際に歩いた数だけ」を回収する行',

  'doors/0': '※チュートリアルの3戦を終えた後に出る。「初めて着いた」文なのに、着く前ではなく後',
  'doors/0/2': '名が明かされる唯一の瞬間。呼ばれる前に間を置く',
  'doors/0/3': '老女が二階の窓から。**画面の名札で先に出さず、誰かに呼ばせる**',

  'boss/0': 'マドロミは畳まれた布団のまま置く（slump-unfold）。読み終えてから起き上がって名乗る',
  'boss/1': '倒したその場ではなく、結果画面を閉じる所で出る',
  'boss/2': 'ムキリョクは頭を垂れて沈んだまま（slump-lift）。カメラは傾いて入り、起き切らない',
  'boss/4': 'ダルモンは縮こまって待つ（slump-loom）。カメラは寄ったまま揺れ続ける（地鳴り）',
  'boss/5': '横へ流れながら引く。歩いてきた場所を見渡す',

  'vitality/1': '施設の札「ウォークの軌跡が開いた」が出る',
  'vitality/5': '施設の札「市が開いた」が出る',
  'vitality/9': '施設の札「掲示板が開いた」が出る',
};

const memo = (k) => MEMO[k] || '';

/* ---- 場面 -------------------------------------------------------- */

const base = {
  kind: 'scene', note: '', key: '', chapter: '', shot: '', foe: '', slump: '', stir: -1,
  action: '', facility: false, steps: 2000, node: 1, hero: true, extra: '', lines: [],
};

const stage = (o) => ({ ...base, ...o });

const lines = (arr, prefix) => arr.map((l, i) => ({
  ...conv(l), who: conv(l).who || 'ウォーク', ms: conv(l).ms || 700, note: memo(`${prefix}/${i}`), text: conv(l).text || '',
}));

/* プロローグ。`fall` と複数の `foes` はここにしか出てこないので、
   専用の欄を作らず「詳しい指定」へそのまま載せる。 */
const prologue = {
  title: 'プロローグ', form: 'stages',
  stages: D.PROLOGUE.map((s, i) => stage({
    note: i === 0 ? '世界が止まっていく' : 'それでも、足は動いた',
    chapter: String(s.chapter ?? ''),
    shot: s.shot || '',
    hero: s.hero !== false,
    foe: s.foes && s.foes.length === 1 ? s.foes[0].id : (s.foe || ''),
    extra: [
      s.fall ? `fall: [${s.fall.map((n) => n.toFixed(2)).join(', ')}]` : '',
      s.foes && s.foes.length > 1
        ? `foes: [${s.foes.map((f) => `{ id: '${f.id}', at: ${f.at} }`).join(', ')}]` : '',
      s.heroWalk ? 'heroWalk: true' : '',
    ].filter(Boolean).join(', '),
    note2: '',
    lines: lines(s.lines, `prologue/${i}`),
  })),
};
prologue.stages.forEach((s, i) => { s.note = i === 0 ? '世界が止まっていく' : 'それでも、足は動いた'; s.memoStage = memo(`prologue/${i}`); });

const TUT_NOTES = ['ダラリとの対峙', 'ダラリ。必勝（残HP 22）', '澱を拾う', '歩いて力になる',
  'ゴロネ。必勝（残HP 15）／ 装備は落とさない', '工房', 'ネムケ。必勝（残HP 25）', '締め'];

const tutorial = {
  title: 'チュートリアル', form: 'stages',
  stages: D.TUTORIAL.map((s, i) => stage({
    kind: s.kind, note: TUT_NOTES[i] || '',
    shot: s.shot || '', foe: s.foe || '', slump: s.slump || '',
    stir: s.stir ?? -1, action: s.action || '', facility: !!s.facility,
    steps: s.steps ?? 2000, node: s.node ?? 1,
    memoStage: memo(`tutorial/${i}`),
    lines: lines(s.lines || [], `tutorial/${i}`),
  })),
};

const doors = {
  title: '章の扉', form: 'keyed',
  stages: [1, 2, 3].map((c, i) => stage({
    key: String(c), note: `第${c}章の扉`, chapter: String(c),
    memoStage: memo(`doors/${i}`),
    lines: lines(D.Master.doorLines(c), `doors/${i}`),
  })),
};

const BOSS_NOTE = {
  'boss-1-before': '第1章 ボス前 — 畳まれた布団の前で対峙する',
  'boss-1-after': '第1章 ボス後 — 一人が起き上がる',
  'boss-2-before': '第2章 ボス前 — 通りの真ん中で頭を垂れている',
  'boss-2-after': '第2章 ボス後 — シャッターが一枚、また一枚と上がっていく',
  'boss-3-before': '第3章 ボス前 — 窪地の底で向かい合う',
  'boss-3-after': '第3章 ボス後 — 起こした人の数だけ灯りが点いている',
};
const BOSS_FOE = { 1: 'madoromi', 2: 'mukiryoku', 3: 'darumon' };
const BOSS_SLUMP = { 1: 'unfold', 2: 'lift', 3: 'loom' };

const boss = {
  title: 'ボスの前後', form: 'keyed',
  stages: Object.keys(D.STORY_SCENES).map((k, i) => {
    const ch = k.split('-')[1];
    const before = k.endsWith('before');
    return stage({
      key: k, note: BOSS_NOTE[k] || k, chapter: ch, shot: D.SHOTS[k] || '',
      foe: before ? BOSS_FOE[ch] : '', slump: before ? BOSS_SLUMP[ch] : '',
      memoStage: memo(`boss/${i}`),
      lines: lines(D.STORY_SCENES[k], `boss/${i}`),
    });
  }),
};

const REGION = { 1: '止まった住宅街', 2: '灯りの落ちた商店街', 3: '灰の窪地' };

const vitality = {
  title: '活気の節目', form: 'keyed',
  stages: Object.keys(D.VITALITY_SCENES).map((k, i) => {
    const [ch, step] = k.split('-');
    return stage({
      key: k, note: `${REGION[ch]} ${step}%`, chapter: ch, shot: D.SHOTS[k] || '',
      facility: step === '45',
      memoStage: memo(`vitality/${i}`),
      lines: lines(D.VITALITY_SCENES[k], `vitality/${i}`),
    });
  }),
};

/* ---- 書き出し ---------------------------------------------------- */

const book = { prologue, tutorial, doors, boss, vitality };

// 場面のメモは `memoStage` で受けたので、`note2` の残骸を落として整える。
for (const s of Object.values(book)) {
  for (const st of s.stages) { delete st.note2; if (!st.memoStage) delete st.memoStage; }
}

const json = JSON.stringify(book, null, 2)
  .split('\n').map((l) => '  ' + l).join('\n');

const html = fs.readFileSync(ROOT + 'tools/scenewright/index.html', 'utf8');
const START = '/* SEED:START */';
const END = '/* SEED:END */';
const a = html.indexOf(START);
const b = html.indexOf(END);
if (a < 0 || b < 0) { console.error('index.html に SEED:START / SEED:END の印が見つかりません'); process.exit(1); }

const block = `${START}\nconst SEED = () => JSON.parse(JSON.stringify(\n${json}\n));\n${END}`;
fs.writeFileSync(ROOT + 'tools/scenewright/index.html', html.slice(0, a) + block + html.slice(b + END.length));

let n = 0, l = 0;
for (const s of Object.values(book)) { n += s.stages.length; s.stages.forEach((st) => { l += st.lines.length; }); }
console.log(`埋め込んだ: ${Object.keys(book).length} 台本 / ${n} 場面 / ${l} 行`);
