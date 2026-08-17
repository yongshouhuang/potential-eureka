#nullable enable
using System;
using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using XiaXia.Core;
using XiaXia.Core.Models;
using XiaXia.Features.Audio;
using XiaXia.Features.Gacha;
using XiaXia.Features.Shared;
using XiaXia.Features.Shared.Events;

namespace XiaXia.Features.Gacha.UI
{
    // UGUI 抽卡屏控制器（MVP 六态状态机 + reveal sequencer）。Phase 5 制作切片（M3）。
    //
    // ── 解耦红线自检（ADR-3）──
    //  • 只经 ServiceRegistry 解析「接口」：IGachaService / IEconomyService / IShikigamiCatalog /
    //    IAudioService / IAudioSettings；绝不持有 GachaManager/EconomyManager/AudioService 具体类字段，
    //    也不 import 这些 manager（红线#3）。
    //  • 跨系统只经 EventBus 订阅：economy:currency_changed（顶栏货币绝对值）；
    //    gacha:shikigami_obtained 仅作轻量副作用（Codex「新」计数），绝不在此实例化卡/起协程（UX §3.1）。
    //  • reveal sequencer 消费 IGachaService.Pull 返回的 IReadOnlyList<GachaResult>，按 art §8 / audio §2 的
    //    t 锚点排逐卡错峰时间轴（十连 0.08s/张），**同一时间轴**驱动 VFX 与音频——严禁随原始事件瞬时齐发
    //    （audio §3.4 红线）。reduce_motion 只压视觉，音频 cue 仍对齐定格揭示时刻（audio §4.3）。
    public sealed class GachaScreenController : MonoBehaviour
    {
        // —— 六态（UX §1）——
        public enum GachaScreenState
        {
            Idle, PoolSelected, Rolling, Reveal, ResultList, InsufficientCurrency,
        }

        [Header("顶栏 / 保底")]
        [SerializeField] private TextMeshProUGUI? _currencyLabel;   // 符箓（tabular，监听 currency_changed）
        [SerializeField] private PityProgressBar? _pityBar;

        [Header("卡池")]
        [SerializeField] private string _defaultPoolId = string.Empty; // 留空则取 GetPoolList 第一项
        [SerializeField] private List<Toggle> _poolTabs = new List<Toggle>(); // 可选；按 GetPoolList 顺序

        [Header("结果区")]
        [SerializeField] private Transform? _revealArea;          // 运行时实例化 ResultCard
        [SerializeField] private GameObject? _resultCardPrefab;  // ResultCard prefab
        [SerializeField] private TextMeshProUGUI? _resultSummary;// 「获得 X / 含 N SSR」

        [Header("按钮")]
        [SerializeField] private PullButton? _singlePull;
        [SerializeField] private PullButton? _tenPull;
        [SerializeField] private Button? _insufficientCta;       // 去推图产出符箓（UX 卡点#1）
        [SerializeField] private Button? _againButton;           // 再来一次（ResultList）
        [SerializeField] private Button? _skipCatcher;           // 点击跳过翻面（Reveal 期）

        [Header("设置")]
        [SerializeField, Tooltip("R3: 服务已注册 IAccessibilitySettings 时此值被覆盖，请经 PlayerProfile.Settings[accessibility_reduce_motion] 注入验证（见 QA S-11）")]
        private bool _reduceMotion;             // MVP 灰盒：主理人本地可经 AccessibilitySettings 注入

        [Header("布局（灰盒测试用，正式美术接入请取消勾选）")]
        [SerializeField] private bool _autoLayout = true;        // 运行时自动把关键 UI 摆到合理位置，省去手动拖拽

        // —— 运行时服务（经 Initialize 注入，仅接口引用）——
        private ServiceRegistry? _services;
        private EventBus? _bus;
        private IGachaService? _gacha;
        private IEconomyService? _econ;
        private IShikigamiCatalog? _catalog;
        private IAudioService? _audio;
        private IAccessibilitySettings? _accSettings; // R4 收口：reduce_motion 动态来源（非序列化默认）

        private GachaScreenState _state = GachaScreenState.Idle;
        private string _poolId = string.Empty;
        private int _soft, _hard;

