#nullable enable
using System;
using System.Collections.Generic;
using XiaXia.Core;
using XiaXia.Features.Shared;
using XiaXia.Features.Shared.Events;

namespace XiaXia.Features.Bond
{
    // 牵绊系统编排（B3）。实现 IBondService，由 Bootstrapper 注册到 ServiceRegistry。
    //
    // ── 解耦红线自检（ADR-3 控制清单）──
    //  • 不持有 GachaManager / EconomyManager / IGachaService / IEconomyService 字段：
    //    牵绊只读写 PlayerProfile.Shikigami[].Fragments/BondLevel（存档 schema 内部字段，非货币），
    //    不绕 EconomyManager，红线#2/#3 允许直接改本地存档数据对象（与 GachaManager 写 Shikigami 同构）。
    //  • 跨系统广播经 EventBus（#2）：bond:level_up。
    //  • 持有的引用仅为基础设施/数据：EventBus / PlayerProfile / BondConfig
    //    （BondConfig 是纯数据对象，非 manager，与 EconomyConfig 同构，#2/#3 允许）。
    //  • 牵绊无随机路径，红线#6 不适用。
    //  • 货币余额单一真源仍在 PlayerProfile.Currencies，由 EconomyManager 经 ServiceRegistry 管控；
    //    本系统的碎片是「式神持有物」而非货币，落 PlayerProfile.Shikigami[].Fragments 单一真源（#2）。
    public sealed class BondManager : IBondService
    {
        private readonly EventBus _bus;
        private readonly PlayerProfile _profile;
        private readonly BondConfig _config;

        public BondManager(EventBus bus, PlayerProfile profile, BondConfig config)
        {
            _bus = bus ?? throw new ArgumentNullException(nameof(bus));
            _profile = profile ?? throw new ArgumentNullException(nameof(profile));
            _config = config ?? throw new ArgumentNullException(nameof(config));
        }

        // 按 id 在存档式神列表中定位实例；找不到返回 null。
        private ShikigamiInstance? Find(string shikigamiId)
        {
            foreach (var s in _profile.Shikigami)
                if (s.Id == shikigamiId) return s;
            return null;
        }

        // ── IBondService：读牵绊等级 ──
        public int GetBondLevel(string shikigamiId)
        {
            var s = Find(shikigamiId);
            return s != null ? s.BondLevel : 0;
        }

        // ── IBondService：增加碎片（单一真源：直接改存档 schema 字段，非货币不绕 EconomyManager）──
        public bool AddFragments(string shikigamiId, int amount)
        {
            var s = Find(shikigamiId);
            if (s == null) return false;
            s.Fragments += amount;
            return true;
        }

        // ── IBondService：能否升阶（阈值由 BondConfig 驱动）──
        public bool CanAwaken(string shikigamiId)
        {
            var s = Find(shikigamiId);
            if (s == null) return false;
            var cost = _config.CostToNext(s.BondLevel);
            if (cost < 0) return false;            // 已满级
            return s.Fragments >= cost;
        }

        // ── IBondService：升阶（扣碎片 + BondLevel+1 + 广播）──
        public bool Awaken(string shikigamiId)
        {
            var s = Find(shikigamiId);
            if (s == null) return false;
            var cost = _config.CostToNext(s.BondLevel);
            if (cost < 0) return false;            // 已满级
            if (s.Fragments < cost) return false;   // 碎片不足
            s.Fragments -= cost;
            s.BondLevel += 1;
            _bus.Publish(new BondLevelUpEvent
            {
                ShikigamiId = shikigamiId,
                NewLevel = s.BondLevel,
            });
            return true;
        }

        // ── IBondService：羁绊加成（由 BondConfig 驱动；可空）──
        public IReadOnlyList<string> GetBondBonuses(string shikigamiId)
        {
            if (_config.BondBonuses.TryGetValue(shikigamiId, out var b))
                return b;
            return Array.Empty<string>();
        }
    }
}
