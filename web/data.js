/* Walk UP! ブラウザ版 — マスターデータと定数
 *
 * Swift 側の `BalanceRules.swift` / `MasterData.swift` / `Rewards.swift`（LoreCatalog）を
 * そのまま移したもの。**数値はここ以外に書かないこと。**
 * ブラウザ版は「画面の見た目」を決めるための試作台なので、数字が本編とずれると
 * 「この見た目でこの手応え」という判断そのものが当てにならなくなる。
 */

const ART = '../WalkUP/Assets.xcassets/';

/** ダルモンと主人公の立ち絵。アセットカタログの imageset をそのまま参照する（複製しない）。 */
const artOf = (id) => `${ART}Darumon/${id}.imageset/${id}.png`;

/** 持ち物の絵（装備・素材・携行品）。
 *
 * **概念は記号、世界に在る物は絵。** 活力・戻る・鍵は概念なので SVG の記号で描き、
 * 靴・外套・護符・澱・核は「拾って持ち歩く物」なので絵にする。
 * 記号で足りる所を絵にすると重くなるだけだが、物を記号にすると世界の手触りが消える。 */
const itemOf = (id) => `${ART}Items/${id}.imageset/${id}.png`;
/** 地域の背景。戦闘・ホーム・地域一覧で共用する。 */
const bgOf = (chapter) => `${ART}Regions/bg${chapter}.imageset/bg${chapter}.png`;

/** 活気が満ちた後の背景（ART_PROMPTS.md §3.7.1）。
 *
 * 元の背景を参照画像にした画像編集で作ってあり、**構図は元と一致している。**
 * 活気 0〜100 に応じて元の上に重ね、透明度で溶かす。
 * `false` に戻すと、既存背景に暖色補正をかけた擬似版に切り替わる（絵を差し替える時の退避）。 */
const bgAliveOf = (chapter) => `${ART}Regions/bg${chapter}_alive.imageset/bg${chapter}_alive.png`;
const HAS_ALIVE_ART = true;

/** 章の扉絵。章に入る瞬間に一度だけ全画面で出す（主人公の後ろ姿入り）。 */
const doorOf = (chapter) => `${ART}Regions/door${chapter}.imageset/door${chapter}.png`;

/** タイトルの一枚絵（縦 9:16）。**文字は入っていない。**
 *  生成に文字を描かせると綴りも字形も崩れるので、題字は組版で載せる。 */
const TITLE_ART = `${ART}Regions/title.imageset/title.png`;

const Balance = {
  // 歩数の変換（§3.1）
  dailyStepCap: 30000,
  stepsPerAP: 1000,

  // レベル（§3.2 / §3.3）
  expPerLevelSquared: 500,
  baseHP: 50, baseATK: 10, baseDEF: 5,
  hpPerLevel: 10, atkPerLevel: 3, defPerLevel: 2,

  // 戦闘（§4.2）。乱数幅 ±20% は §17.12 の実測で決まった値。
  damageVariance: [0.8, 1.2],
  maxTurns: 30,

  // AP 消費（§17.1）
  apCostNormal: 1,
  apCostBoss: 3,

  // 強化（§17.7）
  enhanceGainPerLevel: 0.20,
  maxEnhanceLevel: 5,
  enhanceCost: (level) => 5 * (level + 1) * (level + 1),

  // ドロップ（§17.8）
  dregsFromNormal: 3,
  dregsFromBoss: 10,
  coreFromBoss: 1,
  passMultiplier: 1.5,
  defeatSalvageRatio: 1 / 3,

  // 活気（§17.9）
  vitalityFromNormal: 2,
  vitalityFromBoss: 10,
  vitalityMax: 100,

  // 道標（§18.3）
  stepsPerMilestone: 500,
  milestoneDailyCap: 12,
  coreShardsPerCore: 10,

  applyPass: (amount, hasPass) => (hasPass ? Math.ceil(amount * Balance.passMultiplier) : amount),
  salvaged: (amount) => Math.ceil(amount * Balance.defeatSalvageRatio),
};

/* ------------------------------------------------------------------ */
/* 敵                                                                  */
/* ------------------------------------------------------------------ */

/** 章ごとの4体（ART_PROMPTS.md §3.5）。id はアセット名と一致させる。 */
const SPECIES = {
  1: [
    { id: 'darari', name: 'ダラリ', role: 'standard' },
    { id: 'nemuke', name: 'ネムケ', role: 'swift' },
    { id: 'gorone', name: 'ゴロネ', role: 'tough' },
    { id: 'akubi', name: 'アクビ', role: 'standard' },
  ],
  2: [
    { id: 'uzukumari', name: 'ウズクマリ', role: 'standard' },
    { id: 'tadayoi', name: 'タダヨイ', role: 'swift' },
    { id: 'nebari', name: 'ネバリ', role: 'tough' },
    { id: 'motare', name: 'モタレ', role: 'standard' },
  ],
  3: [
    { id: 'shizumi', name: 'シズミ', role: 'standard' },
    { id: 'kasumi', name: 'カスミ', role: 'swift' },
    { id: 'omori', name: 'オモリ', role: 'tough' },
    { id: 'nukegara', name: 'ヌケガラ', role: 'standard' },
  ],
};

