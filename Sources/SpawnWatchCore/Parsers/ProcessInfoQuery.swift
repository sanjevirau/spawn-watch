import Foundation
import Darwin

public struct ProcessInfoQuery: Sendable {
    public init() {}

    public func listAllPids() -> [Int32] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }

        var pids = [Int32](repeating: 0, count: Int(count))
        let actualCount = proc_listallpids(&pids, Int32(MemoryLayout<Int32>.size * Int(count)))
        guard actualCount > 0 else { return [] }

        return Array(pids.prefix(Int(actualCount)))
    }

    public func getProcessName(pid: Int32) -> String? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard result == size else { return nil }

        return withUnsafeBytes(of: info.pbi_comm) { buffer in
            let bytes = buffer.bindMemory(to: CChar.self)
            return String(cString: bytes.baseAddress!)
        }
    }

    public func getParentPid(pid: Int32) -> Int32? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard result == size else { return nil }
        return Int32(info.pbi_ppid)
    }

    public func getExecutablePath(pid: Int32) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let result = proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
        guard result > 0 else { return nil }
        let length = pathBuffer.firstIndex(of: 0) ?? pathBuffer.count
        return String(decoding: pathBuffer.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    public func getCommandLineArgs(pid: Int32) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: Int = 0

        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }

        guard size > MemoryLayout<Int32>.size else { return nil }

        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var offset = MemoryLayout<Int32>.size

        // Skip the exec_path (first null-terminated string)
        while offset < size && buffer[offset] != 0 { offset += 1 }
        // Skip null padding
        while offset < size && buffer[offset] == 0 { offset += 1 }

        var args: [String] = []
        for _ in 0..<argc {
            guard offset < size else { break }
            var end = offset
            while end < size && buffer[end] != 0 { end += 1 }
            if end > offset {
                let arg = String(bytes: buffer[offset..<end], encoding: .utf8) ?? ""
                args.append(arg)
            }
            offset = end + 1
        }

        return args.isEmpty ? nil : args
    }

    public func getProcessIdentity(pid: Int32) -> ProcessIdentity? {
        guard let name = getProcessName(pid: pid) else { return nil }
        let path = getExecutablePath(pid: pid)
        return ProcessIdentity(pid: pid, name: name, executablePath: path)
    }
}
