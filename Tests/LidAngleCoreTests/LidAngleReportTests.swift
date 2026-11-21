import Testing
@testable import LidAngleCore

@Suite("LidAngleReport.angle(from:)")
struct LidAngleReportTests {
    @Test("Reads a little-endian 16-bit angle after the report ID")
    func parsesLittleEndianAngle() {
        // Report ID 1, angle 0x0078 = 120 degrees
        #expect(LidAngleReport.angle(from: [0x01, 0x78, 0x00]) == 120)
    }

    @Test("Uses the high byte")
    func usesHighByte() {
        // 0x0104 = 260 degrees
        #expect(LidAngleReport.angle(from: [0x01, 0x04, 0x01]) == 260)
    }

    @Test("Ignores extra trailing bytes")
    func ignoresTrailingBytes() {
        #expect(LidAngleReport.angle(from: [0x01, 0x5A, 0x00, 0xFF, 0xFF]) == 90)
    }

    @Test("Returns nil when the report is too short", arguments: [
        [UInt8](), [0x01], [0x01, 0x78],
    ])
    func rejectsShortReports(bytes: [UInt8]) {
        #expect(LidAngleReport.angle(from: bytes) == nil)
    }

    @Test("Returns nil for a value outside 0...360")
    func rejectsOutOfRange() {
        // 0xFFFF = 65535
        #expect(LidAngleReport.angle(from: [0x01, 0xFF, 0xFF]) == nil)
    }

    @Test("Accepts the closed lid value 0")
    func acceptsZero() {
        #expect(LidAngleReport.angle(from: [0x01, 0x00, 0x00]) == 0)
    }
}
