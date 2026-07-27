#!/usr/bin/env python3
"""ImageGen の生成物をアセットに落とすための後処理。

`tools/artpipeline`（Swift）はダルモンの立ち絵に特化していて、背景色の推定・
減色・明度の正規化まで一括で掛かる。**主人公とアイテムには掛けられない**——
§3.8 のとおり主人公は色を揃えない側の存在で、正規化すると灰色に戻る。

ここは切り抜きと配置だけを行う。色には触らない。

  # 透過で出てきた1枚を、1024角の中央に高さ70%で置く
  ./cutout.py in.png out.png

  # 単色背景の一覧画を 3×3 に切り、1マスずつ抜いて並べる
  ./cutout.py sheet.png out_dir/ --grid 3x3 --key magenta --names 靴1,靴2,...

オプション:
  --key magenta|green|none  クロマキーで抜く色（既定 none = すでに透過）
  --tol 70                  キー色とみなす距離（0〜441）
  --canvas 1024             出力の一辺
  --ratio 0.70              中身の高さが占める割合
  --grid RxC                一覧画を分割する
  --names a,b,c             分割時の出力ファイル名（省略すると 01,02,…）
"""

import sys
import pathlib
import numpy as np
from PIL import Image, ImageFilter

KEYS = {"magenta": (255, 0, 255), "green": (0, 255, 0)}


def opt(name, default=None):
    argv = sys.argv[1:]
    for i, a in enumerate(argv):
        if a == f"--{name}" and i + 1 < len(argv):
            return argv[i + 1]
        if a.startswith(f"--{name}="):
            return a.split("=", 1)[1]
    return default


def chroma_key(img, key, tol):
    """単色背景を透過にする。

    **半透明の帯を残すと縁が色付きで光る。** 最初は距離に応じて薄くしていたが、
    キー色の混ざった画素がそのまま残り、暗い背景の上でマゼンタの輪郭として出た
    （実際に一度やらかした）。混ざった画素は救わずに**削り落とす**。

      1. キー色に近い画素を、余裕を持った距離で一気に抜く
      2. さらに 1px 削る（輪郭は太く暗いので、外周1pxは失っても見えない）
      3. 最後にごく弱くぼかして、階段状の縁をならす
    """
    rgba = np.asarray(img.convert("RGBA"), dtype=np.float64)
    rgb = rgba[..., :3]
    dist = np.sqrt(((rgb - np.array(key, dtype=np.float64)) ** 2).sum(axis=-1))

    alpha = rgba[..., 3].copy()
    alpha[dist < tol * 1.5] = 0

    mask = Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8), "L")
    mask = mask.filter(ImageFilter.MinFilter(3))
    mask = mask.filter(ImageFilter.GaussianBlur(0.7))

    # **残る色被りは吸い出す。**
    # 砂粒のように細かく淡い部分は、削ると形が消えるのに色被りだけが残る
    # （足跡の砂に緑が 1% 残った）。形は触らず、キー色の成分だけを引き下げる。
    rgb = despill(rgba[..., :3], key)

    result = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    result.putalpha(mask)
    return result


def despill(rgb, key):
    """キー色の成分が他を上回っている画素から、その成分だけを削る。

    緑キーなら「G が R と B の最大値を超えている画素」の G を抑える。
    素材本来の色（砂の淡い灰、琥珀の赤）はこの条件に入らないので触られない。"""
    out = rgb.astype(np.float64).copy()
    r, g, b = out[..., 0], out[..., 1], out[..., 2]

    if key == KEYS["green"]:
        ceiling = np.maximum(r, b)
        over = g > ceiling
        g[over] = ceiling[over]
    elif key == KEYS["magenta"]:
        # マゼンタは R と B の両方が持ち上がる。G を超えている分だけ戻す。
        ceiling = np.maximum(g, np.minimum(r, b))
        for ch in (r, b):
            over = ch > ceiling
            ch[over] = ceiling[over] + (ch[over] - ceiling[over]) * 0.35
    return out


def place(img, canvas, ratio, tight=False):
    """中身の外接矩形で切り出し、正方形の中央へ既定の比率で置く。

    `tight` を立てると正方形に置かず、外接矩形のまま返す。
    **横長の物（木札・帯）は正方形に入れると上下に大きな余白が焼き付く。**
    その余白は画面上でそのまま隙間になり、詰めようとしても詰められない。"""
    bbox = img.getbbox()
    if bbox is None:
        raise SystemExit("中身が空です（キー色で全部抜けた可能性があります）")
    content = img.crop(bbox)
    if tight:
        return content

    target_h = int(canvas * ratio)
    scale = target_h / content.height
    # 横に広い物は幅で頭打ちにする（はみ出させない）。
    if content.width * scale > canvas * 0.92:
        scale = canvas * 0.92 / content.width
    content = content.resize(
        (max(1, round(content.width * scale)), max(1, round(content.height * scale))),
        Image.LANCZOS,
    )

    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(content, ((canvas - content.width) // 2, (canvas - content.height) // 2), content)
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    # --key magenta のような「値を取るオプション」の値を除く
    values = {opt(n) for n in ("key", "tol", "canvas", "ratio", "grid", "names")}
    args = [a for a in args if a not in values]
    if len(args) != 2:
        print(__doc__)
        sys.exit(1)

    src, dst = args
    key_name = opt("key", "none")
    tol = float(opt("tol", 70))
    canvas = int(opt("canvas", 1024))
    ratio = float(opt("ratio", 0.70))
    grid = opt("grid")

    img = Image.open(src).convert("RGBA")
    if key_name != "none":
        img = chroma_key(img, KEYS[key_name], tol)

    tight = "--tight" in sys.argv
    if not grid:
        place(img, canvas, ratio, tight).save(dst)
        print(dst)
        return

    rows, cols = (int(v) for v in grid.lower().split("x"))
    names = (opt("names") or "").split(",") if opt("names") else []
    out_dir = pathlib.Path(dst)
    out_dir.mkdir(parents=True, exist_ok=True)

    cw, ch = img.width // cols, img.height // rows
    for r in range(rows):
        for c in range(cols):
            index = r * cols + c
            cell = img.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            name = names[index].strip() if index < len(names) else f"{index + 1:02d}"
            if not name:
                continue
            path = out_dir / f"{name}.png"
            try:
                place(cell, canvas, ratio, tight).save(path)
                print(path)
            except SystemExit:
                print(f"  (空: {name} は飛ばした)")


if __name__ == "__main__":
    main()
