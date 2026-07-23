#nullable enable
using System;
using System.Collections.Generic;
using XiaXia.Core;
using XiaXia.Core.Models;
using XiaXia.Features.Shared;
using XiaXia.Features.Shared.Events;

namespace XiaXia.Features.Economy
{
    // 经济闭环编排（B1 / E1 S1–S6）。实现 IEconomyService，由 Bootstrapper 注册到 ServiceRegistry。
    //
    // ── 解耦红线自检（ADR-3 控制清单）──
    //  • 不持有 GachaManager / IGachaService 字段：抽卡扣费由 GachaManager 经
    //    ServiceRegistry.Resolve<IEconomyService>() 在调用点取用本服务，本类零反向引用（#3）。
    //  • 跨系统广播经 EventBus（#2）：economy:currency_changed / economy:reward_granted。
    //  • 持有的引用仅为基础设施/数据：EventBus / PlayerProfile / EconomyConfig / ProductionBudget
    //    （ProductionBudget 是纯逻辑助手，非 manager，与 GachaRollEngine 同构，#2/#3 允许）。
    //  • 经济无随机路径，红线#6 不适用。
    //  • 守 PlayerProfile.Currencies 为货币余额单一真源（与 Gacha 一致，#2）。
    public sealed class EconomyManager : IEconomyService
    {
        private readonly EventBus _bus;
        private readonly PlayerProfile _profile;
        private readonly EconomyConfig _config;
        private readonly ProductionBudget _budget;

        // 时间覆盖（测试注入；默认走系统时钟，见 _CurrentDate / _CurrentWeek）。
        private string _dateOverride = string.Empty;
        private int _weekOverride = -1;

        // ── H4 配套：读取余额（不改状态）──
        // UI 用于 OnEnable 初始化 CurrencyLabel 与符箓不足预检（UX §3.1/§3.2）。
        // 余额单一真源为 PlayerProfile.Currencies（与 Spend/Grant 一致，#2）。
        public int GetBalance(string currency)
        {
            return _profile.Currencies.TryGetValue(currency, out var b) ? b : 0;
        }

        public EconomyManager(EventBus bus, PlayerProfile profile, EconomyConfig config)
        {
            _bus = bus ?? throw new ArgumentNullException(nameof(bus));
            _profile = profile ?? throw new ArgumentNullException(nameof(profile));
            _config = config ?? throw new ArgumentNullException(nameof(config));
            _budget = new ProductionBudget();
        }

        // ── IEconomyService：消耗（Spend）──
        // 校验余额；不足返回 false 且不扣减；成功则扣减 + 广播 economy:currency_changed / economy:reward_granted。
        // 注意：amount<=0 视为 no-op 成功（对齐 Godot）——新手池半价会传 cost=0 的免费抽，必须放行，
        // 否则 GachaManager.Pull 会因 Spend 返回 false 而 break。若需收紧，请拍板改「amount<=0 返回 false」。
        public bool Spend(string currency, int amount, string sink)
        {
            var bal = _profile.Currencies.TryGetValue(currency, out var b) ? b : 0;
            if (bal < amount) return false;
            _profile.Currencies[currency] = bal - amount;
            _bus.Publish(new EconomyCurrencyChangedEvent { Currency = currency, Amount = -amount });
            _bus.Publish(new EconomyRewardGrantedEvent { Currency = currency, Amount = amount, Sink = sink });
            return true;
        }

