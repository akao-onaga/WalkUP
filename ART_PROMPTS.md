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

## 1. 生成の回し方

### 自動（推奨）

```bash
./tools/generate-art.sh nemuke gorone      # 個体を指定
./tools/generate-art.sh --chapter 2        # 章ごと4体
./tools/generate-art.sh --chapter boss     # ボス3体
```

**生成 → 背景処理 → 正規化 → 減色 → 実測** まで1コマンドで通る。
プロンプトはこのファイルから直接読むので、**文面の原本は常にここ**。
スクリプト側に複製しないこと。必ず食い違う。

生成は codex CLI の `image_gen` を使う。**ChatGPT の月額プランで認証されており、
API キーは不要**（`codex login status` が "Logged in using ChatGPT" を返す）。

スクリプトは既に合格している個体を参照画像として自動で添付する。
**文章だけで「他と同じ明るさ」を指示しても揃わない。** 実物を見せるのが確実で、
実際にネムケの明度は 127.3 → 102.6 に改善した。

### 手動（ChatGPT の画像生成を使う場合）

## 1.1 Codex への投げ方

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
- IMPORTANT — the body color must be a MUTED GREY-VIOLET that sits much closer
  to grey than to purple. It should look almost desaturated, like grey with only
  a faint violet cast. Never let the body read as a vivid, clearly purple,
  lavender or lilac color. When in doubt, remove saturation.
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

**明度と彩度の指示は STYLE SPEC に入れていない。** 後処理（`tools/artpipeline`）が
機械的に揃えるため不要であり、かつ**指示を増やすほど造形が犠牲になる**ことが
実測で分かっている（ダラリの頭が4回中2回失われた）。記述量は造形に回す。

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
and unmotivated to stand. Seen from the side, the body is HORIZONTAL, with the
head at the LEFT resting on the ground and the slack jaw touching the floor.
All FOUR thick stubby legs must be clearly visible along the body, folded
uselessly against it, with visible paw pads. ONE foreleg is raised high into
the air above the body line, bent at the wrist so the paw flops over — this
raised leg is the silhouette's key feature and must read clearly. Deep loose
folds of skin bunch along the back and pool on the ground around the body.
Accent color: faded brick red on the pads of all visible paws.
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

#### ① ダラリ / Darari — 標準

**この文面は触らないこと。** 採用アセットはこの記述で生成されたもの。
「頭が胴と一体化して見える」という指摘を受けて6回書き直したが、毎回別の要素が壊れた
（頭を分離させると痩せる、質量を足すと紫になる、色を直すと頭が戻る、
頭からの垂れ布として書くと幽霊になる）。**最終的に元の文面の出力が最良だった。**
色の不一致は後処理で解消済み。

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
and unmotivated to stand. Seen from the side, the body is HORIZONTAL, with the
head at the LEFT resting on the ground and the slack jaw touching the floor.
All FOUR thick stubby legs must be clearly visible along the body, folded
uselessly against it, with visible paw pads. ONE foreleg is raised high into
the air above the body line, bent at the wrist so the paw flops over — this
raised leg is the silhouette's key feature and must read clearly. Deep loose
folds of skin bunch along the back and pool on the ground around the body.
Accent color: faded brick red on the pads of all visible paws.
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
together. Accent color: dull amber on the connecting strands and where they meet each lump.
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
Accent color: faded rust covering the entire underside of the lolling head and the
lower half of the longer arm.
```

---

### 第3章 — 世界の中心の澱み

#### ⑨ シズミ / Shizumi — 標準

```
CHARACTER: A heavy hunched creature that appears to be sinking into the ground,
its lower half already swallowed and blurred away. Broad rounded shoulders
carry a low-hanging head with two deep-set eyes. Its arms are folded across
itself, pressing downward as if helping itself sink.
Accent color: warm tarnished bronze around the sunken rim where it meets the ground.
```

#### ⑩ カスミ / Kasumi — 手数

```
CHARACTER: A frayed, half-dissolved creature whose outline breaks apart into
drifting wisps at its edges. A vague humanoid core with one faint eye remains
recognizable at the center. Its lower body trails off into ragged floating
tatters instead of legs.
Accent color: dull ochre through the drifting wisps at the dissolving edges.
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
Accent color: dull terracotta around the rim of the hollow opening.
```

---

## 3.6 ボス（3体）

**STYLE SPEC のうち1行だけ差し替える。**

```
- The creature occupies about 85% of the canvas height, centered,
  with even margins on all sides.
