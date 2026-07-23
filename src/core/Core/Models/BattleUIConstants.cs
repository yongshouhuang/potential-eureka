using System.Collections.Generic;
using Newtonsoft.Json;

namespace XiaXia.Core.Models
{
    // 战斗 HUD 数据驱动配置（data/battle/battle_ui_constants.json，顶层即本对象）。
    public class BattleUIConstants
    {
        // 五行 -> 形状（triangle/circle/square/diamond/pentagon），键为小写元素名。
        [JsonProperty("element_shapes")] public Dictionary<string, string> ElementShapes { get; set; }
            = new Dictionary<string, string>();
        [JsonProperty("shape_redundancy")] public bool ShapeRedundancy { get; set; }
        [JsonProperty("hotzone_min_px")] public int HotzoneMinPx { get; set; }
        [JsonProperty("mobile_hotzone_min_px")] public int MobileHotzoneMinPx { get; set; }
        // 状态图标，键为 burn/armor_break/poison/momentum。
        [JsonProperty("status_icons")] public Dictionary<string, StatusIconDef> StatusIcons { get; set; }
            = new Dictionary<string, StatusIconDef>();
        [JsonProperty("combo_banner")] public ComboBannerDef ComboBanner { get; set; } = new ComboBannerDef();
        [JsonProperty("qi_gauge")] public QiGaugeDef QiGauge { get; set; } = new QiGaugeDef();
        [JsonProperty("skill_button")] public SkillButtonDef SkillButton { get; set; } = new SkillButtonDef();
        [JsonProperty("layout_breakpoints")] public LayoutBreakpoints LayoutBreakpoints { get; set; } = new LayoutBreakpoints();
        [JsonProperty("dual_end_safe_area")] public DualEndSafeArea DualEndSafeArea { get; set; } = new DualEndSafeArea();
    }

    public class StatusIconDef
    {
        [JsonProperty("label")] public string Label { get; set; } = string.Empty;
        [JsonProperty("element")] public Element Element { get; set; }
        [JsonProperty("kind")] public string Kind { get; set; } = string.Empty;   // dot/debuff/selfbuff
        [JsonProperty("glyph")] public string Glyph { get; set; } = string.Empty;
        [JsonProperty("silhouette")] public string Silhouette { get; set; } = string.Empty;
        [JsonProperty("max_stacks")] public int MaxStacks { get; set; }
        [JsonProperty("max_turns")] public int MaxTurns { get; set; }
    }

    public class SizePct
    {
        [JsonProperty("pc")] public double Pc { get; set; }
        [JsonProperty("mobile")] public double Mobile { get; set; }
    }

    public class SizePx
    {
        [JsonProperty("pc")] public int Pc { get; set; }
        [JsonProperty("mobile")] public int Mobile { get; set; }
    }

    public class ComboBannerDef
    {
        [JsonProperty("anchor")] public string Anchor { get; set; } = string.Empty;
        [JsonProperty("anchor_id")] public int AnchorId { get; set; }
        [JsonProperty("rune_ring")] public string RuneRing { get; set; } = string.Empty;
        [JsonProperty("tabular")] public bool Tabular { get; set; }
        [JsonProperty("max_width_pct")] public SizePct MaxWidthPct { get; set; } = new SizePct();
        [JsonProperty("max_height_px")] public SizePx MaxHeightPx { get; set; } = new SizePx();
        [JsonProperty("margin_top_px")] public SizePx MarginTopPx { get; set; } = new SizePx();
        [JsonProperty("stay_ms")] public int StayMs { get; set; }
        [JsonProperty("rise_in_ms")] public int RiseInMs { get; set; }
        [JsonProperty("tabular_precision")] public int TabularPrecision { get; set; }
        [JsonProperty("double_border")] public bool DoubleBorder { get; set; }
    }

    public class QiGaugeDef
    {
        [JsonProperty("pips")] public int Pips { get; set; }
        [JsonProperty("pip_shape_from_element")] public bool PipShapeFromElement { get; set; }
        // 五行 -> 形状。
        [JsonProperty("pip_glyph_by_element")] public Dictionary<string, string> PipGlyphByElement { get; set; }
            = new Dictionary<string, string>();
        [JsonProperty("tabular")] public bool Tabular { get; set; }
        [JsonProperty("hotzone_min_px")] public int HotzoneMinPx { get; set; }
        [JsonProperty("mobile_pip_px")] public int MobilePipPx { get; set; }
        [JsonProperty("label_format")] public string LabelFormat { get; set; } = string.Empty;
        [JsonProperty("double_border")] public bool DoubleBorder { get; set; }
    }

    public class SkillButtonDef
    {
        [JsonProperty("hotzone_min_px")] public int HotzoneMinPx { get; set; }
        [JsonProperty("mobile_min_px")] public int MobileMinPx { get; set; }
        [JsonProperty("qi_cost_badge")] public bool QiCostBadge { get; set; }
        [JsonProperty("disabled_style")] public string DisabledStyle { get; set; } = string.Empty;
        [JsonProperty("double_border")] public bool DoubleBorder { get; set; }
    }

    public class LayoutBreakpoints
    {
        [JsonProperty("mobile")] public int Mobile { get; set; }
        [JsonProperty("hybrid")] public int Hybrid { get; set; }
    }

    public class SafeAreaPc
    {
        [JsonProperty("min_width")] public int MinWidth { get; set; }
        [JsonProperty("orientation")] public string Orientation { get; set; } = string.Empty;
        [JsonProperty("no_horizontal_scroll")] public bool NoHorizontalScroll { get; set; }
    }

    public class SafeAreaMobile
    {
        [JsonProperty("max_width")] public int MaxWidth { get; set; }
        [JsonProperty("orientation")] public string Orientation { get; set; } = string.Empty;
        [JsonProperty("bottom_bar_min_px")] public int BottomBarMinPx { get; set; }
        [JsonProperty("no_horizontal_scroll")] public bool NoHorizontalScroll { get; set; }
    }

    public class DualEndSafeArea
    {
        [JsonProperty("pc")] public SafeAreaPc Pc { get; set; } = new SafeAreaPc();
        [JsonProperty("mobile")] public SafeAreaMobile Mobile { get; set; } = new SafeAreaMobile();
    }
}
