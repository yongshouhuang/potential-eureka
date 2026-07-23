#nullable enable
using System.Collections.Generic;
using UnityEngine;

namespace XiaXia.Features.Audio
{
    // 音频资产库（audio §5.2）。团结引擎用 ScriptableObject 承载 SoundId → 终稿 clip 的映射。
    //
    // 替换路径：MVP 用 PlaceholderAudioProvider 程序化合成（零资产）；终稿交付后，美术/音频仅重填本资产
    // （绑定终稿 AudioClip[]），AudioService 按本库解析播放——业务代码零改动（audio §5.2）。
    [CreateAssetMenu(menuName = "XiaXia/Audio/SoundBank", fileName = "SoundBank")]
    public sealed class SoundBank : ScriptableObject
    {
        [System.Serializable]
        public sealed class Entry
        {
            public SoundId Id;
            public AudioCategory Category = AudioCategory.SFX;
            public float Volume = 1f;                 // 0..1，终稿微调配比
            public List<AudioClip> Variants = new List<AudioClip>(); // 变体（2–3 个，十连波浪随机取，audio §3.7）
        }

        public List<Entry> Entries = new List<Entry>();

        private Dictionary<SoundId, Entry>? _index;
        private bool _dirty = true;

        // 取某 SoundId 的条目（含变体/类别/音量）。未配置返回 null → AudioService 回退到 Placeholder 合成。
        public Entry? Get(SoundId id)
        {
            if (_dirty) { Rebuild(); _dirty = false; }
            return _index!.TryGetValue(id, out var e) ? e : null;
        }

        // 随机取一个变体 clip（十连波浪防齐奏轰头，audio §3.7）。无变体返回 null。
        public AudioClip? PickVariant(SoundId id, int salt = 0)
        {
            var e = Get(id);
            if (e == null || e.Variants.Count == 0) return null;
            var idx = (e.Variants.Count == 1) ? 0 : (Mathf.Abs(salt) % e.Variants.Count);
            return e.Variants[idx];
        }

        private void Rebuild()
        {
            _index = new Dictionary<SoundId, Entry>(Entries.Count);
            foreach (var e in Entries)
                if (!_index.ContainsKey(e.Id)) _index[e.Id] = e;
        }

        // 编辑器内增删条目后调用，确保索引重建。
        private void OnValidate() => _dirty = true;
    }
}
