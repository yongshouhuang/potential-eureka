#nullable enable
using System.Collections.Generic;
using XiaXia.Core.Models;

namespace XiaXia.Features.Economy
{
    // 纯预算逻辑（B1 / E1）。零依赖、可独立单测（与 GachaRollEngine 同构）。
    // 把「周期判定 / 上限校验 / 产出记录 / 日周界重置」从 EconomyManager 抽离，使其只做编排 + 广播。
    // 直接读写传入的 PlayerProfile.ProductionTracker（单一真源的产出追踪），不持有它以外的状态。
    //
    // 红线安全：本类纯函数式、无随机、无 EventBus、无 manager 引用，IL2CPP/AOT 安全（无反射，ADR-3 R7）。
    public sealed class ProductionBudget
    {
        // 预算上限（按优先级）：daily_soft_cap > daily_cap > weekly_cap；均缺 => 无上限（返回 -1）。
        // 对齐 Godot _within_budget 的 cfg.has() 优先级链。
        public int ResolveCap(CurrencyDef? cfg)
        {
            if (cfg == null) return -1;
            if (cfg.DailySoftCap.HasValue) return cfg.DailySoftCap.Value;
            if (cfg.DailyCap.HasValue)     return cfg.DailyCap.Value;
            if (cfg.WeeklyCap.HasValue)    return cfg.WeeklyCap.Value;
            return -1;
        }

        // 周期键：含 weekly_cap => "W{week}"（如 "W30"）；否则 => "D{date}"（如 "D2026-07-20"）。
        // 必须与 PlayerProfile.ProductionTracker.Period 注释的约定完全一致（GachaManager 旧逻辑同形）。
        public string PeriodKey(CurrencyDef? cfg, string currentDate, int currentWeek)
        {
            if (cfg != null && cfg.WeeklyCap.HasValue) return "W" + currentWeek;
            return "D" + currentDate;
        }

        // 是否允许本次产出（不修改状态）。
        // cap<0 => 永远允许；新周期（stored.period != key）从 0 计：amount<=cap 即可；否则 used+amount<=cap。
        // 默认「全有或全无」：超出上限整笔拒绝（对齐 Godot grant 语义；是否改「按余量部分发放」见 m2-plan 待拍板）。
        public bool CanGrant(string currency, int amount, CurrencyDef? cfg, PlayerProfile profile, string periodKey)
        {
            var cap = ResolveCap(cfg);
            if (cap < 0) return true;
            if (!profile.ProductionTracker.TryGetValue(currency, out var t) || t.Period != periodKey)
                return amount <= cap;               // 新周期，从 0 计
            return t.Amount + amount <= cap;
        }

        // 记录本次产出（仅在非豁免时由调用方调用）。跨周期自动把 amount 重置为 0 再累加。
        public void Record(string currency, int amount, string periodKey, PlayerProfile profile)
        {
            if (!profile.ProductionTracker.TryGetValue(currency, out var t) || t.Period != periodKey)
                t = new ProductionTracker { Period = periodKey, Amount = 0 };
            t.Amount += amount;
            profile.ProductionTracker[currency] = t;
        }

        // 日界重置：把所有「非周」追踪器切到当天（amount 归零）；并跨日重置免费十连领取标记。
        // 由 Bootstrapper / SaveManager 在加载或跨日时调用（对齐 Godot reset_daily_if_needed）。
        public void ResetDailyIfNeeded(PlayerProfile profile, string today)
        {
            var key = "D" + today;
            var currencies = new List<string>(profile.ProductionTracker.Keys);
            foreach (var currency in currencies)
            {
                if (!profile.ProductionTracker.TryGetValue(currency, out var t)) continue;
                if (!t.Period.StartsWith("W") && t.Period != key)
                    profile.ProductionTracker[currency] = new ProductionTracker { Period = key, Amount = 0 };
            }
            var ftp = profile.FreeTenPull;
            if (ftp.LastClaimDate != today) ftp.ClaimedToday = false;
        }

        // 周界重置：把「周」追踪器切到当周（amount 归零）。
        // 由 Bootstrapper / SaveManager 在加载或跨周时调用（对齐 Godot reset_weekly_if_needed）。
        public void ResetWeeklyIfNeeded(PlayerProfile profile, int week)
        {
            var key = "W" + week;
            var currencies = new List<string>(profile.ProductionTracker.Keys);
            foreach (var currency in currencies)
            {
                if (!profile.ProductionTracker.TryGetValue(currency, out var t)) continue;
                if (t.Period.StartsWith("W") && t.Period != key)
                    profile.ProductionTracker[currency] = new ProductionTracker { Period = key, Amount = 0 };
            }
        }
    }
}