/** 雑魚のステータス（§17.2）。役割ごとに1組で、個体は名前と絵だけが変わる。 */
const ZAKO_STATS = {
  '1-standard': { hp: 80, atk: 12, def: 4 },
  '1-tough': { hp: 68, atk: 13, def: 10 },
  '1-swift': { hp: 67, atk: 15, def: 2 },
  '2-standard': { hp: 124, atk: 19, def: 6 },
  '2-tough': { hp: 104, atk: 20, def: 16 },
  '2-swift': { hp: 104, atk: 23, def: 3 },
  '3-standard': { hp: 168, atk: 25, def: 8 },
  '3-tough': { hp: 144, atk: 26, def: 20 },
  '3-swift': { hp: 141, atk: 29, def: 4 },
};

/** ボス（§17.3）。HP は 1000回シミュレーションで決めた値。 */
const BOSS = {
  1: { id: 'boss_ch1', name: 'マドロミ', hp: 370, atk: 25, def: 10, asset: 'madoromi' },
  2: { id: 'boss_ch2', name: 'ムキリョク', hp: 570, atk: 38, def: 16, asset: 'mukiryoku' },
  3: { id: 'boss_ch3', name: 'ダルモン', hp: 890, atk: 52, def: 22, asset: 'darumon' },
};