        // ── IEconomyService：产出（Grant）──
        // 增加货币；遵守 boss_only 与日/周预算硬上限（exemptFromBudget=true 时豁免，如免费十连/新手赠送）。
        // 返回实际增加的量：被拦截（来源不符 / 超预算 / amount<=0）返回 0，且不改任何状态。
        // 默认「全有或全无」：超出上限整笔拒绝（对齐 Godot grant 语义）；是否改「按余量部分发放」见 m2-plan 待拍板。
        public int Grant(string currency, int amount, string source, bool exemptFromBudget = false)
        {
            if (amount <= 0) return 0;

            // 未知货币：当无上限、无 boss_only 处理（对齐 Godot _currency_cfg 返回 {}）。
            var cfg = _config.Currencies.TryGetValue(currency, out var c) ? c : null;

            // boss_only：仅 "Boss" 来源可产出（觉醒石）。
            if (cfg != null && cfg.BossOnly && source != "Boss") return 0;

            // 预算硬上限（免费十连等经 exemptFromBudget 豁免，不占日/周额度）。
            var periodKey = _budget.PeriodKey(cfg, _CurrentDate(), _CurrentWeek());
            if (!exemptFromBudget && !_budget.CanGrant(currency, amount, cfg, _profile, periodKey))
                return 0;

            var bal = _profile.Currencies.TryGetValue(currency, out var b) ? b : 0;
            _profile.Currencies[currency] = bal + amount;
            if (!exemptFromBudget)
                _budget.Record(currency, amount, periodKey, _profile);

            _bus.Publish(new EconomyCurrencyChangedEvent { Currency = currency, Amount = amount });
            return amount;
        }

        // ── 免费十连独立额度（pass2 解耦，不计入日软预算）──
        // 返回实际领取的符箓数（已领过返回 0）。经 Grant(..., exemptFromBudget:true) 发放，演示豁免路径。
        public int ClaimFreeTenPull(string? today = null)
        {
            var date = today ?? _CurrentDate();
            var ftp = _profile.FreeTenPull;
            if (ftp.LastClaimDate != date) ftp.ClaimedToday = false;  // 新的一天 -> 重置
            if (ftp.ClaimedToday) return 0;
            var amt = _config.FreeTenPull.Amount;
            ftp.LastClaimDate = date;
            ftp.ClaimedToday = true;
            return Grant("fu_lu", amt, "free_ten_pull", exemptFromBudget: true);
        }

        // ── E1-S6 资源缺口 -> 推荐产出源（来源由 data/economy.sources 驱动）──
        public IReadOnlyList<string> GetRecommendedSources(string deficitCurrency)
        {
            if (_config.Sources.TryGetValue(deficitCurrency, out var s))
                return s;
            return Array.Empty<string>();
        }

        // ── 日/周界重置（Bootstrapper / SaveManager 在加载或跨日/周时调用）──
        public void ResetDailyIfNeeded(string? today = null) =>
            _budget.ResetDailyIfNeeded(_profile, today ?? _CurrentDate());

        public void ResetWeeklyIfNeeded(int? week = null) =>
            _budget.ResetWeeklyIfNeeded(_profile, week ?? _CurrentWeek());

        // ── 测试注入时间覆盖（对齐 Godot set_date_override / set_week_override）──
        public void SetDateOverride(string date) => _dateOverride = date ?? string.Empty;
        public void SetWeekOverride(int week) => _weekOverride = week;

        // ── 时钟（引擎无关；默认 UTC 当天，AOT 安全）──
        private string _CurrentDate() =>
            string.IsNullOrEmpty(_dateOverride) ? DateTime.UtcNow.ToString("yyyy-MM-dd") : _dateOverride;

        private int _CurrentWeek() =>
            _weekOverride >= 0 ? _weekOverride : IsoWeekNumber(DateTime.UtcNow);

        // ISO 8601 周序号（netstandard2.1 无 System.Globalization.ISOWeek，手写保证 AOT 安全，无反射）。
        private static int IsoWeekNumber(DateTime date)
        {
            int dow = (int)date.DayOfWeek;            // 0=Sun..6=Sat
            int isoDow = dow == 0 ? 7 : dow;          // 1=Mon..7=Sun
            var thursday = date.AddDays(4 - isoDow);
            var yearStart = new DateTime(thursday.Year, 1, 1);
            return (int)((thursday - yearStart).TotalDays) / 7 + 1;
        }
    }
}
