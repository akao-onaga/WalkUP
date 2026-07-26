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
    *) echo "章は 1 / 2 / 3 / boss のいずれか" >&2; exit 2 ;;
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

  python3 - "$NAME" "$WORK/prompt.txt" <<'PY'
import io, re, sys
name, out = sys.argv[1], sys.argv[2]
doc = io.open("ART_PROMPTS.md", encoding="utf-8").read()

# ボスは STYLE SPEC の高さ指定だけ 85% に差し替える（§3.6）
is_boss = name in {"madoromi", "mukiryoku", "darumon"}

spec = doc.split("STYLE SPEC (identical for every image in this set):")[1].split("```")[0]
spec = "STYLE SPEC (identical for every image in this set):" + spec.rstrip()
if is_boss:
    spec = spec.replace("about 70% of the canvas height", "about 85% of the canvas height")

# 見出しから該当個体の CHARACTER ブロックを取り出す
pattern = re.compile(r"^####[^\n]*/\s*" + re.escape(name.capitalize()) + r"\b[^\n]*$", re.M | re.I)
match = pattern.search(doc)
if not match:
    sys.exit(f"ART_PROMPTS.md に '{name}' の個体ブロックが見つかりません")
block = doc[match.end():].split("```")[1].strip()
block = re.sub(r"^CHARACTER[^:]*:\s*", "", block)

io.open(out, "w", encoding="utf-8").write(f"""Generate ONE image using your image generation tool and save it as {name}.png in the current directory.

This is an addition to an existing series. Any attached images are approved members of that series. The new image MUST match their overall brightness, line weight and palette so they look like they came from the same art book. Do not make it lighter than the attached images.

{spec}

CHARACTER: {block}

Save the result as {name}.png. Do nothing else.""")
PY

  ( cd "$WORK" && rm -f "$NAME.png" \
    && cat prompt.txt | codex exec --sandbox workspace-write --skip-git-repo-check \
         ${REFERENCES:+--image "$REFERENCES"} >/dev/null 2>&1 )

  if [ ! -f "$WORK/$NAME.png" ]; then
    echo "  生成に失敗しました（$NAME）" >&2
    continue
  fi

  cp -f "$WORK/$NAME.png" "assets/generated/$NAME.png"
  "$BIN/artpipeline" "assets/generated/$NAME.png" "assets/processed/$NAME.png"
done

echo
echo "=== 実測（§5 合格条件: 明度の差 15 以内 / アクセント面積 3〜6%）==="
"$BIN/artstats" assets/processed/*.png
