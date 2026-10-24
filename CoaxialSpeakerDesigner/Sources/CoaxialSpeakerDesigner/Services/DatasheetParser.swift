import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

/// Service for downloading, parsing, and ingesting loudspeaker datasheets and FRD/ZMA response data files.
public class DatasheetParser: ObservableObject, @unchecked Sendable {
    
    public init() {}
    
    /// Parse FRD or ZMA text data (3 columns: Frequency, Magnitude, Phase).
    public static func parseFRDText(_ text: String) -> [ResponseDataPoint] {
        var points: [ResponseDataPoint] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("*") || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                continue
            }
            
            // Split by tabs, spaces, or commas
            let components = trimmed.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",")))
                .filter { !$0.isEmpty }
            
            if components.count >= 2 {
                if let freq = Double(components[0]),
                   let mag = Double(components[1]) {
                    let phase = components.count >= 3 ? (Double(components[2]) ?? 0.0) : 0.0
                    points.append(ResponseDataPoint(frequency: freq, magnitude: mag, phase: phase))
                }
            }
        }
        
        return points.sorted(by: { $0.frequency < $1.frequency })
    }
    
    /// Export response points to FRD file string format.
    public static func exportToFRD(points: [ResponseDataPoint], comment: String = "Exported from CoaxialSpeakerDesigner") -> String {
        var result = "* \(comment)\n"
        result += "* Freq(Hz)\tMag(dB)\tPhase(Deg)\n"
        for p in points {
            result += String(format: "%.2f\t%.3f\t%.2f\n", p.frequency, p.magnitude, p.phase)
        }
        return result
    }
    
    /// Ingests and parses datasheet content directly from a local file URL.
    public func parseDatasheet(from fileURL: URL) throws -> (ts: WooferTSParameters, tweeter: TweeterParameters, name: String, rawText: String) {
        let data = try Data(contentsOf: fileURL)
        return parseDatasheetData(data, sourceURL: fileURL)
    }

    /// Parses datasheet content directly from raw Data (PDF or plain text).
    public func parseDatasheetData(_ data: Data, sourceURL: URL) -> (ts: WooferTSParameters, tweeter: TweeterParameters, name: String, rawText: String) {
        var rawText = ""
        
        #if canImport(PDFKit)
        let isPDF = sourceURL.pathExtension.lowercased() == "pdf" ||
                    (data.count >= 4 && data.prefix(4) == Data([0x25, 0x50, 0x44, 0x46]))
        
        if isPDF, let pdfDoc = PDFDocument(data: data) {
            var pdfText = ""
            for i in 0..<pdfDoc.pageCount {
                if let page = pdfDoc.page(at: i), let pageString = page.string {
                    pdfText += pageString + "\n"
                }
            }
            if !pdfText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rawText = pdfText
            }
        }
        #endif
        
        if rawText.isEmpty {
            rawText = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        }
        
        // Extract parameters using regex patterns
        let ts = parseTSFromText(rawText)
        let tweeter = parseTweeterFromText(rawText)
        let driverName = extractDriverName(rawText, url: sourceURL)
        
        return (ts, tweeter, driverName, rawText)
    }

    /// Asynchronously fetch datasheet content from URL and extract TS parameters & text.
    public func fetchAndParseDatasheet(url: URL) async throws -> (ts: WooferTSParameters, tweeter: TweeterParameters, name: String, rawText: String) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "DatasheetParser", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to download datasheet from provided URL."])
        }
        
        return parseDatasheetData(data, sourceURL: url)
    }
    
    /// Extract Thiele-Small parameters from raw text using regex & table layout strategies.
    public func parseTSFromText(_ text: String) -> WooferTSParameters {
        var ts = WooferTSParameters(
            fs: 0.0,
            qes: 0.0,
            qms: 0.0,
            qts: 0.0,
            vas: 0.0,
            re: 0.0,
            le: 0.0,
            sd: 0.0,
            xmax: 0.0,
            spl: 0.0,
            pe: 0.0
        )
        
        // 1. Single-line inline regex matches (e.g. Fs = 40 Hz)
        if let val = findValue(pattern: #"\bFs\b\s*[:=.]*\s*([\d.]+)\s*Hz"#, text: text) ??
                     findValue(pattern: #"Resonance\s+Frequency\s*[:=.]*\s*([\d.]+)\s*Hz"#, text: text) { ts.fs = val }
        
        if let val = findValue(pattern: #"\bRe\b\s*[:=.]*\s*([\d.]+)\s*(?:Ω|Ohm)"#, text: text) ??
                     findValue(pattern: #"DC\s+Resistance\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.re = val }
        
        if let val = findValue(pattern: #"\bQes\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.qes = val }
        if let val = findValue(pattern: #"\bQms\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.qms = val }
        if let val = findValue(pattern: #"\bQts\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.qts = val }
        
        if let val = findValue(pattern: #"\bVas\b\s*[:=.]*\s*([\d.]+)"#, text: text) ??
                     findValue(pattern: #"Equivalent\s+Control\s+Volume\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.vas = val }
        
        if let val = findValue(pattern: #"\bLe\b\s*(?:\([^)]*\))?\s*[:=.]*\s*([\d.]+)\s*mH"#, text: text) ??
                     findValue(pattern: #"Voice\s+Coil\s+Inductance\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.le = val }
        
        if let val = findValue(pattern: #"\bSd\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.sd = val }
        if let val = findValue(pattern: #"\bX-?max\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.xmax = val }
        
        // 2. Extract Woofer Sensitivity (must be in realistic 80...120 dB range, not footnote number!)
        let allDb = findAllNumbersWithUnit(text, unit: "dB").filter { $0 >= 80.0 && $0 <= 120.0 }
        if let firstSPL = allDb.first {
            ts.spl = firstSPL
        }

        // 3. Extract Fs in Hz (15...180 Hz)
        if ts.fs == 0 {
            let allHz = findAllNumbersWithUnit(text, unit: "Hz").filter { $0 >= 15.0 && $0 <= 180.0 }
            if let firstFs = allHz.first {
                ts.fs = firstFs
            }
        }

        // 4. Extract DC Resistance Re (1.0...32.0 Ohms)
        if ts.re == 0 {
            let allOhm = findAllNumbersWithUnit(text, unit: "Ω").filter { $0 >= 1.0 && $0 <= 32.0 }
            if let lastRe = allOhm.last {
                ts.re = lastRe
            }
        }

        // 5. Extract Vas (dm3 or Liters)
        if ts.vas == 0 {
            if let v = findFirstNumberWithUnit(text, unit: "dm") ?? findFirstNumberWithUnit(text, unit: "L") {
                ts.vas = v
            }
        }

        // 6. Extract Sd (cm2)
        if ts.sd == 0 {
            if let s = findFirstNumberWithUnit(text, unit: "cm") {
                ts.sd = s
            }
        }

        // 7. Extract Xmax (mm)
        if ts.xmax == 0 {
            // Find mm values in range 2...25 mm
            let allMm = findAllNumbersWithUnit(text, unit: "mm").filter { $0 >= 2.0 && $0 <= 25.0 }
            if let firstXmax = allMm.first {
                ts.xmax = firstXmax
            }
        }

        // 8. Extract Voice Coil Inductance Le (mH)
        if ts.le == 0 {
            let allMh = findAllNumbersWithUnit(text, unit: "mH")
            if let maxMh = allMh.max() {
                ts.le = maxMh
            }
        }

        // 9. Dimensionless sequence for Qes, Qms, Qts
        if ts.qes == 0 || ts.qms == 0 || ts.qts == 0 {
            let floatNums = findAllFloatNumbers(in: text)
            for i in 0..<(floatNums.count - 2) {
                let n1 = floatNums[i]
                let n2 = floatNums[i+1]
                let n3 = floatNums[i+2]
                if n1 >= 0.10 && n1 <= 1.5 && n2 >= 1.0 && n2 <= 25.0 && n3 >= 0.10 && n3 <= 1.5 {
                    let expectedQts = (n1 * n2) / (n1 + n2)
                    if abs(n3 - expectedQts) < 0.05 {
                        ts.qes = n1
                        ts.qms = n2
                        ts.qts = n3
                        break
                    }
                }
            }
        }
        
        // Recalculate Qts if Qes and Qms were found
        if ts.qes > 0 && ts.qms > 0 && ts.qts == 0 {
            ts.qts = (ts.qes * ts.qms) / (ts.qes + ts.qms)
        }

        // Final safety fallbacks for missing parameters
        if ts.fs == 0 { ts.fs = 40.0 }
        if ts.re == 0 { ts.re = 5.0 }
        if ts.spl == 0 { ts.spl = 95.0 }
        if ts.vas == 0 { ts.vas = 50.0 }
        if ts.qts == 0 { ts.qts = 0.35 }
        if ts.sd == 0 { ts.sd = 500.0 }
        if ts.xmax == 0 { ts.xmax = 5.0 }
        if ts.le == 0 { ts.le = 1.0 }
        
        return ts
    }
    
    /// Extract Tweeter parameters from raw text.
    public func parseTweeterFromText(_ text: String) -> TweeterParameters {
        var tw = TweeterParameters(
            fs: 1200.0,
            re: 8.0,
            le: 0.14,
            spl: 95.0,
            pe: 50.0,
            nominalImpedance: 8.0
        )
        
        // 1. Sensitivity in dB (must be 80...120 dB, second unique value is HF)
        let allDb = findAllNumbersWithUnit(text, unit: "dB").filter { $0 >= 80.0 && $0 <= 120.0 }
        var uniqueDb: [Double] = []
        for v in allDb {
            if !uniqueDb.contains(v) { uniqueDb.append(v) }
        }
        if uniqueDb.count >= 2 {
            tw.spl = uniqueDb[1] // e.g. 106.0 dB
        } else if let first = uniqueDb.first {
            tw.spl = first
        }
        
        // 2. Recommended Crossover / Tweeter Fs (kHz or Hz >= 500)
        if let valKhz = findFirstNumberWithUnit(text, unit: "kHz") {
            tw.fs = valKhz * 1000.0 // 1.2 kHz -> 1200.0 Hz
        } else {
            let xoHz = findAllNumbersWithUnit(text, unit: "Hz").filter { $0 >= 500.0 && $0 <= 5000.0 }
            if let first = xoHz.first {
                tw.fs = first
            }
        }
        
        // 3. Tweeter Re (Minimum Impedance HF or second resistance value)
        let allOhm = findAllNumbersWithUnit(text, unit: "Ω").filter { $0 >= 3.0 && $0 <= 32.0 }
        if allOhm.count >= 2 {
            tw.re = allOhm[allOhm.count - 2] // e.g. 8.5 Ω
        }
        
        // 4. Tweeter Inductance Le (smaller mH value)
        let allMh = findAllNumbersWithUnit(text, unit: "mH")
        if let minMh = allMh.min(), minMh < 0.5 {
            tw.le = minMh // e.g. 0.14 mH
        }
        
        return tw
    }
    
    private func findValue(pattern: String, text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        if let match = matches.first, match.numberOfRanges >= 2 {
            let strVal = nsText.substring(with: match.range(at: 1))
            return Double(strVal)
        }
        return nil
    }
    
    private func findFirstNumberWithUnit(_ text: String, unit: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*"# + NSRegularExpression.escapedPattern(for: unit)
        return findValue(pattern: pattern, text: text)
    }
    
    private func findAllNumbersWithUnit(_ text: String, unit: String) -> [Double] {
        let pattern = #"(\d+(?:\.\d+)?)\s*"# + NSRegularExpression.escapedPattern(for: unit)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            return Double(nsText.substring(with: match.range(at: 1)))
        }
    }
    
    private func findAllFloatNumbers(in text: String) -> [Double] {
        let pattern = #"\b(\d+(?:\.\d+)?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            return Double(nsText.substring(with: match.range(at: 1)))
        }
    }
    
    private func extractDriverName(_ text: String, url: URL) -> String {
        // Try matching model name pattern (e.g. 15CXN88, 8CX21, 12CX32)
        if let model = findString(pattern: #"\b(\d{1,2}[A-Z]{2,4}\d{2,4}(?:-[0-9\+]+)?)\b"#, text: text) {
            return model
        }
        
        let filename = url.lastPathComponent
            .replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ".html", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "+", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        
        if !filename.isEmpty && filename != "/" {
            return filename.capitalized
        }
        return "Coaxial Loudspeaker Driver"
    }
    
    private func findString(pattern: String, text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        if let match = matches.first, match.numberOfRanges >= 2 {
            return nsText.substring(with: match.range(at: 1))
        }
        return nil
    }
}
