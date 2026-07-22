using System;
using System.Collections.Generic;

namespace XiaXia.Core
{
    // 类型化事件总线：发布/订阅，主线程假定。映射 Godot autoload/EventBus 与 signals。
    // 内部以 Type -> 处理器列表 维护；调用方无需持有任何 manager 引用。
    public sealed class EventBus
    {
        private readonly Dictionary<Type, List<Delegate>> _handlers = new Dictionary<Type, List<Delegate>>();
        private readonly object _lock = new object();

        // 订阅类型为 T 的事件。
        public void Subscribe<T>(Action<T> handler)
        {
            if (handler == null) throw new ArgumentNullException(nameof(handler));
            lock (_lock)
            {
                if (!_handlers.TryGetValue(typeof(T), out var list))
                {
                    list = new List<Delegate>();
                    _handlers[typeof(T)] = list;
                }
                list.Add(handler);
            }
        }

        // 取消订阅（按引用匹配）。
        public void Unsubscribe<T>(Action<T> handler)
        {
            if (handler == null) throw new ArgumentNullException(nameof(handler));
            lock (_lock)
            {
                if (_handlers.TryGetValue(typeof(T), out var list))
                {
                    list.Remove(handler);
                    if (list.Count == 0) _handlers.Remove(typeof(T));
                }
            }
        }

        // 发布事件给所有订阅者（先快照，避免回调中增删导致枚举异常）。
        public void Publish<T>(T evt)
        {
            List<Delegate> snapshot;
            lock (_lock)
            {
                if (!_handlers.TryGetValue(typeof(T), out var list) || list.Count == 0) return;
                snapshot = new List<Delegate>(list);
            }
            foreach (var d in snapshot)
            {
                ((Action<T>)d)(evt);
            }
        }

        // 清空所有订阅（场景切换/测试复位用）。
        public void Clear()
        {
            lock (_lock) _handlers.Clear();
        }
    }
}
