#nullable enable
using System;

namespace XiaXia.Features.Shared
{
    // 无障碍设置契约（M3 R4 收口）：reduce_motion 由 AccessibilitySettings 持久化到
    // PlayerProfile.Settings["accessibility_reduce_motion"]。变更经 Changed 广播，UI 订阅之。
    // 音频不读此开关（audio §4.3：reduce_motion 只压视觉，音频 cue 保持）。
    public interface IAccessibilitySettings
    {
        bool ReduceMotion { get; set; }
        event Action Changed;
    }
}
