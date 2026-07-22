using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace XiaXia.Core.Models
{
    // 战斗 HUD 数据驱动配置（data/battle/battle_ui_constants.json，顶层即本对象）。
    public class BattleUIConstants
    {
        // 五行 -> 形状（triangle/circle/square/diamond/pentagon），键为小写元素名。
        [JsonPropertyName("element_shapes")] public Dictionary<string, string> ElementShapes { get; set; }
            = new Dictionary<string, string>();
        [JsonPropertyName("shape_redundancy")] public bool ShapeRedundancy { get; set; }
        [JsonPropertyName("hotzone_min_px")] public int HotzoneMinPx { get; set; }
        [JsonPropertyName("mobile_hotzone_min_px")] public int MobileHotzoneMinPx { get; set; }
        // 状态图标，键为 burn/armor_break/poison/momentum。
        [JsonPropertyName("status_icons")] public Dictionary<string, StatusIconDef> StatusIcons { get; set; }
            = new Dictionary<string, StatusIconDef>();
        [JsonPropertyName("combo_banner")] public ComboBannerDef ComboBanner { get; set; } = new ComboBannerDef();
        [JsonPropertyName("qi_gauge")] public QiGaugeDef QiGauge { get; set; } = new QiGaugeDef();
        [JsonPropertyName("skill_button")] public SkillButtonDef SkillButton { get; set; } = new SkillButtonDef();
        [JsonPropertyName("layout_breakpoints")] public LayoutBreakpoints LayoutBreakpoints { get; set; } = new LayoutBreakpoints();
        [JsonPropertyName("dual_end_safe_area")] public DualEndSafeArea DualEndSafeArea { get; set; } = new DualEndSafeArea();
    }

    public class StatusIconDef
    {
        [JsonPropertyName("label")] public string Label { get; set; } = string.Empty;
        [JsonPropertyName("element")] public Element Element { get; set; }
        [JsonPropertyName("kind")] public string Kind { get; set; } = string.Empty;   // dot/debuff/selfbuff
        [JsonPropertyName("glyph")] public string Glyph { get; set; } = string.Empty;
        [JsonPropertyName("silhouette")] public string Silhouette { get; set; } = string.Empty;
        [JsonPropertyName("max_stacks")] public int MaxStacks { get; set; }
        [JsonPropertyName("max_turns")] public int MaxTurns { get; set; }
    }

    public class SizePct
    {
        [JsonPropertyName("pc")] public double Pc { get; set; }
        [JsonPropertyName("mobile")] public double Mobile { get; set; }
    }

    public class SizePx
    {
        [JsonPropertyName("pc")] public int Pc { get; set; }
        [JsonPropertyName("mobile")] public int Mobile { get; set; }
    }

    public class ComboBannerDef
    {
        [JsonPropertyName("anchor")] public string Anchor { get; set; } = string.Empty;
        [JsonPropertyName("anchor_id")] public int AnchorId { get; set; }
        [JsonPropertyName("rune_ring")] public string RuneRing { get; set; } = string.Empty;
        [JsonPropertyName("tabular")] public bool Tabular { get; set; }
        [JsonPropertyName("max_width_pct")] public SizePct MaxWidthPct { get; set; } = new SizePct();
        [JsonPropertyName("max_height_px")] public SizePx MaxHeightPx { get; set; } = new SizePx();
        [JsonPropertyName("margin_top_px")] public SizePx MarginTopPx { get; set; } = new SizePx();
        [JsonPropertyName("stay_ms")] public int StayMs { get; set; }
        [JsonPropertyName("rise_in_ms")] public int RiseInMs { get; set; }
        [JsonPropertyName("tabular_precision")] public int TabularPrecision { get; set; }
        [JsonPropertyName("double_border")] public bool DoubleBorder { get; set; }
    }

    public class QiGaugeDef
    {
        [JsonPropertyName("pips")] public int Pips { get; set; }
        [JsonPropertyName("pip_shape_from_element")] public bool PipShapeFromElement { get; set; }
        // 五行 -> 形状。
        [JsonPropertyName("pip_glyph_by_element")] public Dictionary<string, string> PipGlyphByElement { get; set; }
            = new Dictionary<string, string>();
        [JsonPropertyName("tabular")] public bool Tabular { get; set; }
        [JsonPropertyName("hotzone_min_px")] public int HotzoneMinPx { get; set; }
        [JsonPropertyName("mobile_pip_px")] public int MobilePipPx { get; set; }
        [JsonPropertyName("label_format")] public string LabelFormat { get; set; } = string.Empty;
        [JsonPropertyName("double_border")] public bool DoubleBorder { get; set; }
    }

    public class SkillButtonDef
    {
        [JsonPropertyName("hotzone_min_px")] public int HotzoneMinPx { get; set; }
        [JsonPropertyName("mobile_min_px")] public int MobileMinPx { get; set; }
        [JsonPropertyName("qi_cost_badge")] public bool QiCostBadge { get; set; }
        [JsonPropertyName("disabled_style")] public string DisabledStyle { get; set; } = string.Empty;
        [JsonPropertyName("double_border")] public bool DoubleBorder { get; set; }
    }

    public class LayoutBreakpoints
    {
        [JsonPropertyName("mobile")] public int Mobile { get; set; }
        [JsonPropertyName("hybrid")] public int Hybrid { get; set; }
    }

    public class SafeAreaPc
    {
        [JsonPropertyName("min_width")] public int MinWidth { get; set; }
        [JsonPropertyName("orientation")] public string Orientation { get; set; } = string.Empty;
        [JsonPropertyName("no_horizontal_scroll")] public bool NoHorizontalScroll { get; set; }
    }

    public class SafeAreaMobile
    {
        [JsonPropertyName("max_width")] public int MaxWidth { get; set; }
        [JsonPropertyName("orientation")] public string Orientation { get; set; } = string.Empty;
        [JsonPropertyName("bottom_bar_min_px")] public int BottomBarMinPx { get; set; }
        [JsonPropertyName("no_horizontal_scroll")] public bool NoHorizontalScroll { get; set; }
    }

    public class DualEndSafeArea
    {
        [JsonPropertyName("pc")] public SafeAreaPc Pc { get; set; } = new SafeAreaPc();
        [JsonPropertyName("mobile")] public SafeAreaMobile Mobile { get; set; } = new SafeAreaMobile();
    }
}
