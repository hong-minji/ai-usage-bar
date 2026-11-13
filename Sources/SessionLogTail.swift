import Foundation

/// Session logs may be gigabytes long. Only inspect a bounded tail for the
/// last rate-limit event, and discard any partial first line.
func sessionLogTail(_ url: URL, maximumBytes: Int = 512 * 1024) throws -> String {
    guard maximumBytes > 0 else { return "" }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let size = try handle.seekToEnd()
    let offset = size > UInt64(maximumBytes) ? size - UInt64(maximumBytes) : 0
    try handle.seek(toOffset: offset)
    var data = try handle.read(upToCount: maximumBytes) ?? Data()
    if offset > 0 {
        guard let newline = data.firstIndex(of: 10) else { return "" }
        data = Data(data.suffix(from: data.index(after: newline)))
    }
    return String(decoding: data, as: UTF8.self)
}
