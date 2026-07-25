# ダルモン アートプロンプト仕様

Walk UP! のモンスター「ダルモン」を生成 AI（Codex の ImageGen）で量産するための仕様。

## 設計方針

品質より **シリーズとしての統一感** が課題。1体ずつは良くても、並べた瞬間にバラバラに見えるのが
生成 AI で最も起きやすい失敗。そこで以下の構造をとる。

```
[固定スタイルブロック]  ← 全アセットで1文字も変えない
       +
[個体ブロック]          ← モンスター固有の説明だけを差し替える
```

**固定ブロックを毎回書き直さないこと。** コピペで完全一致させる。ここが崩れると統一感が失われる。

プロンプトは **英語** で書く。画像生成モデルは英語のほうが指示の解像度が高く、
特に「flat shadow」「no gradients」のような描画スタイルの否定指定が効きやすい。

---

## 1. Codex への投げ方

以下をそのまま貼り付ける。3体まとめて依頼することで、モデル内で相互に基準が揃いやすくなる。

> 以下の仕様で、モンスターのイラストを3枚生成してください。
> STYLE SPEC は3枚すべてに完全に同一で適用し、CHARACTER の記述だけを差し替えてください。
> 3枚を並べたときに同じ画集から出てきたように見えることが最優先の要件です。
>
> （この下に「2. 固定スタイルブロック」と「3. 個体ブロック」を貼る）

---

## 2. 固定スタイルブロック（変更禁止）

```
STYLE SPEC (identical for every image in this set):

- One single creature, centered in a 1:1 square canvas, full body visible,
  facing the viewer at a slight three-quarter angle.
- Flat vector illustration. Bold, uniform dark outline of consistent weight.
- Exactly one flat shadow tone per color area. No gradients, no soft shading,
  no texture, no highlights, no glow, no rendering.
- Limited, desaturated, muted palette. Base hues in the grey-violet and dusty
  blue range. Exactly ONE warmer accent color per creature, used sparingly.
- Solid flat background, uniform color #E8E4DC. No shadow on the ground,
  no ground plane, no props, no environment.
- The creature occupies about 70% of the canvas height, centered,
  with even margins on all sides.
- No text, no logo, no signature, no watermark, no border, no frame.
- Mood: sluggish, drowsy, inert — a creature that drains motivation from the
  world. Not frightening, and not a cute mascot. Somewhere between pitiable
  and quietly unsettling.
```

---

## 3. 個体ブロック（3体）

シルエットが縦に垂れる／丸く浮く／横に広がる、と大きく異なるように設計している。
**シルエットだけで見分けられること**がモンスター図鑑の最低条件のため。

### ① ダラリ / Darari — 基本形・雑魚

```
CHARACTER: A slouching blob creature that has half-melted downward and pooled
into a puddle at its own base. Rounded, drooping shoulders it cannot hold up.
Two heavy-lidded eyes with pupils drifting in different directions. A small
mouth left hanging open. Two thin arms hanging straight down, dragging on the
floor. Accent color: dull mustard yellow on the underside of the puddle.
```

### ② ネムケ / Nemuke — 浮遊型

```
CHARACTER: A drifting jellyfish-like creature made of soft sagging folds,
floating just above the ground and tilted as if falling asleep in mid-air.
One enormous eye almost entirely covered by a heavy lid, with long drooping
lashes. Beneath it hang several limp ribbon-like tendrils of uneven length.
Accent color: pale sickly green at the tips of the tendrils.
```

### ③ ゴロネ / Gorone — 重量級

```
CHARACTER: A heavy four-legged creature lying flat on its side, too massive
and unmotivated to stand. A broad blunt head resting on the ground with a
slack jaw. Thick stubby legs folded uselessly, one paw limply raised in the
air. Loose folds of skin pooling on the ground around its body.
Accent color: faded brick red on the pads of its paws.
```

---

## 4. 生成後の後処理（全アセット一律）

生成のばらつきはここで吸収する。**最も費用対効果が高い工程なので省略しない。**

1. **キャンバスを 1024×1024 に統一**し、中央配置・余白比率を揃える
2. **背景色を #E8E4DC に塗り直して完全一致させる**（生成物は微妙にずれる）
3. **ポスタリゼーション（減色 8〜12 色）を全アセットに同一設定で適用**
4. 必要なら軽いドット化を全アセットに同一設定で適用

---

## 5. 3体を並べた時の判断基準

試作の目的は「絵の良し悪し」ではなく **量産できる方式かどうかの判定**。以下を確認する。

| 観点 | 合格条件 |
|---|---|
| シルエット | 塗りつぶしても3体を見分けられる |
| 明度 | 3体の明るさが揃っている（1体だけ浮かない） |
| 輪郭線 | 線の太さが3体で同じに見える |
| アクセント色 | 各体に1色だけ、面積も同程度 |
| 背景 | 完全に同一色（後処理前でも近い） |

**2つ以上落ちる場合はスタイルブロックの記述を修正する。**
個体ブロックをいじって直そうとしないこと。原因は固定側にある。

---

## 6. 今後の展開

MVP（3章構成）で必要な枚数は以下。試作が通ったら同じ方式で量産する。

| 種別 | 枚数 |
|---|---|
| ダルモン（雑魚） | 12〜15 |
| ボス | 3 |
| 地域背景 | 3 |
| 主人公＋装備差分 | 1 + 数枚 |
| UIアイコン | 約20 |

ボスは同じ STYLE SPEC を使いつつ、
`The creature occupies about 85% of the canvas height` に変更して威圧感を出す。
スタイル自体は変えない。
