#nullable enable
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Audio;
using XiaXia.Core;

namespace XiaXia.Features.Audio
{
    // 音频服务实现（audio §3.2 / §3.6 / §3.7）。MonoBehaviour，置于抽卡屏（或常驻音频）场景，
    // 由 Bootstrapper 调 Initialize(services,bus) 注册为 IAudioService 并接通 IAudioSettings。
    //
    // 解耦红线（ADR-3 / audio §0.3 / §6）：不 import 任何 manager；只经
    //   • ServiceRegistry 注册自身（供 UI/sequencer 经 IAudioService 调用）；
    //   • IAudioSettings 订阅静音/音量变更；
    //   • 不订阅 EventBus（揭示音频由 reveal sequencer 驱动，不随原始事件齐发，audio §3.4）。
    //
    // 性能（audio §3.7）：AudioSource 对象池（≤24 语音），十连错峰由 sequencer 吸收；变体/随机化由 SoundBank 提供。
    // 零资产：未配置 SoundBank 时回退 PlaceholderAudioProvider 程序化合成（audio §5.1）。
    [RequireComponent(typeof(AudioSource))]
    public sealed class AudioService : MonoBehaviour, IAudioService
    {
        [Header("混音总线（可选；不填则仅做音量数学，不路由）")]
        [SerializeField] private AudioMixer? _mixer;

        [Header("资产库（可选；空则 Placeholder 程序化合成）")]
        [SerializeField] private SoundBank? _bank;

        [Header("池大小（audio §3.7：≤24 语音）")]
        [SerializeField] private int _poolSize = 24;

        private ServiceRegistry? _services;
        private IAudioSettings? _settings;

        private readonly List<AudioSource> _pool = new List<AudioSource>();
        private readonly Dictionary<AudioSource, SoundId> _active = new Dictionary<AudioSource, SoundId>();
        private readonly Dictionary<SoundId, AudioSource> _loops = new Dictionary<SoundId, AudioSource>();
        private readonly PlaceholderAudioProvider _placeholder = new PlaceholderAudioProvider();

        // 音量状态（audio §4.1，独立于 reduce_motion）
        private float _masterVolume = 1f;
        private bool _sfxEnabled = true;
        private bool _musicEnabled = true;
        private bool _muted = false;
        private int _salt;

        private void Awake() => BuildPool();

        // 由 Bootstrapper 调用：注册服务 + 接通设置。
        public void Initialize(ServiceRegistry services)
        {
            _services = services;
            services.Register<IAudioService>(this);
            if (services.TryResolve<IAudioSettings>(out var s))
            {
                _settings = s;
                _settings.Changed += OnSettingsChanged;
                PullSettings();
            }
        }

        private void OnDestroy()
        {
            if (_settings != null) _settings.Changed -= OnSettingsChanged;
        }

        // —— IAudioService ——
        public void Play(SoundId id, float volumeScale = 1f)
        {
            var src = AcquireSource();
            if (src == null) return;
            src.clip = ResolveClip(id);
            src.loop = false;
            src.volume = EffectiveVolume(id, volumeScale);
            src.outputAudioMixerGroup = ResolveGroup(CategoryOf(id));
            _active[src] = id;
            src.Play();
        }

        public void PlayLoop(SoundId id)
        {
            if (_loops.ContainsKey(id)) return; // 去重
            var src = AcquireSource();
            if (src == null) return;
            src.clip = ResolveClip(id);
            src.loop = true;
            src.volume = EffectiveVolume(id, 1f);
            src.outputAudioMixerGroup = ResolveGroup(CategoryOf(id));
            _active[src] = id;
            src.Play();
            _loops[id] = src;
        }

        public void StopLoop(SoundId id)
        {
            if (!_loops.TryGetValue(id, out var src)) return;
            src.Stop();
            src.loop = false;
            _loops.Remove(id);
            _active.Remove(src);
        }

