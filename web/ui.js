/* Walk UP! ブラウザ版 — 画面
 *
 * `engine.js` が返した結果を並べて再生するだけ。**判断はここに書かない。**
 * 本編（SwiftUI）と同じ切り分けにしてあるので、この層をいくら作り替えても
 * 勝敗もバランスも動かない。演出だけを安心して壊せる。
 */

/* ------------------------------------------------------------------ */
/* 記号                                                                */
/* ------------------------------------------------------------------ */

/* **システムアイコンを使わない。**
 * SF Symbols（や Material Icons）をそのまま並べると、絵がどれだけ描き込んであっても
 * 画面は OS の設定画面の顔になる。線の太さも造形も、輪郭線のアートと揃わない。
 * 数は少なくていいので、この世界の記号を自前で持つ。 */
const ICONS = {
  bolt: 'M13 2 4 14h6l-1 8 9-12h-6l1-8z',
  cube: 'M12 2 21 7 12 12 3 7z M3 8.6 11 13v8.4L3 17z M21 8.6 13 13v8.4l8-4.4z',
  diamond: 'M12 2 22 9 12 22 2 9z',
  /* 武器は靴。剣や杖を記号にすると、歩いた力だけが武器という筋がここで切れる。 */
  shoe: 'M2.5 19v-3.6c0-.7.5-1.3 1.2-1.4l3.6-.7 2.5-3.5c.4-.6 1.2-.8 1.9-.5l1.9.8c.6.2.9.8 1 1.4l.2 1.6 4.7 2c1 .5 1.7 1.5 1.7 2.6V19z',
  cloak: 'M12 2.2c1.7 0 2.9.8 3.8 1.5l4.4 3.3-2.4 3.2 1 11.6H5.2l1-11.6-2.4-3.2 4.4-3.3C9.1 3 10.3 2.2 12 2.2zm0 3.6-2 1.9 2 2.4 2-2.4z',
  charm: 'M9 1.8h6L16.6 5v15a2.4 2.4 0 0 1-2.4 2.4H9.8A2.4 2.4 0 0 1 7.4 20V5zm.6 6.4v1.8h4.8V8.2zm0 4v1.8h4.8v-1.8z',
  book: 'M6 2h12a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zm2 3v6l2.5-1.6L13 11V5z',
  eye: 'M12 5c5.2 0 9 4.6 9 7s-3.8 7-9 7-9-4.6-9-7 3.8-7 9-7zm0 3.5A3.5 3.5 0 1 0 12 15.5 3.5 3.5 0 0 0 12 8.5z',
  post: 'M11 2h2v20h-2z M4 4.5h13l3 3-3 3H4z',
  map: 'M9 2 3 4.5v17.5L9 19.5l6 2.5 6-2.5V2l-6 2.5z',
  hammer: 'M13.5 1.5 22 10l-2.8 2.8-2.6-2.6-8.8 8.8L4 15.2l8.8-8.8-2.6-2.6z',
  sparkle: 'M12 2l2.2 6.3L20.5 10l-6.3 2.2L12 18.5l-2.2-6.3L3.5 10l6.3-1.7z',
  lock: 'M6 10V7a6 6 0 1 1 12 0v3h1.5v12h-15V10zm3 0h6V7a3 3 0 0 0-6 0z',
  check: 'M4 12.5 9.2 18 20.5 5.8 18.4 3.8 9.2 13.8 6 10.5z',
  back: 'M15.5 3 6 12l9.5 9 2-2-7.4-7 7.4-7z',
  close: 'M5.5 3 3 5.5 9.5 12 3 18.5 5.5 21 12 14.5 18.5 21 21 18.5 14.5 12 21 5.5 18.5 3 12 9.5z',
  walk: 'M13.5 1.5a2.2 2.2 0 1 1 0 4.4 2.2 2.2 0 0 1 0-4.4zM9 7.4l4.4-1.1 3.1 3.2 3.5 1.2-.9 2.4-4.2-1.4-1.2 2.3 3.3 3.1V23h-2.6v-5.4l-4.2-3.1L8.6 23H6l3-9z',
  shield: 'M12 1.5 20.5 5v6.8c0 5.4-4.2 8.8-8.5 10.7C7.7 20.6 3.5 17.2 3.5 11.8V5z',
  heart: 'M12 21.5S2.5 14.6 2.5 8.6A4.9 4.9 0 0 1 12 6a4.9 4.9 0 0 1 9.5 2.6c0 6-9.5 12.9-9.5 12.9z',
  flame: 'M12 1.5c3.4 4.4 6.5 6.6 6.5 10.8a6.5 6.5 0 1 1-13 0c0-2.2 1.1-3.4 2.2-4.4 0 2.2 1.1 3.3 2.2 3.3 0-3.3 1.1-6.6 2.1-9.7z',
  zzz: 'M4 4h9v2.2L7.5 12H13v2.2H4V12l5.5-5.8H4zm11 9h7v1.8l-4.2 4.4H22V21h-7v-1.8l4.2-4.4H15z',
};

/** 記号。色は継承させ、置いた場所の文字色に従わせる。 */
function icon(name, size = 16) {
  return `<svg class="glyph" viewBox="0 0 24 24" width="${size}" height="${size}" fill="currentColor" aria-hidden="true">`
    + ICONS[name].split(' M').map((d, i) => `<path d="${i ? 'M' + d : d}"/>`).join('')
    + '</svg>';
}