```

これ以外は変えない。**スタイルを変えて威圧感を出そうとしないこと。** 大きさだけで足りる。

**ただし 85% は効いていない（2026-07-26 実測）。** 3体とも縦占有は 69%・46% で、
雑魚（ダラリ 70%）と変わらなかった。キャンバス内の占有率を文章で指示しても従わない。
**威圧感は表示側で作ること**として `BattleView` のボスの高さを 210 → 310pt にした。
横長のマドロミは縦占有 46% しかないため、高さ指定だけでは特に小さく見える。

生成後の実測（`assets/processed/` の不透明領域）:

| 個体 | 縦占有 | 横占有 | 310pt 指定時の表示 |
|---|---|---|---|
| ダラリ（雑魚・170pt 指定） | 70% | 75% | 127×119pt |
| マドロミ | 46% | 86% | 266×141pt |
| ムキリョク | 69% | 65% | 201×214pt |
| ダルモン | 69% | 70% | 218×215pt |

**ボスの暖色アクセント面積は §5 の合格条件（3〜6%）を満たさない。** マドロミ 1.0% /
ムキリョク 0.0% / ダルモン 1.1%。これは**プロンプトが意図してそう書いている**ためで、
不合格ではない。ムキリョクのアクセントは cold grey-green（暖色でない）、ダルモンは
"the only warm point in the entire image" と一点だけに限定している。
**ボスを再生成しても、この数値は合格しない。** 明度と彩度は3体とも合格している。

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

## 3.7.1 復興後の地域背景（3枚・2026-07-27 追加）

活気ゲージ（§17.9）が満ちた状態の背景。**同じ場所の「戻ってきた」姿**を1枚ずつ作り、
活気 0〜100 に応じて元の背景の上に重ねてクロスフェードさせる（`web/style.css` の
`.world-alive`、`web/ui.js` の `worldLayers`）。

歩いた成果を数値ではなく風景で返すための素材で、この作品の主題そのものを担う。

**3枚とも生成済み**（2026-07-27）。以下は作り直す時の手順。

### 生成方法の制約（守らないと使えない）

**新規に文章から生成しないこと。** 必ず既存の `assets/generated/bg{1,2,3}.png` を
参照画像として渡す。構図・視点・建物の配置がずれると、重ねたときに別の場所へ
溶暗するだけの絵になり、「同じ街が戻ってきた」に見えない。
**変えてよいのは光・色・そこに在る物だけ。**

### 実際に通った手順

Codex CLI の組み込み `imagegen` に参照画像を渡す。ChatGPT ログインで動く。

```bash
codex exec -s read-only -i assets/generated/bg1.png \
  'あなたの imagegen ツールで、添付した背景画像の「復興後」版を1枚作ってください。
   ファイルの読み書きは不要です。生成したら絶対パスだけを報告してください。
   （この下に EDIT INSTRUCTION を貼る）'
```

出力は `~/.codex/generated_images/<session>/call_*.png` に落ちる。
`-s read-only` を付けるのは、画像生成のついでに作業ツリーを触らせないため。

**構図は保たれるが、彩度と明度は毎回ばらつく。** 第2章では垂れ幕が完全に彩度の
乗った赤と黄で出てきて、そのままでは別の画集の絵になった。生成のばらつきは
プロンプトで抑えようとせず、後処理で吸収する（`artpipeline` と同じ方針）。

```bash
python3 tools/aliveart/match.py \
  WalkUP/Assets.xcassets/Regions/bg2.imageset/bg2.png \
  ~/.codex/generated_images/<session>/call_xxx.png \
  WalkUP/Assets.xcassets/Regions/bg2_alive.imageset/bg2_alive.png
