using System;
using System.Collections.Generic;

namespace XiaXia.Core
{
    // 服务注册表：manager 注册自身（Register），消费者按接口/类型解析（Resolve/TryResolve）。
    // 硬红线：任何消费者都不得持有具体 manager 的字段引用，一律经本表解耦。
    public sealed class ServiceRegistry
    {
        private readonly Dictionary<Type, object> _services = new Dictionary<Type, object>();
        private readonly object _lock = new object();

        // 注册服务实例。除按 TService 注册外，还会按实例实现的各接口（不含 IService 基接口）登记，
        // 便于消费者按契约接口解析。
        public void Register<TService>(TService instance) where TService : class
        {
            if (instance == null) throw new ArgumentNullException(nameof(instance));
            lock (_lock)
            {
                _services[typeof(TService)] = instance;
                foreach (var i in instance.GetType().GetInterfaces())
                {
                    if (i == typeof(IService)) continue; // 避免多 manager 互覆 IService 槽位
                    _services[i] = instance;
                }
            }
        }

        // 解析服务；未注册时抛 InvalidOperationException。
        public TService Resolve<TService>() where TService : class
        {
            if (!TryResolve<TService>(out var svc))
                throw new InvalidOperationException($"未注册服务：{typeof(TService).FullName}");
            return svc;
        }

        // 安全解析；未注册返回 false 且 svc 为 null。
        public bool TryResolve<TService>(out TService svc) where TService : class
        {
            lock (_lock)
            {
                if (_services.TryGetValue(typeof(TService), out var obj) && obj is TService typed)
                {
                    svc = typed;
                    return true;
                }
            }
            svc = null;
            return false;
        }

        public bool IsRegistered<TService>() where TService : class
        {
            lock (_lock) return _services.ContainsKey(typeof(TService));
        }

        public void Unregister<TService>() where TService : class
        {
            lock (_lock) _services.Remove(typeof(TService));
        }
    }
}
