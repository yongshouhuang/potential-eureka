#nullable enable
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using XiaXia.Core;
using XiaXia.Features.Shared.Events;

namespace XiaXia.Features.Navigation
{
    // R1 导航层（H-C1 真实导航 + 返回，灰盒推图占位）。
    // 架构：方案 B（同场景内 Canvas/Root 管理，规格 §2/§3）——不拆场景，仅 SetActive 切换屏。
    // 红线：只经 EventBus 订阅意图事件接管跳转，绝不向 UI 暴露任何跳转 API（ADR-3）。
    // 无现成导航框架，本类为最小导航层（规格 §3.1）。
    //
    // 屏栈保证任意时刻仅 1 屏 SetActive(true)；返回事件 Pop 栈顶回抽卡屏（规格 §6）。
    // 本组件须挂于场景持久根（与 Bootstrapper 同物体/同场景根），切勿挂在屏 Root 上——
    // 屏 Root 的 SetActive 切换不应触发本组件 OnDisable，否则订阅会被误摘除（R1-2）。
    public sealed class NavigationManager : MonoBehaviour
    {
        [Header("屏根（拖拽）")]
        [SerializeField] private GameObject? _gachaScreenRoot;
        [SerializeField] private GameObject? _battleScreenRoot;

        [Header("返回按钮（拖拽）")]
        [SerializeField] private Button? _battleBackButton;

        private readonly List<GameObject> _stack = new List<GameObject>();
        private EventBus? _bus;

        // 由 Bootstrapper 在 Awake 末尾注入（与 GachaScreenController.Initialize 同签名）。
        // 注入同一 bus 实例并在此订阅意图事件，完全复用引导注入，不自行 new 基础设施。
        // services 预留给未来导航域服务（如场景过渡器），R1 暂未使用。
        public void Initialize(ServiceRegistry services, EventBus bus)
        {
            _bus = bus;
            Debug.Log($"[NavMgr] Initialize() called | bus={(_bus != null ? "✓" : "✗")} | gachaRoot={(_gachaScreenRoot != null ? "✓" : "✗")} | battleRoot={(_battleScreenRoot != null ? "✓" : "✗")} | backBtn={(_battleBackButton != null ? _battleBackButton.name : "NULL")}");

            // 仅由导航层订阅意图事件（原 Bootstrapper 的 gray-box stub 已在 R1 移除，避免双订阅歧义 R1-3）。
            _bus.Subscribe<GachaAcquireIntentEvent>(OnAcquireIntent);
            _bus.Subscribe<GachaReturnIntentEvent>(OnReturnIntent);

            // 返回按钮只 Publish 事件，不持有 NavigationManager 引用（与进入对称，ADR-3）。
            if (_battleBackButton != null)
                _battleBackButton.onClick.AddListener(() =>
                {
                    Debug.Log("[NavMgr] BACK 按钮被点击！正在发布 GachaReturnIntentEvent...");
                    _bus?.Publish(new GachaReturnIntentEvent());
                });
            else
                Debug.LogWarning("[NavMgr] ⚠️ _battleBackButton 为 NULL！返回按钮无法绑定 onClick");

            // 初始仅 gacha 屏 active（R1-1：避免两屏 Canvas 叠层 / 射线穿透）。
            _battleScreenRoot?.SetActive(false);
            _gachaScreenRoot?.SetActive(true);
        }

        // 兜底：若 OnEnable 先于 Initialize 触发（跨物体 Awake/OnEnable 顺序不保证），
        // _bus 尚未注入则直接返回，等待 Initialize 注入（同 GachaScreenController 模式）。
        private void OnEnable()
        {
            if (_bus == null) return;
        }

        // gacha:acquire_intent —— reason → 屏 路由（规格 §4）。
        private void OnAcquireIntent(GachaAcquireIntentEvent e)
        {
            switch (e.Reason)
            {
                case "battle":
                    _gachaScreenRoot?.SetActive(false);
                    _battleScreenRoot?.SetActive(true);
                    _stack.Add(_battleScreenRoot!);
                    break;
                case "store":
                    Debug.LogWarning("store 屏未实现");
                    break;
                default:
                    Debug.LogWarning($"未知 acquire reason: {e.Reason}");
                    break;
            }
        }

        // gacha:return_intent —— 返回：Pop 栈顶并显 gacha 屏（规格 §6）。R1 仅回 gacha。
        private void OnReturnIntent(GachaReturnIntentEvent e)
        {
            Debug.Log($"[NavMgr] OnReturnIntent 收到！stack.Count={_stack.Count} | gachaRoot={(_gachaScreenRoot != null ? "✓" : "✗")}");
            if (_stack.Count > 0)
            {
                var top = _stack[^1];
                Debug.Log($"[NavMgr] 隐藏栈顶: {top.name}");
                top.SetActive(false);
                _stack.RemoveAt(_stack.Count - 1);
            }
            else
                Debug.LogWarning("[NavMgr] ⚠️ 栈为空，没有可隐藏的屏");
            Debug.Log("[NavMgr] 显示 GachaScreenRoot");
            _gachaScreenRoot?.SetActive(true);
        }

        // R1-2：配对反订阅，防重编译/场景重载导致的持久订阅泄漏与重复跳转。
        // OnDisable 与 OnDestroy 均调用；EventBus.Unsubscribe 按引用移除、幂等，重复调用安全。
        private void OnDisable() => UnsubscribeAll();
        private void OnDestroy() => UnsubscribeAll();

        private void UnsubscribeAll()
        {
            if (_bus == null) return;
            _bus.Unsubscribe<GachaAcquireIntentEvent>(OnAcquireIntent);
            _bus.Unsubscribe<GachaReturnIntentEvent>(OnReturnIntent);
        }
    }
}
