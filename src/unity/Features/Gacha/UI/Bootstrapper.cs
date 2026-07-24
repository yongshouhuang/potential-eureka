#nullable enable
using XiaXia.Core;
using XiaXia.Core.Models;
using XiaXia.Features.Audio;
using XiaXia.Features.Economy;
using XiaXia.Features.Gacha;
using XiaXia.Features.Shared;
using XiaXia.Features.Shared.Events;
using UnityEngine;

namespace XiaXia.Features.Gacha.UI
{
    // 运行时引导（M3 R1 收口）：在场景 Awake 阶段构造并注册全部服务、接通设置、调起 UI 控制器。
    //
    // 红线自检（ADR-3）：本类只 new 基础设施/数据并 Register 到 ServiceRegistry；
    // 不持有任何 manager 字段——Initialize 后即交出控制权，消费者一律经 ServiceRegistry 解析接口。
    // 挂法：在抽卡屏场景根挂一个空 GameObject，拖入 GachaScreenController 与 AudioService 引用。
    public sealed class Bootstrapper : MonoBehaviour
    {
        [Header("场景组件（拖拽）")]
        [SerializeField] private GachaScreenController? _gachaScreen;
        [SerializeField] private AudioService? _audioService;

        [Header("随机种子（0=系统播种；测试可固定复现）")]
        [SerializeField] private int _seed = 1;

        [Header("测试种子：无存档时初始符箓（灰盒验证用，正式存档由新手引导发放）")]
        [SerializeField] private int _seedFuLu = 50;

        private void Awake()
        {
            var bus = new EventBus();
            var profile = new PlayerProfile();
            // MVP 灰盒验证：空档案默认无符箓，无法触发抽卡。注入测试种子（仅当存档无该货币时），
            // 正式版本应改由新手引导/首登奖励发放，不在 Bootstrapper 硬编码。
            if (!profile.Currencies.ContainsKey("fu_lu")) profile.Currencies["fu_lu"] = _seedFuLu;
            var gameState = new GameState(bus, profile);
            var services = new ServiceRegistry();

            // 基础设施（ConfigLoader 不依赖引擎 API；ResolveDataBasePath 走环境变量/相对候选，
            // 本机若解析不到 data/ 可设 XIA_CORE_DATA 环境变量指向仓库根 data/）。
            var dataPath = ConfigLoader.ResolveDataBasePath();
            var loader = new ConfigLoader(dataPath);
            var rng = new RngWrapper(_seed);

            services.Register<EventBus>(bus);
            services.Register<GameState>(gameState);
            services.Register<PlayerProfile>(profile);
            services.Register<ServiceRegistry>(services);

            // 设置单例（audio §4.1 / R4 无障碍）：纯 C#，读写 PlayerProfile.Settings。
            services.Register<IAudioSettings>(new XiaXia.Features.Audio.AudioSettings(profile));
            services.Register<IAccessibilitySettings>(new AccessibilitySettings(profile));

            // 数据访问（H3）：式神目录读 data/shikigami/shikigami_defs.json。
            services.Register<IShikigamiCatalog>(new ShikigamiCatalog(loader));

            // 业务服务：经济（B1/E1）+ 抽卡（B2/E2）。GachaManager 构造接收 services 引用，
            // 调用点再 Resolve<IEconomyService>，故 EconomyManager 须先注册（顺序已满足）。
            EconomyConfig econConfig;
            try { econConfig = loader.LoadConfig<EconomyConfig>("economy/economy_config.json"); }
            catch { econConfig = new EconomyConfig(); } // data 缺失时不崩，货币按未知货币处理
            services.Register<IEconomyService>(new EconomyManager(bus, profile, econConfig));
            services.Register<IGachaService>(new GachaManager(bus, loader, profile, services, rng));

            // 音频服务：自身注册 IAudioService 并接通 IAudioSettings（audio §4.1）。
            _audioService?.Initialize(services);

            // 抽卡屏：经 ServiceRegistry 解析全部接口依赖（红线#1/#3）。
            // 兜底：重编译等导致序列化引用丢失时，按类型在场景内查找，避免手动重新拖拽。
            var screen = _gachaScreen ?? FindObjectOfType<GachaScreenController>();
            screen?.Initialize(services, bus);

            // 灰盒占位：订阅「获取符箓」意图事件并打日志；真实导航（去推图）由外部系统接管（ADR-3）。
            bus.Subscribe<GachaAcquireIntentEvent>(e =>
                Debug.Log($"[Gacha] AcquireIntent received: reason={e.Reason} (gray-box stub; real nav TBD)"));
        }
    }
}
