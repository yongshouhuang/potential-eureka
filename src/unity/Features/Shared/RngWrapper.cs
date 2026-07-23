#nullable enable
using System;

namespace XiaXia.Features.Shared
{
    // 种子化 RNG 封装。所有随机路径一律经此，保证测试可复现（ADR-3 红线#6）。
    // 用 System.Random：IL2CPP/AOT 安全（无反射），不使用 Godot RandomNumberGenerator。
    // 本身是基础设施（非 manager），manager 可持有/调用它，不违反解耦红线。
    public sealed class RngWrapper
    {
        private int _seed;
        private Random _rand;

        // seed 为 0 时仍由 System.Random 自行播种（与 Godot RNGWrapper 默认语义一致）。
        public RngWrapper(int seed = 1)
        {
            _seed = seed;
            _rand = new Random(seed);
        }

        // 重设种子（同种子 => 同序列，保证可复现）。
        public void Reseed(int seed)
        {
            _seed = seed;
            _rand = new Random(seed);
        }

        public int Seed => _seed;

        // [0,1) 浮点
        public double NextDouble() => _rand.NextDouble();

        // [0, toExclusive) 整数（常用于按数组长度取索引）；toExclusive<=0 返回 0。
        public int NextInt(int toExclusive)
        {
            if (toExclusive <= 0) return 0;
            return _rand.Next(toExclusive);
        }

        // 以概率 p 命中
        public bool Chance(double p) => _rand.NextDouble() < p;
    }
}
