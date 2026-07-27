/* Walk UP! ブラウザ版 — ルールと状態
 *
 * Swift 側の `StepConverter` / `BattleEngine` / `RewardCalculator` / `MilestoneOpener` /
 * `GameModel` に対応する。**判断はここに閉じ込め、`ui.js` は結果を再生するだけにする。**
 * 本編と同じ切り分けにしてあるので、演出をいくら差し替えても勝敗は動かない。
 *
 * ブラウザ版と本編で唯一違うのは歩数の入り口だけ。ヘルスケアが無いので
 * `walk()` で手で入れる（§11-1 のデモモードと同じ考え方）。
 */

/* ------------------------------------------------------------------ */
/* 戦闘（§4.1〜§4.3）                                                  */
/* ------------------------------------------------------------------ */

const BattleEngine = {
  /** §4.2 の `max(1, ATK - DEF/2) × random(0.8...1.2)`。DEF/2 は実数で割ってから丸める。 */
  damage(atk, def) {
    const base = Math.max(1, atk - def / 2);
    const [lo, hi] = Balance.damageVariance;
    const roll = lo + Math.random() * (hi - lo);
    return Math.max(1, Math.round(base * roll));
  },

  /** 先攻は主人公固定。**戦闘に入る前に勝敗まで確定させる**（§4.1）。
   *
   * `guaranteed` はチュートリアル専用（§11-1）。**倒れず、必ず勝つ。**
   * 装備を渡した上で数値の上も3戦とも100%にしてあるが、乱数に委ねている限り
   * 「必ず勝つ」を仕様として言えない。ここで断ち切る。
   * 本編の戦闘からは決して渡さないこと。 */
  resolve(player, enemy, { guaranteed = false } = {}) {
    let playerHP = player.maxHP;
    let enemyHP = enemy.maxHP;
    const turns = [];

    for (let index = 1; index <= Balance.maxTurns; index++) {
      const toEnemy = BattleEngine.damage(player.atk, enemy.def);
      enemyHP -= toEnemy;
      turns.push({ index, attacker: 'player', damage: toEnemy, remaining: Math.max(0, enemyHP) });
      if (enemyHP <= 0) return { turns, result: 'victory', playerRemainingHP: playerHP };

      const toPlayer = BattleEngine.damage(enemy.atk, player.def);
      playerHP -= toPlayer;
      // **踏みとどまる。** 削られる手応えは残したまま、倒れる一撃だけを止める。
      if (guaranteed && playerHP <= 0) playerHP = 1;
      turns.push({ index, attacker: 'enemy', damage: toPlayer, remaining: Math.max(0, playerHP) });
      if (playerHP <= 0) return { turns, result: 'defeat', playerRemainingHP: 0 };
    }

    // 30ターンで決着せず＝「活力が尽きて撤退」（§4.2）。
    if (guaranteed) {
      // 決着だけは付ける。ここに来ることは想定していないが、
      // 来た時に「必ず勝つ」が破れる方が困る。
      turns.push({ index: Balance.maxTurns, attacker: 'player', damage: Math.max(1, enemyHP), remaining: 0 });
      return { turns, result: 'victory', playerRemainingHP: playerHP };
    }
    return { turns, result: 'defeat', playerRemainingHP: Math.max(0, playerHP) };
  },

  /** 強化と刻印を反映した実効値（§17.7 / §6.2）。
   *
   * **刻印は強化の倍率に乗せない。** 刻印は歩き方が形になった物で、
   * 澱で打ち直した量とは出所が違う。掛けると出所の違いが数値の中で溶ける。 */
  effective(item) {
    const m = 1 + Balance.enhanceGainPerLevel * item.enhanceLevel;
    const base = { hp: Math.floor(item.hp * m), atk: Math.floor(item.atk * m), def: Math.floor(item.def * m) };
    for (const id of item.engravings ?? []) {
      const e = ENGRAVINGS[id];
      if (!e) continue;
      base.hp += e.hp; base.atk += e.atk; base.def += e.def;
    }
    return base;
  },

  playerFighter(level, equipment) {
    const bonus = equipment.filter((e) => e.isEquipped).reduce((total, item) => {
      const e = BattleEngine.effective(item);
      return { hp: total.hp + e.hp, atk: total.atk + e.atk, def: total.def + e.def };
    }, { hp: 0, atk: 0, def: 0 });

    return {
      name: '主人公',
      maxHP: Balance.baseHP + level * Balance.hpPerLevel + bonus.hp,
      atk: Balance.baseATK + level * Balance.atkPerLevel + bonus.atk,
      def: Balance.baseDEF + level * Balance.defPerLevel + bonus.def,
    };
  },

  enemyFighter: (enemy) => ({ name: enemy.name, maxHP: enemy.hp, atk: enemy.atk, def: enemy.def }),
};

