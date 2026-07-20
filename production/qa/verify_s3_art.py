import os, struct

ref = "F:/AI/仙侠卡牌项目/art/references"
expected = [
    "char_sr_zhu_que_portrait_front.png","char_sr_zhu_que_portrait_side.png","char_sr_zhu_que_portrait_back.png","char_sr_zhu_que_face.png","char_sr_zhu_que_chibi.png",
    "char_r_qiu_long_portrait_front.png","char_r_qiu_long_portrait_side.png","char_r_qiu_long_portrait_back.png","char_r_qiu_long_face.png","char_r_qiu_long_chibi.png",
    "char_r_hu_wei_portrait_front.png","char_r_hu_wei_portrait_side.png","char_r_hu_wei_portrait_back.png","char_r_hu_wei_face.png","char_r_hu_wei_chibi.png",
    "char_n_huo_ling_portrait_front.png","char_n_huo_ling_portrait_side.png","char_n_huo_ling_portrait_back.png","char_n_huo_ling_face.png","char_n_huo_ling_chibi.png",
    "status_burn.png","status_armor_break.png","status_poison.png","status_momentum.png",
    "combo_banner.png",
]

def png_dims(path):
    with open(path,'rb') as f:
        sig = f.read(8)
        if sig != b'\x89PNG\r\n\x1a\n':
            return None, None, "BAD_SIG"
        f.read(4)
        typ = f.read(4)
        if typ != b'IHDR':
            return None, None, "NO_IHDR"
        w = struct.unpack('>I', f.read(4))[0]
        h = struct.unpack('>I', f.read(4))[0]
        return w, h, "OK"

print(f"{'FILE':45} {'W':>6} {'H':>6} {'RATIO':>7} {'KB':>7}  CHECK")
print("-"*92)
all_ok = True
for name in expected:
    p = os.path.join(ref, name)
    if not os.path.exists(p):
        print(f"{name:45} MISSING"); all_ok = False; continue
    sz = os.path.getsize(p)
    w, h, st = png_dims(p)
    if st != "OK":
        print(f"{name:45} ERR:{st}"); all_ok = False; continue
    ratio = f"{w/h:.3f}" if h else "?"
    print(f"{name:45} {w:>6} {h:>6} {ratio:>7} {sz/1024:>7.0f}  {st}")
print("-"*92)
print(f"TOTAL EXPECTED: {len(expected)}  ALL_OK={all_ok}")