```

元画像の平均彩度に合わせ、明度だけ 16% 上げる。**`artpipeline --background` は使わない。**
あちらは明度を 78 に「揃える」ので、明るくなったこと自体が打ち消され、
活気を上げても風景が変わらなくなる。

```
EDIT INSTRUCTION (apply to the existing background image, keep the composition
identical — same viewpoint, same buildings, same camera, same framing):

- Keep every structure, road, pole, and object in exactly the same position.
- The place has come back to life. Windows and signs are lit with warm amber
  light. The vending machine glows. Street lamps are on.
- Raise the overall value slightly and warm the palette toward amber, while
  staying inside the same limited, desaturated grey-violet and dusty blue range.
  Do not make it saturated or cheerful — this is a quiet return, not a festival.
- Remove signs of abandonment: shutters half open instead of closed, mail no
  longer spilling, weeds thinner.
- Still no people and no creatures anywhere. The life is in the light, not in
  figures.
- Same flat vector style, same bold uniform dark outline, no gradients, no glow
  sprites, no texture.
- Keep the CENTER of the image visually quiet — character art sits on top of it.
```

出力先は `WalkUP/Assets.xcassets/Regions/bg{n}_alive.imageset/bg{n}_alive.png`。
素の生成物は `assets/generated/bg{n}_alive.png`、後処理後は `assets/processed/` にも置く
（後処理をやり直せるようにするため）。

`web/data.js` の `HAS_ALIVE_ART` が切り替えスイッチ。`false` に戻すと、
既存背景に暖色補正をかけた擬似版で動く（絵を差し替えている最中の退避用）。

**第3章だけ作りが違う。** 荒野には灯りが点く場所が無いので、復興は
「重い空が開いて地平に暖色が差す・地割れが浅くなる・裂け目に小さな芽が出る」で示した。
`web/ui.js` の `LAMP_SPOTS[3]` を空にしてあるのはこのため（何も無い地面に光の玉が
浮くだけになる）。

---

## 3.7.2 持ち物の絵（装備9点・素材4点・2026-07-27 追加）

**概念は記号、世界に在る物は絵。** 活力・戻る・鍵は概念なので自前の SVG で描き、
靴・外套・護符・澱・核・かけらは「拾って持ち歩く物」なので絵にする。
記号で足りる所を絵にすると重くなるだけだが、物を記号にすると世界の手触りが消える。

**`item_salve`（気付けの塗り薬）はもう使っていない。** 携行品という概念ごと
落としたため（DESIGN.md §18.4）。素材4点の一覧画から切り出した1枚なので
アセットは残してあるが、コードからの参照はゼロ。

### `eq_starter`（履き古した靴・2026-07-29 追加）

チュートリアルで最初から履いている靴（§11-1）。**長らく絵が無く、`itemArt` の
代替（`shoe` の記号）が出ていた**——しかもそれが出るのは装備画面と、
チュートリアルの工房の場面。つまり**遊び始めて最初の3分**で見える所だった。

既存の `eq_ch1_weapon`（目覚めの靴）を**参照画像として渡し**、同じ画風で
「それより古く、質素で、弱く見える」ものを頼む。低い甲・締め具なし・
すり減った靴底・ほつれた紐・つま先の当て布。差し色は琥珀を紐の先に一点だけ。

```bash
# プロンプトは**標準入力から渡す**（下の落とし穴）
cat prompt.txt | codex exec -s read-only \
  -i WalkUP/Assets.xcassets/Items/eq_ch1_weapon.imageset/eq_ch1_weapon.png

python3 tools/imagegen/cutout.py <生成物.png> \
  WalkUP/Assets.xcassets/Items/eq_starter.imageset/eq_starter.png \
  --key magenta --tol 70 --ratio 0.75