/* ------------------------------------------------------------------ */
/* 報酬（§17.8 / §17.9）                                               */
/* ------------------------------------------------------------------ */

const Rewards = {
  forBattle(enemy, result, hasPass, equipmentReward) {
    const baseDregs = enemy.isBoss ? Balance.dregsFromBoss : Balance.dregsFromNormal;
    const baseVitality = enemy.isBoss ? Balance.vitalityFromBoss : Balance.vitalityFromNormal;

    if (result === 'victory') {
      return {
        dregs: Balance.applyPass(baseDregs, hasPass),
        cores: enemy.isBoss ? Balance.coreFromBoss : 0,
        vitality: Balance.applyPass(baseVitality, hasPass),
        equipment: equipmentReward,
      };
    }
    // §4.3「全損させない」。AP は返らず、装備も出ない。
    return {
      dregs: Balance.applyPass(Balance.salvaged(baseDregs), hasPass),
      cores: 0, vitality: 0, equipment: null,
    };
  },
};

/** 道標の開封（§18.4）。抽選表は 世界の記述65 / 目撃10 / かけら25。
 *
 * **携行品は廃止した（2026-07-27）。** 戦闘は毎回全快で始まる設計（§4.1）なので、
 * 「戦闘前に使える回復」は効果量をいくつにしても何も起きない。
 * 一時強化に読み替える手もあったが、道具の管理という層を1つ増やすだけで、
 * §2 の「1セッション3分」に対して割に合わない。 */
const Milestones = {
  weights: [['lore', 65], ['sighting', 10], ['shard', 25]],

  pick() {
    let roll = Math.random() * 100;
    for (const [kind, weight] of Milestones.weights) {
      roll -= weight;
      if (roll < 0) return kind;
    }
    return 'lore';
  },

  /** **一括で開ける**（§18.2）。1つずつ開けさせると1セッション3分が壊れる。 */
  open(count, unlockedChapter, alreadyUnlocked, alreadySighted, loreToday = 0) {
    const finds = [];
    const used = new Set(alreadyUnlocked);
    const sighted = new Set(alreadySighted);
    let lore = loreToday;

    // 引き当て済みなら次の未解放へ回す。読み物として途中が抜けないようにする（§18.6）。
    // **1日の上限に当たったら、その日はもう出さない**（§18.4）。
    const takeLore = () => {
      if (lore >= Balance.loreDailyCap) return null;
      const entry = LORE.find((l) => l.chapter <= Math.max(1, unlockedChapter) && !used.has(l.id));
      if (!entry) return null;
      used.add(entry.id);
      lore += 1;
      return { kind: 'lore', id: entry.id, title: '世界の記述', text: entry.text };
    };

    // **未発見の個体からしか引かない。** 既に見た相手を引いても図鑑は動かず、
    // 開封の演出だけが1枚増える。開放済みの章すべてが対象（その章の4体とも出る）。
    const takeSighting = () => {
      const pool = [];
      for (let chapter = 1; chapter <= Math.max(1, unlockedChapter); chapter++) {
        for (const s of Master.species(chapter)) {
          if (!sighted.has(s.id)) pool.push(Master.zako(chapter, s.role, s));
        }
      }
      if (!pool.length) return null;
      const enemy = pool[Math.floor(Math.random() * pool.length)];
      sighted.add(enemy.id);
      return { kind: 'sighting', id: enemy.id, title: `${enemy.name} の目撃情報` };
    };

    const shard = () => ({ kind: 'shard', title: '怠惰の核のかけら' });

    // 引き切った時の逃がし先は**もう一方の読み物側**にする。
    // かけらへ直行させると、記述22本を読み終えた数日後から核が跳ね上がり、
    // §18.4 の「核1つに約8.3日」という補助経路の前提が崩れる。
    for (let i = 0; i < count; i++) {
      switch (Milestones.pick()) {
        case 'lore': finds.push(takeLore() ?? takeSighting() ?? shard()); break;
        case 'sighting': finds.push(takeSighting() ?? takeLore() ?? shard()); break;
        default: finds.push(shard());
      }
    }
    return finds;
  },
};