const Master = {
  nodesPerChapter: 8,

  species: (chapter) => SPECIES[chapter],

  /** 章解放に必要な累計歩数（§5.1）。 */
  chapterGate: (chapter) => ({ 1: 20000, 2: 60000, 3: 120000 }[chapter] ?? Infinity),

  zako(chapter, role, species) {
    const stats = ZAKO_STATS[`${chapter}-${role}`];
    const entry = species ?? SPECIES[chapter].find((s) => s.role === role);
    return {
      id: entry.id, name: entry.name, ...stats,
      isBoss: false, asset: entry.id, chapter,
      apCost: Balance.apCostNormal,
    };
  },

  boss(chapter) {
    const b = BOSS[chapter];
    return { ...b, isBoss: true, chapter, apCost: Balance.apCostBoss };
  },

  /** ノードの中身（§17.4）。2/4/6 で装備を確定ドロップさせる。 */
  node(chapter, index) {
    const roster = SPECIES[chapter];
    const enemyAt = (position) => Master.zako(chapter, roster[position].role, roster[position]);
    switch (index) {
      case 1: return { enemy: enemyAt(0), equipment: null };
      case 2: return { enemy: enemyAt(2), equipment: Master.equipment(chapter, 'weapon') };
      case 3: return { enemy: enemyAt(1), equipment: null };
      case 4: return { enemy: enemyAt(2), equipment: Master.equipment(chapter, 'armor') };
      case 5: return { enemy: enemyAt(3), equipment: null };
      case 6: return { enemy: enemyAt(2), equipment: Master.equipment(chapter, 'accessory') };
      case 7: return { enemy: enemyAt(1), equipment: null };
      case 8: return { enemy: Master.boss(chapter), equipment: null };
    }
  },

  /** 装備カタログ（§17.6）。武器が「靴」なのは §1.1（歩く力だけが武器になる）。 */
  equipment(chapter, slot) {
    const table = {
      '1-weapon': [0, 7, 0], '1-armor': [50, 0, 3], '1-accessory': [0, 3, 2],
      '2-weapon': [0, 13, 0], '2-armor': [90, 0, 6], '2-accessory': [0, 5, 3],
      '3-weapon': [0, 20, 0], '3-armor': [140, 0, 9], '3-accessory': [0, 8, 5],
    };
    const [hp, atk, def] = table[`${chapter}-${slot}`];
    const tier = ['', '目覚めの', '抗いの', '灯火の'][chapter];
    const noun = { weapon: '靴', armor: '外套', accessory: '護符' }[slot];
    return {
      id: `eq_ch${chapter}_${slot}`, name: `${tier}${noun}`,
      slot, hp, atk, def, enhanceLevel: 0, isEquipped: false,
    };
  },

  /** チュートリアルで最初に渡す靴（§11-1）。
   *
   * **歩数ゼロの Lv1 は、素のままではノード1に 61.9% でしか勝てない。**
   * 審査員は歩かない（§11）。最初の戦闘で4割が負ける状態は、
   * この作品の第一印象をそこで決めてしまう。
   *
   * ATK+5 だと3戦とも勝率100%（残HP 22 → 15 → 25）で、楽勝には見えないまま必ず勝てる。
   * ATK+3 では2戦目のゴロネ（DEF10）が 87.6% まで落ち、必勝の細工が表に出る。
   * ノード2の「目覚めの靴」ATK+7 より弱いので、進行の順序も壊れない。 */
  starterShoe: () => ({
    id: 'eq_starter', name: '履き古した靴', slot: 'weapon',
    hp: 0, atk: 5, def: 0, enhanceLevel: 0, isEquipped: true,
  }),

  /** 章の扉に添える一行。**説明しない。** 世界の側の言葉で、これから入る場所を言う。 */
  doorLine: (chapter) => ({
    1: '誰も歩かなくなった通りに、足音が一つ戻ってくる。',
    2: '下りたシャッターの向こうに、まだ誰かがいる気がする。',
    3: 'ここでは、歩くという発想そのものが失われている。',
  }[chapter]),

  region: (chapter) => ({
    1: { id: 'region_ch1', name: '止まった住宅街' },
    2: { id: 'region_ch2', name: '灯りの落ちた商店街' },
    3: { id: 'region_ch3', name: '灰の窪地' },
  }[chapter]),

  /** 図鑑の解説文。「世界の記述」と同じ声で書く（§18.4）。 */
  flavor: (id) => ({
    darari: '立っているのが面倒になった者の成れの果て。溶けかけた体のまま、通る人の足元をぼんやり眺めている。',
    nemuke: 'まぶたの重さだけで出来ている。目が合うと、こちらのあくびが止まらなくなる。',
    gorone: '一度横になったきり、二度と立たないと決めた。押しても引いても動かないが、追ってくることもない。',
    akubi: '誰かがあくびをするたび、少しずつ増える。悪意はない。ただ、伝染する。',
    uzukumari: '膝を抱えたまま固まっている。声をかけても顔を上げない。上げ方を忘れている。',
    tadayoi: '行き先を決めるのをやめた者。風の向くまま、閉じた商店街の天井の下を漂っている。',
    nebari: '踏み出そうとした足にまとわりつく。振りほどけないのではない。振りほどく気力が湧かない。',
    motare: '何かに寄りかかっていないと形を保てない。シャッターに、倒れた自転車に、人の背中に。',
    shizumi: '底へ底へと沈んでいく。沈むほど楽になると、知ってしまった。',
    kasumi: '輪郭を手放した者。何になりたかったのか、本人ももう思い出せない。',
    omori: '持ち上げようとした荷物が、そのまま重さになった。抱えているのではなく、抱えられている。',
    nukegara: '中身が先に出ていった後の形。それでも街に立っているのは、倒れ方を知らないから。',
    boss_ch1: '横になる場所を差し出してくる。その折り目に一度身を預けた者は、二度と起き上がらない。',
    boss_ch2: '頭を垂れすぎて、肩より下に沈んでしまった。胴のくぼみは、誰かから抜き取った意欲の跡。',
    boss_ch3: 'すべての怠惰が融け合った本体。中央の目は、あなたを見ている。追ってはこない。ただ、待っている。',
  }[id] ?? ''),

  /** 図鑑に載る全個体。雑魚4体＋ボス1体を章の順に。 */
  roster() {
    const list = [];
    for (const chapter of [1, 2, 3]) {
      for (const s of SPECIES[chapter]) list.push(Master.zako(chapter, s.role, s));
      list.push(Master.boss(chapter));
    }
    return list;
  },
};

/* ------------------------------------------------------------------ */
/* チュートリアル（§11-1）                                              */
/* ------------------------------------------------------------------ */

/** 歩数ゼロでも遊べる、という審査対策の実体（§11-1）。
 *
 * **仕様には「チュートリアル戦闘を1回無償提供」としか書かれていなかった**が、
 * 1戦では素材が3つしか出ず、強化（5澱）に届かない。
 * 3戦にすると ノード2で靴が落ち、澱がちょうど6つ＝強化1段ぶんに届く。
 * 討伐 → 素材 → 強化 が、作り物の数字を挟まずに順に並ぶ。
 *
 * **戦うのは第1章のノード1・2・3そのもの。** 専用の敵を作らない。
 * 章ゲート（20,000歩）と活力の消費だけを外す。倒したぶんは本当に進行として残るので、
 * 歩き始めた人はノード4から続けられる。
 *
 * 勝敗は `guaranteed` で保証する（`engine.js`）。数値の上でも3戦とも100%だが、
 * 乱数に委ねると「必ず勝つ」を仕様として言えない。 */
