/// Decodes the HID feature report of the MacBook lid angle sensor.
///
/// Report layout: byte 0 is the report ID, bytes 1-2 are the angle in
/// degrees as a little-endian unsigned 16-bit integer.
public enum LidAngleReport {
    public static let reportID: UInt8 = 1
    public static let validRange: ClosedRange<Double> = 0...360

    public static func angle(from bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3 else { return nil }
        let raw = UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
        let degrees = Double(raw)
        return validRange.contains(degrees) ? degrees : nil
    }
}
