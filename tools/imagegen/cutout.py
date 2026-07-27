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

    out = rgba[..., :3].astype(np.uint8)
    result = Image.fromarray(out, "RGB").convert("RGBA")
    result.putalpha(mask)
    return result


def place(img, canvas, ratio):
    """中身の外接矩形で切り出し、正方形の中央へ既定の比率で置く。"""
    bbox = img.getbbox()
    if bbox is None:
        raise SystemExit("中身が空です（キー色で全部抜けた可能性があります）")
    content = img.crop(bbox)

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

    if not grid:
        place(img, canvas, ratio).save(dst)
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
                place(cell, canvas, ratio).save(path)
                print(path)
            except SystemExit:
                print(f"  (空: {name} は飛ばした)")


if __name__ == "__main__":
    main()
