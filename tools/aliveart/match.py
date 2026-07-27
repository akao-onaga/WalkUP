#!/usr/bin/env python3
"""復興後の背景を、元の背景と同じ「画集」に揃える後処理。

ART_PROMPTS.md §3.7.1 で生成した `bg{n}_alive` は、構図こそ元と一致するが
**彩度と明度が毎回ばらつく**（第2章では赤と黄の垂れ幕が完全に彩度の乗った色で出た）。
生成のばらつきはプロンプトで抑えようとせず後処理で吸収する、という
`tools/artpipeline` と同じ方針をここでも採る。

artpipeline をそのまま使えない理由:
  あちらは背景の平均明度を 78、彩度を 0.16 に「揃える」。復興後の絵に掛けると、
  明るくなったこと自体が打ち消され、活気を上げても風景が変わらなくなる。

ここでは元画像を基準に、**彩度は合わせ、明度だけ意図した分だけ上げる**。

  ./match.py <元.png> <復興後.png> <出力.png> [--gain 1.16] [--sat 1.10]

  --gain  元画像の平均明度に対する倍率（既定 1.16 = 16% 明るい）
  --sat   元画像の平均彩度に対する倍率（既定 1.10 = わずかに色が戻る）
"""

import sys
import numpy as np
from PIL import Image


def to_hsv(rgb):
    """0..1 の RGB 配列を HSV へ。PIL の convert('HSV') は 8bit で丸まるので自前で持つ。"""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    diff = mx - mn

    hue = np.zeros_like(mx)
    mask = diff > 1e-6
    # 最大値がどの成分かで場合分けする。
    idx = rgb.argmax(axis=-1)
    with np.errstate(invalid="ignore", divide="ignore"):
        hue = np.where((idx == 0) & mask, ((g - b) / diff) % 6, hue)
        hue = np.where((idx == 1) & mask, ((b - r) / diff) + 2, hue)
        hue = np.where((idx == 2) & mask, ((r - g) / diff) + 4, hue)
    hue = hue / 6.0

    sat = np.where(mx > 1e-6, diff / np.maximum(mx, 1e-6), 0.0)
    return hue, sat, mx


def to_rgb(h, s, v):
    i = np.floor(h * 6.0)
    f = h * 6.0 - i
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
    i = (i % 6).astype(int)

    out = np.zeros(h.shape + (3,), dtype=np.float64)
    for k, (rr, gg, bb) in enumerate([(v, t, p), (q, v, p), (p, v, t),
                                      (p, q, v), (t, p, v), (v, p, q)]):
        m = i == k
        out[m, 0], out[m, 1], out[m, 2] = rr[m], gg[m], bb[m]
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 3:
        print(__doc__)
        sys.exit(1)

    def opt(name, default):
        for a in sys.argv[1:]:
            if a.startswith(f"--{name}="):
                return float(a.split("=", 1)[1])
        if f"--{name}" in sys.argv:
            return float(sys.argv[sys.argv.index(f"--{name}") + 1])
        return default

    gain = opt("gain", 1.16)
    sat_gain = opt("sat", 1.10)

    src_path, alive_path, out_path = args
    src = np.asarray(Image.open(src_path).convert("RGB"), dtype=np.float64) / 255.0
    alive_img = Image.open(alive_path).convert("RGB")

    # **寸法は元に合わせる。** 1ピクセルでもずれると重ねた時に輪郭が二重になる。
    if alive_img.size != Image.open(src_path).size:
        alive_img = alive_img.resize(Image.open(src_path).size, Image.LANCZOS)
    alive = np.asarray(alive_img, dtype=np.float64) / 255.0

    _, src_s, src_v = to_hsv(src)
    h, s, v = to_hsv(alive)

    # 彩度: 元画像の平均に合わせてから、意図した分だけ戻す。
    target_s = src_s.mean() * sat_gain
    s = np.clip(s * (target_s / max(s.mean(), 1e-6)), 0, 1)

    # 明度: 元画像の平均に対して gain 倍。上限で潰れないよう、白飛びは抑える。
    target_v = min(src_v.mean() * gain, 0.92)
    v = np.clip(v * (target_v / max(v.mean(), 1e-6)), 0, 1)

    out = np.clip(to_rgb(h, s, v) * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(out).save(out_path)

    print(f"{out_path}")
    print(f"  彩度 {s.mean():.3f}（元 {src_s.mean():.3f}）"
          f" / 明度 {v.mean():.3f}（元 {src_v.mean():.3f}）")


if __name__ == "__main__":
    main()
