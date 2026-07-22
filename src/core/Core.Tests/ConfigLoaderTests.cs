using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using XiaXia.Core;
using XiaXia.Core.Models;
using Xunit;

namespace XiaXia.Core.Tests
{
    // 配置加载测试。数据根目录经 ConfigLoader.ResolveDataBasePath() 解析：
    // 优先环境变量 XIA_CORE_DATA，否则从运行目录向上寻找 data/。
    public class ConfigLoaderTests
    {
        private static ConfigLoader CreateLoader()
        {
            var basePath = ConfigLoader.ResolveDataBasePath();
            Assert.True(Directory.Exists(basePath),
                $"未找到 data 目录。请设置环境变量 XIA_CORE_DATA 指向仓库 data/，或在能解析到 data/ 的目录运行 dotnet test。候选失败路径：{basePath}");
            return new ConfigLoader(basePath);
        }

        [Fact]
        public void LoadShikigamiDefs_包含13式神且SSR为3()
        {
            var defs = CreateLoader().LoadShikigamiDefs();
            Assert.Equal(13, defs.Count);
            var ssrCount = defs.Values.Count(d => d.Rarity == Rarity.SSR);
            Assert.Equal(3, ssrCount);
        }

        [Fact]
        public void LoadShikigamiDefs_所有skills引用均存在()
        {
            var loader = CreateLoader();
            var defs = loader.LoadShikigamiDefs();
            var skills = loader.LoadSkillDefs();
            var missing = (from d in defs.Values
                           from sid in d.Skills
                           where !skills.ContainsKey(sid)
                           select sid).ToList();
            Assert.Empty(missing);
        }

        [Fact]
        public void LoadGachaPools_稀有度概率与初始SR正确()
        {
            var pools = CreateLoader().LoadGachaPools();
            Assert.True(pools.ContainsKey("standard"));
            Assert.True(pools.ContainsKey("newbie"));

            var std = pools["standard"];
            // 各档概率存在且 SSR == 0.02
            Assert.Equal(0.02, std.RarityRates.SSR, 5);
            Assert.Equal(0.10, std.RarityRates.SR, 5);
            Assert.Equal(0.35, std.RarityRates.R, 5);
            Assert.Equal(0.53, std.RarityRates.N, 5);
            // 概率闭合
            var sum = std.RarityRates.SSR + std.RarityRates.SR + std.RarityRates.R + std.RarityRates.N;
            Assert.Equal(1.0, sum, 5);

            // 初始 SR（仅 newbie 池含 starter_sr_id）
            Assert.Equal("sr_zhu_que", pools["newbie"].StarterSrId);
        }

        [Fact]
        public void LoadChapters_三章二十七关()
        {
            var chapters = CreateLoader().LoadChapters();
            Assert.Equal(3, chapters.Count);
            var totalStages = chapters.Sum(c => c.Stages.Count);
            Assert.Equal(27, totalStages);
        }

        [Fact]
        public void LoadBattleUIConstants_五行形状与状态图标齐全()
        {
            var ui = CreateLoader().LoadBattleUIConstants();
            Assert.Equal(5, ui.ElementShapes.Count);
            foreach (var e in new[] { "metal", "wood", "earth", "water", "fire" })
                Assert.True(ui.ElementShapes.ContainsKey(e), $"缺少元素形状：{e}");
            Assert.Equal(4, ui.StatusIcons.Count);
            Assert.True(ui.StatusIcons.ContainsKey("burn"), "缺少 burn 状态图标");
        }

        [Fact]
        public void LoadCultivationConfig_觉醒映射存在()
        {
            var cfg = CreateLoader().LoadCultivationConfig();
            Assert.Equal(3, cfg.Awaken.TierThreshold);
            Assert.True(cfg.Awaken.SkillsByShikigami.ContainsKey("ssr_qing_long"));
            Assert.Equal("skill_qing_long_awakened", cfg.Awaken.SkillsByShikigami["ssr_qing_long"]);
        }
    }
}
