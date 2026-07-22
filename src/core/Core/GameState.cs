using System;
using System.Collections.Generic;

namespace XiaXia.Core
{
    // 回合变更事件（经 EventBus 广播）。
    public sealed class TurnChangedEvent
    {
        public int Turn { get; set; }
        public int ActiveUnitId { get; set; }
    }

    // 活跃单位快照变更事件（经 EventBus 广播）。
    public sealed class ActiveUnitChangedEvent
    {
        public int UnitId { get; set; }
        public string State { get; set; } = string.Empty;
    }

    // 共享读写状态容器（当前回合、活跃单位快照等）。
    // 所有变更经 EventBus 广播，消费者订阅事件而非轮询字段——保持与 Godot GameState autoload 同构。
    public sealed class GameState
    {
        private readonly EventBus _bus;
        private int _turn;
        private int _activeUnitId;
        private readonly Dictionary<string, object> _values = new Dictionary<string, object>();

        public GameState(EventBus bus)
        {
            _bus = bus ?? throw new ArgumentNullException(nameof(bus));
        }

        public int Turn
        {
            get => _turn;
            set
            {
                if (_turn != value)
                {
                    _turn = value;
                    _bus.Publish(new TurnChangedEvent { Turn = value, ActiveUnitId = _activeUnitId });
                }
            }
        }

        public int ActiveUnitId
        {
            get => _activeUnitId;
            set
            {
                if (_activeUnitId != value)
                {
                    _activeUnitId = value;
                    _bus.Publish(new ActiveUnitChangedEvent { UnitId = value });
                }
            }
        }

        // 通用键值状态（如活跃单位快照），读取方自行约定 key。
        public void SetValue(string key, object value)
        {
            if (key == null) throw new ArgumentNullException(nameof(key));
            _values[key] = value;
        }

        public bool TryGetValue(string key, out object value)
        {
            if (key == null) throw new ArgumentNullException(nameof(key));
            return _values.TryGetValue(key, out value);
        }
    }
}
