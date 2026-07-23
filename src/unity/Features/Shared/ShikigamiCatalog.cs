#nullable enable
using System.Collections.Generic;
using XiaXia.Core;
using XiaXia.Core.Models;

namespace XiaXia.Features.Shared
{
    // H3：式神目录实现（读 data/shikigami/shikigami_defs.json，经 ConfigLoader）。
    // 纯数据访问器：不持有 manager 字段、不广播、不写存档（ADR-3 #2/#3）——与 GachaRollEngine 同构。
    //
    // 注册：由 Bootstrapper 以 `new ShikigamiCatalog(configLoader)` 构造并
    //       `_services.Register<IShikigamiCatalog>(catalog)`。
    public sealed class ShikigamiCatalog : IShikigamiCatalog
    {
        private readonly ConfigLoader _loader;
        private Dictionary<string, ShikigamiDef>? _injected; // 测试桩（headless 不读盘）

        public ShikigamiCatalog(ConfigLoader loader)
        {
            _loader = loader ?? throw new System.ArgumentNullException(nameof(loader));
        }

        // 测试用：注入假式神表，绕开 ConfigLoader 读盘（对齐 GachaManager.SetPoolsForTest）。
        public void SetDefsForTest(Dictionary<string, ShikigamiDef> defs) => _injected = defs;

        private Dictionary<string, ShikigamiDef> Defs() =>
            _injected ?? _loader.LoadShikigamiDefs();

        public ShikigamiMeta GetMeta(string id)
        {
            var defs = Defs();
            if (string.IsNullOrEmpty(id) || !defs.TryGetValue(id, out var d))
                return new ShikigamiMeta();

            return new ShikigamiMeta
            {
                DisplayName = d.Name,
                PortraitKey = id, // 立绘 sprite 键 = 式神 id
                Element = d.Element,
                BondId = d.BondTags.Count > 0 ? d.BondTags[0] : string.Empty,
            };
        }

        public (int atk, int hp) GetCombatStats(string id)
        {
            var defs = Defs();
            if (string.IsNullOrEmpty(id) || !defs.TryGetValue(id, out var d))
                return (0, 0);
            return (d.BaseStats.Atk, d.BaseStats.Hp);
        }
    }
}
