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
  /* 武器は靴。剣や杖を記号にすると、歩いた力だけが武器という筋がここで切れる。
     **厚い靴底を独立した形で持たせる。** 靴の輪郭だけだと 16px では鞄に見える。 */
  shoe: 'M5.2 16.2V9.1a2.2 2.2 0 0 1 2.2-2.2h2.1c.6 0 1.1.4 1.3.9l1.1 2.9 5.9 2.3a3.4 3.4 0 0 1 2.2 3.2zM2.6 16.2h18.8a1.7 1.7 0 0 1 0 3.4H2.6a1.7 1.7 0 0 1 0-3.4z',
  /* 外套。襟の V を穴で抜くと、肩から吊るした布に見える。 */
  cloak: 'M12 2.3 7.9 4.1 3.4 7.6l2.4 3.1L4.9 21.7h14.2l-.9-11 2.4-3.1-4.5-3.5zM12 5.1 9.9 6.7 12 10.3 14.1 6.7z',
  /* 護符。お札の形にして帯を2本抜く。星にすると「良いもの」一般の記号になる。 */
  charm: 'M8.6 1.8h6.8l1.5 2.6v15.2a2.6 2.6 0 0 1-2.6 2.6H9.7a2.6 2.6 0 0 1-2.6-2.6V4.4zM9.9 8.2h4.2v1.7H9.9zM9.9 12.4h4.2v1.7H9.9z',
  /* 本。栞を穴で抜く。閉じた本＋栞で「読み物」だと分かる。 */
  book: 'M6.2 1.9h11.6c.7 0 1.2.5 1.2 1.2v17.8c0 .7-.5 1.2-1.2 1.2H6.2A2.4 2.4 0 0 1 3.8 19.7V4.3a2.4 2.4 0 0 1 2.4-2.4zM9.6 1.9h3.3v8L11.2 8.5 9.6 9.9z',
  eye: 'M12 5c5.2 0 9 4.6 9 7s-3.8 7-9 7-9-4.6-9-7 3.8-7 9-7zm0 3.5A3.5 3.5 0 1 0 12 15.5 3.5 3.5 0 0 0 12 8.5z',
  /* 道標。柱と板は重なるので nonzero の和集合で描く（EVENODD に入れない）。
     板を2枚にすると「どちらへ行くか」の記号になり、1枚より道標らしい。 */
  post: 'M11 2.1h2v19.8h-2zM4.1 4.3h12.7l2.7 2.9-2.7 2.9H4.1zM19.9 11.9H7.2l-2.7 2.9 2.7 2.9h12.7z',
  /* 地図。折り目を2本抜いて「折り畳んだ紙」にする。 */
  map: 'M9 2.1 3 4.4v17.4l6-2.3 6 2.3 6-2.3V2.1l-6 2.3zM8.3 4.4h1.3v14.9H8.3zM14.4 5.4h1.3v14.9h-1.3z',
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

/** 内側を「穴」として抜く記号。
 *
 * 副パスを別々の `<path>` に分けると、穴のつもりの形が塗り潰されて出てくる
 * （外套の襟、お札の帯、本の栞、地図の折り目）。1本のパスにまとめ、
 * `fill-rule="evenodd"` で内側を抜く。
 *
 * **重なり合う副パスを持つ記号（道標の柱と板）はここに入れない。**
 * evenodd だと重なった部分が穴になる。既定の nonzero なら和集合になる。 */
const EVENODD = new Set(['cloak', 'charm', 'book', 'map', 'eye', 'lock']);

/** 記号。色は継承させ、置いた場所の文字色に従わせる。 */
function icon(name, size = 16) {
  const rule = EVENODD.has(name) ? ' fill-rule="evenodd"' : '';
  return `<svg class="glyph" viewBox="0 0 24 24" width="${size}" height="${size}" fill="currentColor" aria-hidden="true">`
    + `<path${rule} d="${ICONS[name]}"/>`
    + '</svg>';
}

/* ------------------------------------------------------------------ */
/* 道具                                                                */
/* ------------------------------------------------------------------ */

const fmt = (n) => n.toLocaleString('ja-JP');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const $ = (root, sel) => root.querySelector(sel);
const $$ = (root, sel) => [...root.querySelectorAll(sel)];

/** 文字送り。
 *
 * **読み物は、置くのではなく送る。** 完成した文章を一度に出すと、
 * 目に入った瞬間に「読むか読まないか」を選ばれてしまう。1文字ずつ出れば読み始めている。
 * 句読点で息を置くと、朗読の間になる。
 *
 * 途中で止められること（`stop`）が要件。**待たされる読み物は二度と開かれない。** */
function typeInto(el, text, { speed = 32 } = {}) {
  let index = 0;
  let timer = null;
  let finish;
  el.textContent = '';

  const done = new Promise((resolve) => { finish = resolve; });

  const tick = () => {
    el.textContent = text.slice(0, ++index);
    if (index % 3 === 0) Sound.play('type');
    if (index >= text.length) { finish(); return; }
    // 句読点の後だけ長く置く。均等に送ると機械の出力に見える。
    const ch = text[index - 1];
    timer = setTimeout(tick, '、，'.includes(ch) ? speed * 6 : '。！？'.includes(ch) ? speed * 10 : speed);
  };
  tick();

  // **止めた時も必ず解決させる。** ここを忘れると、送りを飛ばした後の続きが永久に来ない。
  done.stop = () => { clearTimeout(timer); el.textContent = text; finish(); };
  return done;
}

/** 変わった数を、変わったと分かるように置き換える。
 *
 * **黙って差し替えない。** 装備を替えて ATK が 47 から 53 になったとき、
 * 数字だけ入れ替わると「変えた甲斐」がどこにも残らない。
 * 前の値から回し、増減を短く浮かせる。 */
