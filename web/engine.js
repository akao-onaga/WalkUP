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

  /** 先攻は主人公固定。**戦闘に入る前に勝敗まで確定させる**（§4.1）。 */
  resolve(player, enemy) {
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
      turns.push({ index, attacker: 'enemy', damage: toPlayer, remaining: Math.max(0, playerHP) });
      if (playerHP <= 0) return { turns, result: 'defeat', playerRemainingHP: 0 };
    }
    // 30ターンで決着せず＝「活力が尽きて撤退」（§4.2）。
    return { turns, result: 'defeat', playerRemainingHP: Math.max(0, playerHP) };
  },

  /** 強化を反映した実効値（§17.7）。 */
  effective(item) {
    const m = 1 + Balance.enhanceGainPerLevel * item.enhanceLevel;
    return { hp: Math.floor(item.hp * m), atk: Math.floor(item.atk * m), def: Math.floor(item.def * m) };
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

/** 道標の開封（§18.4）。抽選表は 世界の記述45 / 目撃25 / 携行品20 / かけら10。 */
const Milestones = {
  weights: [['lore', 45], ['sighting', 25], ['consumable', 20], ['shard', 10]],

  pick() {
    let roll = Math.random() * 100;
    for (const [kind, weight] of Milestones.weights) {
      roll -= weight;
      if (roll < 0) return kind;
    }
    return 'lore';
  },

  /** **一括で開ける**（§18.2）。1つずつ開けさせると1セッション3分が壊れる。 */
  open(count, unlockedChapter, alreadyUnlocked) {
    const finds = [];
    const used = new Set(alreadyUnlocked);

    for (let i = 0; i < count; i++) {
      switch (Milestones.pick()) {
        case 'lore': {
          // 引き当て済みなら次の未解放へ回す。読み物として途中が抜けないようにする（§18.6）。
          const entry = LORE.find((l) => l.chapter <= Math.max(1, unlockedChapter) && !used.has(l.id));
          if (entry) {
            used.add(entry.id);
            finds.push({ kind: 'lore', id: entry.id, title: '世界の記述', text: entry.text });
          } else {
            finds.push({ kind: 'shard', title: '怠惰の核のかけら' });
          }
          break;
        }
        case 'sighting': {
          const roles = ['standard', 'tough', 'swift'];
          const role = roles[Math.floor(Math.random() * roles.length)];
          const enemy = Master.zako(unlockedChapter, role);
          finds.push({ kind: 'sighting', id: enemy.id, title: `${enemy.name} の目撃情報` });
          break;
        }
        case 'consumable':
          finds.push({ kind: 'consumable', id: 'salve', title: '気付けの塗り薬' });
          break;
        default:
          finds.push({ kind: 'shard', title: '怠惰の核のかけら' });
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
  player: { cumulativeSteps: 0, ap: 0, todayCreditedSteps: 0, milestoneCreditedToday: 0, day: 1 },
  equipment: [],
  chapters: [1, 2, 3].map((chapterId) => ({ chapterId, nodeIndex: 0, isCleared: false })),
  regions: [],
  bestiary: [],
  materials: { dregs: 0, core: 0, core_shard: 0 },
  consumables: {},
  unlockedLore: [],
  pendingMilestones: 0,
  hasPass: false,
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

  /** 歩数を入れる。当日分は差分だけ、上限 30,000 歩／日（§3.1 のチート対策）。 */
  walk(steps) {
    const p = Game.state.player;
    const before = p.cumulativeSteps;

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
    p.todayCreditedSteps = 0;
    p.milestoneCreditedToday = 0;
    p.day += 1;
    Game.state.lastOutcome = null;
    Game.save();
  },

  // ---- 道標 ----

  openMilestones() {
    const count = Game.state.pendingMilestones;
    if (count <= 0) return [];

    const finds = Milestones.open(count, Game.unlockedChapter, Game.state.unlockedLore);
    for (const find of finds) {
      if (find.kind === 'lore') Game.state.unlockedLore.push(find.id);
      if (find.kind === 'sighting') Game.markSighted(find.id);
      if (find.kind === 'consumable') Game.state.consumables[find.id] = (Game.state.consumables[find.id] ?? 0) + 1;
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

  enhance(id) {
    const item = Game.state.equipment.find((e) => e.id === id);
    if (!item || !Game.canEnhance(item)) return false;
    Game.state.materials.dregs -= Balance.enhanceCost(item.enhanceLevel);
    item.enhanceLevel += 1;
    Game.save();
    return true;
  },
};
