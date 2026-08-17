#nullable enable
using TMPro;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

namespace XiaXia.Features.Gacha.UI
{
    // 抽卡按钮（单抽 / 十连，art §5）。
    // 视觉四态（E1：由 3 态扩为 4 态，新增 PityArmed）：Normal / Pressed / Disabled / PityArmed。
    //   Normal 常态 / Pressed 按下（Button 原生表现）/ Disabled 禁用-符箓不足（UX §3.2）/ PityArmed 保底临近（art §3.2）。
    // 禁用态：去饱和信息灰 + 锁 glyph + 对角划线（由美术 sprite / UISkin 承载，不纯色，UX §3.2）。
    // 保底态（PityArmed）：视觉资产待美术接入（btn_bg_armed_9slice + 角标 sprite），本类仅留状态钩子与空引用，见 E1。
    // MVP 灰盒：Disabled 以 interactable=false + 锁 glyph 显隐 + 序列化禁用色调表达；对角划线/去饱和由美术终稿 sprite 承载。
    [RequireComponent(typeof(RectTransform))]
    public sealed class PullButton : MonoBehaviour
    {
        // 视觉状态（E1：由 3 态扩为 4 态，新增 PityArmed）。Pressed 由 Button 组件原生表现，本类不单独控。
        public enum PullState
        {
            Normal,      // 常态
            Pressed,     // 按下（Button 原生 pressed sprite / scale）
            Disabled,    // 禁用-符箓不足（UX §3.2）
            PityArmed,   // 保底临近（≥ hard-5，如 hard=90 → ≥85，art §3.2）：idle 辉光转鎏金→朱砂 + 角标「必出 SSR」
        }

        [Header("art §7.3 字段")]
        [SerializeField] private Button? _btn;
        [SerializeField] private TextMeshProUGUI? _txtLabel; // 文案 + 符箓消耗（tabular）
        [SerializeField] private Image? _imgLockIcon;       // 禁用态锁 glyph（ico_st_disable）
        [SerializeField] private Image? _imgBg;             // 9-slice 按钮底（常态/按下/禁用 sprite）

        // E1（M4 美术 eng 钩子）：保底临近态视觉资产（待美术接入，空引用）。
        //   TODO(art): _imgArmedBg   ← btn_bg_armed_9slice（主 CTA idle 辉光转鎏金→朱砂）
        //   TODO(art): _imgArmedBadge← 角标 sprite「必出 SSR」（鎏金/朱砂描边）
        // 当前不挂任何 sprite，SetPityArmed 仅切换状态标志 + 安全 SetActive（空引用时 no-op），真实视觉待美术终稿 prefab 接好这两引用后生效。
        [SerializeField] private Image? _imgArmedBg;        // 保底态底（空引用，待美术接入）
        [SerializeField] private Image? _imgArmedBadge;     // 保底态角标（空引用，待美术接入）

        // E5（footgun）：_disabledTint 是灰盒占位去饱和色（非美术资产、非硬编码业务语义色——仅运行时乘到 _imgBg.color）。
        //   • 若 prefab 接入烘焙禁用 sprite（btn_bg_disabled_9slice，已含去饱和+对角划线），须把此处 _disabledTint 设为「白 (1,1,1)」，
        //     否则 _imgBg.color 会与 sprite 双重去饱和 → 禁用态过重（可见瑕疵，非阻断，见 m4-art-closure R2）。
        //   • 默认 #8A9599：仅用于「未接禁用 sprite」时由代码去饱和表达禁用态；接 sprite 后请改白。
        //   • 约定：_disabledTint 永不接受 null；白值 = Color.white 表示「不做额外去饱和，完全交给 sprite」。
        //   • 注：本双重去饱和问题仅 PullButton 存在；PityProgressBar 无禁用态/无 _disabledTint（见其头部 E5 说明）。
        [Header("禁用态色调（灰盒占位，非硬编码业务色；接禁用 sprite 时须改白，见 E5）")]
        [SerializeField] private Color _disabledTint = new Color(0.541f, 0.584f, 0.600f); // 信息灰 #8A9599（接禁用 sprite 时改白）

        private Color _normalTint = Color.white;
        private PullState _state = PullState.Normal;
        private bool _pityArmed; // E1：保底临近标志（仅影响视觉态钩子，不改变可交互性）

        private void Awake()
        {
            if (_imgBg != null) _normalTint = _imgBg.color;
        }

        // 配置按钮：文案 + 可支付性 + 点击回调。
        public void Configure(string label, bool canAfford, UnityAction onClick)
        {
            if (_txtLabel != null) _txtLabel.text = label;
            SetDisabledInsufficient(!canAfford);
            if (_btn != null)
            {
                _btn.onClick.RemoveAllListeners();
                if (canAfford && onClick != null) _btn.onClick.AddListener(onClick);
            }
        }

        // 禁用-符箓不足态（UX §3.2）：锁 glyph 显 + 置灰 + 不可交互。
        // E5 footgun：_disabledTint 与禁用 sprite 不得双重去饱和（见字段注释；接 sprite 时 _disabledTint 须设白）。
        public void SetDisabledInsufficient(bool disabled)
        {
            if (_imgLockIcon != null) _imgLockIcon.gameObject.SetActive(disabled);
            if (_btn != null) _btn.interactable = !disabled;
            if (_imgBg != null) _imgBg.color = disabled ? _disabledTint : _normalTint;
            // 禁用优先：禁用态覆盖保底辉光；解除禁用时若仍临近保底则回到 PityArmed。
            _state = disabled ? PullState.Disabled : (_pityArmed ? PullState.PityArmed : PullState.Normal);
        }

        // E1（M4 eng 钩子）：保底临近态切换。由 GachaScreenController 在 pity 临近硬保底（如 ≥85，hard=90）时调用。
        //   • 仅切换状态标志与 _state；真实视觉（idle 辉光转鎏金→朱砂 / 角标「必出 SSR」）待美术接入 _imgArmedBg / _imgArmedBadge 后由 prefab 生效。
        //   • 不改变可交互性：保底态按钮仍可点击（保底临近更应鼓励抽卡），与 Disabled 正交。
        //   • 若同时处于 Disabled（符箓不足），保底辉光不覆盖禁用态（_state 在 SetDisabledInsufficient 中已优先置 Disabled）。
        public void SetPityArmed(bool armed)
        {
            _pityArmed = armed;
            // E1 视觉钩子（待美术接入 _imgArmedBg / _imgArmedBadge）：空引用阶段 SetActive 为 no-op（无 sprite 不渲染），仅维持状态。
            if (_imgArmedBg != null) _imgArmedBg.gameObject.SetActive(armed);      // TODO(art): 接 btn_bg_armed_9slice 后此 GameObject 承载鎏金→朱砂辉光
            if (_imgArmedBadge != null) _imgArmedBadge.gameObject.SetActive(armed); // TODO(art): 角标「必出 SSR」sprite
            if (_state != PullState.Disabled)
                _state = armed ? PullState.PityArmed : PullState.Normal;
        }

        // 当前视觉状态（E1：供调试 / 后续 VFX 读取；不改变业务行为）。
        public PullState CurrentState => _state;
    }
}
