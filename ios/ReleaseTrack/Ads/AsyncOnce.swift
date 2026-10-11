import Foundation

/// 只执行一次的异步初始化：并发或重复调用都等待同一次执行（R01：广告 SDK 不重复初始化）。
@MainActor
final class AsyncOnce {
    private var task: Task<Void, Never>?
    /// 实际执行次数（测试用；正常为 0 或 1）
    private(set) var runs = 0

    func run(_ body: @escaping @MainActor () async -> Void) async {
        if task == nil {
            runs += 1
            task = Task { @MainActor in await body() }
        }
        await task?.value
    }
}