        private Coroutine? _revealRoutine;
        private readonly List<ResultCard> _revealCards = new List<ResultCard>();
        private readonly List<(float time, Action act)> _timeline = new List<(float, Action)>();
        private int _timelineIdx;
        private float _revealElapsed;
        private bool _skip;

        // ====================================================================
        // 生命周期
        // ====================================================================
        // 由 Bootstrapper 调用：注入服务并接通事件（R4 已收口——reduce_motion 经
        // IAccessibilitySettings 注入并动态跟随，不再仅取序列化默认值）。
        public void Initialize(ServiceRegistry services, EventBus bus)
        {
            _services = services;
            _bus = bus;
            _gacha = services.Resolve<IGachaService>();
            _econ = services.Resolve<IEconomyService>();
            _catalog = services.Resolve<IShikigamiCatalog>();
            if (services.TryResolve<IAudioService>(out var a)) _audio = a;
            // 注：IAudioSettings 由 AudioService 订阅（audio §4.1），本控制器不直读音频开关；
            // reduce_motion 取序列化默认值，若 AccessibilitySettings 已注册则覆盖并动态跟随（R4 收口）。
            if (services.TryResolve<IAccessibilitySettings>(out var acc))
            {
                _accSettings = acc;
                _reduceMotion = acc.ReduceMotion;
                acc.Changed += OnAccessibilityChanged;
            }
            // 兜底首刷：OnEnable 可能在 Initialize 之前触发（_gacha 彼时为 null 已提前 return），
            // 此处服务已就绪，强制刷新状态机 + 按钮监听，确保单/十连可点击（UX §1.3）。
            BindPool(_ResolveDefaultPoolId());
            RefreshCurrency();
            if (!CanAfford(1)) SetState(GachaScreenState.InsufficientCurrency);
            else SetState(GachaScreenState.PoolSelected);
            AutoLayout();
        }

        // R4 收口：无障碍开关变更时动态更新视觉压制（音频不受影响，audio §4.3）。
        private void OnAccessibilityChanged() => _reduceMotion = _accSettings?.ReduceMotion ?? _reduceMotion;

        // 灰盒测试布局：重编译/手动拖拽不便时，Initialize 末尾自动把关键 UI 摆到合理位置。
        // 正式美术接入请取消勾选 _autoLayout（此段仅调试辅助，不干预业务逻辑）。
        private void AutoLayout()
        {
            if (!_autoLayout) return;
            SetRect(_currencyLabel?.transform as RectTransform, 0.5f, 1f, 0f, -100f, 400f, 100f);
            SetRect(_pityBar?.transform as RectTransform, 0.5f, 1f, 0f, -260f, 600f, 40f);
            SetRect(_singlePull?.transform as RectTransform, 0.5f, 0f, 0f, 200f, 300f, 120f);
            SetRect(_tenPull?.transform as RectTransform, 0.5f, 0f, 0f, 60f, 300f, 120f);
        }

        private static void SetRect(RectTransform? rt, float ax, float ay, float x, float y, float w, float h)
        {
            if (rt == null) return;
            rt.anchorMin = new Vector2(ax, ay);
            rt.anchorMax = new Vector2(ax, ay);
            rt.pivot = new Vector2(0.5f, 0.5f);
            rt.anchoredPosition = new Vector2(x, y);
            rt.sizeDelta = new Vector2(w, h);
            if (rt.TryGetComponent<TextMeshProUGUI>(out var tmp)) tmp.color = Color.white;
        }

        private void OnEnable()
        {
            if (_bus != null)
            {
                _bus.Subscribe<EconomyCurrencyChangedEvent>(OnCurrencyChanged);
                _bus.Subscribe<GachaShikigamiObtainedEvent>(OnShikigamiObtained);
            }
            if (_insufficientCta != null) _insufficientCta.onClick.AddListener(OnInsufficientCta);
            if (_againButton != null) _againButton.onClick.AddListener(OnAgain);
            if (_skipCatcher != null) _skipCatcher.onClick.AddListener(SkipReveal);

            // 若 Initialize 尚未执行（_gacha 为 null），跳过首刷，待 Initialize 末尾兜底刷新。
            // Unity 不保证跨物体 Awake/OnEnable 顺序，防止按钮监听在 _gacha 就绪前被永久跳过。
            if (_gacha == null) return;
            BindPool(_ResolveDefaultPoolId());
            RefreshCurrency();
            // MVP：Idle 在 OnEnable 自动绑默认池 → PoolSelected（UX §1.3）。
            if (!CanAfford(1)) SetState(GachaScreenState.InsufficientCurrency);
            else SetState(GachaScreenState.PoolSelected);
        }

