#nullable enable
using NUnit.Framework;
using XiaXia.Core;
using XiaXia.Core.Models;
using XiaXia.Features.Audio;

namespace XiaXia.Features.Audio.Tests
{
    // 音频契约单测（Unity EditMode）。纯逻辑（SoundId 映射 / AudioSettings 持久化）可 headless；
    // PlaceholderAudioProvider 用 AudioClip.Create（Unity Editor 可用）。
    [TestFixture]
    public class AudioTests
    {
        // SoundId.RevealTopLayerFor 稀有度映射（audio §3.1）。
        [Test]
        public void RevealTopLayerFor_MapsRarity()
        {
            Assert.AreEqual(SoundId.Gacha_Reveal_N, Rarity.N.RevealTopLayerFor());
            Assert.AreEqual(SoundId.Gacha_Reveal_R, Rarity.R.RevealTopLayerFor());
            Assert.AreEqual(SoundId.Gacha_Reveal_SR, Rarity.SR.RevealTopLayerFor());
            Assert.AreEqual(SoundId.Gacha_Reveal_SSR, Rarity.SSR.RevealTopLayerFor());
        }

        // AudioSettings：落点对齐 PlayerProfile.Settings（存档 schema v1），变更广播 Changed。
        [Test]
        public void AudioSettings_PersistsToProfile_AndBroadcasts()
        {
            var profile = new PlayerProfile();
            var s = new AudioSettings(profile);
            var fires = 0;
            s.Changed += () => fires++;

            s.SfxEnabled = false; // 默认 true → 变更
            Assert.AreEqual(1, fires, "值变化才广播");
            Assert.IsTrue(profile.Settings.TryGetValue("audio_sfx_enabled", out var b) && b is bool bb && bb == false,
                "sfx_enabled 持久化到 Settings");

            s.SfxEnabled = false; // 无变化
            Assert.AreEqual(1, fires, "无变化不重复广播");

            s.MasterVolume = 0.5f;
            Assert.IsTrue(profile.Settings.TryGetValue("audio_master_volume", out var v) && v is double d && d == 0.5,
                "master_volume 持久化为 double");
            Assert.AreEqual(0.5f, s.MasterVolume, 1e-6f, "回读一致");
        }

        // PlaceholderAudioProvider：零资产合成 blip（audio §5.1），可听辨稀有度差异。
        [Test]
        public void PlaceholderAudioProvider_GetClip_ReturnsNonNullClip()
        {
            var p = new PlaceholderAudioProvider();
            var clip = p.GetClip(SoundId.Gacha_Reveal_SSR);
            Assert.IsNotNull(clip, "合成 clip 非空");
            Assert.Greater(clip.length, 0f, "有时长");
            // SSR climax 时长最长（1.8s），N 最短（0.3s）——QA 可听辨。
            var n = new PlaceholderAudioProvider().GetClip(SoundId.Gacha_Reveal_N);
            Assert.Less(n.length, clip.length, "SSR climax 长于 N");
        }
    }
}