/* ------------------------------------------------------------------ */
/* 状態                                                                */
/* ------------------------------------------------------------------ */

const SAVE_KEY = 'walkup.web.v1';

const emptyState = () => ({
  // 当日の歩き方（morning=早朝の歩数 / floors=上った階数 / distance=最長距離km）。
  // 本編ではヘルスケアから引く。ブラウザ版は開発用トレイから入れる。
  player: {
    cumulativeSteps: 0, ap: 0, todayCreditedSteps: 0, milestoneCreditedToday: 0, day: 1,
    morning: 0, floors: 0, distance: 0,
    loreCreditedToday: 0, bountyDoneToday: [],
  },
  equipment: [],
  chapters: [1, 2, 3].map((chapterId) => ({ chapterId, nodeIndex: 0, isCleared: false })),
  regions: [],
  bestiary: [],
  materials: { dregs: 0, core: 0, core_shard: 0 },
  unlockedLore: [],
  pendingMilestones: 0,
  hasPass: false,
  /** 扉絵を見せ終えた章。**一度見せたら二度出さない。**
   *  毎回出すと、開く度に足止めされる画面になる。 */
  seenDoors: [],

  /** 日別の歩数（新しい順）。設定画面の「直近7日」に出す。
   *  本編ではヘルスケアから引くので保存しないが、ブラウザ版は自前で持つしかない。
   *  歩き方（早朝の歩数・階数・距離）も併せて持つ。「ウォークの軌跡」が読む（§6.2）。 */
  history: [],

  /** 見せ終えた活気の節目（`"1-45"` の形）。**一度見せたら二度出さない。** */
  seenVitalityScenes: [],

  /** 見せ終えた章の山場の場面（`"boss-1-after"` の形）。 */
  seenStory: [],

  /** 通知の許可を聞き終えたか（§15-4）。**第1章クリア後に一度だけ。** */
  seenNotifyAsk: false,
  notifyGranted: false,

  /** 歩数の取得を許したか。初回の導入画面で聞く（§11 の権限説明）。 */
  stepAccessGranted: false,

  /** 導入画面を見せ終えたか。**初回だけ。** */
  seenIntro: false,

  /** チュートリアル（§11-1）を終えたか、と何段目まで進んだか。
   *
   * **途中で閉じても続きから再開できるように段を保存する。** 3戦を通す間に
   * アプリを閉じられる可能性は普通にあり、そこで最初からやり直させると
   * 「歩かずに理解できる」どころか二度と開かれない。 */
  seenTutorial: false,
  tutorialStep: 0,

  /** チュートリアルの「歩く」一拍で歩数を入れ終えたか。
   *
   * **段だけでは足りない。** 段が進むのは進むボタンを押した時なので、
   * 歩数を入れた直後・押す前に閉じられると、開き直すたびに歩数が入る。
   * §3.4 の二重計上防止と同じ話で、入れた事実そのものを残す必要がある。 */
  tutorialWalked: false,

  /** 完結を見せ終えたか。第3章のボスを倒した後に一度だけ出す（§5.3）。 */
  seenEnding: false,
  /** 直前の変換結果。ホームで「今回の増分」を出すために持つ。 */
  lastOutcome: null,
});

