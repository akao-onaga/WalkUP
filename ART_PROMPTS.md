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
- Fully transparent background (alpha channel). No background color, no shadow
  on the ground, no ground plane, no props, no environment. The creature must be
  fully isolated with clean edges suitable for compositing.
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
2. **背景を完全に透過させる**（PNG のアルファチャンネル）。生成物には背景が
   残ることがあるため、必ず除去して縁のにじみも整える
3. **ポスタリゼーション（減色 8〜12 色）を全アセットに同一設定で適用**
4. 必要なら軽いドット化を全アセットに同一設定で適用

### 背景を透過にする理由（2026-07-26 確定）

当初は背景色 `#E8E4DC` を焼き込む仕様だったが、**透過に変更した**。

焼き込むと、ダークモードで暗い画面の中にモンスターの明るい四角が浮く。
本作は「夜に1セッション3分」（DESIGN.md §2）が前提なので、
ライトモード固定にすると夜のプレイで目が疲れる。

透過にすれば背景はアプリ側で敷けるため、**ライト/ダークの両方に対応でき、
さらに地域背景をモンスターの後ろに敷ける**。ゲームとしての見栄えも上がる。

代償は後処理に背景除去の工程が増えること。**量産を始める前に決めておく必要があった。**
12〜15体を焼き込みで作った後にこの判断をすると、全部作り直しになる。

---

## 5. 3体を並べた時の判断基準

試作の目的は「絵の良し悪し」ではなく **量産できる方式かどうかの判定**。以下を確認する。

| 観点 | 合格条件 |
|---|---|
| シルエット | 塗りつぶしても3体を見分けられる |
| 明度 | 3体の明るさが揃っている（1体だけ浮かない） |
| 輪郭線 | 線の太さが3体で同じに見える |
| アクセント色 | 各体に1色だけ、面積も同程度 |
| 背景 | 完全に透過している（縁にゴミが残っていない） |

**2つ以上落ちる場合はスタイルブロックの記述を修正する。**
個体ブロックをいじって直そうとしないこと。原因は固定側にある。

---

## 6. 今後の展開

MVP（3章構成）で必要な枚数は以下。試作が通ったら同じ方式で量産する。

| 種別 | 枚数 | 状態 |
|---|---|---|
| ダルモン（雑魚） | 12〜15 | 試作3体のみ |
| ボス | 3 | 未着手 |
| 地域背景 | 3 | 未着手 |
| 主人公＋装備差分 | 1 + 数枚 | 未着手 |
| UIアイコン | 約20 | 未着手 |
| **アプリアイコン** | **1**（1024px） | **暫定版あり・要差し替え** |

**アプリアイコンは当初この表から抜けていた。** App Store へのアップロードには必須で、
無いと検証で弾かれる。現在は場つなぎとして `#E8E4DC` と `#5F5B76` で
「Walk UP」＝昇る3本のバーを描いた幾何マークが入っている
（`WalkUP/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png`）。

制約が2つある。**背景を透過させないこと**（App Store が透過を許さない）。
**小サイズで潰れないこと**（ダルモンをそのまま縮小すると 60px で判別不能になる）。
このためダルモン本体ではなく、シルエットの強い記号にするのが妥当。

ボスは同じ STYLE SPEC を使いつつ、
`The creature occupies about 85% of the canvas height` に変更して威圧感を出す。
スタイル自体は変えない。
