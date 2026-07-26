#!/bin/bash
# ダルモンを生成 → 後処理 → 実測 まで一気に通す。
#
#   ./tools/generate-art.sh nemuke gorone
#   ./tools/generate-art.sh --chapter 2
#
# 生成は codex CLI の image_gen を使う。ChatGPT の月額プランで認証されており、
# API キーは不要（`codex login status` で "Logged in using ChatGPT" を確認済み）。
#
# **プロンプトは ART_PROMPTS.md から直接読む。** ここに文面を複製すると必ず
# 食い違うので、原本は常に ART_PROMPTS.md 側に置く。
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p assets/generated assets/processed

# ツールを用意する（未ビルドなら作る）
BIN="$WORK/bin"; mkdir -p "$BIN"
swiftc -O -o "$BIN/artpipeline" tools/artpipeline/main.swift
swiftc -O -o "$BIN/artstats" tools/artstats/main.swift

# 章指定を個体名に展開する
if [ "${1:-}" = "--chapter" ]; then
  case "${2:-}" in
    1) set -- darari nemuke gorone akubi ;;
    2) set -- uzukumari tadayoi nebari motare ;;
    3) set -- shizumi kasumi omori nukegara ;;
    boss) set -- madoromi mukiryoku darumon ;;
    bg) set -- bg1 bg2 bg3 ;;
    *) echo "章は 1 / 2 / 3 / boss / bg のいずれか" >&2; exit 2 ;;
  esac
fi

[ $# -gt 0 ] || { echo "使い方: $0 <個体名>... | --chapter <1|2|3|boss>" >&2; exit 2; }

# 既に合格している個体を参照画像として渡す。
# **文章だけで「他と同じ明るさ」を指示しても揃わない。** 実物を見せるのが確実。
REFERENCES=""
for ref in darari akubi; do
  [ -f "assets/generated/$ref.png" ] && REFERENCES="${REFERENCES:+$REFERENCES,}$ROOT/assets/generated/$ref.png"
done

for NAME in "$@"; do
  echo "=== $NAME ==="

  python3 - "$NAME" "$WORK/prompt.txt" <<'PYEOF'
import io, re, sys
name, out = sys.argv[1], sys.argv[2]
doc = io.open("ART_PROMPTS.md", encoding="utf-8").read()

def spec_after(marker):
    """指定の見出し以降にある最初の STYLE SPEC ブロックを取り出す。"""
    body = doc[doc.index(marker):]
    return body.split("```")[1].strip()

is_boss = name in {"madoromi", "mukiryoku", "darumon"}
is_background = name.startswith("bg")
is_hero = name == "hero"

if is_background:
    index = int(name[2:])
    spec = spec_after("## 3.7 地域背景")
    block = doc.split(f"BACKGROUND {index}:")[1].split("```")[0].strip()
    subject = f"BACKGROUND {index}: {block}"
elif is_hero:
    spec = spec_after("## 3.8 主人公")
    block = doc.split("## 3.8 主人公")[1].split("```")[3].strip()
    subject = block
else:
    spec = spec_after("## 2. 固定スタイルブロック")
    if is_boss:
        # ボスは高さ指定の1行だけを差し替える（§3.6）
        spec = spec.replace("about 70% of the canvas height", "about 85% of the canvas height")
    pattern = re.compile(r"^####[^\n]*/\s*" + re.escape(name.capitalize()) + r"\b[^\n]*$", re.M | re.I)
    match = pattern.search(doc)
    if not match:
        sys.exit(f"ART_PROMPTS.md に '{name}' の個体ブロックが見つかりません")
    body = doc[match.end():].split("```")[1].strip()
    subject = re.sub(r"^CHARACTER[^:]*:\s*", "CHARACTER: ", body)

if is_background:
    intro = ("This is a background plate. Character art will be composited on top of it, "
             "so the center of the image must stay visually quiet.")
elif is_hero:
    # **主人公にだけはパレットを合わせさせない。** 参照と同じ色に寄せると、
    # 主人公まで「怠惰に堕ちた側」に見える（§1 では唯一堕落していない存在）。
    # 揃えるのは描線と塗りの作法だけ。
    intro = ("This is the protagonist of a series whose other members are attached. "
             "MATCH the attached images ONLY in drawing technique — the same bold uniform "
             "outline weight and the same flat one-tone shading. "
             "DO NOT match their palette: the attached creatures are deliberately drained, "
             "grey and cold, and this character must be the opposite — noticeably brighter, "
             "warmer and more saturated than everything else in the world.")
else:
    intro = ("This is an addition to an existing series. Any attached images are approved "
             "members of that series. The new image MUST match their overall brightness, "
             "line weight and palette so they look like they came from the same art book.")

io.open(out, "w", encoding="utf-8").write(f"""Generate ONE image using your image generation tool and save it as {name}.png in the current directory.

{intro}

{spec}

{subject}

Save the result as {name}.png. Do nothing else.""")
PYEOF

  # 背景はキャラクターと処理が違う（透過させない・中央寄せしない）。
  # 主人公は色の目標値が違う（明るく・鮮やかに・暖色へ）。§1 で唯一堕落していない存在。
  case "$NAME" in
    bg[0-9]*) PIPELINE_FLAGS="--background" ;;
    hero)     PIPELINE_FLAGS="--protagonist" ;;
    *)        PIPELINE_FLAGS="" ;;
  esac

  ( cd "$WORK" && rm -f "$NAME.png" \
    && cat prompt.txt | codex exec --sandbox workspace-write --skip-git-repo-check \
         ${PIPELINE_FLAGS:+} ${REFERENCES:+--image "$REFERENCES"} >/dev/null 2>&1 )

  if [ ! -f "$WORK/$NAME.png" ]; then
    echo "  生成に失敗しました（$NAME）" >&2
    continue
  fi

  cp -f "$WORK/$NAME.png" "assets/generated/$NAME.png"
  "$BIN/artpipeline" "assets/generated/$NAME.png" "assets/processed/$NAME.png" $PIPELINE_FLAGS
done

echo
echo "=== 実測（§5 合格条件: 明度の差 15 以内 / アクセント面積 3〜6%）==="
"$BIN/artstats" assets/processed/*.png
