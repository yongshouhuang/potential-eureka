#nullable enable

namespace XiaXia.Features.Audio
{
    // 混音总线分类（对齐 AudioMixer Group，audio §3.6）。
    // Master 为总控；Music/Ambient/SFX/UI/VO 为子总线。静音/音量按类别控制。
    public enum AudioCategory
    {
        Master,
        Music,
        Ambient,
        SFX,
        UI,
        VO,
    }

    // 音频服务契约（audio §3.2）。由 AudioService（MonoBehaviour）实现并注册到 ServiceRegistry。
    //
    // 解耦红线（ADR-3 / audio §3.0 / §6）：音频层不 import 任何 manager，只经
    //   • UI 调用点直接 audio.Play(...)（瞬时反馈）；
    //   • reveal sequencer 在调度到的 t 锚点调用 audio.Play(...)；
    //   • 设置经 IAudioSettings 单例（变更广播），不直连各 manager。
    //
    // ⚠ 音频不被 reduce_motion 门控（audio §4.3）：Play 不读 MotionScale，只受静音开关/分类音量影响。
    public interface IAudioService
    {
        // 一次性播放（reveal sequencer / UI 调用点）。volumeScale 为本次叠加缩放。
        void Play(SoundId id, float volumeScale = 1f);

        // 开始循环（如 Gacha_Rolling）。同一 id 重复调用安全（去重）。
        void PlayLoop(SoundId id);

        // 停止循环（揭示开始时停 rolling）。
        void StopLoop(SoundId id);

        // 停止某类别全部声音（切屏清场用）。
        void StopCategory(AudioCategory cat);

        // 全局静音开关（独立于 reduce_motion，audio §4.1）。
        void SetMuted(bool muted);

        // 分类音量（0..1），由 IAudioSettings 订阅驱动。
        void SetCategoryVolume(AudioCategory cat, float v);
    }
}
