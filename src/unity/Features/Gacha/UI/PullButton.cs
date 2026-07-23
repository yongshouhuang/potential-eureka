#nullable enable
using TMPro;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

namespace XiaXia.Features.Gacha.UI
{
    // 抽卡按钮（单抽 / 十连，art §5）。三态：常态 / 按下 / 禁用-符箓不足。
    // 禁用态：去饱和信息灰 + 锁 glyph + 对角划线（由美术 sprite / UISkin 承载，不纯色，UX §3.2）。
    // MVP 灰盒：以 interactable=false + 锁 glyph 显隐 + 序列化禁用色调表达；对角划线/去饱和由美术终稿 sprite 承载。
    [RequireComponent(typeof(RectTransform))]
    public sealed class PullButton : MonoBehaviour
    {
        [Header("art §7.3 字段")]
        [SerializeField] private Button? _btn;
        [SerializeField] private TextMeshProUGUI? _txtLabel; // 文案 + 符箓消耗（tabular）
        [SerializeField] private Image? _imgLockIcon;       // 禁用态锁 glyph（ico_st_disable）
        [SerializeField] private Image? _imgBg;             // 9-slice 按钮底

        [Header("禁用态色调（灰盒占位，非硬编码业务色；终稿由美术 sprite 覆盖）")]
        [SerializeField] private Color _disabledTint = new Color(0.541f, 0.584f, 0.600f); // 信息灰 #8A9599

        private Color _normalTint = Color.white;

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
        public void SetDisabledInsufficient(bool disabled)
        {
            if (_imgLockIcon != null) _imgLockIcon.gameObject.SetActive(disabled);
            if (_btn != null) _btn.interactable = !disabled;
            if (_imgBg != null) _imgBg.color = disabled ? _disabledTint : _normalTint;
        }
    }
}
