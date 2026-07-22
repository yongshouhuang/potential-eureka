namespace XiaXia.Core
{
    // 服务标记接口。各 manager 可选择性实现此接口（或自有子接口），
    // 但 Core 层绝不持有具体 manager 的字段引用——只按接口/类型经 ServiceRegistry 解析。
    public interface IService
    {
    }
}
