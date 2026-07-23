#nullable enable
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using XiaXia.Core.Models;
using XiaXia.Features.Shared;

namespace XiaXia.Features.Gacha.UI
{
    // 出货结果卡（art §1 / §7.3）。运行时由 GachaScreenController 实例化并 Setup。
    //
    // 稀有度三重冗余（颜色+边框纹理+角星 1/2/3，art §1.3 / UX §6 E）：按 Rarity 显隐 imgFrame*/imgStar*。
    // 美术按 art §7.3 字段名同名替换 sprite/材质即可，不动布局（MVP 灰盒占位）。
    [RequireComponent(typeof(RectTransform))]
    public sealed class ResultCard : MonoBehaviour
    {
        // —— art §7.3 字段名约定（美术后续同名替换）——
        [Header("帧（四档，按稀有度显隐其一）")]
        [SerializeField] private Image? _imgFrameN, _imgFrameR, _imgFrameSR, _imgFrameSSR;
        [SerializeField] private Image? _imgFrameSweep;   // SSR 光扫 overlay（card_frame_ssr_sweep，加法）
        [Header("角星（1/2/3，按档显隐）")]
        [SerializeField] private Image? _imgStar1, _imgStar2, _imgStar3;
        [Header("卡背 / 底纹 / 立绘")]
        [SerializeField] private Image? _imgCardBack;     // 卡背（翻面起手态）
        [SerializeField] private Image? _imgCardBg;       // 卡面底纹（card_bg）
        [SerializeField] private RawImage? _rawPortrait;  // 立绘占位（portrait_placeholder，后续换式神立绘）
        [Header("文本（tabular）")]
        [SerializeField] private TextMeshProUGUI? _txtName;   // 式神名（H2）
        [SerializeField] private TextMeshProUGUI? _txtRarity; // N/R/SR/SSR
        [SerializeField] private TextMeshProUGUI? _txtATK, _txtHP; // tabular 数值
        [Header("五行形状 glyph")]
        [SerializeField] private Image? _imgElementGlyph; // 五行形状（圆/三角/方），CVD 冗余
        [Header("材质（翻面 / SSR 叠加）")]
        [SerializeField] private Material? _matRiseGlow, _matSSRRainbow;
        [Header("翻面")]
        [SerializeField] private FlipController? _flip;

        private Rarity _rarity;

        // 填充一张卡。stats 来自 IShikigamiCatalog.GetCombatStats（ATK/HP，tabular）。
        public void Setup(GachaResult result, ShikigamiMeta meta, (int atk, int hp) stats, bool reduceMotion)
        {
            _rarity = result.Rarity;
            ShowFrame(result.Rarity);
            ShowStars(result.Rarity);

            if (_txtName != null) _txtName.text = meta.DisplayName;
            if (_txtRarity != null) _txtRarity.text = result.Rarity.ToString();
            if (_txtATK != null) _txtATK.text = $"ATK {stats.atk}";
            if (_txtHP != null) _txtHP.text = $"HP {stats.hp}";

            // 五行形状 glyph：MVP 灰盒由美术替换（五行形状 sprite）；此处仅保留占位槽。
            // 立绘占位：rawPortrait 用 portrait_placeholder（美术替换接口）。

            // SSR 扫光 overlay：仅 SSR 显（紫宸虹光，art §3）。
            SetActive(_imgFrameSweep, result.Rarity == Rarity.SSR);
            if (_imgFrameSweep != null) _imgFrameSweep.gameObject.SetActive(result.Rarity == Rarity.SSR);

            _flip?.ShowBack(); // 初始背面朝上，等 reveal sequencer 翻面
        }

        public FlipController? Flip => _flip;
        public Rarity Rarity => _rarity;

        // SSR 紫宸虹光峰值（reveal sequencer 在 t=0.25+0.2s 调用，art §3 / audio §8.2）。
        // MVP 灰盒：启用扫光 overlay（美术材质做动态光扫；reduce_motion 下静态显边框不扫，art §6 I）。
        public void PlaySsrHolo()
        {
            if (_imgFrameSweep == null) return;
            _imgFrameSweep.gameObject.SetActive(true);
            // 终稿：触发 mat_ssr_rainbow 光扫动画 + 紫宸 bloom；MVP 仅置显（静态等效）。
        }

        private void ShowFrame(Rarity r)
        {
            SetActive(_imgFrameN, r == Rarity.N);
            SetActive(_imgFrameR, r == Rarity.R);
            SetActive(_imgFrameSR, r == Rarity.SR);
            SetActive(_imgFrameSSR, r == Rarity.SSR);
        }

        private void ShowStars(Rarity r)
        {
            var n = r switch { Rarity.R => 1, Rarity.SR => 2, Rarity.SSR => 3, _ => 0 };
            SetActive(_imgStar1, n >= 1);
            SetActive(_imgStar2, n >= 2);
            SetActive(_imgStar3, n >= 3);
        }

        private static void SetActive(Object? o, bool v)
        {
            if (o is GameObject go) go.SetActive(v);
            else if (o is Component c) c.gameObject.SetActive(v);
        }
    }
}
