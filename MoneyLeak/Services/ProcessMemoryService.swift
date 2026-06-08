import AppKit
import Darwin

final class ProcessMemoryService: @unchecked Sendable {
    static let shared = ProcessMemoryService()

    private let iconCacheLock = NSLock()
    private var iconCache: [String: NSImage] = [:]

    private struct RawProcess {
        let pid: Int32
        let name: String
        let executablePath: String?
        let bundlePath: String?
        let memoryBytes: UInt64
        let cost: Double
    }

    nonisolated func totalPhysicalRAMBytes() -> UInt64 {
        var memsize: UInt64 = 0
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        var size = MemoryLayout<UInt64>.size
        sysctl(&mib, 2, &memsize, &size, nil, 0)
        return memsize
    }

    nonisolated func fetchProcesses(customCostPerMB: Double? = nil) -> [ProcessMemoryInfo] {
        let totalRAM = totalPhysicalRAMBytes()
        let costModel = RAMOpportunityCostModel(
            totalPhysicalRAMBytes: totalRAM,
            customCostPerMB: customCostPerMB
        )

        var buffer = [pid_t](repeating: 0, count: 8192)
        let bytesUsed = proc_listallpids(&buffer, Int32(buffer.count * MemoryLayout<pid_t>.size))
        guard bytesUsed > 0 else { return [] }

        let pidCount = Int(bytesUsed) / MemoryLayout<pid_t>.size
        var rawProcesses: [RawProcess] = []
        rawProcesses.reserveCapacity(pidCount)

        for pid in buffer.prefix(pidCount) where pid > 0 {
            guard let memoryBytes = residentMemoryBytes(for: pid), memoryBytes > 0 else {
                continue
            }

            let path = executablePath(for: pid)
            rawProcesses.append(
                RawProcess(
                    pid: pid,
                    name: processName(for: pid, path: path),
                    executablePath: path,
                    bundlePath: bundlePath(from: path),
                    memoryBytes: memoryBytes,
                    cost: costModel.memoryCost(for: memoryBytes)
                )
            )
        }

        return groupProcesses(rawProcesses)
            .sorted { $0.residentMemoryBytes > $1.residentMemoryBytes }
    }

    nonisolated private func groupProcesses(_ rawProcesses: [RawProcess]) -> [ProcessMemoryInfo] {
        var bundleGroups: [String: [RawProcess]] = [:]
        var standalone: [RawProcess] = []

        for process in rawProcesses {
            if let bundlePath = process.bundlePath {
                bundleGroups[bundlePath, default: []].append(process)
            } else {
                standalone.append(process)
            }
        }

        var result: [ProcessMemoryInfo] = []
        result.reserveCapacity(bundleGroups.count + standalone.count)

        for process in standalone {
            result.append(makeProcessInfo(from: [process], bundlePath: nil))
        }

        for (bundlePath, members) in bundleGroups {
            result.append(makeProcessInfo(from: members, bundlePath: bundlePath))
        }

        return result
    }

    nonisolated private func makeProcessInfo(from members: [RawProcess], bundlePath: String?) -> ProcessMemoryInfo {
        let displayName = bundlePath.map(displayNameFromBundle(path:)) ?? members[0].name
        let representative = pickRepresentative(from: members, displayName: displayName)
        let totalMemory = members.reduce(UInt64(0)) { $0 + $1.memoryBytes }
        let totalCost = members.reduce(0.0) { $0 + $1.cost }
        let id = bundlePath ?? "pid:\(representative.pid)"

        let icon: NSImage?
        if let bundlePath {
            icon = iconForBundle(bundlePath)
        } else {
            icon = processIcon(for: representative.pid)
        }

        let memberInfos = members
            .map { member in
                ProcessMemberInfo(
                    pid: member.pid,
                    name: member.name,
                    executablePath: member.executablePath,
                    residentMemoryBytes: member.memoryBytes,
                    memoryCost: member.cost
                )
            }
            .sorted { $0.residentMemoryBytes > $1.residentMemoryBytes }

        return ProcessMemoryInfo(
            id: id,
            pid: representative.pid,
            processCount: members.count,
            processName: displayName,
            icon: icon,
            residentMemoryBytes: totalMemory,
            memoryCost: totalCost,
            members: memberInfos
        )
    }

    nonisolated private func pickRepresentative(from members: [RawProcess], displayName: String) -> RawProcess {
        members.first(where: { $0.name == displayName })
            ?? members.min(by: { $0.name.count < $1.name.count })
            ?? members[0]
    }

    nonisolated private func bundlePath(from executablePath: String?) -> String? {
        guard let executablePath,
              let appRange = executablePath.range(of: ".app/") else {
            return nil
        }
        return String(executablePath[..<appRange.upperBound])
    }

    nonisolated private func displayNameFromBundle(path: String) -> String {
        let name = (path as NSString).lastPathComponent
        if name.hasSuffix(".app") {
            return String(name.dropLast(4))
        }
        return name
    }

    nonisolated private func residentMemoryBytes(for pid: pid_t) -> UInt64? {
        var taskInfo = proc_taskinfo()
        let size = proc_pidinfo(
            pid,
            PROC_PIDTASKINFO,
            0,
            &taskInfo,
            Int32(MemoryLayout<proc_taskinfo>.size)
        )
        guard size == MemoryLayout<proc_taskinfo>.size else { return nil }
        return taskInfo.pti_resident_size
    }

    nonisolated private func executablePath(for pid: pid_t) -> String? {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 else {
            return nil
        }
        return String(cString: pathBuffer)
    }

    nonisolated private func processName(for pid: pid_t, path: String?) -> String {
        if let path {
            let name = (path as NSString).lastPathComponent
            if !name.isEmpty { return name }
        }

        // proc_name is intentionally not used — it logs "task name port right" errors for protected PIDs.
        return "Unknown Process"
    }

    nonisolated private func iconForBundle(_ bundlePath: String) -> NSImage? {
        iconCacheLock.lock()
        if let cached = iconCache[bundlePath] {
            iconCacheLock.unlock()
            return cached
        }
        iconCacheLock.unlock()

        let icon = NSWorkspace.shared.icon(forFile: bundlePath)
        icon.size = NSSize(width: 16, height: 16)

        iconCacheLock.lock()
        iconCache[bundlePath] = icon
        iconCacheLock.unlock()
        return icon
    }

    nonisolated private func processIcon(for pid: pid_t) -> NSImage? {
        guard let path = executablePath(for: pid) else {
            return NSImage(named: NSImage.applicationIconName)
        }

        iconCacheLock.lock()
        if let cached = iconCache[path] {
            iconCacheLock.unlock()
            return cached
        }
        iconCacheLock.unlock()

        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 16, height: 16)

        iconCacheLock.lock()
        iconCache[path] = icon
        iconCacheLock.unlock()
        return icon
    }
}