const TUTORIAL = [
  {
    kind: 'scene', foe: 'darari',
    lines: [
      '道の真ん中で、何かがうずくまっている。',
      '避けて通ろうとしたが、それは道いっぱいに広がっていた。',
      '襲ってはこない。ただ、そこから動かない。',
      '足元を見る。履き古した靴。踏み出せるのは、これだけだ。',
    ],
  },
  { kind: 'battle', node: 1 },
  {
    kind: 'scene',
    lines: [
      'それは溶けて、地面に灰紫の澱を残した。',
      '怠惰の澱。この街から抜き取られた気力の、残りかす。',
      '持ち帰れば、靴に染み込ませることができる。',
    ],
  },
  // **レベルは歩数から導く値**なので、別枠で上げずに歩数を渡す（`GameState` は level を保存しない）。
  // 2,000歩 でちょうど Lv2。ついでに活力2と道標4も入り、
  // チュートリアルを抜けた直後に「やることがある」状態で渡せる。
  {
    kind: 'walk', steps: 2000,
    lines: [
      '澱を拾って、また歩き出す。',
      '歩いた分だけ、体が軽くなっていく。この世界では、それがそのまま力になる。',
    ],
  },
  { kind: 'battle', node: 2 },
  {
    kind: 'scene', action: 'equip',
    lines: [
      '澱が六つ。新しい靴も手に入った。',
      '澱を五つ注ぐと、靴は一段丈夫になる。段は五つまで積める。',
      '装備を開いて、履き替えてから先へ進む。',
    ],
  },
  { kind: 'battle', node: 3 },
  {
    kind: 'scene',
    lines: [
      '三体を退けた。道の先は、まだ暗い。',
      'ここから先へ進めるのは、あなたが実際に歩いた分だけ。',
    ],
  },
];

/** 「世界の記述」（§18.4）。テキストだけで世界が戻っていく感触を作る。 */
const LORE = [
  ['lore_001', 1, 'はじめに止まったのは、街の時計だった。誰も直そうとしなかった。'],
  ['lore_002', 1, '郵便受けに手紙が溜まっている。中身は、どれも読まれるのを諦めている。'],
  ['lore_003', 1, 'パン屋の主人は、生地をこねる手を止めて眠っている。もう三日になる。'],
  ['lore_004', 1, '子どもたちの走る音が消えた通りに、風だけが残った。'],
  ['lore_005', 1, 'ダルモンは襲わない。ただ、そばにいるだけで人から気力を抜いていく。'],
  ['lore_006', 1, '歩くと、足の裏に地面の硬さが返ってくる。それだけで少し目が覚める。'],
  ['lore_007', 1, '誰かの足跡が残っていた。あなたのものではない。まだ歩いている人がいる。'],
  ['lore_008', 1, '駅の改札は開いたままだ。通り抜ける人がいないので、閉じる意味がない。'],
  ['lore_009', 1, '自販機の灯りだけが律儀に点いている。誰も買わないまま、温かい缶が冷めていく。'],
  ['lore_010', 1, '図書館の本は、開かれた頁のまま埃をかぶっている。続きを読む者がいない。'],
  ['lore_011', 1, '橋の上で立ち止まると、川はまだ流れていた。動くものが、少し羨ましい。'],
  ['lore_012', 1, '「明日でいい」という言葉が、この街でいちばんよく使われている。'],
  ['lore_013', 2, '隣町へ続く道は、草に覆われかけていた。往来が絶えると、道は自然に還る。'],
  ['lore_014', 2, '商店街の半分はシャッターが下りている。残り半分も、開ける理由を探している。'],
  ['lore_015', 2, '壊れた自転車が置き去りにされている。直せば動く。直す気力が無いだけだ。'],
  ['lore_016', 2, '誰かが壁に線を引いていた。歩いた日を数えた跡らしい。途中で途切れている。'],
  ['lore_017', 2, 'ダルモンの通った跡には、いつも眠気に似た匂いが残る。'],
  ['lore_018', 2, '老人が縁側で言った。「昔はな、みんな歩いて隣町まで行ったんだ」'],
  ['lore_019', 3, '世界の中心に近づくほど、空気が重くなる。息をするのも億劫になる。'],
  ['lore_020', 3, 'ここでは誰も歩かない。歩くという発想そのものが失われている。'],
  ['lore_021', 3, '怠惰は罰ではない。ただ、そこに留まり続けることが、静かに全部を奪っていく。'],
  ['lore_022', 3, 'あなたの足音が響く。この場所で音を立てているのは、あなただけだ。'],
].map(([id, chapter, text]) => ({ id, chapter, text }));
