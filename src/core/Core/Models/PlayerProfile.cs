#nullable enable
using System.Collections.Generic;

namespace XiaXia.Core.Models
{
    // 玩家档案中央数据（存档载体 / 单一真源）— save schema v1（对齐 Godot GameState.gd §1.7）。
    //
    // 纯数据对象，**非 manager**；manager 可读写它（ADR-3 红线 #2/#3 允许持有本地数据对象）。
    // M1 的 Core.GameState 仅为 stub（turn/activeUnit + 通用键值）；本类是 M2 真正的存档 schema。
    // DECISION-D：自 XiaXia.Features.Shared 提升进 Core.Models（动 M1 资产，依赖方向不变：
    // Features 仍可见 Core.Models.PlayerProfile，Core 不反向依赖 Features）。
    public sealed class PlayerProfile
    {
        public const int SchemaVersion = 1;

        // 货币余额：fu_lu/ling_yu/ling_qi/po_dan/jue_xing_shi -> int
        public Dictionary<string, int> Currencies { get; set; } = new Dictionary<string, int>();

        // 抽卡保底：pool_id -> 连续非 SSR 抽数（不跨池）
        public Dictionary<string, int> Pity { get; set; } = new Dictionary<string, int>();

        // 式神列表：{id,level,breakthrough,awakened_skills,bond_level,fragments}
        public List<ShikigamiInstance> Shikigami { get; set; } = new List<ShikigamiInstance>();

        // 卡组：4 式神 id + 1 法宝 id
        public List<string> Deck { get; set; } = new List<string>();

        // 设置：high_contrast/text_scale/layout_override/...
        public Dictionary<string, object> Settings { get; set; } = new Dictionary<string, object>();

        // 进度：chapters_cleared/stars ...
        public Dictionary<string, object> Progression { get; set; } = new Dictionary<string, object>();

        // 免费十连独立额度（pass2 解耦，不计入软预算）
        public FreeTenPull FreeTenPull { get; set; } = new FreeTenPull();

        // 产出追踪：currency -> { period, amount }，日/周预算硬上限判定
        public Dictionary<string, ProductionTracker> ProductionTracker { get; set; }
            = new Dictionary<string, ProductionTracker>();

        // 抽卡进度：pool_id -> { pulls_done, starter_claimed }，新手半价计数与必出 SR
        public Dictionary<string, GachaProgressEntry> GachaProgress { get; set; }
            = new Dictionary<string, GachaProgressEntry>();

        // 存档元信息
        public SaveMeta Meta { get; set; } = new SaveMeta();
    }

    // 式神实例（玩家持有的一份）。
    public sealed class ShikigamiInstance
    {
        public string Id { get; set; } = string.Empty;
        public int Level { get; set; } = 1;
        public int Breakthrough { get; set; } = 0;
        public List<string> AwakenedSkills { get; set; } = new List<string>();
        public int BondLevel { get; set; } = 0;
        public int Fragments { get; set; } = 0;
    }

    // 免费十连额度状态。
    public sealed class FreeTenPull
    {
        public string LastClaimDate { get; set; } = string.Empty;
        public bool ClaimedToday { get; set; }
    }

    // 产出追踪（日/周预算）。
    public sealed class ProductionTracker
    {
        public string Period { get; set; } = string.Empty; // "D2026-07-20" / "W30"
        public int Amount { get; set; }
    }

    // 抽卡进度（每池独立）。
    public sealed class GachaProgressEntry
    {
        public int PullsDone { get; set; }
        public bool StarterClaimed { get; set; }
    }

    // 存档元信息。
    public sealed class SaveMeta
    {
        public int SchemaVersion { get; set; } = PlayerProfile.SchemaVersion;
        public long LastWriteTs { get; set; }
        public string DeviceId { get; set; } = string.Empty;
        public string Checksum { get; set; } = string.Empty;
    }
}