function showChange(el, from, to) {
  if (from === to || !Number.isFinite(from)) { el.textContent = fmt(to); return; }

  const start = performance.now();
  const step = (now) => {
    const t = Math.min(1, (now - start) / 420);
    const eased = 1 - Math.pow(1 - t, 3);
    el.textContent = fmt(Math.round(from + (to - from) * eased));
    if (t < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);

  const diff = to - from;
  const bubble = document.createElement('span');
  bubble.className = `delta-pop ${diff > 0 ? 'up' : 'down'}`;
  bubble.textContent = `${diff > 0 ? '+' : ''}${diff}`;
  el.parentElement.appendChild(bubble);
  setTimeout(() => bubble.remove(), 900);
  Sound.play(diff > 0 ? 'gain' : 'tap');
}

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
    maybeShowDoor();
  },
  /** 今の階層を作り直す。**アニメーションは付けない**（同じ画面が開き直して見える）。 */
  rebuild(build) {
    const top = layers[layers.length - 1];
    if (!top) return;
    const fresh = build();
    fresh.classList.add('static');
    layers[layers.length - 1] = fresh;
    frame.replaceChild(fresh, top);
  },
  /** 下の階層を、それが自分で覚えている作り方で描き直す。 */
  refresh() {
    const top = layers[layers.length - 1];
    if (top && top._build) Nav.rebuild(top._build);
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

  /** 帯で切り替える。討伐へ入る時のように、場所が変わったと伝えたい所で使う。 */
  async wipeTo(build) {
    const w = document.getElementById('wipe');
    Sound.play('transition');
    w.classList.add('on');
    w.classList.remove('open');
    requestAnimationFrame(() => w.classList.add('close'));
    await sleep(290);
    build();
    await sleep(110);
    w.classList.remove('close');
    w.classList.add('open');
    await sleep(320);
    w.classList.remove('on', 'open');
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
/* 世界の層（生気）                                                     */
/* ------------------------------------------------------------------ */

/** 灯りの位置（%）。地域ごとに手で置く。
 *  絵の中の光源（自販機・窓・街灯）に大まかに合わせてあるが、
 *  **輪郭の無いにじみなので、多少ずれても「どこかに灯りがある」として読める。** */
const LAMP_SPOTS = {
  1: [[79, 55, 120], [17, 47, 90], [50, 46, 70]],
  2: [[13, 52, 110], [87, 50, 110], [50, 33, 80]],
  // 第3章は荒野。**灯りが点く場所が無い。** ここの復興は空が開くことで示すので、
  // 灯りを置くと、何も無い地面に光の玉が浮いているだけになる。
  3: [],
};

/** 遠景のダルモンを置く位置（%）。
 *
 * 中央は主人公が立つので空け、下端は暗く沈むので避ける（形が見えなくなる）。
 * **接地する個体は路面の高さに置く。** 空に浮かせると、絵の中の存在ではなく
 * 貼り付けた画像に見える。浮いていてよいのは各章2番目（浮遊型）だけ。 */
const DISTANT_SPOTS = [[11, 60, 52], [88, 50, 46], [31, 57, 34]];

/**
 * 世界の地の層をまとめて作る。ホームと討伐で共用する。
 *
 * @param life  0...1（活気 / 100）。この一つの値で、背景の復活・灯りの数・
 *              粒の色と速さ・遠景のダルモンの濃さが決まる。
 */
function worldLayers(chapter, life, { distant = 0 } = {}) {
  // **前に見せた状態から現在の状態へ動かす。**
  // 討伐から戻ったとき、いきなり明るい街が出ても「増えた」ことは伝わらない。
  // 前回の生気で描いてから今の値へ遷移させると、灯りが1つ増えるのが見える。
  const from = shownLife[chapter] ?? life;
  shownLife[chapter] = life;

  const lampOn = (i, value) => {
    // 段階的に点す。全部が同時に明るくなると照明のスイッチに見える。
    //
    // **絵そのものに灯りが描かれている以上、この層は光源ではなく「にじみ」。**
    // 同じ強さで重ねると、窓の灯りの上にもう一つ丸い光が乗って二重に見える。
    // 濃さを抑え、段階の合図としてだけ働かせる。
    const threshold = [0.12, 0.45, 0.75][i] ?? 0.9;
    const raw = value >= threshold ? Math.min(1, (value - threshold) / 0.25) : 0;
    return raw * (HAS_ALIVE_ART ? 0.45 : 1);
  };

  const lamps = (LAMP_SPOTS[chapter] ?? []).map(([x, y, size], i) => {
    return `<div class="lamp" data-on="${lampOn(i, life).toFixed(2)}"
      style="left:${x}%;top:${y}%;width:${size}px;height:${size}px;
      margin:${-size / 2}px 0 0 ${-size / 2}px;opacity:${lampOn(i, from).toFixed(2)};
      animation-delay:${i * 1.3}s"></div>`;
  }).join('');

  const ghosts = DISTANT_SPOTS.slice(0, 3).map(([x, y, size], i) => {
    const species = Master.species(chapter)[i];
    const gone = i >= distant;
    return `<img src="${artOf(species.id)}" alt="" class="${gone ? 'gone' : ''}"
      style="left:${x}%;top:${y}%;width:${size}px;margin:${-size / 2}px 0 0 ${-size / 2}px;
             animation-delay:${i * 0.9}s">`;
  }).join('');

  // 粒は活気で色と速さが変わる。止まった世界では灰色でほとんど動かない。
  const moteCount = 6 + Math.round(life * 12);
  const motes = [...Array(moteCount)].map((_, i) => {
    const dur = (16 - life * 7) + (i % 5) * 2;
    const tint = life > 0.4 ? 'rgba(226,180,134,.7)' : 'rgba(232,228,220,.45)';
    return `<div class="mote" style="left:${(i * 37) % 100}%;top:${45 + (i * 17) % 45}%;
      background:${tint};animation-duration:${dur}s;animation-delay:${-(i * 1.7)}s"></div>`;
  }).join('');

  return `
    <div class="world-bg" style="background-image:url('${bgOf(chapter)}')"></div>
    <div class="world-alive ${HAS_ALIVE_ART ? '' : 'faux'}" data-life="${life.toFixed(2)}"
         style="background-image:url('${HAS_ALIVE_ART ? bgAliveOf(chapter) : bgOf(chapter)}');opacity:${from.toFixed(2)}"></div>
    <div class="world-scrim"></div>
    <div class="lamps">${lamps}</div>
    <div class="distant">${ghosts}</div>
    <div class="motes">${motes}</div>`;
}

/** 前回この章を見せたときの生気。遷移の起点に使う（保存はしない）。 */
const shownLife = {};

/** 生気を目標値へ動かす。`worldLayers` を差し込んだ直後に1回呼ぶ。 */
function settleLife(root) {
  requestAnimationFrame(() => {
    const alive = $(root, '.world-alive');
    if (alive) alive.style.opacity = alive.dataset.life;
    $$(root, '.lamp').forEach((l) => { l.style.opacity = l.dataset.on; });
    const mark = $(root, '.life-mark i');
    if (mark) mark.style.width = `${Number(mark.dataset.life) * 100}%`;
  });
}

/* ------------------------------------------------------------------ */
/* ホーム                                                              */
/* ------------------------------------------------------------------ */

function renderHome() {
  const home = document.getElementById('home');
  const s = Game.state;
  const outcome = s.lastOutcome;
  const gate = Game.nextGate;
  const next = Game.nextNode;

  const chapter = Game.unlockedChapter;
  const region = Master.region(chapter);
  const cap = Balance.dailyStepCap;

  // 生気。活気ゲージがそのまま風景の状態になる。
  const life = Game.vitality(chapter) / Balance.vitalityMax;
  // まだ討伐していないダルモンが、この章にあと何体いるか（遠景に出す数）。
  const remaining = Math.max(0, Math.min(3, Master.nodesPerChapter - Game.progress(chapter).nodeIndex));

  home.className = 'screen world';
  home.innerHTML = `
    ${worldLayers(chapter, life, { distant: remaining })}

    ${s.pendingMilestones > 0 ? `
      <button class="marker" data-act="milestones" title="道標">
        ${itemArt('prop_signpost', 40)}
        <span class="bubble">${s.pendingMilestones}</span>
      </button>` : ''}

    <div class="world-inner">
      <div class="hud">
        ${crest(Game.level, Game.levelProgress)}
        <div class="grow"></div>
        <div class="pills">
          <span class="pill vigor">${icon('bolt', 13)}<span data-res="ap">${fmt(s.player.ap)}</span></span>
          <span class="pill">${icon('cube', 13)}<span data-res="dregs">${fmt(Game.dregs)}</span></span>
        </div>
      </div>

      <!-- 居場所を出す。アプリ名ではなく地名。RPG が画面上部に出すのと同じ扱い。 -->
      <div class="place">
        <div class="ch">第${chapter}章 ・ ${s.player.day} 日目</div>
        <div class="nm">${region.name}</div>
        <div class="life-mark" title="この地に戻った気配"><i data-life="${life}" style="width:0"></i></div>
      </div>

      <!-- **画面で一番広い面積を絵に渡す。** 主人公はここに立つ。 -->
      <div class="stage">
        <div class="ground"></div>
        <!-- 立っているのではなく、**歩いて来る。** この世界で唯一動いている存在なので、
             最初の一動作を「移動」にする。止まった絵で始めると背景と同類になる。 -->
        <img class="hero walk-in" src="${artOf('hero')}" alt="主人公">
      </div>

      ${targetRibbon(next, gate)}

      <div class="night stepbar">
        <span class="k">今日</span>
        <span class="v" data-count="${s.player.todayCreditedSteps}">0</span>
        <span class="cap">/ ${fmt(cap)}</span>
        <div class="meter" data-step="${s.player.todayCreditedSteps / cap}"><i style="width:0"></i></div>
        ${outcome && outcome.levelsGained > 0 ? '<span class="badge-up">Lv UP</span>' : ''}
      </div>

      <div class="dock">
        <button class="btn go" data-act="map" ${Game.canBattle ? '' : 'disabled'}>
          ${icon('map', 18)}${next ? '討伐に出る' : '周回して素材を集める'}
        </button>
        <div class="satellites">
          <button class="sat" data-act="equip">
            <span class="disc">${icon('shield', 22)}${Game.hasEquipWork ? '<span class="dot"></span>' : ''}</span>
            <span class="lb">装備</span>
          </button>
          <button class="sat" data-act="bestiary"><span class="disc">${icon('book', 22)}</span><span class="lb">図鑑</span></button>
          <button class="sat" data-act="region"><span class="disc">${icon('map', 22)}</span><span class="lb">地域</span></button>
          <button class="sat ${s.hasPass ? 'on' : ''}" data-act="pass"><span class="disc">${icon('sparkle', 22)}</span><span class="lb">パス</span></button>
        </div>
      </div>
    </div>`;

  // 数値は置いた瞬間から回す。「今日も無駄じゃなかった」は数字が動いて初めて伝わる。
  $$(home, '[data-count]').forEach((el) => countUp(el, Number(el.dataset.count)));
  $$(home, '[data-step]').forEach((m) => growMeter(m, Number(m.dataset.step)));
  $$(home, '[data-gate]').forEach((m) => growMeter(m, Number(m.dataset.gate)));
  // 位の環。0 から回す。
  const arc = $(home, '.crest .arc');
  const len = Number(arc.dataset.len);
  requestAnimationFrame(() => { arc.style.strokeDashoffset = len * (1 - Game.levelProgress); });

  // 生気（背景・灯り・気配の目盛り）を目標値へ動かす。
  settleLife(home);

  // **持ち物の増減を、持ち物の札の上で言う。**
  // 討伐から戻ったとき、澱の数が黙って差し替わると、何を持ち帰ったのか残らない。
  const res = { ap: s.player.ap, dregs: Game.dregs };
  $$(home, '[data-res]').forEach((v) => showChange(v, shownRes[v.dataset.res], res[v.dataset.res]));
  Object.assign(shownRes, res);

  // 歩いて入ってきたら、**立ち姿に持ち替えて**待機の揺れに移る。
  // 走っている絵のまま上下に揺れると、その場で駆け足しているように見える。
  const hero = $(home, '.hero');
  hero.addEventListener('animationend', () => {
    hero.classList.remove('walk-in');
    hero.src = artOf('hero_stand');
    hero.classList.add('bob');
  }, { once: true });

  // レベルが上がった日だけ鳴らす。毎回鳴らすと祝いの意味が消える。
  if (outcome && outcome.levelsGained > 0) setTimeout(() => Sound.play('levelup'), 450);

}

/** 新しい章に届いていたら扉絵を挟む。
 *
 * **タイトルより先に出さない。** 起動直後は必ずタイトルが最前面なので、
 * ここは「一番上の階層が無くなった時」——つまり戻ってきた時にだけ確かめる。 */
function maybeShowDoor() {
  const door = Game.pendingDoor;
  if (door !== null && layers.length === 0) Nav.push(chapterDoorScreen(door));
}

/** 位の紋。**数値を四角い札に入れない。** 丸い紋章に環のゲージが回ると「格」に見える。 */
function crest(level, progress) {
  const r = 33;
  const len = 2 * Math.PI * r;
  return `<div class="crest">
    <svg viewBox="0 0 74 74">
      <circle cx="37" cy="37" r="${r}" fill="none" stroke="rgba(10,9,13,.55)" stroke-width="6"/>
      <circle class="arc" cx="37" cy="37" r="${r}" fill="none" stroke="var(--vigor)" stroke-width="6"
              stroke-linecap="round" transform="rotate(-90 37 37)"
              stroke-dasharray="${len.toFixed(1)}" stroke-dashoffset="${len.toFixed(1)}" data-len="${len.toFixed(1)}"/>
    </svg>
    <div class="face"><span class="lv">LV</span><span class="no">${level}</span></div>
  </div>`;
}

/** 次の標的。**帯（リボン）で出す。** 四角い箱に入れると予定表に戻る。 */
function targetRibbon(next, gate) {
  if (next) {
    const node = Master.node(next.chapter, next.index);
    const affordable = Game.player.ap >= node.enemy.apCost;
    return `<button class="ribbon" data-act="map">
      <span class="face"><img src="${artOf(node.enemy.asset)}" alt=""></span>
      <span style="text-align:left">
        <span class="where" style="display:block">第${next.chapter}章 ・ ノード ${next.index}</span>
        <span class="who">${node.enemy.isBoss ? 'ボス：' : ''}${node.enemy.name}</span>
      </span>
      <span class="cost ${affordable ? '' : 'short'}">${icon('bolt', 14)}${node.enemy.apCost}</span>
    </button>`;
  }
  if (gate) {
    // 歩数ゲートに届いていない状態。**ここで「歩けば開く」ことを明示する。**
    return `<div class="ribbon" style="display:block;padding:10px 22px 10px 14px">
      <span class="where">次の地へ</span>
      <div class="who" style="margin:2px 0 7px">第${gate.chapter}章まで あと ${fmt(gate.remaining)} 歩</div>
      <div class="meter slim" data-gate="${gate.progress}" style="border-color:rgba(232,228,220,.7);background:rgba(255,255,255,.12)"><i style="width:0"></i></div>
    </div>`;
  }
  return `<div class="ribbon" style="padding:12px 22px 12px 14px">
    <span class="who">世界は動き出した</span>
  </div>`;
}

/* ------------------------------------------------------------------ */
/* タイトル                                                            */
/* ------------------------------------------------------------------ */

/** タイトル画面。
 *
 * ホームから題字を外した代わりに、**アプリの顔をここに置く。**
 * 一枚絵は生成したもの（文字は入っていない）。題字は組版で載せる——
 * 生成に文字を描かせると綴りも字形も崩れる。 */
function titleScreen() {
  const started = Game.player.cumulativeSteps > 0;

  const el = make('screen cover title', `
    <div class="title-art" style="background-image:url('${TITLE_ART}')"></div>
    <div class="title-veil"></div>
    <div class="title-inner">
      <div class="title-mark">
        <span class="tw">Walk</span><span class="tu">UP!</span>
      </div>
      <div class="title-sub">歩いた分だけ、世界が目を覚ます</div>
      <div class="grow"></div>
      <div class="title-hint">${started ? '触れて つづける' : '触れて はじめる'}</div>
    </div>`);

  el.addEventListener('click', () => {
    Sound.play('transition');
    Nav.pop();
  }, { once: true });

  return el;
}

/* ------------------------------------------------------------------ */
/* 章の扉                                                              */
/* ------------------------------------------------------------------ */

/** 章に入る瞬間に一度だけ出す扉絵。
 *
 * **章の解放を数字だけで伝えない。** 「第2章が解放されました」と札を出すのは
 * 進捗通知であって、新しい土地に着いたことではない。
 * その場所の絵と、世界の側の一行を置く。名前は木札に載せる。 */
function chapterDoorScreen(chapter) {
  const region = Master.region(chapter);

  const el = make('screen cover door', `
    <div class="door-inner">
      <div class="door-no">第 ${chapter} 章</div>
      <div class="door-plaque">
        <img src="${itemOf('prop_plaque')}" alt="">
        <span class="door-name">${region.name}</span>
      </div>
      <!-- **16:9 で描いた絵を縦画面に敷き詰めない。**
           cover で埋めると 2.4 倍に拡大され、小さく立たせた主人公が巨大になって
           構図が壊れる。画集の図版のように帯で見せる。 -->
      <div class="door-frame">
        <div class="door-art" style="background-image:url('${doorOf(chapter)}')"></div>
      </div>
      <p class="door-line"></p>
      <div class="door-hint">画面を触って進む</div>
    </div>`);

  // 一行は送る。扉で足を止めさせるのは、ここで読ませたいからで、
  // 読ませたい文章を一度に出すと読まれない。
  const line = $(el, '.door-line');
  let typing = null;
  setTimeout(() => { typing = typeInto(line, Master.doorLine(chapter), { speed: 46 }); }, 1100);

  el.addEventListener('click', () => {
    if (typing && line.textContent !== Master.doorLine(chapter)) { typing.stop(); return; }
    Game.markDoorSeen(chapter);
    Sound.play('page');
    Nav.pop();
  });

  Sound.play('transition');
  return el;
}

/* ------------------------------------------------------------------ */
/* 討伐マップ                                                          */
/* ------------------------------------------------------------------ */

/** 標の座標（%）。下から上へ蛇行させる。
 *
 * **等間隔の縦一列にしないこと。** 均等に並んだ点は目次であって地図ではない。
 * 手で置いた不規則な配置が「道」を作る。 */
const PIN_SPOTS = [
  [24, 90], [50, 82], [74, 73], [40, 63], [19, 53], [53, 44], [77, 34], [46, 20],
];

/** 討伐（画面 #2）。**紙の一覧をやめて地図にした。** 1画面に1章。 */
function mapScreen(chapter = Game.nextNode?.chapter ?? Game.unlockedChapter, selected = null) {
  const isOpen = Game.player.cumulativeSteps >= Master.chapterGate(chapter);
  const region = Master.region(chapter);
  const cleared = Game.progress(chapter).isCleared;
  const nextIndex = Game.nextNode?.chapter === chapter ? Game.nextNode.index : null;

  // 道。通った区間と未踏の区間で線を描き分ける。
  const done = Game.progress(chapter).nodeIndex;
  const path = (from, to) => PIN_SPOTS.slice(from, to).map(([x, y]) => `${x},${y}`).join(' ');

  const pins = PIN_SPOTS.map(([x, y], i) => {
    const index = i + 1;
    const node = Master.node(chapter, index);
    const isDone = Game.isNodeCleared(chapter, index);
    const unlocked = Game.isNodeUnlocked(chapter, index);
    return `<button class="pin ${isDone ? 'cleared' : ''} ${unlocked ? '' : 'locked'}
              ${node.enemy.isBoss ? 'boss' : ''} ${index === nextIndex ? 'next' : ''} ${index === selected ? 'sel' : ''}"
            style="left:${x}%; top:${y}%" data-pin="${index}" ${unlocked ? '' : 'disabled'}>
      ${unlocked ? `<img src="${artOf(node.enemy.asset)}" alt="">` : icon('lock', 18)}
      <span class="no">${index}</span>
      ${isDone ? `<span class="stamp">${icon('check', 11)}</span>` : ''}
    </button>`;
  }).join('');

  const life = Game.vitality(chapter) / Balance.vitalityMax;

  const el = make('screen world cover', `
    ${isOpen
      ? worldLayers(chapter, life, { distant: 0 })
      : `<!-- 未開放の地は色を抜くだけ。**暗くしすぎると何も見えず、行きたい気持ちが湧かない。** -->
         <div class="world-bg" style="background-image:url('${bgOf(chapter)}');filter:grayscale(1) brightness(.92)"></div>
         <div class="world-scrim"></div>`}

    <div class="world-inner">
      <div class="hud">
        <button class="round-button" data-act="back" style="background:rgba(18,16,24,.6);border-color:rgba(232,228,220,.8);color:#fff">${icon('back', 15)}</button>
        <div class="grow"></div>
        <span class="pill vigor">${icon('bolt', 13)}${fmt(Game.player.ap)}</span>
      </div>

      <div class="chapter-nav" style="margin-top:8px">
        <button class="arrow" data-chapter="${chapter - 1}" ${chapter > 1 ? '' : 'disabled'}>${icon('back', 14)}</button>
        <div class="place" style="flex:1">
          <div class="ch">第${chapter}章${cleared ? ' ・ 制圧' : ''}</div>
          <div class="nm">${isOpen ? region.name : '？？？'}</div>
        </div>
        <button class="arrow right" data-chapter="${chapter + 1}" ${chapter < 3 ? '' : 'disabled'}>${icon('back', 14)}</button>
      </div>

      ${isOpen ? `<div class="mapfield">
        <!-- 非等比の viewBox で引くので、線は non-scaling-stroke で太さを守る。
             これが無いと縦方向に引き伸ばされて、道が帯になる。 -->
        <svg viewBox="0 0 100 100" preserveAspectRatio="none">
          <polyline class="road-todo" vector-effect="non-scaling-stroke" points="${path(Math.max(0, done - 1), 8)}"/>
          ${done > 0 ? `<polyline class="road-done" vector-effect="non-scaling-stroke" points="${path(0, done)}"/>` : ''}
        </svg>
        ${pins}
      </div>` : '<div class="grow"></div>'}

      ${isOpen ? selectionPlate(chapter, selected) : `
        <div class="locked-note night" style="padding:18px">
          ${icon('lock', 26)}
          <div style="font-size:15px;font-weight:800;letter-spacing:.08em">この地はまだ閉じている</div>
          <div style="font-size:12px;opacity:.75">累計 ${fmt(Master.chapterGate(chapter))} 歩で道が開く（いま ${fmt(Game.player.cumulativeSteps)} 歩）</div>
          <div class="meter slim" data-gate="${Game.player.cumulativeSteps / Master.chapterGate(chapter)}"
               style="width:200px;margin-top:4px;border-color:rgba(232,228,220,.7);background:rgba(255,255,255,.12)"><i style="width:0"></i></div>
        </div>
        <div class="grow"></div>`}
    </div>`);

  // 標を選ぶ → 下の札が変わる。**選んでから挑む。** 押した瞬間に戦闘が始まると、
  // 誰と戦うのか分からないまま画面が変わる。
  $$(el, '[data-pin]').forEach((pin) => pin.addEventListener('click', () => {
    Nav.rebuild(() => mapScreen(chapter, Number(pin.dataset.pin)));
  }));
  $$(el, '[data-chapter]').forEach((btn) => btn.addEventListener('click', () => {
    Nav.rebuild(() => mapScreen(Number(btn.dataset.chapter)));
  }));
  const go = $(el, '[data-go]');
  if (go) go.addEventListener('click', () => startBattle(chapter, Number(go.dataset.go)));
  $$(el, '[data-gate]').forEach((m) => growMeter(m, Number(m.dataset.gate)));
  settleLife(el);

  el._build = () => mapScreen(chapter, selected);
  return el;
}

/** 地図の下端に出す、選んだ標の札。 */
function selectionPlate(chapter, selected) {
  if (!selected) {
    return `<div class="ribbon selection" style="padding:12px 22px 12px 14px;margin-bottom:14px">
      <span class="who" style="font-size:13px;opacity:.8">標を選ぶ</span>
    </div>`;
  }
  const node = Master.node(chapter, selected);
  const e = node.enemy;
  const affordable = Game.player.ap >= e.apCost;
  const isDone = Game.isNodeCleared(chapter, selected);

  return `<div class="selection" style="margin-bottom:14px">
    <div class="ribbon" style="margin-bottom:10px">
      <span class="face"><img src="${artOf(e.asset)}" alt=""></span>
      <span style="text-align:left">
        <span class="where" style="display:block">ノード ${selected}${isDone ? ' ・ 討伐済' : ''}${e.isBoss ? ' ・ ボス' : ''}</span>
        <span class="who">${e.name}</span>
        <span class="stats">
          <span>${icon('heart', 10)} ${e.hp}</span>
          <span>${icon('flame', 10)} ${e.atk}</span>
          <span>${icon('shield', 10)} ${e.def}</span>
        </span>
      </span>
      <span class="cost ${affordable ? '' : 'short'}">${icon('bolt', 14)}${e.apCost}</span>
    </div>
    ${node.equipment && !Game.state.equipment.some((x) => x.id === node.equipment.id)
      ? `<div class="row" style="gap:6px;color:#E2B486;font-size:11px;font-weight:800;justify-content:center;margin-bottom:10px">
           ${icon('shield', 12)}${node.equipment.name} を入手できる
         </div>` : ''}
    <button class="btn go" data-go="${selected}" ${affordable ? '' : 'disabled'}>
      ${affordable ? '挑む' : `活力が足りない（必要 ${e.apCost}）`}
    </button>
  </div>`;
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
    ${enemy.isBoss ? `<div class="boss-intro"><span class="bn">${enemy.name}</span></div>` : ''}

    <div class="inner">
      <div class="battle-tag" data-tag>第${session.chapter}章 ・ ノード ${session.nodeIndex}</div>
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
          <!-- 溶けた跡。撃破の後にここだけが残る。 -->
          <img class="puddle" src="${itemOf('prop_puddle')}" alt="">
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

  // ボスは名乗ってから始める。**雑魚と同じ入り方をすると、ボスがただの強い個体になる。**
  if (enemy.isBoss) {
    Sound.play('defeat');   // 低く落ちる音。歓迎ではなく、圧として鳴らす
    await sleep(1750);
    $(el, '.boss-intro')?.remove();
  }

  await sleep(320);

  const tag = $(el, '[data-tag]');
  const tagBase = tag.textContent;

  for (const [i, turn] of log.turns.entries()) {
    const isFinal = i === log.turns.length - 1;
    tag.textContent = `${tagBase} ・ ${turn.index}手目`;
    const attacker = turn.attacker === 'player' ? hero : foe;
    const target = turn.attacker === 'player' ? foe : hero;
    const hurtIsPlayer = target === hero;

    // 1. 踏み込み。**とどめだけ、踏み込む前に一拍置く。**
    //    速さが一定のままだと、決着の瞬間が他の手と同じ重さになる。
    if (isFinal) { attacker.classList.add('wind-up'); await sleep(260); attacker.classList.remove('wind-up'); }
    attacker.classList.add('lunge');
    Sound.play('step');
    await sleep(beat * 0.35);
    attacker.classList.remove('lunge');

    // 2. 命中。HP の減少・数値・煙・振動・音を同じ瞬間に集中させる。
    target.classList.add('recoil', 'flash');
    spawnDamage(target, turn.damage, hurtIsPlayer);
    spawnPuff(target);
    inner.classList.add(isFinal ? 'shake-strong' : hurtIsPlayer ? 'shake-strong' : 'shake-light');
    if (hurtIsPlayer) flash.style.opacity = '.22';
    if (isFinal) el.classList.add('impact');   // 画面全体を一瞬白く抜く
    Sound.play(hurtIsPlayer ? 'hurt' : 'hit');

    const ratio = turn.remaining / (hurtIsPlayer ? player.maxHP : enemy.hp);
    growMeter(hurtIsPlayer ? meters.playerMeter : meters.enemyMeter, ratio);
    $(el, hurtIsPlayer ? '[data-player-hp]' : '[data-enemy-hp]').textContent = turn.remaining;

    // 残りが少ないと計器が脈を打つ。**数字を読ませずに危うさを伝える。**
    const plate = (hurtIsPlayer ? meters.playerMeter : meters.enemyMeter).closest('.gauge-plate');
    plate.classList.toggle('critical', ratio > 0 && ratio < 0.3);

    // **止める時間を、とどめだけ倍にする。** 手応えは動かす量ではなく止める長さで出る。
    await sleep(isFinal ? beat * 0.7 : beat * 0.28);

    // 3. 戻す。
    target.classList.remove('recoil', 'flash');
    inner.classList.remove('shake-strong', 'shake-light');
    el.classList.remove('impact');
    flash.style.opacity = '0';
    await sleep(beat * 0.37);
  }

  if (log.result === 'victory') {
    foe.classList.add('melted');
    $(foe, 'img').classList.remove('bob');
    Sound.play('melt');
    await sleep(750);
  } else {
    flash.style.opacity = '.35';
    Sound.play('defeat');
    await sleep(450);
    flash.style.opacity = '0';
  }

  Nav.replaceTop(resultScreen(session));
}

function spawnDamage(target, amount, onPlayer) {
  const n = document.createElement('div');
  n.className = `dmg ${onPlayer ? 'on-player' : ''}`;
  n.textContent = amount;
  target.appendChild(n);
  setTimeout(() => n.remove(), 620);
}

/** 命中の跡。斬撃ではなく土煙と靴底で見せる（武器は靴なので）。 */
function spawnPuff(target) {
  const puff = document.createElement('div');
  puff.className = 'puff';
  // 靴底の跡は描いた絵を置く。CSS の角丸矩形では「厚底の溝」まで出せない。
  let html = `<img class="sole" src="${itemOf('prop_footprint')}" alt="">`;
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
  // 拾った物は絵、活気は概念なので記号のまま。
  const rows = [];
  if (r.dregs > 0) rows.push([itemArt('mat_dregs', 38), '怠惰の澱', `×${r.dregs}`]);
  if (r.cores > 0) rows.push([itemArt('mat_core', 38), '怠惰の核', `×${r.cores}`]);
  if (r.vitality > 0) rows.push([icon('sparkle', 30), '地域の活気', `+${r.vitality}`]);
  if (r.equipment) rows.push([itemArt(r.equipment.id, 38), r.equipment.name, '入手']);

  const turnCount = Math.ceil(session.log.turns.length / 2);

  // **紙に戻さない。** 戦った場所の上で締める。beige の紙面に切り替えると、
  // 戦闘の熱が切れて領収書を見せられたようになる。
  const el = make('screen world cover result', `
    <div class="world-bg" style="background-image:url('${bgOf(session.chapter)}')"></div>
    <div class="world-scrim" style="background:linear-gradient(to bottom, rgba(10,9,13,.86), rgba(10,9,13,.7) 45%, rgba(10,9,13,.92))"></div>

    <div class="world-inner" style="justify-content:center;gap:14px">
      <div class="result-seal ${won ? '' : 'lost'}">${icon(won ? 'check' : 'zzz', 44)}</div>
      <div class="result-title white">${won ? '討伐した' : '撤退した'}</div>
      <div class="white" style="text-align:center;font-size:11px;letter-spacing:.1em;opacity:.75">
        第${session.chapter}章 ノード${session.nodeIndex} ・ ${session.enemy.name} ・ ${turnCount} ターン
      </div>

      <div class="row" style="justify-content:center;margin-top:6px">
        <span class="plate night">${won ? '獲　得' : '持ち帰った分'}</span>
      </div>
      ${rows.length === 0 ? '<div class="white" style="text-align:center;font-size:12px;opacity:.7">何も持ち帰れなかった</div>' : ''}
      <div class="loot-grid">
        ${rows.map(([art, title, amount]) => `<div class="loot hidden">
          ${art}
          <span class="lnum">${amount}</span>
          <span class="lname">${title}</span>
        </div>`).join('')}
      </div>
      ${Game.state.hasPass && won ? `<div class="white row" style="gap:5px;font-size:11px;justify-content:center;color:#E2B486">${icon('sparkle', 12)}活力パスにより素材と活気が 1.5倍</div>` : ''}

      ${!won ? `<div class="night" style="padding:14px;background:rgba(120,50,50,.5);margin-top:4px">
        <div class="white" style="font-weight:800;font-size:14px;margin-bottom:6px">装備を整えれば勝てる</div>
        <div class="white" style="font-size:11px;line-height:1.7;opacity:.85">消費した活力は戻りません。ですが素材は残りました。装備を強化してから、もう一度挑んでください。</div>
      </div>` : ''}

      <div class="grow" style="max-height:24px"></div>
      ${!won ? `<button class="btn secondary" data-act="equip" style="margin-bottom:10px">${icon('hammer', 15)}装備を強化する</button>` : ''}
      <button class="btn go" data-act="close-result">${won ? '地図へ戻る' : '出直す'}</button>
    </div>`);

  // 判子 → 獲得物の順に鳴らす。**1枚ずつ順に出す。**
  // まとめて出すと、何を得たのかが読み飛ばされる。
  setTimeout(() => Sound.play('stamp'), 60);
  $$(el, '.loot').forEach((card, i) => setTimeout(() => {
    card.classList.remove('hidden');
    card.classList.add('show');
    Sound.play('gain');
  }, 320 + i * 140));

  return el;
}

/* ------------------------------------------------------------------ */
/* 装備・強化                                                          */
/* ------------------------------------------------------------------ */

const SLOT_GLYPH = { weapon: 'shoe', armor: 'cloak', accessory: 'charm' };
const SLOT_NAME = { weapon: '靴', armor: '外套', accessory: '護符' };

/** 持ち物の絵札。`<img>` を枠いっぱいに置く。
 *  絵が無い物（まだ生成していない物）は記号で代替し、**画面が壊れないようにする。** */
const itemArt = (id, size) => `<img class="item-art" src="${itemOf(id)}" alt="" style="width:${size}px;height:${size}px">`;

/** 素材・携行品の絵の名前。engine 側の ID と対応させる。 */
const MATERIAL_ART = { dregs: 'mat_dregs', core: 'mat_core', core_shard: 'mat_shard', salve: 'item_salve' };
/** 枠を体のどこに置くか（%）。**靴は足元に置く。**
 *  手元に置いた時点で「振るうのは足」という §1.1 の筋と噛み合わなくなる。 */
const SLOT_POS = { armor: [15, 30], accessory: [85, 30], weapon: [50, 84] };

/** 装備・強化（画面 #4）。**§4.1 のとおり、ここがこの作品で唯一の意思決定。** */
function equipScreen(slot = 'weapon') {
  const f = Game.fighter;
  const items = Game.state.equipment.filter((e) => e.slot === slot);

  const slots = ['armor', 'accessory', 'weapon'].map((s) => {
    const worn = Game.state.equipment.find((e) => e.slot === s && e.isEquipped);
    const [x, y] = SLOT_POS[s];
    // 着けている物はその物の絵、空きは記号の影。**絵と記号を役割で分ける。**
    return `<button class="slot ${worn ? '' : 'empty'} ${s === slot ? 'sel' : ''}"
              style="left:${x}%;top:${y}%" data-slot="${s}">
      ${worn ? itemArt(worn.id, 46) : icon(SLOT_GLYPH[s], 30)}
      ${worn && worn.enhanceLevel > 0 ? `<span class="lv">+${worn.enhanceLevel}</span>` : ''}
      <span class="tag">${SLOT_NAME[s]}</span>
    </button>`;
  }).join('');

  const el = make('screen sheet', header('装備・強化', counter('cube', Game.dregs)) + `<div class="body">
    <div class="doll">
      <div class="floor"></div>
      <!-- 人形は**立ち姿**を使う。走っている絵を置くと、装備を見ている場面と噛み合わない。 -->
      <img class="figure" src="${artOf('hero_stand')}" alt="主人公">
      ${slots}
    </div>

    <div class="tile-row">
      <div class="tile"><span class="k">${icon('heart', 11)}HP</span><span class="v" data-stat="hp">${f.maxHP}</span></div>
      <div class="tile vigor"><span class="k">${icon('flame', 11)}ATK</span><span class="v" data-stat="atk">${f.atk}</span></div>
      <div class="tile accent"><span class="k">${icon('shield', 11)}DEF</span><span class="v" data-stat="def">${f.def}</span></div>
    </div>

    <div class="panel">
      <span class="plate">${SLOT_NAME[slot]}</span>
      ${slot === 'weapon'
        ? '<div class="caption" style="margin-top:6px">この世界で武器になるのは踏み出す力——ウォーク力だけ。</div>'
        : ''}
      ${items.length === 0
        ? `<div class="caption" style="margin-top:10px">まだ持っていない。各章のノード 2・4・6 を討伐すると手に入る。</div>`
        : `<div style="margin-top:6px">${items.map((i) => gearRow(i, slot)).join('')}</div>`}
    </div>
  </div>`);

  // 枠を選ぶと、下の一覧がその枠の話に変わる。
  $$(el, '[data-slot]').forEach((b) => b.addEventListener('click', () => {
    Sound.play('tap');
    Nav.rebuild(() => equipScreen(b.dataset.slot));
  }));
  // 着脱と強化はその場で数字に反映する。**シートは開き直さない。**
  // 自動戦闘なので、ここで手応えを返せないと唯一の意思決定が空虚になる。
  $$(el, '[data-equip]').forEach((b) => b.addEventListener('click', () => {
    Game.toggleEquip(b.dataset.equip);
    Nav.rebuild(() => equipScreen(slot));
  }));
  $$(el, '[data-enhance]').forEach((b) => b.addEventListener('click', () => {
    if (Game.enhance(b.dataset.enhance)) {
      Sound.play('gain');
      Nav.rebuild(() => equipScreen(slot));
    }
  }));

  // **着け替えの結果を数字で返す。** 前に見せた値から回して、増減を浮かせる。
  const now = { hp: f.maxHP, atk: f.atk, def: f.def };
  $$(el, '[data-stat]').forEach((v) => {
    showChange(v, shownStats[v.dataset.stat], now[v.dataset.stat]);
  });
  Object.assign(shownStats, now);

  el._build = () => equipScreen(slot);
  return el;
}

/** 前に見せた実効値と持ち物。増減を出すために持つ（どちらも保存しない）。 */
const shownStats = {};
const shownRes = {};

/** 実効値の差。表示に使う分だけ。 */
function statDiff(after, before) {
  return { hp: after.hp - before.hp, atk: after.atk - before.atk, def: after.def - before.def };
}

const ZERO_STATS = { hp: 0, atk: 0, def: 0 };

/** 差分を「+9 ATK」の形に。**0 は書かない。** 変わらない値を並べると読む所が増えるだけ。 */
function diffText(d) {
  return [['HP', d.hp], ['ATK', d.atk], ['DEF', d.def]]
    .filter(([, v]) => v !== 0)
    .map(([k, v]) => `<span class="${v > 0 ? 'up' : 'down'}">${v > 0 ? '+' : ''}${v} ${k}</span>`)
    .join(' ');
}

function gearRow(item, slot) {
  const e = BattleEngine.effective(item);
  const cost = Balance.enhanceCost(item.enhanceLevel);
  const maxed = item.enhanceLevel >= Balance.maxEnhanceLevel;
  const stats = [
    e.hp > 0 ? `HP +${e.hp}` : null,
    e.atk > 0 ? `ATK +${e.atk}` : null,
    e.def > 0 ? `DEF +${e.def}` : null,
  ].filter(Boolean).join(' / ');

  // 「装備すると何がどう変わるか」。いま着けている物との差だけを出す。
  const worn = Game.state.equipment.find((x) => x.slot === slot && x.isEquipped);
  const swap = item.isEquipped ? null
    : diffText(statDiff(e, worn ? BattleEngine.effective(worn) : ZERO_STATS));

  // 「強化すると何が増えるか」。段階を上げた後の実効値との差。
  const nextGain = maxed ? null
    : diffText(statDiff(BattleEngine.effective({ ...item, enhanceLevel: item.enhanceLevel + 1 }), e));

  const short = !Game.canEnhance(item) && !maxed;

  return `<div class="gear ${item.isEquipped ? 'on' : ''}">
    <span class="face">${itemArt(item.id, 40)}</span>
    <div>
      <div class="name">${item.name}${item.enhanceLevel > 0 ? ` <b>+${item.enhanceLevel}</b>` : ''}</div>
      <div class="stat">${stats}</div>
      ${swap ? `<div class="delta">装備すると ${swap}</div>` : ''}
      ${nextGain ? `<div class="delta" style="opacity:.75">強化すると ${nextGain}</div>` : ''}
      <div class="pips">${[...Array(Balance.maxEnhanceLevel)].map((_, i) => `<i class="${i < item.enhanceLevel ? 'on' : ''}"></i>`).join('')}</div>
    </div>
    <div class="acts">
      <button class="chip ${item.isEquipped ? 'on' : ''}" data-equip="${item.id}">${item.isEquipped ? '装備中' : '装備'}</button>
      ${maxed
        ? '<span class="caption">最大</span>'
        : `<button class="chip ${short ? 'short' : ''}" data-enhance="${item.id}" ${short ? 'disabled' : ''}>
             ${icon('hammer', 12)}${short ? `あと ${cost - Game.dregs}` : cost}
           </button>`}
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
    // 目撃は「情報」なので記号、かけらと携行品は「物」なので絵。
    const art = f.kind === 'sighting' ? icon('eye', 28)
      : itemArt(MATERIAL_ART[f.kind === 'shard' ? 'core_shard' : 'salve'], 36);
    things.set(key, { art, count: (things.get(key)?.count ?? 0) + 1 });
  }

  const tokens = [...things].map(([title, t]) => `<div class="loot hidden">
    ${t.art}<span class="lnum">×${t.count}</span><span class="lname">${title}</span>
  </div>`).join('');

  const el = make('screen sheet', header(`道標 ${finds.length}`) + `<div class="body">
    ${tokens ? `<div class="stack">
      <span class="plate" style="align-self:flex-start">拾ったもの</span>
      <div class="loot-grid">${tokens}</div>
    </div>` : ''}

    ${lore.length ? `<div class="stack">
      <span class="plate" style="align-self:flex-start">世界の記述 ${lore.length} 篇</span>
      <div class="scripture">
        ${lore.map(() => '<p></p>').join('')}
      </div>
      <div class="skip-hint">画面を触ると最後まで送る</div>
    </div>` : ''}
  </div>`);

  // 拾った物を先に置く。
  $$(el, '.loot').forEach((node, i) => setTimeout(() => {
    node.classList.remove('hidden');
    node.classList.add('show');
    Sound.play('gain');
  }, 140 + i * 110));

  // 記述は**送る**。読み始めさせるための一手。
  const lines = $$(el, '.scripture p');
  let current = null;
  let skipped = false;

  (async () => {
    await sleep(200 + $$(el, '.loot').length * 110);
    for (let i = 0; i < lines.length; i++) {
      if (skipped) { lines[i].textContent = lore[i].text; continue; }
      current = typeInto(lines[i], lore[i].text);
      await current;
      await sleep(260);
    }
    $(el, '.skip-hint')?.remove();
  })();

  // 待たされる読み物は二度と開かれない。触れば全部出る。
  el.addEventListener('click', () => {
    if (skipped) return;
    skipped = true;
    current?.stop();
    lines.forEach((p, i) => { p.textContent = lore[i].text; });
    $(el, '.skip-hint')?.remove();
  });

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

// 触れた合図は**押した部品の側で**鳴らす。画面ごとに書くと必ず付け忘れる。
frame.addEventListener('pointerdown', (event) => {
  if (event.target.closest('.btn, .chip, .sat, .round-button, .arrow, .pin, .marker, .ribbon')) {
    Sound.play('tap');
  }
}, true);

frame.addEventListener('click', (event) => {
  const target = event.target.closest('[data-act]');
  if (!target) return;
  switch (target.dataset.act) {
    case 'back': Sound.play('page'); Nav.pop(); break;
    case 'close-result': Nav.pop(); break;
    case 'map': leaveForMap(); break;
    case 'equip': Sound.play('page'); Nav.push(equipScreen()); break;
    case 'bestiary': Sound.play('page'); Nav.push(bestiaryScreen()); break;
    case 'region': Sound.play('page'); Nav.push(regionScreen()); break;
    case 'pass': Sound.play('page'); Nav.push(passScreen()); break;
    case 'milestones': Sound.play('page'); Nav.push(milestoneScreen(Game.openMilestones())); break;
  }
});

/** 討伐へ出る。**主人公が歩き去ってから地図を開く。**
 *  その場で画面が差し替わると「画面遷移」だが、歩いて出て行くと「移動」になる。 */
async function leaveForMap() {
  const hero = $(document.getElementById('home'), '.hero');
  if (hero) {
    hero.classList.remove('bob', 'walk-in');
    hero.classList.add('walk-out');
    Sound.play('step');
    setTimeout(() => Sound.play('step'), 190);
    setTimeout(() => Sound.play('step'), 380);
    await sleep(520);
  }
  await Nav.wipeTo(() => Nav.push(mapScreen()));
}

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

  // 生気の変化を目で確かめるための操作。討伐しなくても街が戻る様子を見られる。
  $(tray, '[data-act="vitality"]').addEventListener('click', () => {
    const chapter = Game.unlockedChapter;
    const id = Master.region(chapter).id;
    let region = Game.state.regions.find((r) => r.regionId === id);
    if (!region) { region = { regionId: id, vitality: 0, isUnlocked: true }; Game.state.regions.push(region); }
    const before = region.vitality;
    region.vitality = Math.min(Balance.vitalityMax, region.vitality + 25);
    Game.save();
    renderHome();
    // 灯りの段階を越えた時だけ音を鳴らす。毎回鳴らすと段階の意味が消える。
    const steps = [12, 45, 75];
    if (steps.some((s) => before < s && region.vitality >= s)) setTimeout(() => Sound.play('light'), 700);
    updateTray();
  });

  $(tray, '[data-act="title"]').addEventListener('click', () => {
    while (layers.length) { const l = layers.pop(); l.remove(); }
    renderHome();
    Nav.push(titleScreen());
  });

  const soundButton = $(tray, '[data-act="sound"]');
  soundButton.addEventListener('click', () => {
    Sound.enabled = !Sound.enabled;
    soundButton.textContent = `音: ${Sound.enabled ? 'ON' : 'OFF'}`;
    if (Sound.enabled) Sound.play('tap');
  });
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

// **タイトルから始める。** ホームから題字を外したので、アプリの顔はここ。
// 触れば即座に抜けられる（毎回見せられる画面なので、足止めにしない）。
Nav.push(titleScreen());
