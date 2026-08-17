#nullable enable
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using XiaXia.Features.Gacha;

namespace XiaXia.Features.Gacha.UI
{
    // 保底进度条（UX §4 / art §4）。绑定 GetPity(poolId) + GetPityThresholds(poolId)，不跨池。
    // 视觉字段按 art §7.3：_imgFill / _txtCount / _txtSub / _mark50 / _mark90（imgTrack/matPityFill 暂缓至终稿增强，见 design/art/m4-ui-art-spec.md §7.3）。
    // 填充比例与文案由 PityModel（纯逻辑）计算，本类只做绑定与呈现，不写死阈值/文案逻辑。
    [RequireComponent(typeof(RectTransform))]
    public sealed class PityProgressBar : MonoBehaviour
    {
        [Header("art §7.3 字段")]
        [SerializeField] private Image? _imgFill;        // 填充（Fill 模式或 9-slice）
        [SerializeField] private TextMeshProUGUI? _txtCount; // "12 / 90" tabular
        [SerializeField] private TextMeshProUGUI? _txtSub;   // 副文（距保底 / 软保底生效 / 下抽必出 SSR）
        [SerializeField] private GameObject? _mark50;     // 软标记（菱形 tick，形状冗余）
        [SerializeField] private GameObject? _mark90;     // 硬标记（方形双刻 tick，形状冗余）

        private int _boundPity = -1;
        private int _boundSoft;
        private int _boundHard;

        // 绑定当前池保底（不跨池：切换池时由调用方传入新池的 pity/thresholds）。
        public void Bind(int pity, int soft, int hard)
        {
            _boundPity = pity;
            _boundSoft = soft;
            _boundHard = hard;

            var v = PityModel.Compute(pity, soft, hard);
            if (_imgFill != null) _imgFill.fillAmount = v.FillRatio;
            if (_txtCount != null) _txtCount.text = v.CountText ?? "";
            if (_txtSub != null) _txtSub.text = v.SubText ?? "";

            // 形状刻度常显（CVD 冗余：形状+数字+颜色，art §4.3），不靠纯色区分两段。
            // 灰盒阶段 art §7.3 字段 Inspector 可能留空，用 ?. 避免 UnassignedReferenceException。
            _mark50?.SetActive(true);
            _mark90?.SetActive(true);
        }

        // 进度条更新时检测阈值跨越（audio §3.3 保底提示）。
        // 委托给 PityModel.DetectCrossing（纯逻辑，可 headless 单测）。
        public PityModel.Crossing DetectCrossing(int newPity)
        {
            var c = PityModel.DetectCrossing(_boundPity, newPity, _boundSoft, _boundHard);
            _boundPity = newPity;
            return c;
        }
    }
}