        public void StopCategory(AudioCategory cat)
        {
            // 停止该类别正在播放的一次性语音
            foreach (var kv in _active)
            {
                if (kv.Value != default && CategoryOf(kv.Key) == cat && kv.Key.isPlaying)
                {
                    kv.Key.Stop();
                    _active.Remove(kv.Key);
                }
            }
            // 停止该类别的循环
            var toStop = new List<SoundId>();
            foreach (var kv in _loops)
                if (CategoryOf(kv.Key) == cat) toStop.Add(kv.Key);
            foreach (var k in toStop) StopLoop(k);
        }

        public void SetMuted(bool muted) { _muted = muted; }
        public void SetCategoryVolume(AudioCategory cat, float v)
        {
            // 预留：当前音量已在 EffectiveVolume 数学合成；如需经 AudioMixer 暴露参数接管，在此设置。
        }

        // —— 内部 ——
        private void BuildPool()
        {
            for (var i = 0; i < _poolSize; i++)
            {
                var go = new GameObject($"AudioSrc_{i}") { hideFlags = HideFlags.HideAndDontSave };
                go.transform.SetParent(transform);
                var src = go.AddComponent<AudioSource>();
                src.playOnAwake = false;
                _pool.Add(src);
            }
        }

        private AudioSource? AcquireSource()
        {
            foreach (var s in _pool) if (!s.isPlaying) return s;
            // 池满：抢占索引最小者（移动端 polyphony 峰值保护，audio §3.7）
            return _pool.Count > 0 ? _pool[0] : null;
        }

        private AudioClip ResolveClip(SoundId id)
        {
            if (_bank != null)
            {
                var clip = _bank.PickVariant(id, _salt++);
                if (clip != null) return clip;
            }
            return _placeholder.GetClip(id);
        }

        private AudioCategory CategoryOf(SoundId id)
        {
            var e = _bank?.Get(id);
            return e?.Category ?? DefaultCategory(id);
        }

        // 类目默认映射（audio §3.6）：rolling/ambient→Ambient；UI 类→UI；序章→VO；其余→SFX。
        private static AudioCategory DefaultCategory(SoundId id) => id switch
        {
            SoundId.Gacha_Rolling => AudioCategory.Ambient,
            SoundId.Gacha_Pool_Select => AudioCategory.UI,
            SoundId.Gacha_SinglePull_Click => AudioCategory.UI,
            SoundId.Gacha_TenPull_Click => AudioCategory.UI,
            SoundId.Gacha_Insufficient => AudioCategory.UI,
            SoundId.Gacha_Screen_Close => AudioCategory.UI,
            SoundId.Bond_Prologue_Open => AudioCategory.VO,
            _ => AudioCategory.SFX,
        };

        private AudioMixerGroup? ResolveGroup(AudioCategory cat)
        {
            if (_mixer == null) return null;
            var groups = _mixer.FindMatchingGroups(cat.ToString());
            return groups.Length > 0 ? groups[0] : null;
        }

        // 最终音量 = 条目音量 * 调用缩放 * 类别门控(sfx/music) * 主音量 * 静音。
        // 注意：不读 reduce_motion（audio §4.3）。
        private float EffectiveVolume(SoundId id, float volumeScale)
        {
            var cat = CategoryOf(id);
            var gate = cat switch
            {
                AudioCategory.SFX or AudioCategory.UI => _sfxEnabled ? 1f : 0f,
                AudioCategory.Music or AudioCategory.Ambient => _musicEnabled ? 1f : 0f,
                _ => 1f,
            };
            var entry = _bank?.Get(id);
            var baseVol = entry?.Volume ?? 1f;
            var v = baseVol * volumeScale * gate * _masterVolume * (_muted ? 0f : 1f);
            return Mathf.Clamp01(v);
        }

        // —— 设置接通（audio §4.1）——
        private void OnSettingsChanged() => PullSettings();
        private void PullSettings()
        {
            if (_settings == null) return;
            _masterVolume = _settings.MasterVolume;
            _sfxEnabled = _settings.SfxEnabled;
            _musicEnabled = _settings.MusicEnabled;
        }
    }
}
