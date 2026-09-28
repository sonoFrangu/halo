import Foundation

/// Asks `system_profiler` for the batteries of connected Bluetooth headphones.
///
/// Public and permission-free (unlike private IOBluetooth selectors or a Bluetooth scan).
/// It takes about a second, so it runs once per connection, off the main actor.
enum BluetoothBatteryReader {
    static func batteries(of deviceName: String) async -> HeadphoneBatteries? {
        guard let data = await runSystemProfiler() else { return nil }
        return HeadphoneBatteries.parse(systemProfilerJSON: data, deviceName: deviceName)
    }

    private static func runSystemProfiler() async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
                process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
                let output = Pipe()
                process.standardOutput = output
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                // Read before waiting: the output can exceed the pipe buffer.
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0 ? data : nil)
            }
        }
    }
}