/* ------------------------------------------------------------------ */
/* 道具                                                                */
/* ------------------------------------------------------------------ */

const fmt = (n) => n.toLocaleString('ja-JP');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const $ = (root, sel) => root.querySelector(sel);
const $$ = (root, sel) => [...root.querySelectorAll(sel)];

/** 数を回して見せる。**完成値をいきなり置くと、同じ数でも受け取られ方がまるで違う。** */
function countUp(el, target, duration = 700) {
  const start = performance.now();
  const step = (now) => {
    const t = Math.min(1, (now - start) / duration);
    const eased = 1 - Math.pow(1 - t, 3);
    el.textContent = fmt(Math.round(target * eased));
    if (t < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

/** ゲージは 0 から伸ばす。到達点だけ置くと、伸びた実感が残らない。 */
function growMeter(meterEl, ratio) {
  requestAnimationFrame(() => {
    $(meterEl, 'i').style.width = `${Math.max(0, Math.min(1, ratio)) * 100}%`;
  });
}

const meter = (cls = '') => `<div class="meter ${cls}"><i style="width:0"></i></div>`;

function make(cls, html) {
  const d = document.createElement('div');
  d.className = cls;
  d.innerHTML = html;
  return d;
}

/* ------------------------------------------------------------------ */
/* 画面の出し入れ                                                       */
/* ------------------------------------------------------------------ */

const frame = document.getElementById('frame');
const curtain = document.getElementById('curtain');
const layers = [];

const Nav = {
  /** `build` を覚えさせておくと、戻ってきたときに作り直せる。
   *  討伐から帰った一覧が古い活力を出したままだと、そこで没入が切れる。 */
  push(el, build) {
    if (build) el._build = build;
    frame.appendChild(el);
    layers.push(el);
    return el;
  },
  pop() {
    const el = layers.pop();
    if (!el) return;
    el.classList.add('leaving');
    setTimeout(() => el.remove(), 220);
    renderHome();
    Nav.refresh();
  },
  /** 下の階層を作り直す。**アニメーションは付けない**（戻っただけなのに開き直して見える）。 */
  refresh() {
    const top = layers[layers.length - 1];
    if (!top || !top._build) return;
    const fresh = top._build();
    fresh._build = top._build;
    fresh.classList.add('static');
    layers[layers.length - 1] = fresh;
    frame.replaceChild(fresh, top);
  },
  replaceTop(el, build) {
    const old = layers.pop();
    if (old) old.remove();
    Nav.push(el, build);
  },
  /** 一拍暗くしてから次の場所を出す。**ここが無いと戦闘が「次の頁」に見える。** */
  async curtainTo(build) {
    curtain.classList.add('on');
    await sleep(240);
    build();
    await sleep(60);
    curtain.classList.remove('on');
  },
};

/** 画面の見出し。標準のナビゲーションバーの代わり。 */
function header(title, trailing = '') {
  return `<div class="game-header">
    <button class="round-button" data-act="back">${icon('back', 15)}</button>
    <h1>${title}</h1><div class="grow"></div>${trailing}
  </div>`;
}

const counter = (name, value, cls = '') => `<span class="counter ${cls}">${icon(name, 14)}<span class="num">${fmt(value)}</span></span>`;

/* ------------------------------------------------------------------ */
/* ホーム                                                              */
/* ------------------------------------------------------------------ */

function renderHome() {
  const home = document.getElementById('home');
  const s = Game.state;
  const outcome = s.lastOutcome;
  const gate = Game.nextGate;
  const next = Game.nextNode;

  const walked = s.player.todayCreditedSteps > 0;

  home.innerHTML = `
    <div class="signboard">
      <span class="title">Walk UP!</span>
      <span class="day">${s.player.day} 日目</span>
    </div>

    <!-- 図版。**絵を薄めない。** ここが1枚の絵として立っているかどうかで、
         開いた瞬間に「ゲーム」か「記録アプリ」かが決まる。 -->
    <div class="plate-art" style="background-image:url('${bgOf(Game.unlockedChapter)}')">
      <div class="ground"></div>
      <img class="hero bob" src="${artOf('hero')}" alt="主人公">
      <div class="voice">
        <div class="l1">${walked ? '今日も歩いた' : 'まだ歩いていない'}</div>
        <div class="l2">${walked ? 'その分だけ、世界が目を覚ます。' : '一歩ごとに、止まった街が動き出す。'}</div>
      </div>
    </div>

    <div class="body">
      <div class="rank-band">
        <span class="lv">Lv <b>${Game.level}</b></span>
        <div class="right">
          <div class="row between">
            <span class="caption">累計 ${fmt(s.player.cumulativeSteps)} 歩</span>
            ${outcome && outcome.levelsGained > 0 ? '<span class="badge-up">Lv UP</span>' : ''}
            ${outcome && outcome.gainedSteps > 0
              ? `<span class="num" style="font-size:13px;color:var(--accent)">+<span data-gain>0</span> 歩</span>` : ''}
          </div>
          ${meter('slim')}
        </div>
      </div>

      <div class="tile-row">
        <div class="tile"><span class="k">${icon('walk', 11)}今日</span><span class="v" data-count="${s.player.todayCreditedSteps}">0</span></div>
        <div class="tile vigor"><span class="k">${icon('bolt', 11)}活力</span><span class="v" data-count="${s.player.ap}">0</span></div>
        <div class="tile accent"><span class="k">${icon('cube', 11)}澱</span><span class="v" data-count="${Game.dregs}">0</span></div>
      </div>

      ${s.pendingMilestones > 0 ? `
      <button class="notice" data-act="milestones" style="text-align:left;width:100%">
        <span class="tag">道標</span>
        <span class="face">${icon('post', 34)}</span>
        <span>
          <span class="who" style="display:block">${s.pendingMilestones} つ 残されている</span>
          <span class="caption">歩いた道のりに、何かが落ちている</span>
        </span>
      </button>` : ''}

      ${destinationBlock(next, gate)}

      <button class="btn" data-act="map" ${Game.canBattle ? '' : 'disabled'}>
        ${icon('map', 18)}${next ? '討伐に出る' : '周回して素材を集める'}
      </button>
      <div class="btn-row">
        <button class="btn secondary" data-act="equip">${icon('shield', 15)}装備・強化</button>
        <button class="btn secondary" data-act="bestiary">${icon('book', 15)}図鑑</button>
      </div>
      <div class="btn-row">
        <button class="btn secondary" data-act="region">${icon('map', 15)}地域</button>
        <button class="btn secondary" data-act="pass">${icon('sparkle', 15)}${s.hasPass ? 'パス有効' : '活力パス'}</button>
      </div>
      <div style="height:6px"></div>
    </div>`;

  // 数値は置いた瞬間から回す。「今日も無駄じゃなかった」は数字が動いて初めて伝わる。
  $$(home, '[data-count]').forEach((el) => countUp(el, Number(el.dataset.count)));
  growMeter($(home, '.rank-band .meter'), Game.levelProgress);
  if (outcome && outcome.gainedSteps > 0) countUp($(home, '[data-gain]'), outcome.gainedSteps);
}

/** 次の目的地。**高札として出す。** 「見出し＋行」で書くと予定表になる。 */
function destinationBlock(next, gate) {
  if (next) {
    const node = Master.node(next.chapter, next.index);
    const affordable = Game.player.ap >= node.enemy.apCost;
    return `<div class="notice">
      <span class="tag">次の目的地</span>
      <span class="face"><img src="${artOf(node.enemy.asset)}" alt=""></span>
      <span>
        <span class="where">第${next.chapter}章 ・ ノード ${next.index}</span>
        <span class="who" style="display:block">${node.enemy.isBoss ? 'ボス：' : ''}${node.enemy.name}</span>
      </span>
      <span class="cost ${affordable ? '' : 'short'}">${icon('bolt', 15)}${node.enemy.apCost}</span>
    </div>`;
  }
  if (gate) {
    return `<div class="notice" style="display:block">
      <span class="tag">次の目的地</span>
      <div style="font-weight:800;font-size:14px;margin-bottom:8px">第${gate.chapter}章の解放まで あと ${fmt(gate.remaining)} 歩</div>
      <div class="meter slim"><i style="width:${Math.round(gate.progress * 100)}%"></i></div>
      ${Game.canBattle ? '<div class="caption" style="margin-top:8px">解放を待つ間も、討伐済みのダルモンに再挑戦して素材を集められます。</div>' : ''}
    </div>`;
  }
  return `<div class="notice" style="display:block">
    <span class="tag">次の目的地</span>
    <div class="body-text">本編は完結しました。地域の復興を進められます。</div>
  </div>`;
}

/* ------------------------------------------------------------------ */
/* 討伐マップ                                                          */
/* ------------------------------------------------------------------ */

function mapScreen() {
  const chapters = [1, 2, 3].map((chapter) => {
    const gate = Master.chapterGate(chapter);
    const isOpen = Game.player.cumulativeSteps >= gate;
    const cleared = Game.progress(chapter).isCleared;

    const nodes = isOpen ? `<div class="trail">${[...Array(Master.nodesPerChapter)].map((_, i) => {
      const index = i + 1;
      const node = Master.node(chapter, index);
      const done = Game.isNodeCleared(chapter, index);
      const open = Game.isNodeUnlocked(chapter, index);
      const affordable = Game.player.ap >= node.enemy.apCost;
      return `<button class="node ${done ? 'cleared' : ''} ${open ? '' : 'locked'} ${node.enemy.isBoss ? 'boss' : ''}"
                data-battle="${chapter}-${index}" ${open ? '' : 'disabled'}>
        <span class="medal">
          ${open ? `<img src="${artOf(node.enemy.asset)}" alt="">` : icon('lock', 16)}
          ${done ? `<span class="stamp">${icon('check', 11)}</span>` : ''}
        </span>
        <span>
          <span class="name">${node.enemy.isBoss ? 'ボス：' : ''}${node.enemy.name}</span>
          ${node.equipment ? `<span class="drop">${icon('shield', 11)}装備を入手</span>` : ''}
        </span>
        <span class="cost ${affordable ? '' : 'short'}">${icon('bolt', 13)}${node.enemy.apCost}</span>
      </button>`;
    }).join('')}</div>` : `<div class="caption row" style="gap:6px">${icon('lock', 13)}${fmt(gate)} 歩で解放</div>`;

    // 章は「扉」で開く。見出しの文字だけだと目次になる。
    return `<div class="panel chapter-card ${isOpen ? '' : 'closed'}">
      <div class="chapter-door ${isOpen ? '' : 'locked'}" style="background-image:url('${bgOf(chapter)}')">
        <span class="no">第${chapter}章</span>
        <h2>${Master.region(chapter).name}</h2>
        <div class="grow"></div>
        ${cleared ? `<span class="no">${icon('check', 11)} 制圧</span>` : ''}
      </div>
      <div class="chapter-body">${nodes}</div>
    </div>`;
  }).join('');

  const el = make('screen sheet', header('討伐', counter('bolt', Game.player.ap, 'vigor')) + `<div class="body">${chapters}</div>`);

  $$(el, '[data-battle]').forEach((btn) => btn.addEventListener('click', () => {
    const [chapter, index] = btn.dataset.battle.split('-').map(Number);
    startBattle(chapter, index);
  }));
  el._build = mapScreen;
  return el;
}

/* ------------------------------------------------------------------ */
/* 戦闘                                                                */
/* ------------------------------------------------------------------ */

function startBattle(chapter, index) {
  const session = Game.startBattle(chapter, index);
  if (session.error) { toast(session.error); return; }
  Nav.curtainTo(() => Nav.push(battleScreen(session)));
}

function battleScreen(session) {
  const { enemy, player, log } = session;
  const el = make('screen cover battle', `
    <div class="bg" style="background-image:url('${bgOf(session.chapter)}')"></div>
    <div class="scrim"></div>
    <div class="inner">
      <div class="battle-tag">第${session.chapter}章 ・ ノード ${session.nodeIndex}</div>
      <div class="enemy-name ${enemy.isBoss ? 'boss' : ''}">${enemy.name}</div>
      <div class="gauge-plate">
        ${meter('danger')}<span class="hp" data-enemy-hp>${enemy.hp}</span>
      </div>
      <div class="field">
        <!-- **主人公は左、ダルモンは右。** 主人公は右へ歩いていく絵なので、
             左に置くと踏み込みの向きと絵が噛み合う。 -->
        <div class="fighter hero"><img src="${artOf('hero')}" alt="主人公"></div>
        <div class="fighter foe ${enemy.isBoss ? 'boss' : ''}">
          <img class="bob" src="${artOf(enemy.asset)}" alt="${enemy.name}">
          <div class="puddle"></div>
        </div>
      </div>
      <div class="gauge-plate">
        <span class="who">主人公</span>${meter()}<span class="hp" data-player-hp>${player.maxHP}</span>
      </div>
    </div>
    <div class="hit-flash"></div>`);

  const enemyMeter = $$(el, '.meter')[0];
  const playerMeter = $$(el, '.meter')[1];
  growMeter(enemyMeter, 1);
  growMeter(playerMeter, 1);

  playBattle(el, session, { enemyMeter, playerMeter });
  return el;
}

/** ログを順に再生する。**手応えは「動かす量」ではなく「止める瞬間」で作る。**
 *  踏み込む → 命中で一瞬止める → 揺らす、の順番が効く。 */
async function playBattle(el, session, meters) {
  const { log, enemy, player } = session;
  const inner = $(el, '.inner');
  const hero = $(el, '.fighter.hero');
  const foe = $(el, '.fighter.foe');
  const flash = $(el, '.hit-flash');

  // 1手あたりの間隔は手数から逆算して総時間を 3〜8秒に収める（§4.1）。
  const beat = Math.min(400, Math.max(130, 4500 / Math.max(1, log.turns.length)));

  await sleep(320);

  for (const turn of log.turns) {
    const attacker = turn.attacker === 'player' ? hero : foe;
    const target = turn.attacker === 'player' ? foe : hero;
    const hurtIsPlayer = target === hero;

    // 1. 踏み込み。
    attacker.classList.add('lunge');
    await sleep(beat * 0.35);
    attacker.classList.remove('lunge');

    // 2. 命中。HP の減少・数値・煙・振動を同じ瞬間に集中させる。
    target.classList.add('recoil', 'flash');
    spawnDamage(target, turn.damage);
    spawnPuff(target);
    inner.classList.add(hurtIsPlayer ? 'shake-strong' : 'shake-light');
    if (hurtIsPlayer) flash.style.opacity = '.22';

    const ratio = turn.remaining / (hurtIsPlayer ? player.maxHP : enemy.hp);
    growMeter(hurtIsPlayer ? meters.playerMeter : meters.enemyMeter, ratio);
    $(el, hurtIsPlayer ? '[data-player-hp]' : '[data-enemy-hp]').textContent = turn.remaining;

    await sleep(beat * 0.28);

    // 3. 戻す。
    target.classList.remove('recoil', 'flash');
    inner.classList.remove('shake-strong', 'shake-light');
    flash.style.opacity = '0';
    await sleep(beat * 0.37);
  }

  if (log.result === 'victory') {
    foe.classList.add('melted');
    $(foe, 'img').classList.remove('bob');
    await sleep(750);
  } else {
    flash.style.opacity = '.35';
    await sleep(450);
    flash.style.opacity = '0';
  }

  Nav.replaceTop(resultScreen(session));
}

function spawnDamage(target, amount) {
  const n = document.createElement('div');
  n.className = 'dmg';
  n.textContent = amount;
  target.appendChild(n);
  setTimeout(() => n.remove(), 620);
}

/** 命中の跡。斬撃ではなく土煙と靴底で見せる（武器は靴なので）。 */
function spawnPuff(target) {
  const puff = document.createElement('div');
  puff.className = 'puff';
  let html = '<span class="sole"></span>';
  for (let i = 0; i < 7; i++) {
    const angle = (i / 7) * Math.PI;
    const size = 16 + (i % 3) * 6;
    html += `<span style="width:${size}px;height:${size}px;left:${-size / 2}px;bottom:0;`
      + `--dx:${Math.round(Math.cos(Math.PI + angle) * 46)}px;`
      + `--dy:${Math.round(-Math.sin(angle) * 46 * 0.45)}px"></span>`;
  }
  puff.innerHTML = html;
  target.appendChild(puff);
  setTimeout(() => puff.remove(), 340);
}

/* ------------------------------------------------------------------ */
/* 結果                                                                */
/* ------------------------------------------------------------------ */

function resultScreen(session) {
  const won = session.log.result === 'victory';
  const r = session.reward;
  // 獲得物は**絵札**にする。「名前 …… ×3」の行で書くと納品書になる。
  const rows = [];
  if (r.dregs > 0) rows.push(['cube', '怠惰の澱', `×${r.dregs}`]);
  if (r.cores > 0) rows.push(['diamond', '怠惰の核', `×${r.cores}`]);
  if (r.vitality > 0) rows.push(['sparkle', '地域の活気', `+${r.vitality}`]);
  if (r.equipment) rows.push([{ weapon: 'shoe', armor: 'cloak', accessory: 'charm' }[r.equipment.slot], r.equipment.name, '入手']);

  const turnCount = Math.ceil(session.log.turns.length / 2);

  const el = make('screen cover result', `
    <div class="game-header"><div class="grow"></div>
      <button class="round-button" data-act="close-result">${icon('close', 14)}</button>
    </div>
    <div class="body">
      <div class="result-seal ${won ? '' : 'lost'}">${icon(won ? 'check' : 'zzz', 44)}</div>
      <div class="result-title">${won ? '討伐した' : '活力が尽きて撤退した'}</div>
      <div class="caption" style="text-align:center">第${session.chapter}章 ノード${session.nodeIndex} ・ ${session.enemy.name} ・ ${turnCount} ターン</div>

      <div class="stack">
        <div class="row" style="justify-content:center">
          <span class="plate">${won ? '獲　得' : '持ち帰った分'}</span>
        </div>
        ${rows.length === 0 ? '<div class="caption" style="text-align:center">何も持ち帰れなかった</div>' : ''}
        <div class="loot-grid">
          ${rows.map(([g, title, amount]) => `<div class="loot hidden">
            ${icon(g, 30)}
            <span class="lnum">${amount}</span>
            <span class="lname">${title}</span>
          </div>`).join('')}
        </div>
        ${Game.state.hasPass && won ? `<div class="caption row" style="gap:5px;color:var(--accent);justify-content:center">${icon('sparkle', 12)}活力パスにより素材と活気が 1.5倍</div>` : ''}
      </div>

      ${!won ? `<div class="panel warn stack">
        <div style="font-weight:800;font-size:15px">装備を整えれば勝てる</div>
        <div class="caption">消費した活力は戻りません。ですが素材は残りました。装備を強化してから、もう一度挑んでください。</div>
        <button class="btn" data-act="equip">${icon('hammer', 16)}装備を強化する</button>
      </div>` : ''}
    </div>`);

  // **1枚ずつ順に出す。** まとめて出すと、何を得たのかが読み飛ばされる。
  $$(el, '.loot').forEach((card, i) => setTimeout(() => {
    card.classList.remove('hidden');
    card.classList.add('show');
  }, 320 + i * 140));

  return el;
}

/* ------------------------------------------------------------------ */
/* 装備・強化                                                          */
/* ------------------------------------------------------------------ */

function equipScreen() {
  const f = Game.fighter;
  const slots = [
    ['weapon', '武器 — 靴', 'この世界で武器になるのは踏み出す力——ウォーク力だけ。'],
    ['armor', '防具', null],
    ['accessory', '装飾', null],
  ];

  const sections = slots.map(([slot, name, note]) => {
    const items = Game.state.equipment.filter((e) => e.slot === slot);
    if (items.length === 0) return '';
    return `<div class="panel">
      <span class="plate">${name}</span>
      ${note ? `<div class="caption" style="margin-top:6px">${note}</div>` : ''}
      <div style="margin-top:10px">${items.map(equipRow).join('')}</div>
    </div>`;
  }).join('');

  const empty = `<div class="panel" style="text-align:center;padding:28px">
    <div style="color:var(--text-soft)">${icon('cube', 34)}</div>
    <div style="font-weight:800;margin-top:8px">まだ装備がありません</div>
    <div class="caption" style="margin-top:4px">各章のノード 2・4・6 を討伐すると手に入ります。</div>
  </div>`;

  const el = make('screen sheet', header('装備・強化', counter('cube', Game.dregs)) + `<div class="body">
    <div class="tile-row">
      <div class="tile"><span class="k">${icon('heart', 11)}HP</span><span class="v">${f.maxHP}</span></div>
      <div class="tile vigor"><span class="k">${icon('flame', 11)}ATK</span><span class="v">${f.atk}</span></div>
      <div class="tile accent"><span class="k">${icon('shield', 11)}DEF</span><span class="v">${f.def}</span></div>
    </div>
    ${Game.state.equipment.length === 0 ? empty : sections}
  </div>`);

  // 着脱と強化はその場で数字に反映する。**シートは開き直さない。**
  // 自動戦闘なので、ここで手応えを返せないと唯一の意思決定が空虚になる。
  $$(el, '[data-equip]').forEach((b) => b.addEventListener('click', () => { Game.toggleEquip(b.dataset.equip); Nav.refresh(); }));
  $$(el, '[data-enhance]').forEach((b) => b.addEventListener('click', () => { if (Game.enhance(b.dataset.enhance)) Nav.refresh(); }));
  el._build = equipScreen;
  return el;
}

function equipRow(item) {
  const e = BattleEngine.effective(item);
  const cost = Balance.enhanceCost(item.enhanceLevel);
  const maxed = item.enhanceLevel >= Balance.maxEnhanceLevel;
  const stats = [
    e.hp > 0 ? `HP +${e.hp}` : null,
    e.atk > 0 ? `ATK +${e.atk}` : null,
    e.def > 0 ? `DEF +${e.def}` : null,
  ].filter(Boolean).join(' / ');
  const glyph = { weapon: 'shoe', armor: 'cloak', accessory: 'charm' }[item.slot];

  return `<div class="equip-item">
    <div class="row">
      ${icon(glyph, 22)}
      <div>
        <div class="ename">${item.name}${item.enhanceLevel > 0 ? ` <span class="plus">+${item.enhanceLevel}</span>` : ''}</div>
        <div class="caption">${stats}</div>
      </div>
      <div class="grow"></div>
      <button class="chip ${item.isEquipped ? 'on' : ''}" data-equip="${item.id}">${item.isEquipped ? '装備中' : '装備'}</button>
    </div>
    <div class="row">
      <div class="pips">${[...Array(Balance.maxEnhanceLevel)].map((_, i) => `<i class="${i < item.enhanceLevel ? 'on' : ''}"></i>`).join('')}</div>
      <div class="grow"></div>
      ${maxed
        ? '<span class="caption">最大</span>'
        : `<button class="chip" data-enhance="${item.id}" ${Game.canEnhance(item) ? '' : 'disabled'}>${icon('hammer', 12)}${cost}</button>`}
    </div>
  </div>`;
}

/* ------------------------------------------------------------------ */
/* 図鑑                                                                */
/* ------------------------------------------------------------------ */

function bestiaryScreen() {
  const roster = Master.roster();
  const defeated = roster.filter((e) => (Game.bestiaryEntry(e.id)?.defeatedCount ?? 0) > 0).length;

  const chapters = [1, 2, 3].map((chapter) => `
    <div class="panel chapter-card">
      <div class="chapter-door" style="background-image:url('${bgOf(chapter)}')">
        <span class="no">第${chapter}章</span>
        <h2>${Master.region(chapter).name}</h2>
      </div>
      <div class="chapter-body">
        <div class="bestiary-grid">
          ${roster.filter((e) => e.chapter === chapter).map(bestiaryCell).join('')}
        </div>
      </div>
    </div>`).join('');

  const el = make('screen sheet', header('図鑑') + `<div class="body">
    <div class="panel">
      <div class="row" style="align-items:baseline;gap:6px">
        <span style="font-size:34px;font-weight:800;color:var(--accent)" class="num">${defeated}</span>
        <span class="caption">/ ${roster.length} 体</span>
      </div>
      <div style="margin:10px 0 8px">${meter()}</div>
      <div class="caption">討伐すると図鑑に載る。道標で目撃したダルモンは影だけが残る。</div>
    </div>
    ${chapters}
  </div>`);

  growMeter($(el, '.body .panel .meter'), defeated / roster.length);
  $$(el, '[data-detail]').forEach((b) => b.addEventListener('click', () => Nav.push(bestiaryDetail(b.dataset.detail))));
  el._build = bestiaryScreen;
  return el;
}

function bestiaryCell(enemy) {
  const entry = Game.bestiaryEntry(enemy.id);
  const defeated = (entry?.defeatedCount ?? 0) > 0;
  const sighted = entry?.isSighted ?? false;

  if (!sighted) {
    return `<div class="bestiary-cell unknown ${enemy.isBoss ? 'boss' : ''}"><div class="qm">?</div><div class="cname">？？？</div></div>`;
  }
  return `<button class="bestiary-cell ${defeated ? '' : 'shadow'} ${enemy.isBoss ? 'boss' : ''}" data-detail="${enemy.id}">
    ${defeated && entry.defeatedCount > 1 ? `<span class="count">×${entry.defeatedCount}</span>` : ''}
    <img src="${artOf(enemy.asset)}" alt="">
    <span class="cname">${defeated ? enemy.name : '影'}</span>
  </button>`;
}

function bestiaryDetail(id) {
  const enemy = Master.roster().find((e) => e.id === id);
  const entry = Game.bestiaryEntry(id);
  const defeated = (entry?.defeatedCount ?? 0) > 0;

  return make('screen sheet', header(defeated ? enemy.name : '目撃情報') + `<div class="body">
    <div class="detail-art" style="background-image:url('${bgOf(enemy.chapter)}')">
      <img src="${artOf(enemy.asset)}" alt="" style="${defeated ? '' : 'filter:brightness(0) opacity(.4)'}">
    </div>

    ${defeated ? `
      <div class="stat-line">
        <div><div class="k">HP</div><div class="v">${enemy.hp}</div></div>
        <div><div class="k">ATK</div><div class="v">${enemy.atk}</div></div>
        <div><div class="k">DEF</div><div class="v">${enemy.def}</div></div>
      </div>
      <div class="panel">
        <span class="plate">記　述</span>
        <div class="body-text" style="margin-top:10px">${Master.flavor(enemy.id)}</div>
      </div>
      <div class="panel tight row between">
        <span class="caption">討伐数</span>
        <span class="num" style="font-size:16px">${entry.defeatedCount}</span>
      </div>
      <div class="panel tight row between">
        <span class="caption">初めて見た日</span>
        <span class="num" style="font-size:16px">${entry.firstSeenDay ?? '—'} 日目</span>
      </div>`
    : `<div class="panel">
        <div class="body-text">道標に、この個体を見たという記録が残っていた。まだ姿を正しく捉えていない。</div>
        <div class="caption" style="margin-top:8px">討伐すると、姿と数値が図鑑に載る。</div>
      </div>`}
  </div>`);
}

/* ------------------------------------------------------------------ */
/* 地域                                                                */
/* ------------------------------------------------------------------ */

function regionScreen() {
  const cards = [1, 2, 3].map((chapter) => {
    const region = Master.region(chapter);
    const isOpen = Game.player.cumulativeSteps >= Master.chapterGate(chapter);
    const vitality = Game.vitality(chapter);
    const entries = LORE.filter((l) => l.chapter === chapter);
    const unlocked = entries.filter((l) => Game.state.unlockedLore.includes(l.id));

    return `<div class="panel region-card">
      <div class="region-head ${isOpen ? '' : 'locked'}" style="background-image:url('${bgOf(chapter)}')">
        <div class="rname">${isOpen ? '' : icon('lock', 13)}${isOpen ? region.name : '？？？'}</div>
      </div>
      <div class="region-body">
        ${isOpen ? `
          <div class="stack">
            <div class="row between">
              <span class="plate">活　気</span>
              <span class="num" style="color:var(--vigor);font-size:17px">${vitality} <span style="font-size:12px;color:var(--text-soft)">/ ${Balance.vitalityMax}</span></span>
            </div>
            <div class="meter vigor" data-vit="${vitality / Balance.vitalityMax}"><i style="width:0"></i></div>
            <div class="caption">${vitality >= Balance.vitalityMax
              ? 'この地域は活気を取り戻した。'
              : 'ダルモンを討伐するほど、街に人の気配が戻る。'}</div>
          </div>
          <div class="stack">
            <div class="row between">
              <span class="plate">世界の記述</span>
              <span class="caption num">${unlocked.length} / ${entries.length}</span>
            </div>
            <!-- 未読は伏せる。本文を出すと歩いて引き当てる動機が消える。
                 「まだ読めない」と書く代わりに、**読めない紙面そのもの**を見せる。 -->
            <div class="scripture">
              ${entries.map((l) => Game.state.unlockedLore.includes(l.id)
                ? `<p>${l.text}</p>`
                : '<p class="veiled"><i></i><i></i></p>').join('')}
            </div>
          </div>`
        : `<div class="caption row" style="gap:6px">${icon('lock', 13)}${fmt(Master.chapterGate(chapter))} 歩で解放</div>`}
      </div>
    </div>`;
  }).join('');

  const el = make('screen sheet', header('地域') + `<div class="body">${cards}</div>`);
  $$(el, '[data-vit]').forEach((m) => growMeter(m, Number(m.dataset.vit)));
  el._build = regionScreen;
  return el;
}

/* ------------------------------------------------------------------ */
/* 道標・活力パス                                                      */
/* ------------------------------------------------------------------ */

/** 道標の開封結果。
 *
 * **拾った物と読み物を分ける。** 24個の findings を1件1カードで積むと、
 * それは通知の一覧であって、歩いて拾い集めた実感にならない。
 * 物は絵札を並べ、記述は本文として組む。 */
function milestoneScreen(finds) {
  const lore = finds.filter((f) => f.kind === 'lore');
  const things = new Map();
  for (const f of finds.filter((f) => f.kind !== 'lore')) {
    const key = f.title;
    const glyph = { sighting: 'eye', consumable: 'charm', shard: 'diamond' }[f.kind];
    things.set(key, { glyph, count: (things.get(key)?.count ?? 0) + 1 });
  }

  const tokens = [...things].map(([title, t]) => `<div class="loot hidden">
    ${icon(t.glyph, 26)}<span class="lnum">×${t.count}</span><span class="lname">${title}</span>
  </div>`).join('');

  const el = make('screen sheet', header(`道標 ${finds.length}`) + `<div class="body">
    ${tokens ? `<div class="stack">
      <span class="plate" style="align-self:flex-start">拾ったもの</span>
      <div class="loot-grid">${tokens}</div>
    </div>` : ''}

    ${lore.length ? `<div class="stack">
      <span class="plate" style="align-self:flex-start">世界の記述 ${lore.length} 篇</span>
      <div class="scripture">
        ${lore.map((l) => `<p class="hidden">${l.text}</p>`).join('')}
      </div>
    </div>` : ''}
  </div>`);

  // 物 → 記述 の順に置いていく。まとめて出すと何を拾ったか読み飛ばされる。
  const revealed = [...$$(el, '.loot'), ...$$(el, '.scripture p')];
  revealed.forEach((node, i) => setTimeout(() => {
    node.classList.remove('hidden');
    node.classList.add('show');
  }, 140 + i * 110));
  return el;
}

function passScreen() {
  const on = Game.state.hasPass;
  const el = make('screen sheet', header('活力パス') + `<div class="body">
    <div class="panel pass-hero">
      ${icon('sparkle', 46)}
      <div style="font-size:18px;font-weight:800">活力パス</div>
      <div class="caption">ダルモン討伐の報酬が増え、復興が早く進む月額パス。</div>
      <div class="pass-price">¥480<span style="font-size:14px"> / 月</span></div>
    </div>
    <div class="panel stack">
      <span class="plate">できること</span>
      <div class="row" style="gap:8px">${icon('cube', 16)}<span class="body-text">素材（澱・核）が 1.5倍</span></div>
      <div class="row" style="gap:8px">${icon('sparkle', 16)}<span class="body-text">地域の活気が 1.5倍</span></div>
      <div class="caption">歩数・EXP・活力（AP）には影響しません。歩いた分だけ進むという前提は変えない。</div>
    </div>
    <button class="btn" data-act="toggle-pass">${on ? 'パスを解除する（試用）' : 'パスを有効にする（試用）'}</button>
    <div class="caption" style="text-align:center">ブラウザ版では課金は行われません。効果の確認用です。</div>
  </div>`);

  $(el, '[data-act="toggle-pass"]').addEventListener('click', () => {
    Game.state.hasPass = !Game.state.hasPass;
    Game.save();
    Nav.refresh();
  });
  el._build = passScreen;
  return el;
}

/** 短い通知。alert を使わない（OS の顔が出た瞬間にゲームでなくなる）。 */
function toast(message) {
  const t = make('toast', message);
  Object.assign(t.style, {
    position: 'absolute', left: '20px', right: '20px', bottom: '90px', zIndex: 95,
    background: 'var(--card)', border: '2px solid var(--ink)', borderRadius: '14px',
    padding: '12px 14px', fontSize: '13px', fontWeight: '700', textAlign: 'center',
    boxShadow: '0 3px 0 rgba(46,42,56,.5)',
  });
  frame.appendChild(t);
  setTimeout(() => t.remove(), 2200);
}

/* ------------------------------------------------------------------ */
/* 配線                                                                */
/* ------------------------------------------------------------------ */

frame.addEventListener('click', (event) => {
  const target = event.target.closest('[data-act]');
  if (!target) return;
  switch (target.dataset.act) {
    case 'back': Nav.pop(); break;
    case 'close-result': Nav.pop(); break;
    case 'map': Nav.push(mapScreen()); break;
    case 'equip': Nav.push(equipScreen()); break;
    case 'bestiary': Nav.push(bestiaryScreen()); break;
    case 'region': Nav.push(regionScreen()); break;
    case 'pass': Nav.push(passScreen()); break;
    case 'milestones': Nav.push(milestoneScreen(Game.openMilestones())); break;
  }
});

/* 開発用トレイ。歩数はブラウザに存在しないので手で入れる。 */
function bindTray() {
  const tray = document.getElementById('tray');
  $$(tray, '[data-walk]').forEach((b) => b.addEventListener('click', () => {
    Game.walk(Number(b.dataset.walk));
    renderHome();
    updateTray();
  }));
  $(tray, '[data-act="next-day"]').addEventListener('click', () => { Game.nextDay(); renderHome(); updateTray(); });
  $(tray, '[data-act="reset"]').addEventListener('click', () => {
    if (confirm('進行状況を消して最初から始めますか？')) { Game.reset(); renderHome(); updateTray(); }
  });
  $(tray, '[data-act="fold"]').addEventListener('click', () => tray.classList.toggle('folded'));
}

function updateTray() {
  const p = Game.player;
  document.getElementById('tray-state').textContent =
    `day ${p.day} / 本日 ${fmt(p.todayCreditedSteps)} 歩（上限 ${fmt(Balance.dailyStepCap)}） / 累計 ${fmt(p.cumulativeSteps)} / AP ${p.ap} / Lv ${Game.level}`;
}

Game.load();
renderHome();
bindTray();
updateTray();
