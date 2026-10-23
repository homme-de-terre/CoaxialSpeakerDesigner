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
    
    /// Asynchronously fetch datasheet content from URL and extract TS parameters & text.
    public func fetchAndParseDatasheet(url: URL) async throws -> (ts: WooferTSParameters, tweeter: TweeterParameters, name: String, rawText: String) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "DatasheetParser", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to download datasheet from provided URL."])
        }
        
        var rawText = ""
        
        #if canImport(PDFKit)
        let isPDF = url.pathExtension.lowercased() == "pdf" ||
                    (httpResponse.mimeType?.contains("pdf") ?? false) ||
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
        let driverName = extractDriverName(rawText, url: url)
        
        return (ts, tweeter, driverName, rawText)
    }
    
    /// Extract Thiele-Small parameters from raw text using regex & table layout strategies.
    public func parseTSFromText(_ text: String) -> WooferTSParameters {
        var ts = WooferTSParameters()
        
        // 1. Single-line inline regex matches
        if let val = findValue(pattern: #"\bFs\b\s*[:=.]*\s*([\d.]+)"#, text: text) ??
                     findValue(pattern: #"Resonance\s+Frequency\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.fs = val }
        
        if let val = findValue(pattern: #"\bRe\b\s*[:=.]*\s*([\d.]+)"#, text: text) ??
                     findValue(pattern: #"DC\s+Resistance\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.re = val }
        
        if let val = findValue(pattern: #"\bQes\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.qes = val }
        if let val = findValue(pattern: #"\bQms\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.qms = val }
        if let val = findValue(pattern: #"\bQts\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.qts = val }
        
        if let val = findValue(pattern: #"\bVas\b\s*[:=.]*\s*([\d.]+)"#, text: text) ??
                     findValue(pattern: #"Equivalent\s+Control\s+Volume\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.vas = val }
        
        if let val = findValue(pattern: #"\bLe\b\s*(?:\([^)]*\))?\s*[:=.]*\s*([\d.]+)"#, text: text) ??
                     findValue(pattern: #"Voice\s+Coil\s+Inductance\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.le = val }
        
        if let val = findValue(pattern: #"\bSd\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.sd = val }
        if let val = findValue(pattern: #"\bX-?max\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.xmax = val }
        
        if let val = findValue(pattern: #"LF\s+Sensitivity\s*[:=.]*\s*([\d.]+)"#, text: text) ??
                     findValue(pattern: #"\b(?:Sensitivity|SPL)\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.spl = val }
        
        // 2. Table / Block Layout Strategy (e.g. B&C, Beyma, 18 Sound)
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let paramIdx = lines.firstIndex(where: { $0.caseInsensitiveCompare("PARAMETERS") == .orderedSame || $0.localizedCaseInsensitiveContains("THIELE-SMALL") }) {
            let start = max(0, paramIdx - 35)
            let end = min(lines.count, paramIdx + 35)
            let blockLines = Array(lines[start..<end])
            let blockText = blockLines.joined(separator: "\n")
            
            if ts.fs == 0, let val = findFirstNumberWithUnit(blockText, unit: "Hz") { ts.fs = val }
            if ts.re == 0, let val = findFirstNumberWithUnit(blockText, unit: "Ω") { ts.re = val }
            if ts.vas == 0, let val = findFirstNumberWithUnit(blockText, unit: "dm") ?? findFirstNumberWithUnit(blockText, unit: "L") { ts.vas = val }
            if ts.sd == 0, let val = findFirstNumberWithUnit(blockText, unit: "cm") { ts.sd = val }
            if ts.xmax == 0, let val = findFirstNumberWithUnit(blockText, unit: "mm") { ts.xmax = val }
            if ts.le == 0, let val = findFirstNumberWithUnit(blockText, unit: "mH") { ts.le = val }
            
            // Qes, Qms, Qts dimensionless sequence check
            if ts.qes == 0 || ts.qms == 0 || ts.qts == 0 {
                let numbers = findAllFloatNumbers(in: blockText)
                if numbers.count >= 3 {
                    for i in 0..<(numbers.count - 2) {
                        let n1 = numbers[i]
                        let n2 = numbers[i+1]
                        let n3 = numbers[i+2]
                        if n1 >= 0.05 && n1 <= 2.0 && n2 >= 1.0 && n2 <= 30.0 && n3 >= 0.05 && n3 <= 2.0 {
                            let expectedQts = (n1 * n2) / (n1 + n2)
                            if abs(n3 - expectedQts) < 0.08 {
                                if ts.qes == 0 { ts.qes = n1 }
                                if ts.qms == 0 { ts.qms = n2 }
                                if ts.qts == 0 { ts.qts = n3 }
                                break
                            }
                        }
                    }
                }
            }
        }
        
        // Recalculate Qts if Qes and Qms were found
        if ts.qes > 0 && ts.qms > 0 && ts.qts == 0 {
            ts.qts = (ts.qes * ts.qms) / (ts.qes + ts.qms)
        }
        
        return ts
    }
    
    /// Extract Tweeter parameters from raw text.
    public func parseTweeterFromText(_ text: String) -> TweeterParameters {
        var tw = TweeterParameters()
        
        if let val = findValue(pattern: #"HF\s+Sensitivity\s*[:=.]*\s*([\d.]+)"#, text: text) ??
                     findValue(pattern: #"(?:Tweeter\s*SPL|HF\s*SPL)\s*[:=.]*\s*([\d.]+)"#, text: text) { tw.spl = val }
        
        if let val = findValue(pattern: #"Minimum\s+Impedance\s+HF\s*[:=.]*\s*([\d.]+)"#, text: text) ??
                     findValue(pattern: #"(?:Tweeter\s*Re|HF\s*Re)\s*[:=.]*\s*([\d.]+)"#, text: text) { tw.re = val }
        
        if let val = findValue(pattern: #"(?:Recommended\s+Crossover|Tweeter\s*Fs|HF\s*Fs)\s*[:=.]*\s*([\d.]+)"#, text: text) { tw.fs = val }
        
        // Fallback for HF sensitivity from general dB values if needed
        if tw.spl == 0 {
            let allDb = findAllNumbersWithUnit(text, unit: "dB").filter { $0 >= 80 && $0 <= 120 }
            if allDb.count >= 2 {
                tw.spl = allDb[1]
            }
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
