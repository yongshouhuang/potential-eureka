#nullable enable
using System;
using XiaXia.Core;
using XiaXia.Core.Models;

namespace XiaXia.Features.Shared
{
    // 无障碍设置单例（M3 R4 收口）：承载 reduce_motion（视觉压制开关）。
    // 与 AudioSettings 同构——纯 C# 单例，经 ServiceRegistry 注册，读写 PlayerProfile.Settings（存档 schema v1）。
    // 红线：不 import 任何 manager（ADR-3 #3）。
    //
    // 注册：由 Bootstrapper 以 `new AccessibilitySettings(profile)` 构造并
    //       `_services.Register<IAccessibilitySettings>(s)`。
    // 消费：GachaScreenController.Initialize 经 TryResolve 取得，覆盖序列化默认值并动态跟随 Changed。
    public sealed class AccessibilitySettings : IAccessibilitySettings
    {
        private const string K_ReduceMotion = "accessibility_reduce_motion";

        private readonly PlayerProfile _profile;
        public event Action? Changed;

        public AccessibilitySettings(PlayerProfile profile)
        {
            _profile = profile ?? throw new ArgumentNullException(nameof(profile));
        }

        public bool ReduceMotion
        {
            get => GetBool(K_ReduceMotion, false);
            set => SetBool(K_ReduceMotion, value);
        }

        // —— 存档读写（PlayerProfile.Settings 字典；JSON 往返后 bool→bool）——
        private bool GetBool(string key, bool fallback)
        {
            if (_profile.Settings.TryGetValue(key, out var v) && v is bool b) return b;
            return fallback;
        }

        private void SetBool(string key, bool value)
        {
            if (GetBool(key, !value) == value) return; // 无变化不广播
            _profile.Settings[key] = value;
            Changed?.Invoke();
        }
    }
}