```

`Contents.json` は `cutout.py` が作らないので、既存の imageset から写して置く。

### `codex exec` の `-i` はプロンプトを飲み込む

`-i, --image <FILE>...` は**可変長**なので、

```bash
codex exec -s read-only -i 参照画像.png 'プロンプト'   # ← 効かない
```

と書くと、プロンプトの文字列まで画像ファイルの一つとして食われ、
`No prompt provided via stdin.` で止まる。**プロンプトは標準入力から渡すこと。**

### 一覧画で作って機械的に切る

1点ずつ生成すると回数がそのまま費用になる。**格子に並べた1枚として生成し、
後で分割する。** 装備9点は 3×3 で1回、素材4点は 2×2 で1回。

```bash
# 生成（プロンプトで「縦3等分・横3等分、各マスの中央に1点、マスをまたがせない」と縛る）
codex exec -s read-only '…3行×3列の格子に並べた1枚の一覧画として…'

# 分割・クロマキー・配置
python3 tools/imagegen/cutout.py <生成物.png> out_dir/ \
  --grid 3x3 --key magenta --tol 70 --ratio 0.76 \
  --names eq_ch1_weapon,eq_ch2_weapon,eq_ch3_weapon,…
```

格子の指示は素直に守られた。**行ごとに種類、列ごとに章（強化度）**にすると、
段位の差が絵として並ぶので比べながら描かせられる。

### 透過は「アルファで」と頼まない（失敗した）

主人公の立ち姿で `Fully transparent background (alpha channel)` と指定したところ、
**透過を表す市松模様が画素として描き込まれた絵**が返ってきた。
アルファは一部だけ立っていて、人物の周りに格子柄の矩形が焼き付いている。

必ず**平坦な単色の塗り**を要求し、後処理で抜く。

```
**背景は必ず、画像の端から端までを覆う一様な純マゼンタ（#FF00FF）の塗りに
してください。** 透過にしないでください。市松模様（透過を表す格子柄）を
描かないでください。グラデーション・影・周辺減光・テクスチャも描かないで
ください。人物のどこにもマゼンタを使わないでください。
```

キー色は**素材に含まれない色**を選ぶ。主人公側の装備（緑・琥珀・生成り）は
マゼンタ、堕落した側の素材（灰紫）は緑。逆にすると輪郭ごと抜けて事故る。

### 縁のにじみは救わず削る

`cutout.py` は最初、キー色との距離に応じて縁を半透明にしていた。
**キー色の混ざった画素がそのまま残り、暗い背景の上でマゼンタの輪郭として光った。**
混ざった画素は救わずに削り落とす——余裕を持った距離で一気に抜き、さらに 1px 削り、
最後にごく弱くぼかす。輪郭は太く暗いので、外周 1px は失っても見えない。

---

## 3.8 主人公

**ダルモン用の STYLE SPEC は使えない。** mood が正反対（あちらは inert、こちらは
「唯一動いている存在」）なので、専用の固定ブロックを使う。描画スタイルだけは揃える。

```
STYLE SPEC (protagonist):

- One single character, centered in a 1:1 square canvas, full body visible.
- Flat vector illustration. Bold, uniform dark outline of consistent weight.
- Exactly one flat shadow tone per color area. No gradients, no soft shading,
  no texture, no highlights, no glow, no rendering.
- CLEAR, SATURATED palette built on GREEN — vivid fresh greens carry the
  figure, with warm amber and cream as the supporting accents. Bright enough
  to read at a glance against a drained grey-violet world. This character must
  NOT share the muted grey-violet range of the creature illustrations: he is
  the ONE thing in this world that has not gone grey.
- Fully transparent background (alpha channel). No background color, no shadow
  on the ground, no ground plane, no props, no environment. Clean edges
  suitable for compositing.
- The character occupies about 70% of the canvas height, centered,
  with even margins on all sides.
- No text, no logo, no signature, no watermark, no border, no frame.
- Mood: energetic and eager to move. Bright, spirited, ready to take on
  whatever is in front of him — not gloomy, not tired, not solemn.