const Game = {
  state: emptyState(),

  load() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (raw) Game.state = { ...emptyState(), ...JSON.parse(raw) };
    } catch (_) { /* 壊れた保存データは捨てて初期状態で始める */ }
    // 廃止した携行品。**保存済みの側はコードを直しても消えない**ので、読み込みで落とす。
    delete Game.state.consumables;
    return Game.state;
  },
  save() {
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(Game.state)); } catch (_) {}
  },
  reset() { Game.state = emptyState(); Game.save(); },

  // ---- 導出 ----

  get player() { return Game.state.player; },
  get level() { return Math.max(1, Math.floor(Math.sqrt(Game.state.player.cumulativeSteps / Balance.expPerLevelSquared))); },
  get dregs() { return Game.state.materials.dregs ?? 0; },
  get cores() { return Game.state.materials.core ?? 0; },
  get shards() { return Game.state.materials.core_shard ?? 0; },

  /** 次のレベルまでの進捗 0...1。 */
  get levelProgress() {
    const lv = Game.level;
    const current = Balance.expPerLevelSquared * lv * lv;
    const next = Balance.expPerLevelSquared * (lv + 1) * (lv + 1);
    return Math.min(1, Math.max(0, (Game.state.player.cumulativeSteps - current) / (next - current)));
  },

  get unlockedChapter() {
    let unlocked = 1;
    for (const chapter of [1, 2, 3]) {
      if (Game.state.player.cumulativeSteps >= Master.chapterGate(chapter)) unlocked = chapter;
    }
    return unlocked;
  },

  get fighter() { return BattleEngine.playerFighter(Game.level, Game.state.equipment); },

  /** 第1章のゲートに届いていれば以後は常に討伐に出られる（周回が余剰 AP を受け止める）。 */
  get canBattle() { return Game.state.player.cumulativeSteps >= Master.chapterGate(1); },

  progress: (chapter) => Game.state.chapters.find((c) => c.chapterId === chapter),

  /** 次に挑む未クリアのノード。全て討伐済みなら null。 */
  get nextNode() {
    for (const chapter of [1, 2, 3]) {
      if (Game.state.player.cumulativeSteps < Master.chapterGate(chapter)) continue;
      const done = Game.progress(chapter).nodeIndex;
      if (done < Master.nodesPerChapter) return { chapter, index: done + 1 };
    }
    return null;
  },

  /** まだ扉絵を見せていない、到達済みの章。無ければ null。
   *  複数溜まっていたら小さい章から順に出す（順番に読ませる）。 */
  get pendingDoor() {
    for (const chapter of [1, 2, 3]) {
      if (Game.state.player.cumulativeSteps < Master.chapterGate(chapter)) continue;
      if (!Game.state.seenDoors.includes(chapter)) return chapter;
    }
    return null;
  },

  markDoorSeen(chapter) {
    if (!Game.state.seenDoors.includes(chapter)) Game.state.seenDoors.push(chapter);
    Game.save();
  },

  /** まだ届いていない章のゲート。届いていれば null。 */
  get nextGate() {
    for (const chapter of [1, 2, 3]) {
      const gate = Master.chapterGate(chapter);
      const steps = Game.state.player.cumulativeSteps;
      if (steps < gate) {
        const previous = chapter > 1 ? Master.chapterGate(chapter - 1) : 0;
        return { chapter, remaining: gate - steps, progress: (steps - previous) / (gate - previous) };
      }
    }
    return null;
  },

  isNodeUnlocked: (chapter, index) =>
    Game.state.player.cumulativeSteps >= Master.chapterGate(chapter) &&
    index <= Game.progress(chapter).nodeIndex + 1,

  isNodeCleared: (chapter, index) => index <= Game.progress(chapter).nodeIndex,

  vitality(chapter) {
    const id = Master.region(chapter).id;
    return Game.state.regions.find((r) => r.regionId === id)?.vitality ?? 0;
  },

  bestiaryEntry: (id) => Game.state.bestiary.find((e) => e.darumonId === id),

  // ---- 歩数（§3.1 / §3.4） ----

  /** 歩数を入れる。当日分は差分だけ、上限 30,000 歩／日（§3.1 のチート対策）。
   *
   * `how` は歩き方（§6.2）。**歩数そのものとは別に積む。**
   * 上限に当たって歩数が入らなかった日も、どう歩いたかは記録として残る。 */
  walk(steps, how = {}) {
    const p = Game.state.player;
    const before = p.cumulativeSteps;

    p.morning += how.morning ?? 0;
    p.floors += how.floors ?? 0;
    // 距離はその日の「最長」なので足さずに大きい方を採る。
    p.distance = Math.max(p.distance, how.distance ?? steps * 0.0007);

    const capped = Math.min(Balance.dailyStepCap, p.todayCreditedSteps + steps);
    p.cumulativeSteps += Math.max(0, capped - p.todayCreditedSteps);
    p.todayCreditedSteps = capped;

    const milestones = Math.min(
      Math.floor(capped / Balance.stepsPerMilestone),
      Balance.milestoneDailyCap
    );
    const gainedMilestones = Math.max(0, milestones - p.milestoneCreditedToday);
    p.milestoneCreditedToday = milestones;
    Game.state.pendingMilestones += gainedMilestones;

    // AP は累計歩数から導く。差分を都度割ると端数が切り捨てで消える（§3.1）。
    const levelBefore = Math.max(1, Math.floor(Math.sqrt(before / Balance.expPerLevelSquared)));
    const gainedAP = Math.floor(p.cumulativeSteps / Balance.stepsPerAP) - Math.floor(before / Balance.stepsPerAP);
    p.ap += gainedAP;

    Game.state.lastOutcome = {
      gainedSteps: p.cumulativeSteps - before,
      gainedAP,
      gainedMilestones,
      levelsGained: Game.level - levelBefore,
    };
    Game.save();
    return Game.state.lastOutcome;
  },

  /** 日付を進める。当日カウンタを畳むだけ（§3.4 の日跨ぎ処理に相当）。 */
  nextDay() {
    const p = Game.state.player;
    // 畳む前に、その日の歩数と歩き方を履歴へ移す。7日ぶんだけ持つ。
    Game.state.history.unshift({
      day: p.day, steps: p.todayCreditedSteps,
      morning: p.morning, floors: p.floors, distance: p.distance,
    });
    Game.state.history = Game.state.history.slice(0, 7);
    p.todayCreditedSteps = 0;
    p.milestoneCreditedToday = 0;
    p.morning = 0; p.floors = 0; p.distance = 0;
    p.bountyDoneToday = [];
    p.loreCreditedToday = 0;
    p.day += 1;
    Game.state.lastOutcome = null;
    Game.save();
  },

  /** 直近7日。当日を先頭に置く（まだ畳んでいないので履歴には入っていない）。 */
  get recentDays() {
    return [{ day: Game.state.player.day, steps: Game.state.player.todayCreditedSteps, today: true },
            ...Game.state.history];
  },

  /** 本編を最後まで終えたか。第3章のボスまで討伐済み。 */
  get isFinished() {
    return Game.progress(3).nodeIndex >= Master.nodesPerChapter;
  },

  // ---- 道標 ----

  openMilestones() {
    const count = Game.state.pendingMilestones;
    if (count <= 0) return [];

    const sighted = Game.state.bestiary.filter((e) => e.isSighted).map((e) => e.darumonId);
    const finds = Milestones.open(count, Game.unlockedChapter, Game.state.unlockedLore, sighted,
      Game.state.player.loreCreditedToday ?? 0);
    for (const find of finds) {
      if (find.kind === 'lore') {
        Game.state.unlockedLore.push(find.id);
        Game.state.player.loreCreditedToday = (Game.state.player.loreCreditedToday ?? 0) + 1;
      }
      if (find.kind === 'sighting') Game.markSighted(find.id);
      if (find.kind === 'shard') Game.state.materials.core_shard += 1;
    }

    // かけらが揃ったら核に変える（§18.4）。
    if (Game.state.materials.core_shard >= Balance.coreShardsPerCore) {
      const converted = Math.floor(Game.state.materials.core_shard / Balance.coreShardsPerCore);
      Game.state.materials.core_shard %= Balance.coreShardsPerCore;
      Game.state.materials.core += converted;
    }

    Game.state.pendingMilestones = 0;
    Game.save();
    return finds;
  },

  markSighted(id) {
    const entry = Game.bestiaryEntry(id);
    if (entry) entry.isSighted = true;
    else Game.state.bestiary.push({ darumonId: id, defeatedCount: 0, isSighted: true, firstSeenDay: Game.state.player.day });
  },

  // ---- 戦闘 ----

  /** 戦闘を解決して報酬まで反映する。返り値は再生用のログ一式。 */
  startBattle(chapter, index) {
    if (!Game.isNodeUnlocked(chapter, index)) return { error: 'このノードはまだ挑めません。' };

    const node = Master.node(chapter, index);
    const cost = node.enemy.apCost;
    if (Game.state.player.ap < cost) {
      return { error: `活力が足りません（必要 ${cost} / 所持 ${Game.state.player.ap}）。もう少し歩いてください。` };
    }

    // 消費した AP は勝っても負けても返らない（§4.3）。
    Game.state.player.ap -= cost;

    const fighter = Game.fighter;
    const log = BattleEngine.resolve(fighter, BattleEngine.enemyFighter(node.enemy));

    const alreadyOwned = node.equipment && Game.state.equipment.some((e) => e.id === node.equipment.id);
    const reward = Rewards.forBattle(
      node.enemy, log.result, Game.state.hasPass,
      alreadyOwned ? null : node.equipment
    );

    Game.applyReward(reward, chapter, index, log.result, node.enemy);
    return { chapter, nodeIndex: index, enemy: node.enemy, log, reward, player: fighter };
  },

  // ---- 章の山場の場面 ----

  /** まだ見せていないボス撃破後の場面。無ければ null。
   *
   * **状態から導く。** 「いま倒した」という旗を立てて回すと、
   * 結果画面を閉じ損ねた時などに旗が残り、関係ない場面で出てくる。
   * 章が制圧済みで、まだ見せていない——これだけで一意に決まる。 */
  get pendingStory() {
    for (const chapter of [1, 2, 3]) {
      const key = `boss-${chapter}-after`;
      if (Game.progress(chapter).isCleared && !Game.state.seenStory.includes(key)) {
        return { key, chapter, lines: STORY_SCENES[key] ?? [] };
      }
    }
    return null;
  },

  /** ボスに挑む直前の場面。まだ見せていなければ返す。 */
  bossIntroScene(chapter) {
    const key = `boss-${chapter}-before`;
    if (Game.state.seenStory.includes(key) || !STORY_SCENES[key]) return null;
    return { key, chapter, lines: STORY_SCENES[key] };
  },

  markStory(key) {
    if (!Game.state.seenStory.includes(key)) Game.state.seenStory.push(key);
    Game.save();
  },

  // ---- 活気の節目と施設（§6.1 / §6.2） ----

  /** その地域の施設の段。0=まだ無い / 1=開いた（45%） / 2=伸びた（100%）。 */
  facilityStage(chapter) {
    const v = Game.vitality(chapter);
    if (v >= 100) return 2;
    if (v >= 45) return 1;
    return 0;
  },

  /** 工房（靴の強化）はチュートリアルで開く。**活気には紐づけない**（§6.2）。
   *  強化は開始直後から要る仕組みなので、周回でしか届かない値の後ろに置けない。 */
  get forgeOpen() { return Game.state.seenTutorial; },

  /** まだ見せていない、越え済みの節目。無ければ null。
   *  小さい章・低い節目から順に出す（順番に読ませる）。 */
  get pendingVitalityScene() {
    for (const chapter of [1, 2, 3]) {
      const v = Game.vitality(chapter);
      for (const step of VITALITY_STEPS) {
        const key = `${chapter}-${step}`;
        if (v >= step && !Game.state.seenVitalityScenes.includes(key)) {
          return { chapter, step, key, lines: VITALITY_SCENES[key] ?? [] };
        }
      }
    }
    return null;
  },

  markVitalityScene(key) {
    if (!Game.state.seenVitalityScenes.includes(key)) Game.state.seenVitalityScenes.push(key);
    Game.save();
  },

  // ---- ウォークの軌跡（第1章の施設・§6.2） ----

  /** 直近7日の歩き方。**当日も含める**（今日そう歩いたのに反映されないと理由が分からない）。 */
  get walkProfile() {
    const p = Game.state.player;
    const days = [{ steps: p.todayCreditedSteps, morning: p.morning, floors: p.floors, distance: p.distance },
                  ...Game.state.history].slice(0, 7);
    const steps = days.reduce((t, d) => t + (d.steps ?? 0), 0);
    return {
      morningRatio: steps > 0 ? days.reduce((t, d) => t + (d.morning ?? 0), 0) / steps : 0,
      floors: days.reduce((t, d) => t + (d.floors ?? 0), 0),
      maxDistance: days.reduce((t, d) => Math.max(t, d.distance ?? 0), 0),
    };
  },

  /** いま刻める刻印。**最も強い傾向を1つだけ。** 届いていなければ null。 */
  get availableEngraving() {
    const profile = Game.walkProfile;
    let best = null;
    for (const rule of ENGRAVING_RULES) {
      const value = rule.read(profile);
      const score = value / rule.need;
      if (score >= 1 && (!best || score > best.score)) {
        best = { score, value, rule, engraving: ENGRAVINGS[rule.id] };
      }
    }
    return best;
  },

  /** 刻める数。100% まで戻した地域では2つ載る。 */
  get engravingSlots() { return Game.facilityStage(1) >= 2 ? 2 : 1; },

  /** 装備に刻む。核を1つ使う。**同じ刻印は重ねない。** */
  engrave(itemId) {
    const item = Game.state.equipment.find((e) => e.id === itemId);
    const found = Game.availableEngraving;
    if (!item || !found || Game.cores < 1) return false;
    item.engravings = item.engravings ?? [];
    if (item.engravings.includes(found.engraving.id)) return false;

    // 上限に達していたら、いちばん古い刻印を押し出す。
    if (item.engravings.length >= Game.engravingSlots) item.engravings.shift();
    item.engravings.push(found.engraving.id);
    Game.state.materials.core -= 1;
    Game.save();
    return true;
  },

  // ---- 市（第2章の施設・§6.2） ----

  /** その交換がいま成立するか。 */
  canTrade(trade) {
    return Object.entries(trade.give).every(([id, n]) => (Game.state.materials[id] ?? 0) >= n);
  },

  trade(id) {
    const t = TRADES.find((x) => x.id === id);
    if (!t || !Game.canTrade(t)) return false;
    const gain = Game.facilityStage(2) >= 2 ? t.after : t.get;
    for (const [m, n] of Object.entries(t.give)) Game.state.materials[m] -= n;
    for (const [m, n] of Object.entries(gain)) Game.state.materials[m] = (Game.state.materials[m] ?? 0) + n;
    Game.save();
    return true;
  },

  // ---- 掲示板（第3章の施設・§6.2） ----

  /** 今日の貼り紙。**日付を種にした決定的な選び方**にする（開き直しても変わらない）。 */
  get dailyBounty() {
    const stage = Game.facilityStage(3);
    if (stage < 1) return [];
    const pool = [];
    for (let chapter = 1; chapter <= Game.unlockedChapter; chapter++) {
      for (const s of Master.species(chapter)) pool.push(Master.zako(chapter, s.role, s));
    }
    const picked = [];
    for (let i = 0; i < (stage >= 2 ? 2 : 1) && pool.length; i++) {
      const index = (Game.state.player.day * 7919 + i * 104729) % pool.length;
      picked.push(pool.splice(index, 1)[0]);
    }
    return picked;
  },

  isBountyDone: (id) => (Game.state.player.bountyDoneToday ?? []).includes(id),

  /** 貼り紙の相手に挑む。**活力は通常どおり消費する**（無料にすると歩数の意味が薄れる）。 */
  startBountyBattle(enemyId) {
    const enemy = Game.dailyBounty.find((e) => e.id === enemyId);
    if (!enemy) return { error: '貼り紙はもう剥がされています。' };
    if (Game.isBountyDone(enemyId)) return { error: 'この依頼は今日ぶんを終えています。' };
    if (Game.state.player.ap < enemy.apCost) {
      return { error: `活力が足りません（必要 ${enemy.apCost} / 所持 ${Game.state.player.ap}）。` };
    }
    Game.state.player.ap -= enemy.apCost;

    const fighter = Game.fighter;
    const log = BattleEngine.resolve(fighter, BattleEngine.enemyFighter(enemy));
    const reward = Rewards.forBattle(enemy, log.result, Game.state.hasPass, null);
    // 依頼は報酬が良い。**素材と活気だけ**に乗せる（歩数と EXP には決して乗せない・§2）。
    reward.dregs = Math.ceil(reward.dregs * Balance.bountyMultiplier);
    reward.vitality = Math.ceil(reward.vitality * Balance.bountyMultiplier);

    if (log.result === 'victory') {
      Game.state.player.bountyDoneToday = [...(Game.state.player.bountyDoneToday ?? []), enemyId];
    }
    Game.applyReward(reward, enemy.chapter, 0, log.result, enemy);
    return { chapter: enemy.chapter, nodeIndex: 0, enemy, log, reward, player: fighter, bounty: true };
  },

  // ---- チュートリアル（§11-1） ----

  /** いまチュートリアルの何段目か。終わっていれば null。 */
  get tutorialStage() {
    if (Game.state.seenTutorial) return null;
    return TUTORIAL[Game.state.tutorialStep] ?? null;
  },

  /** 一段進める。最後まで来たら終わりにする。 */
  advanceTutorial() {
    Game.state.tutorialStep += 1;
    if (Game.state.tutorialStep >= TUTORIAL.length) Game.state.seenTutorial = true;
    Game.save();
  },

  /** 最初の靴を履かせる。**二度渡さない**（再開したときに増える）。 */
  grantStarterShoe() {
    const shoe = Master.starterShoe();
    if (Game.state.equipment.some((e) => e.id === shoe.id)) return;
    Game.state.equipment.push({ ...shoe });
    Game.save();
  },

  /** チュートリアルの戦闘。**章ゲートと活力の消費を外し、必ず勝つ**（§11-1）。
   *
   * 敵も報酬も第1章のノードそのものを使う。専用の敵を置くと、
   * チュートリアルで倒した相手を本編でもう一度倒すことになる。 */
  startTutorialBattle(index) {
    const node = Master.node(1, index);
    const fighter = Game.fighter;
    const log = BattleEngine.resolve(fighter, BattleEngine.enemyFighter(node.enemy), { guaranteed: true });

    const alreadyOwned = node.equipment && Game.state.equipment.some((e) => e.id === node.equipment.id);
    const reward = Rewards.forBattle(node.enemy, log.result, Game.state.hasPass, alreadyOwned ? null : node.equipment);

    Game.applyReward(reward, 1, index, log.result, node.enemy);
    return { chapter: 1, nodeIndex: index, enemy: node.enemy, log, reward, player: fighter, tutorial: true };
  },

  applyReward(reward, chapter, index, result, enemy) {
    Game.state.materials.dregs += reward.dregs;
    Game.state.materials.core += reward.cores;

    if (reward.equipment) {
      const item = { ...reward.equipment };
      // 初めて手に入れた装備は迷わせないよう自動で着ける。
      item.isEquipped = !Game.state.equipment.some((e) => e.slot === item.slot && e.isEquipped);
      Game.state.equipment.push(item);
    }

    if (result === 'victory') {
      const entry = Game.bestiaryEntry(enemy.id);
      if (entry) { entry.defeatedCount += 1; entry.isSighted = true; }
      else Game.state.bestiary.push({ darumonId: enemy.id, defeatedCount: 1, isSighted: true, firstSeenDay: Game.state.player.day });

      const progress = Game.progress(chapter);
      progress.nodeIndex = Math.max(progress.nodeIndex, index);
      progress.isCleared = progress.nodeIndex >= Master.nodesPerChapter;

      if (reward.vitality > 0) {
        const regionId = Master.region(chapter).id;
        let region = Game.state.regions.find((r) => r.regionId === regionId);
        if (!region) { region = { regionId, vitality: 0, isUnlocked: true }; Game.state.regions.push(region); }
        region.vitality = Math.min(Balance.vitalityMax, region.vitality + reward.vitality);
      }
    }
    Game.save();
  },

  // ---- 装備 ----

  toggleEquip(id) {
    const item = Game.state.equipment.find((e) => e.id === id);
    if (!item) return;
    const willEquip = !item.isEquipped;
    // 同じスロットは1つだけ。
    if (willEquip) Game.state.equipment.filter((e) => e.slot === item.slot).forEach((e) => { e.isEquipped = false; });
    item.isEquipped = willEquip;
    Game.save();
  },

  canEnhance: (item) =>
    item.enhanceLevel < Balance.maxEnhanceLevel &&
    Game.dregs >= Balance.enhanceCost(item.enhanceLevel),

  /** 装備画面に「いま出来ること」があるか。ホームの印に使う。
   *
   * **持っているだけでは印を出さない。** 強化できる澱が貯まった、または
   * 着け替えれば強くなる物がある、という**行動可能な状態**のときだけ立てる。
   * 常に点いている印は、数日で見えなくなる。 */
  get hasEquipWork() {
    return Game.state.equipment.some((item) => {
      if (Game.canEnhance(item)) return true;
      if (item.isEquipped) return false;
      const worn = Game.state.equipment.find((x) => x.slot === item.slot && x.isEquipped);
      const mine = BattleEngine.effective(item);
      const theirs = worn ? BattleEngine.effective(worn) : { hp: 0, atk: 0, def: 0 };
      return mine.hp + mine.atk * 3 + mine.def * 2 > theirs.hp + theirs.atk * 3 + theirs.def * 2;
    });
  },

  enhance(id) {
    const item = Game.state.equipment.find((e) => e.id === id);
    if (!item || !Game.canEnhance(item)) return false;
    Game.state.materials.dregs -= Balance.enhanceCost(item.enhanceLevel);
    item.enhanceLevel += 1;
    Game.save();
    return true;
  },
};
