/* Walk UP! ブラウザ版 — 音（試作）
 *
 * **音源ファイルを持たない。** すべて WebAudio で合成する。
 * 素材の購入も権利処理も要らず、鳴らしてみて要否を判断できる。
 * 本編（SwiftUI）で採用するなら、ここで決まった「長さ・高さ・減衰」を仕様として
 * 音源制作に渡す。合成のまま AVAudioEngine で作り直すこともできる。
 *
 * 設計方針は触覚と同じ（DESIGN.md ResultView のコメント）。
 * **強い音を1か所に集中させる。** すべてを鳴らすと、どれも意味を失う。
 *   踏み込み・命中 … 短く鈍い。世界の色と同じで、金属音や電子音にしない
 *   獲得          … ここだけ倍音を持たせる。手応えの本体
 *   撃破          … 下がって消える。倒したのではなく「溶けた」ので余韻を残す
 */

const Sound = {
  ctx: null,
  enabled: true,

  /** 最初の操作で初期化する。ブラウザは操作なしに音を出させない。 */
  unlock() {
    if (Sound.ctx || !Sound.enabled) return;
    try {
      Sound.ctx = new (window.AudioContext || window.webkitAudioContext)();
    } catch (_) { Sound.enabled = false; }
  },

  get now() { return Sound.ctx.currentTime; },

  /** 減衰する音。`type` は波形、`freq` は開始周波数、`to` を渡すと下がる。 */
  tone({ type = 'sine', freq = 440, to = null, dur = 0.12, gain = 0.15, delay = 0 }) {
    if (!Sound.ctx) return;
    const t = Sound.now + delay;
    const osc = Sound.ctx.createOscillator();
    const amp = Sound.ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    if (to) osc.frequency.exponentialRampToValueAtTime(to, t + dur);
    // 立ち上がりを 8ms 付ける。0 から一気に鳴らすとプチッと鳴る。
    amp.gain.setValueAtTime(0.0001, t);
    amp.gain.exponentialRampToValueAtTime(gain, t + 0.008);
    amp.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    osc.connect(amp).connect(Sound.ctx.destination);
    osc.start(t);
    osc.stop(t + dur + 0.02);
  },

  /** 雑音。足音・土煙・紙の音に使う。`cut` は低域通過の遮断周波数。 */
  noise({ dur = 0.09, gain = 0.12, cut = 1400, sweepTo = null, delay = 0 }) {
    if (!Sound.ctx) return;
    const t = Sound.now + delay;
    const frames = Math.max(1, Math.floor(Sound.ctx.sampleRate * dur));
    const buffer = Sound.ctx.createBuffer(1, frames, Sound.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < frames; i++) data[i] = Math.random() * 2 - 1;

    const src = Sound.ctx.createBufferSource();
    src.buffer = buffer;
    const filter = Sound.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(cut, t);
    if (sweepTo) filter.frequency.exponentialRampToValueAtTime(sweepTo, t + dur);
    const amp = Sound.ctx.createGain();
    amp.gain.setValueAtTime(gain, t);
    amp.gain.exponentialRampToValueAtTime(0.0001, t + dur);

    src.connect(filter).connect(amp).connect(Sound.ctx.destination);
    src.start(t);
  },

  play(name) {
    if (!Sound.enabled) return;
    Sound.unlock();
    if (!Sound.ctx) return;
    if (Sound.ctx.state === 'suspended') Sound.ctx.resume();

    switch (name) {
      // 画面を触った合図。**ここは限界まで小さく。** 押すたびに鳴るので、
      // 存在感を持たせると数分でうるさくなる。
      case 'tap':
        Sound.tone({ type: 'sine', freq: 620, dur: 0.05, gain: 0.05 });
        break;

      // 足音。土と砂利。金属音にしない（この世界に硬い物はあまり無い）。
      case 'step':
        Sound.noise({ dur: 0.11, gain: 0.13, cut: 900, sweepTo: 300 });
        Sound.tone({ type: 'sine', freq: 120, to: 70, dur: 0.09, gain: 0.09 });
        break;

      // 命中（こちらの攻撃）。踏み抜く音。
      case 'hit':
        Sound.noise({ dur: 0.13, gain: 0.16, cut: 1600, sweepTo: 400 });
        Sound.tone({ type: 'triangle', freq: 180, to: 90, dur: 0.12, gain: 0.13 });
        break;

      // 被弾。自分が受けた時だけ重くする。全部重くすると意味が薄れる。
      case 'hurt':
        Sound.noise({ dur: 0.2, gain: 0.2, cut: 900, sweepTo: 180 });
        Sound.tone({ type: 'sawtooth', freq: 150, to: 60, dur: 0.22, gain: 0.14 });
        break;

      // 撃破。溶け落ちる。下がりきって余韻を残す。
      case 'melt':
        Sound.tone({ type: 'sine', freq: 320, to: 70, dur: 0.75, gain: 0.14 });
        Sound.noise({ dur: 0.7, gain: 0.09, cut: 700, sweepTo: 120 });
        break;

      // 獲得。**ここだけ倍音を持たせる。** 手応えの本体。
      case 'gain':
        Sound.tone({ type: 'triangle', freq: 784, dur: 0.16, gain: 0.11 });
        Sound.tone({ type: 'sine', freq: 1175, dur: 0.2, gain: 0.06, delay: 0.05 });
        break;

      // 判子。押した瞬間の鈍い衝撃。
      case 'stamp':
        Sound.tone({ type: 'sine', freq: 160, to: 60, dur: 0.22, gain: 0.2 });
        Sound.noise({ dur: 0.07, gain: 0.14, cut: 2200 });
        break;

      // レベルが上がった日だけ。毎回鳴らすと祝いの意味が消える。
      case 'levelup':
        [523, 659, 784, 1046].forEach((f, i) =>
          Sound.tone({ type: 'triangle', freq: f, dur: 0.22, gain: 0.1, delay: i * 0.07 }));
        break;

      // 撤退。勝利の裏返しとして、上がらずに落ちる。
      case 'defeat':
        Sound.tone({ type: 'sawtooth', freq: 220, to: 82, dur: 0.6, gain: 0.12 });
        break;

      // 文字送り。**限界まで小さく。** 1文字ごとに鳴るので、聞こえるか聞こえないかでいい。
      case 'type':
        Sound.noise({ dur: 0.02, gain: 0.035, cut: 3000 });
        break;

      // 紙をめくる。帳面を開く時と、道標を読む時。
      case 'page':
        Sound.noise({ dur: 0.17, gain: 0.1, cut: 5000, sweepTo: 900 });
        break;

      // 場面が変わる。息を吸う音に近い掃引。
      case 'transition':
        Sound.noise({ dur: 0.42, gain: 0.11, cut: 300, sweepTo: 3000 });
        break;

      // 灯りが点く。活気が段階を越えた瞬間だけ。
      case 'light':
        Sound.tone({ type: 'sine', freq: 880, dur: 0.5, gain: 0.05 });
        Sound.tone({ type: 'sine', freq: 1320, dur: 0.6, gain: 0.03, delay: 0.06 });
        break;
    }
  },
};