```

```
CHARACTER: A spirited BOY of about twelve, drawn in STRICT SIDE VIEW (full
profile), the whole body turned toward the RIGHT edge of the canvas and
striding to the right with obvious energy. He is a child, not an adult: a
slightly large head on a small light frame, about five heads tall.
Mid-stride at full speed — legs thrown wide apart in a big step, the rear
shoe pushing off hard so its thick treaded SOLE is visible, both arms swung
strongly, the front arm driving forward.
The face IS visible in profile and faces right: simple flat features in the
same bold outline as the rest — one wide open eye fixed straight ahead, a
strong angled eyebrow, mouth set in a determined line. He looks fired up and
ready for a fight. No blush, no sparkle, no rendering.
He wears GREEN adventuring gear designed for a video game hero: a fitted
short green jacket with a raised collar, a buckled belt at the waist, and
snug green trousers tucked in at the ankle. Trim and buckles in warm amber.
NO ROBE, NO CLOAK, NO HOOD, NO CAPE, NO POINTED HAT, NO BACKPACK, NO BAG —
nothing on his back at all. Short messy hair, bare head.
BOTH HANDS ARE EMPTY — no staff, no stick, no weapon of any kind.
The BOOTS are the hero's signature equipment and the most detailed part of
the figure — chunky game-style adventure boots with thick deeply treaded
soles, layered plates, a strap and buckle across each instep, and reinforced
toe caps. They read as powerful gear, not ordinary footwear. Nothing covers
the legs, so both boots and the full stride read clearly. He leans into the
step — the only figure in this world that is still moving.
Accent color: he is the bright one. Nothing about him is grey.
```

**主人公だけは色を揃えない（2026-07-27 変更）。** 当初は「暖色のアクセントを1点」
だったが、それでは足りなかった。**全体がダルモンと同じ灰紫だと、主人公まで
堕落した側に見える。** §1 で主人公は世界で唯一堕落していない存在なので、
明度・彩度・色相のすべてで世界から離す。

この変更は3か所に入っている。**1か所でも戻すと灰色に戻る。**

| 場所 | 内容 |
|---|---|
| STYLE SPEC（上） | 暖色で鮮やかに、と明示。灰紫のレンジを禁止 |
| `tools/generate-art.sh` | 参照画像に「描線だけ合わせ、パレットは合わせるな」と指示 |
| `tools/artpipeline --protagonist` | 明度 126 / 彩度 0.42 / 暖色へ加算（他は 107 / 0.23 / 灰紫） |

**後処理が最後に効く。** プロンプトだけ直しても `artpipeline` が全アセットを
彩度 0.23 に落とすので、灰色に戻る。実際に一度これで戻した。

**武器は靴（2026-07-26 変更）。** 当初は「短い杖」を持たせていたが、
歩くことが冒険になる（§1）という設計原理に対して、手に持つ武器は嘘になる。
装備の武器スロットも「杖」から「靴」に変えてある。
**靴が絵の中で最も描き込まれた部分になるよう指示している。** ここを普通の靴として
描かれると、ただ歩いている人に戻ってしまう。

**ローブとフードは廃止（2026-07-26 再変更）。** 杖を外した後も、フード付きの
外套のままだったので魔法使いに見えていた。**背景は現代の住宅街と商店街**（§3.7）で、
そこを歩くのがファンタジーの旅人では世界と噛み合わない。
現代の服装（ウィンドブレーカー・デイパック）に変えている。
**「ローブでない」ことは否定形で明示しないと戻る。** 生成は繰り返すと元の型に寄る。

**横向き・顔ありに変更（2026-07-27）。** 背面の絵は「歩き去る人」にしか見えず、
戦闘画面で敵と並べても**対面しているように読めなかった**（ダルモン側は正面向き）。
真横（プロファイル）で右を向かせ、顔も出している。
`BattleView` は主人公を左・ダルモンを右に置くので、**右向きであることが要件**。
向きを変えるなら配置も一緒に変えること。

---

## 3.9 街の人（6人・2026-07-28 追加）

物語の場面で喋る住人。**セリフだけで姿が無いと、起きていないのと同じ**なので立ち絵を出す
（`web/README.md` の「街の人が出入りする」）。

| ファイル | 誰 | 出る場所 |
|---|---|---|
| `p_elder` | 老女 | ボス1の前後・第1章 100% |
| `p_smith` | 工房の主 | チュートリアル（強化の説明）・ボス2の前後 |
| `p_trader` | 市の店主 | 第2章 45% / 75% / 100% |
| `p_cobbler` | 靴の老人 | 第1章 45% |
| `p_baker` | パン屋の主人 | ボス1の後 |
| `p_man` | 男 | 第1章 12% |

### パレットは主人公とダルモンの「間」に置く

**どちらに寄せても筋が壊れる。**

- ダルモンの灰紫に寄せると、**起きた人が堕ちた側に見える**
- 主人公の鮮やかな緑に寄せると、**主人公が「唯一色を持つ者」でなくなる**（§3.8 の前提）

くすんだ暖色の土気色（黄土・粘土・埃っぽい茶・褪せたオリーブ・生成り）に置く。
**ダルモンより明確に暖かく、主人公より明確に静か。** プロンプトに3行で書いてある。

### 6人を1枚で生成する

生成回数がそのまま費用になる（§10.1.1）。**3行×2列の一覧画で1回。**
参照画像は主人公とダラリの2枚を渡し、「描線だけ揃えろ、パレットは間に置け」と指示する。

```bash
codex exec -s read-only \
  -i WalkUP/Assets.xcassets/Darumon/hero_stand.imageset/hero_stand.png \
  -i WalkUP/Assets.xcassets/Darumon/darari.imageset/darari.png \
  < people-prompt.txt

