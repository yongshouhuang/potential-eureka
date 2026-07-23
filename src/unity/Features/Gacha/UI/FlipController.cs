#nullable enable
using System.Collections;
using UnityEngine;

namespace XiaXia.Features.Gacha.UI
{
    // 卡牌翻面（scale-X 翻 + 灵光粒子；读 reduce_motion/MotionScale 走静态等效定格，art §2.4 / UX §6 I）。
    // 纯视觉：不持有业务数据；由 ResultCard / GachaScreenController 调用 BeginFlip。
    //
    // 实现（Canvas 友好，art §2.4 指引 A）：卡根 RectTransform.localScale.x 由 1→0（中点换 Sprite 卡背→卡面）→1
    // 完成翻面；翻面期间灵光/扫光由上层（ResultCard 材质）叠加。无 3D 相机、无 RenderTexture。
    [RequireComponent(typeof(RectTransform))]
    public sealed class FlipController : MonoBehaviour
    {
        [Header("翻面控件")]
        [SerializeField] private RectTransform? _cardRoot;   // 缩放对象（通常为卡根）
        [SerializeField] private GameObject? _back;          // 卡背（翻面前显示）
        [SerializeField] private GameObject? _front;         // 卡面（翻面后显示）
        [SerializeField] private float _flipDuration = 0.5f; // 普通卡翻面时长（art §2.1）

        private Coroutine? _flip;

        // 起手翻面。reduceMotion=true 时直接定格到正面（静态等效，art §6 I：保留边框+角星+名+数字）。
        // onReveal：换面瞬间（scale=0）回调（用于触发灵光升腾 / 音频 chime 的「揭示」时刻）。
        public void BeginFlip(bool reduceMotion, System.Action? onReveal = null)
        {
            if (_flip != null) StopCoroutine(_flip);
            if (reduceMotion)
            {
                ShowFront();
                onReveal?.Invoke();
                return;
            }
            _flip = StartCoroutine(FlipRoutine(onReveal));
        }

        // 直接定格正面（跳过 / reduce_motion 用）。
        public void ShowFront()
        {
            SetScaleX(1f);
            SetActive(_back, false);
            SetActive(_front, true);
        }

        // 初始态：背面朝上。
        public void ShowBack()
        {
            SetScaleX(1f);
            SetActive(_back, true);
            SetActive(_front, false);
        }

        // 跳过用：停掉进行中的翻面协程并直接定格正面。
        public void ForceFront()
        {
            if (_flip != null) { StopCoroutine(_flip); _flip = null; }
            ShowFront();
        }

        private IEnumerator FlipRoutine(System.Action? onReveal)
        {
            var root = _cardRoot != null ? _cardRoot : (RectTransform)transform;
            ShowBack();
            // t=0.00 → 0.20 起手下沉（1 → 0.92）
            yield return TweenScaleX(root, 1f, 0.92f, 0.20f, Ease.OutCubic);
            // t=0.20 → 0.25 加速（0.92 → 0）
            yield return TweenScaleX(root, 0.92f, 0f, 0.05f, Ease.OutCubic);
            // 换面（scaleX=0 切 Sprite 卡背→卡面）
            SetActive(_back, false);
            SetActive(_front, true);
            onReveal?.Invoke();
            // t=0.25 → 0.5 卡面升起（0 → 1，Back 过冲回正，art §2.2）
            yield return TweenScaleX(root, 0f, 1f, _flipDuration - 0.25f, Ease.OutBack);
            _flip = null;
        }

        private IEnumerator TweenScaleX(RectTransform t, float from, float to, float dur, Ease ease)
        {
            var elapsed = 0f;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                var k = dur <= 0 ? 1f : Mathf.Clamp01(elapsed / dur);
                t.localScale = new Vector3(Mathf.Lerp(from, to, Ease01(k, ease)), 1f, 1f);
                yield return null;
            }
            t.localScale = new Vector3(to, 1f, 1f);
        }

        private void SetScaleX(float x) => ((RectTransform)transform).localScale = new Vector3(x, 1f, 1f);

        private enum Ease { Linear, OutCubic, OutBack }
        private static float Ease01(float k, Ease ease) => ease switch
        {
            Ease.OutCubic => 1f - Mathf.Pow(1f - k, 3f),
            Ease.OutBack => OutBack(k),
            _ => k,
        };
        private static float OutBack(float k)
        {
            const float c1 = 1.70158f, c3 = c1 + 1f;
            return 1f + c3 * Mathf.Pow(k - 1f, 3f) + c1 * Mathf.Pow(k - 1f, 1f);
        }

        private static void SetActive(Object? o, bool v)
        {
            if (o is GameObject go) go.SetActive(v);
            else if (o is Component c) c.gameObject.SetActive(v);
        }
    }
}