        private void OnDisable()
        {
            if (_bus != null)
            {
                _bus.Unsubscribe<EconomyCurrencyChangedEvent>(OnCurrencyChanged);
                _bus.Unsubscribe<GachaShikigamiObtainedEvent>(OnShikigamiObtained);
            }
            if (_accSettings != null) _accSettings.Changed -= OnAccessibilityChanged;
            if (_insufficientCta != null) _insufficientCta.onClick.RemoveListener(OnInsufficientCta);
            if (_againButton != null) _againButton.onClick.RemoveListener(OnAgain);
            if (_skipCatcher != null) _skipCatcher.onClick.RemoveListener(SkipReveal);
            if (_revealRoutine != null) { StopCoroutine(_revealRoutine); _revealRoutine = null; }
        }

        // ====================================================================
        // 状态机（UX §1）
        // ====================================================================
        private void SetState(GachaScreenState next)
        {
            _state = next;
            switch (next)
            {
                case GachaScreenState.PoolSelected:
                    ShowInsufficientCta(false);
                    RefreshPullButtons();
                    break;
                case GachaScreenState.InsufficientCurrency:
                    ShowInsufficientCta(true);
                    RefreshPullButtons(); // 按钮置灰（UX §3.2）
                    _audio?.Play(SoundId.Gacha_Insufficient);
                    break;
                case GachaScreenState.Rolling:
                case GachaScreenState.Reveal:
                    ShowInsufficientCta(false);
                    break;
                case GachaScreenState.ResultList:
                    ShowInsufficientCta(false);
                    // 抽卡完成回到结果列表：恢复单/十连按钮可点（UX §1.3）。
                    // 修复「只能点一次」——Rolling 锁定后若不再刷新，按钮会永久 Disabled。
                    RefreshPullButtons();
                    break;
            }
        }

        // ====================================================================
        // 卡池绑定（不跨池）
        // ====================================================================
        private string _ResolveDefaultPoolId()
        {
            if (!string.IsNullOrEmpty(_defaultPoolId)) return _defaultPoolId;
            var list = _gacha?.GetPoolList();
            return (list != null && list.Count > 0) ? list[0].Id : string.Empty;
        }

        private void BindPool(string poolId)
        {
            _poolId = poolId;
            if (_gacha != null) (_soft, _hard) = _gacha.GetPityThresholds(poolId);
            var pity = _gacha?.GetPity(poolId) ?? 0;
            _pityBar?.Bind(pity, _soft, _hard);
            RefreshPullButtons();
        }

        // 切换卡池（PoolTab tap）。重绑保底/消耗，不保留旧池值（UX §4.1 不跨池）。
        private void SelectPool(string poolId)
        {
            if (_state == GachaScreenState.Rolling || _state == GachaScreenState.Reveal) return;
            BindPool(poolId);
            _audio?.Play(SoundId.Gacha_Pool_Select);
            SetState(CanAfford(1) ? GachaScreenState.PoolSelected : GachaScreenState.InsufficientCurrency);
        }

        // ====================================================================
        // 货币
        // ====================================================================
        private void RefreshCurrency()
        {
            if (_currencyLabel == null || _econ == null) return;
            // 绝对值：经 IEconomyService.GetBalance（H4 配套），非累加（UX §3.1）。
            _currencyLabel.text = _econ.GetBalance("fu_lu").ToString(); // 数值 tabular（inspector 设 tnum）
        }

        // economy:currency_changed：信号到达即刷新绝对值（UI 不维护累加缓存）。
        private void OnCurrencyChanged(EconomyCurrencyChangedEvent evt)
        {
            if (evt.Currency != "fu_lu") return;
            RefreshCurrency();
            // 从 InsufficientCurrency 恢复：货币达标即回 PoolSelected（UX §1.2）。
            if (_state == GachaScreenState.InsufficientCurrency && CanAfford(1))
                SetState(GachaScreenState.PoolSelected);
        }

