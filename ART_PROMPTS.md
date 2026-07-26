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
  blue range.
- IMPORTANT — every creature in the set must share the same overall brightness.
  The body must read as a MID-DARK tone: clearly darker than a light background,
  never pale or washed out. Do not make any single creature lighter or airier
  than the others, even if its concept suggests weightlessness.
- Exactly ONE warm accent color per creature (amber, ochre, rust, brick, or
  apricot — never a cool color), covering roughly 3-6% of the creature's area.
  Used on one small body part only.
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
Accent color: sallow yellow-ochre at the tips of the tendrils.
```

### ③ ゴロネ / Gorone — 重量級

```
CHARACTER: A heavy four-legged creature lying flat on its side, too massive
and unmotivated to stand. Seen from the side, the body is HORIZONTAL and level,
with the head at the LEFT resting directly on the ground, slack jaw touching
the floor. The spine runs left to right across the image; do not tilt or rotate
the body. Thick stubby legs folded uselessly, one paw limply raised straight up.
Loose folds of skin pooling on the ground around its body.
Accent color: faded brick red on the pads of its paws.
```

---

## 3.5 量産用の全個体ブロック（2026-07-26）

§2 の STYLE SPEC は**1文字も変えずに**全ブロックへ適用する。差し替えるのは CHARACTER のみ。

### 投げ方

**章ごとに4体まとめて依頼する。** 1体ずつだと基準が揃わず、逆に12体まとめると
モデルが破綻する。同じ章の個体を並べて評価したいので、この単位が扱いやすい。

命名は既存3体に合わせ、**怠惰・眠気を表す日本語**から採っている。

---

### 第1章 — 日常に忍び込む怠惰

#### ① ダラリ / Darari — 標準（既存・要再生成）

```
CHARACTER: A slouching blob creature that has half-melted downward and pooled
into a puddle at its own base. Rounded, drooping shoulders it cannot hold up.
Two heavy-lidded eyes with pupils drifting in different directions. A small
mouth left hanging open. Two thin arms hanging straight down, dragging on the
floor. Accent color: dull mustard yellow on the underside of the puddle.
```

#### ② ネムケ / Nemuke — 手数（既存・要再生成）

```
CHARACTER: A drifting jellyfish-like creature made of soft sagging folds,
floating just above the ground and tilted as if falling asleep in mid-air.
One enormous eye almost entirely covered by a heavy lid, with long drooping
lashes. Beneath it hang several limp ribbon-like tendrils of uneven length.
Accent color: sallow yellow-ochre at the tips of the tendrils.
```

#### ③ ゴロネ / Gorone — 硬い（既存・要再生成）

```
CHARACTER: A heavy four-legged creature lying flat on its side, too massive
and unmotivated to stand. Seen from the side, the body is HORIZONTAL and level,
with the head at the LEFT resting directly on the ground, slack jaw touching
the floor. The spine runs left to right across the image; do not tilt or rotate
the body. Thick stubby legs folded uselessly, one paw limply raised straight up.
Loose folds of skin pooling on the ground around its body.
Accent color: faded brick red on the pads of its paws.
```

#### ④ アクビ / Akubi — 標準

```
CHARACTER: A tall thin creature bent forward at the waist, unable to hold its
spine straight, so its long neck droops down past its own knees. The head is
mostly one enormous open mouth caught mid-yawn, eyes squeezed shut by the
yawn. Two spindly arms dangle loosely, fingertips brushing the floor.
Accent color: dusty apricot inside the open mouth.
```

---

### 第2章 — 街に広がる停滞

#### ⑤ ウズクマリ / Uzukumari — 標準

```
CHARACTER: A rounded creature crouched into a tight ball with its knees pulled
up and its arms wrapped around them, refusing to unfold. Only the top half of
a face is visible above its own arms: two dull eyes staring at nothing. A
short blunt tail rests limply on the ground behind it.
Accent color: muted ochre on the soles of its bare feet.
```

#### ⑥ タダヨイ / Tadayoi — 手数

```
CHARACTER: A creature made of several loosely connected floating lumps that
drift apart from one another, held together only by thin sagging strands.
The largest lump carries a single half-closed eye. The lumps hover at
different heights, as if the creature cannot be bothered to hold itself
together. Accent color: pale seafoam where the strands meet the lumps.
```

#### ⑦ ネバリ / Nebari — 硬い

```
CHARACTER: A wide squat creature that has spread outward across the ground
like thick cooling wax, far broader than it is tall. Its surface sags in heavy
folds. A row of three small dull eyes sits low on the front of the mass. No
visible limbs; it simply oozes.
Accent color: dull amber along the leading edge where it has spread.
```

#### ⑧ モタレ / Motare — 手数

```
CHARACTER: A lanky creature leaning heavily to one side as if propped against
an invisible wall, one shoulder far lower than the other. Its head lolls onto
the raised shoulder. Two unequal arms hang slack, the longer one nearly
touching the ground. Its lower body tapers into a soft rounded base.
Accent color: faded rust at the tip of the lolling head.
```

---

### 第3章 — 世界の中心の澱み

#### ⑨ シズミ / Shizumi — 標準

```
CHARACTER: A heavy hunched creature that appears to be sinking into the ground,
its lower half already swallowed and blurred away. Broad rounded shoulders
carry a low-hanging head with two deep-set eyes. Its arms are folded across
itself, pressing downward as if helping itself sink.
Accent color: cold tarnished bronze around the sunken rim.
```

#### ⑩ カスミ / Kasumi — 手数

```
CHARACTER: A frayed, half-dissolved creature whose outline breaks apart into
drifting wisps at its edges. A vague humanoid core with one faint eye remains
recognizable at the center. Its lower body trails off into ragged floating
tatters instead of legs.
Accent color: dim lilac at the dissolving edges.
```

#### ⑪ オモリ / Omori — 硬い

```
CHARACTER: An enormously dense, compact creature shaped like a rounded weight,
so heavy it has pressed itself into the ground. Its short thick limbs are
splayed out under its own mass, unable to lift it. A single wide flat eye
spans the front of the body, half-lidded.
Accent color: deep oxidized copper along the pressure ring beneath it.
```

#### ⑫ ヌケガラ / Nukegara — 標準

```
CHARACTER: A hollow, empty-shelled creature standing upright but clearly
vacant, with a large ragged opening through its torso that you can see
through. Its posture is stiff and lifeless, arms hanging straight. The head
tilts back slightly, empty eye sockets facing upward.
Accent color: pale bone white around the rim of the hollow opening.
```

---

## 3.6 ボス（3体）

**STYLE SPEC のうち1行だけ差し替える。**

```
- The creature occupies about 85% of the canvas height, centered,
  with even margins on all sides.
