import Foundation
import IOKit.hid

/// Reads the lid angle from the built-in HID sensor
/// (Apple vendor 0x05AC, product 0x8104, usage page Sensor 0x20, usage Orientation 0x8A).
public final class LidAngleSensor {
    public enum SensorError: Error, CustomStringConvertible {
        case managerOpenFailed(IOReturn)
        case deviceNotFound
        case deviceOpenFailed(IOReturn)

        public var description: String {
            switch self {
            case .managerOpenFailed(let code):
                return "Cannot open the HID manager (IOReturn 0x\(String(code, radix: 16)))."
            case .deviceNotFound:
                return "No lid angle sensor found. This Mac may not have one."
            case .deviceOpenFailed(let code):
                return "Cannot open the lid angle sensor (IOReturn 0x\(String(code, radix: 16)))."
            }
        }
    }

    static let matching: [String: Int] = [
        kIOHIDVendorIDKey: 0x05AC,
        kIOHIDProductIDKey: 0x8104,
        kIOHIDPrimaryUsagePageKey: 0x0020,
        kIOHIDPrimaryUsageKey: 0x008A,
    ]

    private let manager: IOHIDManager
    private let device: IOHIDDevice

    public init() throws {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, Self.matching as CFDictionary)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            throw SensorError.managerOpenFailed(openResult)
        }

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = devices.first(where: { Self.readAngle(from: $0) != nil }) ?? devices.first
        else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw SensorError.deviceNotFound
        }

        let deviceOpen = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard deviceOpen == kIOReturnSuccess else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw SensorError.deviceOpenFailed(deviceOpen)
        }
        self.device = device
    }

    deinit {
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    /// Current lid angle in degrees, or nil if the read fails.
    public func readAngle() -> Double? {
        Self.readAngle(from: device)
    }

    private static func readAngle(from device: IOHIDDevice) -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        let result = report.withUnsafeMutableBufferPointer { buffer in
            IOHIDDeviceGetReport(
                device,
                kIOHIDReportTypeFeature,
                CFIndex(LidAngleReport.reportID),
                buffer.baseAddress!,
                &length
            )
        }
        guard result == kIOReturnSuccess else { return nil }
        return LidAngleReport.angle(from: Array(report.prefix(length)))
    }
}