        // gacha:shikigami_obtained：仅轻量副作用（Codex「新」统计），**绝不**实例化卡/起协程（UX §3.1）。
        // 翻面以 Pull() 返回的 results 列表为权威有序源。
        private void OnShikigamiObtained(GachaShikigamiObtainedEvent evt)
        {
            // MVP：留作 Codex「新」标记扩展点；此处不触碰 UI 实例。
        }

        // ====================================================================
        // 抽卡流程（UX §3）
        // ====================================================================
        private bool CanAfford(int count)
        {
            if (_gacha == null || _econ == null) return false;
            return _econ.GetBalance("fu_lu") >= _gacha.GetPullCost(_poolId, count);
        }

        private void RefreshPullButtons()
        {
            if (_gacha == null) return;
            var singleCost = _gacha.GetPullCost(_poolId, 1);
            var tenCost = _gacha.GetPullCost(_poolId, 10);
            var canSingle = CanAfford(1);
            var canTen = CanAfford(10);
            var locked = _state == GachaScreenState.Rolling || _state == GachaScreenState.Reveal;
            _singlePull?.Configure($"单抽 -{singleCost} 符箓", canSingle && !locked, () => OnPull(1));
            _tenPull?.Configure($"十连 -{tenCost} 符箓", canTen && !locked, () => OnPull(10));
        }

        // 单/十连入口（UX §3.1）。先可支付性预检，不足转 InsufficientCurrency。
        // 允许 PoolSelected / InsufficientCurrency / ResultList 触发，Rolling/Reveal 期间屏蔽。
        private void OnPull(int count)
        {
            if (_state is GachaScreenState.Rolling or GachaScreenState.Reveal) return;
            if (!CanAfford(count))
            {
                SetState(GachaScreenState.InsufficientCurrency);
                return;
            }
            // Rolling：禁用按钮 + 灵光升腾 + rolling loop
            SetState(GachaScreenState.Rolling);
            _audio?.Play(count == 10 ? SoundId.Gacha_TenPull_Click : SoundId.Gacha_SinglePull_Click);
            _audio?.PlayLoop(SoundId.Gacha_Rolling);

            var results = _gacha!.Pull(_poolId, count); // 同步返回有序结果（M2 实现）

            // 保底：先记录跨越（用 Pull 后新值），再重绑进度条
            var newPity = _gacha.GetPity(_poolId);
            if (_pityBar != null)
            {
                var cross = _pityBar.DetectCrossing(newPity);
                if (cross == PityModel.Crossing.Hard) _audio?.Play(SoundId.Gacha_Pity_Triggered);
                else if (cross == PityModel.Crossing.Soft) _audio?.Play(SoundId.Gacha_Pity_Near);
            }
            _pityBar?.Bind(newPity, _soft, _hard);

            // Reveal：消费 results 排错峰时间轴（audio §3.3，不随原始事件齐发）
            _revealRoutine = StartCoroutine(RevealSequence(results));
        }