```

これ以外は変えない。**スタイルを変えて威圧感を出そうとしないこと。** 大きさだけで足りる。

#### ボス① マドロミ / Madoromi — 第1章

```
CHARACTER: A vast sagging mass resembling a collapsed bed of flesh, wide and
low, with folds that invite something to lie down and never rise. Two enormous
half-lidded eyes sit far apart near the top. Along its lower edge, dozens of
short limp tendrils reach outward across the ground like grasping fingers that
have given up halfway.
Accent color: dull mustard yellow deep within the folds.
```

#### ボス② ムキリョク / Mukiryoku — 第2章

```
CHARACTER: A towering stooped figure whose head hangs so low it has sunk
below its own shoulders, leaving only a rounded hump where a head should be.
Its long arms reach the ground and pool there. The torso is riddled with
shallow hollow depressions, as if something was scooped out of it repeatedly.
Accent color: cold grey-green inside the hollows.
```

#### ボス③ ダルモン / Darumon — 第3章・本体

```
CHARACTER: An immense creature that is clearly the origin of all the others:
its body is composed of many smaller drooping shapes fused together, half-
melted into one another, some still bearing a single dull eye. At the center,
one very large heavy-lidded eye looks down at the viewer without interest.
Its lower mass spreads outward and downward without a clear boundary.
Accent color: a single warm ember orange at the very center of the large eye —
the only warm point in the entire image.
```

---

## 3.7 地域背景（3枚）

**創造物ではなく風景なので、STYLE SPEC は使わない。** 専用の仕様を使う。

```
STYLE SPEC (identical for every background in this set):

- A wide horizontal illustration, 16:9, of an empty outdoor place with no
  people and no creatures anywhere.
- Flat vector illustration. Bold uniform dark outline. Exactly one flat shadow
  tone per color area. No gradients, no soft shading, no texture, no glow.
- Limited, desaturated, muted palette in the grey-violet and dusty blue range,
  matching a companion set of creature illustrations.
- Slightly hazy, still, and abandoned in mood — a place where everyone stopped
  moving. Melancholy but not frightening.
- Composition must leave the CENTER of the image visually quiet and uncluttered,
  because character art will be placed on top of it.
- No text, no logo, no signature, no watermark, no border, no frame.
```

```
BACKGROUND 1: A small residential street at dusk. Shuttered shopfronts, a
stopped clock on a pole, unopened mail spilling from a postbox. Faint lit
vending machine on one side.
```

```
BACKGROUND 2: A shopping arcade with half its shutters down, a bicycle left
on its side, weeds pushing up through the pavement, faded banners hanging
motionless overhead.
```

```
BACKGROUND 3: A wide grey basin at the center of the world where the air
itself looks heavy. Cracked flat ground, distant collapsed structures, a low
oppressive sky.
```

---

## 3.8 主人公

```
CHARACTER: A small determined traveler seen from behind at a three-quarter
angle, mid-stride, one foot lifted in a clear walking pose. Simple hooded
travel cloak, a short staff in one hand, a satchel at the hip. The posture is
upright and forward-leaning — the only figure in this world that is still
moving. Face is not visible.
Accent color: warm amber on the inner lining of the hood.
```

**主人公だけは暖色のアクセントを使う。** ダルモンが全て寒色に沈んでいる中で、
唯一動いている存在であることを色で示す。

---

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

### 明度とアクセント面積は目視で判断しないこと

「1体だけ浮いている」は目で見ても分からない。実測する。

```bash
swiftc -O -o /tmp/artstats tools/artstats/main.swift
/tmp/artstats assets/processed/*.png
```

**合格条件: 平均明度の差が 15 以内、アクセント面積が 3〜6%。**

第1章の4体を実測したところ、ネムケだけ明度 127.3（他3体は 102〜109）で
1体だけ明るく、アクセント面積も 0.1% しかなかった。
後者は STYLE SPEC が「ONE warm accent color」と指定しているのに、
個体ブロックが `pale sickly green`（寒色）を指定していたという**仕様の矛盾**が原因。
どちらも目視では見落としていた。

---

## 6. 今後の展開

MVP（3章構成）で必要な枚数は以下。試作が通ったら同じ方式で量産する。

| 種別 | 枚数 | 状態 |
|---|---|---|
| ダルモン（雑魚） | 12 | プロンプト用意済み（§3.5）・既存3体は要再生成 |
| ボス | 3 | プロンプト用意済み（§3.6） |
| 地域背景 | 3 | プロンプト用意済み（§3.7） |
| 主人公＋装備差分 | 1 + 数枚 | プロンプト用意済み（§3.8）・装備差分は未着手 |
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
