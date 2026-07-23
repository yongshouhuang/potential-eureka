#nullable enable
using XiaXia.Core.Models;

namespace XiaXia.Features.Shared
{
    // H3：式神展示元数据（ResultCard 名/立绘/五行/牵绊）。
    // 由 ShikigamiCatalog 实现并注册到 ServiceRegistry；UI 经本接口取数，不直连数据加载。
    //
    // 解耦红线：本接口仅依赖 Core.Models（ShikigamiDef/Element）；实现只读 ConfigLoader，
    // 不持有任何 manager 字段（与 IGachaService/IEconomyService 同构，ADR-3 #3）。
    public interface IShikigamiCatalog
    {
        // 式神展示元数据。找不到返回全空（UI 退化为灰盒占位，不抛异常）。
        //   displayName : 式神名（ShikigamiDef.name）
        //   portraitKey : 立绘 sprite 查找键（= 式神 id；终稿美术按 Assets/Art/UI/Gacha/Sprites/portrait_{id} 替换）
        //   element     : 五行（ResultCard 五行形状 glyph）
        //   bondId      : 主牵绊 id（取 bond_tags[0]；ShikigamiDef 模型为 bond_tags 列表，无单 bondId 字段）
        ShikigamiMeta GetMeta(string id);

        // 扩展（H3 未要求，MVP 灰盒可用）：基础战斗属性（ResultCard ATK/HP，tabular）。
        // 终稿若改由独立数值表驱动，此方法与 GetMeta 解耦、互不影响。
        (int atk, int hp) GetCombatStats(string id);
    }

    // H3：式神元数据值对象。
    public sealed class ShikigamiMeta
    {
        public string DisplayName { get; set; } = string.Empty;
        public string PortraitKey { get; set; } = string.Empty;
        public Element Element { get; set; }
        public string BondId { get; set; } = string.Empty;
    }
}