        // ====================================================================
        // Reveal Sequencer（GachaScreenController 内，audio §3.3 / art §8）
        // ====================================================================
        private IEnumerator RevealSequence(IReadOnlyList<GachaResult> results)
        {
            SetState(GachaScreenState.Reveal);
            _revealCards.Clear();
            _timeline.Clear();
            _skip = false;
            _revealElapsed = 0f;

            var cues = RevealSchedule.Build(results);
            // 同一时间轴：逐卡调度 VFX（翻面/SSR 虹光）与音频（Flip_Start / Reveal_Swap / 顶层 / SSR climax）。
            foreach (var cue in cues)
            {
                var idx = cue.CardIndex;
                var rarity = cue.Rarity;
                _timeline.Add((cue.AppearTime, new Action(() =>
                {
                    var card = InstantiateResultCard(results[idx], rarity);
                    if (card == null) return;
                    _revealCards.Add(card);
                    _audio?.Play(SoundId.Gacha_Card_Flip_Start);          // t=0.00 起手 whoosh
                    _audio?.StopLoop(SoundId.Gacha_Rolling);
                    card.Flip?.BeginFlip(_reduceMotion);                  // 起手翻面（reduce_motion→瞬判定格）
                })));
                _timeline.Add((cue.RevealTime, new Action(() =>
                {
                    _audio?.Play(SoundId.Gacha_Reveal_Swap);             // t=0.25 青碧灵光升腾 chime（基础层）
                    _audio?.Play(rarity.RevealTopLayerFor());            // t=0.25 稀有度顶层（叠于 Swap）
                })));
                if (cue.IsSsr)
                    _timeline.Add((cue.SsrClimaxTime, new Action(() =>
                    {
                        _audio?.Play(SoundId.Gacha_Reveal_SSR_Climax);   // t=0.25+0.2s 紫宸虹光峰值（audio §8.2）
                        CardAt(idx)?.PlaySsrHolo();
                    })));
            }
            _timeline.Sort((a, b) => a.time.CompareTo(b.time));
            _timelineIdx = 0;

            var total = RevealSchedule.TotalDuration(cues);
            while (_revealElapsed < total && !_skip)
            {
                _revealElapsed += Time.deltaTime;
                while (_timelineIdx < _timeline.Count && _timeline[_timelineIdx].time <= _revealElapsed)
                {
                    _timeline[_timelineIdx].act();
                    _timelineIdx++;
                }
                yield return null;
            }

            // 收尾：确保全部定格（含未跑完的跳过情况）
            foreach (var c in _revealCards) c.Flip?.ForceFront();
            _audio?.StopLoop(SoundId.Gacha_Rolling);
            _revealRoutine = null;

            // SSR 触发羁绊序章（UX §1.3：仅 SSR，1–2 屏，MVP 留钩子）
            var ssrAny = false;
            foreach (var r in results) if (r.Rarity == Rarity.SSR) ssrAny = true;
            ShowResultSummary(results, ssrAny);
            SetState(GachaScreenState.ResultList);
            if (ssrAny) _audio?.Play(SoundId.Bond_Prologue_Open); // 占位钩子（P2，audio §2 #13）
        }

        private ResultCard? InstantiateResultCard(GachaResult result, Rarity rarity)
        {
            if (_resultCardPrefab == null || _revealArea == null) return null;
            var go = UnityEngine.Object.Instantiate(_resultCardPrefab, _revealArea);
            var card = go.GetComponent<ResultCard>();
            if (card != null && _catalog != null)
            {
                var meta = _catalog.GetMeta(result.ShikigamiId);
                var stats = _catalog.GetCombatStats(result.ShikigamiId);
                card.Setup(result, meta, stats, _reduceMotion);
            }
            return card;
        }

        private ResultCard? CardAt(int index) =>
            (index >= 0 && index < _revealCards.Count) ? _revealCards[index] : null;

        private void SkipReveal()
        {
            if (_state != GachaScreenState.Reveal) return;
            _skip = true; // 循环退出后由 RevealSequence 收尾定格
        }

        private void ShowResultSummary(IReadOnlyList<GachaResult> results, bool ssrAny)
        {
            if (_resultSummary == null) return;
            var ssr = 0;
            foreach (var r in results) if (r.Rarity == Rarity.SSR) ssr++;
            _resultSummary.text = $"获得 {results.Count} 式神 · 含 {ssr} SSR";
        }

        // ====================================================================
        // 结果区操作
        // ====================================================================
        private void OnAgain()
        {
            if (_state != GachaScreenState.ResultList) return;
            BindPool(_poolId); // 重绑保底（已更新）
            SetState(CanAfford(1) ? GachaScreenState.PoolSelected : GachaScreenState.InsufficientCurrency);
        }

        private void OnInsufficientCta()
        {
            // 去推图产出符箓（UX 卡点#1）。MVP：仅占位跳转意图（Battle 屏由主菜单导航层接管）。
            _audio?.Play(SoundId.Gacha_Insufficient);
            _bus?.Publish(new GachaAcquireIntentEvent { Reason = "battle" });
        }

        private void ShowInsufficientCta(bool show)
        {
            if (_insufficientCta != null) _insufficientCta.gameObject.SetActive(show);
        }
    }
}
