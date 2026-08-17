#nullable enable
using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using XiaXia.Features.Gacha;

namespace XiaXia.Features.Gacha.UI
{
    // 保底进度条（UX §4 / art §4）。绑定 GetPity(poolId) + GetPityThresholds(poolId)，不跨池。
    // 视觉字段（按实际序列化字段，E6 修正，对照 design/art/m4-ui-art-spec.md §7.3）：
    //   _imgFill（填充）/ _txtCount（"12 / 90"）/ _txtSub（副文）/ _mark50（软标记·菱形）/ _mark90（硬标记·方形双刻）。
    //   E3 已评估：不新增 imgTrack / matPityFill 序列化字段——轨道由 prefab 背景 Image 承载、渐变经 _imgFill.material（mat_pity_fill）赋值；
    //   复用现有 _imgFill 即可，美术已按现有字段落地、无阻塞。
    // 填充比例与文案由 PityModel（纯逻辑）计算，本类只做绑定与呈现，不写死阈值/文案逻辑。
    // E5（footgun，仅 PullButton 适用）：本进度条无禁用态、无 _disabledTint，不存在「禁用 sprite 与 _disabledTint 双重去饱和」问题。
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
        // E2（M4 eng 钩子）：跨越后触发脉冲动画回调/事件，供后续 VFX 接入（描边加厚+微缩放 0.2s，art §4.2）。
        //   • milestone 取被跨过的阈值（Soft→_boundSoft，Hard→_boundHard），供 VFX 定位刻度。
        //   • 默认空方法体 + C# event；VFX/动画层订阅 MilestonePulse 或覆写 OnMilestonePulse 即可，零接口改动。
        public PityModel.Crossing DetectCrossing(int newPity)
        {
            var c = PityModel.DetectCrossing(_boundPity, newPity, _boundSoft, _boundHard);
            _boundPity = newPity;
            if (c == PityModel.Crossing.Soft) Pulse(_boundSoft);
            else if (c == PityModel.Crossing.Hard) Pulse(_boundHard);
            return c;
        }

        // E2 脉冲入口：protected virtual 供子类/覆写；同时广播 C# event（null 安全）。
        private void Pulse(int milestone)
        {
            OnMilestonePulse(milestone);
            MilestonePulse?.Invoke(milestone);
        }

        // E2（M4 eng 钩子）：阈值跨越脉冲回调（空实现，待 VFX 接入）。milestone = 被跨过的阈值（50 软 / 90 硬）。
        protected virtual void OnMilestonePulse(int milestone) { }

        // E2（M4 eng 钩子）：阈值跨越脉冲事件，VFX/动画层可订阅（reduce_motion 下由订阅方读 MotionScale 决定跳过，art §4.2 / Standard I）。
        public event Action<int>? MilestonePulse;
    }
}