python3 tools/imagegen/cutout.py <生成物.png> out/ --grid 3x2 --key magenta --tol 70 \
  --ratio 0.80 --names p_elder,p_smith,p_trader,p_cobbler,p_baker,p_man
```

**6人とも一発で通った。** 格子・背景のマゼンタ・人物の描き分けはどれも素直に守られる。

- **左を向かせる。** 場面では主人公が左・街の人が右に立つので、
  右を向いていると背中で会話することになる
- **背丈は絵で決まらない。** `cutout.py` が1人ずつ 80% に正規化するので、
  「小柄な老女」と「大柄な工房の主」の差は消える。背丈で語らせない
- 背景は純マゼンタの塗りを要求する（§3.7.2）。土気色にマゼンタは含まれないので安全

### 表情差分は持たない（2026-07-28 の判断）

驚き・焦り・安堵を絵で作ると 6人×3枚で一覧画2〜3回ぶんになる。
**入り方・待機の揺れ・話者の明るさで出す**方を選んだ。

その明るさの付け方で一度失敗している。**聞き手を半分の明るさまで落としたら、
工房の主（焦げ茶の前掛け）が夜の地面に沈んで見えなくなった。**
立ち絵の明るさは絵ごとに違うので、引き算の演出は暗い絵から先に壊す。
**話者に光を足す形に変えた**（暖色の淡い外光＋わずかな増光）。足し算ならどの絵でも壊れない。

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

### 明度と彩度はプロンプトで揃えようとしないこと（2026-07-26 の教訓）

**生成は毎回すべての属性を引き直す。** ある属性を指定で直すと、別の属性が壊れる。
ダラリで実際に4回起きた。

| 回 | 頭の分離 | 質量 | 色 |
|---|---|---|---|
| 1 | ❌ 平ら | ✅ | ✅ |
| 2 | ✅ | ❌ 痩せた | ✅ |
| 3 | ✅ | ✅ | ❌ 紫に寄った |
| 4 | ❌ 戻った | ✅ | ✅ |

ゴロネでも同じことが起きた（向きを固定したら四肢が消えた）。

**そこで役割を分けた。**

| 性質 | 直す場所 | 理由 |
|---|---|---|
| シルエット・造形・ポーズ | プロンプト | 生成でしか作れない |
| **明度・彩度** | **後処理（`tools/artpipeline`）** | 機械的に揃う。引き直しが起きない |

後処理は不透明部の平均明度を 107、平均彩度を 0.23 に寄せる。色相は触らないので
個体ごとの色味の差は残る。全アセットに同じ目標を適用するため、
**「1体だけ明るい」「1体だけ紫」が構造的に起きなくなる。**

STYLE SPEC 側の明度・彩度の記述は残してあるが、**保険であって主たる手段ではない**。

### アクセント面積は目視で判断しないこと

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
