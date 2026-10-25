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
    public func parseDatasheet(from fileURL: URL) throws -> (
        ts: WooferTSParameters,
        tweeter: TweeterParameters,
        name: String,
        recommendedCrossover: Double,
        missingParams: [String],
        warnings: [String],
        rawText: String
    ) {
        let data = try Data(contentsOf: fileURL)
        return parseDatasheetData(data, sourceURL: fileURL)
    }

    /// Parses datasheet content directly from raw Data (PDF or plain text).
    public func parseDatasheetData(_ data: Data, sourceURL: URL) -> (
        ts: WooferTSParameters,
        tweeter: TweeterParameters,
        name: String,
        recommendedCrossover: Double,
        missingParams: [String],
        warnings: [String],
        rawText: String
    ) {
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
        
        let normText = normalizeCommas(in: rawText)
        let driverName = extractDriverName(rawText, url: sourceURL)
        let recommendedCrossover = parseRecommendedCrossover(from: normText) ?? 0.0
        let ts = parseTSFromText(normText)
        let tweeter = parseTweeterFromText(normText, recommendedCrossover: recommendedCrossover, wooferRe: ts.re)
        
        // Plausibility & Missing Parameter Analysis
        var missingParams: [String] = []
        var warnings: [String] = []

        if ts.fs == 0 { missingParams.append("Fs") }
        else if ts.fs < 15.0 || ts.fs > 250.0 { warnings.append("Fs (\(ts.fs) Hz) is outside typical range (15–200 Hz).") }

        if ts.qes == 0 { missingParams.append("Qes") }
        else if ts.qes < 0.08 || ts.qes > 2.5 { warnings.append("Qes (\(ts.qes)) is outside typical range (0.1–2.0).") }

        if ts.qms == 0 { missingParams.append("Qms") }
        else if ts.qms < 0.8 || ts.qms > 30.0 { warnings.append("Qms (\(ts.qms)) is outside typical range (1.0–25.0).") }

        if ts.qts == 0 { missingParams.append("Qts") }
        else if ts.qts < 0.08 || ts.qts > 2.0 { warnings.append("Qts (\(ts.qts)) is outside typical range (0.1–1.5).") }

        if ts.vas == 0 { missingParams.append("Vas") }
        else if ts.vas < 1.0 || ts.vas > 900.0 { warnings.append("Vas (\(ts.vas) L) is outside typical range (2–800 L).") }

        if ts.re == 0 { missingParams.append("Re") }
        else if ts.re < 1.0 || ts.re > 25.0 { warnings.append("Woofer Re (\(ts.re) Ω) is outside typical range (1.5–20 Ω).") }

        if ts.spl == 0 { missingParams.append("Sensitivity") }
        else if ts.spl < 75.0 || ts.spl > 115.0 { warnings.append("Woofer Sensitivity (\(ts.spl) dB) seems implausible.") }

        if tweeter.spl < 85.0 || tweeter.spl > 125.0 {
            warnings.append("Tweeter Sensitivity (\(tweeter.spl) dB) seems implausible.")
        }

        if recommendedCrossover > 0 && (recommendedCrossover < 500.0 || recommendedCrossover > 8000.0) {
            warnings.append("Recommended Crossover (\(Int(recommendedCrossover)) Hz) seems outside typical coaxial range.")
        }

        return (ts, tweeter, driverName, recommendedCrossover, missingParams, warnings, rawText)
    }

    /// Asynchronously fetch datasheet content from URL and extract TS parameters & text.
    public func fetchAndParseDatasheet(url: URL) async throws -> (
        ts: WooferTSParameters,
        tweeter: TweeterParameters,
        name: String,
        recommendedCrossover: Double,
        missingParams: [String],
        warnings: [String],
        rawText: String
    ) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "DatasheetParser", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to download datasheet from provided URL."])
        }
        
        return parseDatasheetData(data, sourceURL: url)
    }
    
    /// Extract Thiele-Small parameters from normalized text without hard-coded fallbacks.
    public func parseTSFromText(_ text: String) -> WooferTSParameters {
        let normText = normalizeCommas(in: text)
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
        
        // 1. Single-line inline regex matches
        if let val = findValue(pattern: #"\b(?:Fs|Resonant\s+Frequency)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(?:Hz)?"#, text: normText) {
            if val >= 15.0 && val <= 250.0 { ts.fs = val }
        }
        if let val = findValue(pattern: #"\b(?:Re|DC\s+Resistance|Voice\s+coil\s+resistance)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(?:Ω|Ohm)?"#, text: normText) {
            if val >= 1.0 && val <= 30.0 { ts.re = val }
        }
        if let val = findValue(pattern: #"\b(?:Qes|Electrical\s+Quality\s+Factor)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)"#, text: normText) {
            ts.qes = val
        }
        if let val = findValue(pattern: #"\b(?:Qms|Mechanical\s+Quality\s+Factor)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)"#, text: normText) {
            ts.qms = val
        }
        if let val = findValue(pattern: #"\b(?:Qts|Total\s+Quality\s+Factor)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)"#, text: normText) {
            ts.qts = val
        }
        if let val = findValue(pattern: #"\b(?:Vas|Equivalent\s+(?:Air\s+)?Volume(?:\s+to\s+Cms)?)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)"#, text: normText) {
            ts.vas = val
        }
        if let val = findValue(pattern: #"\b(?:Le|Inductance)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(?:mH)?"#, text: normText) {
            ts.le = val
        }
        if let val = findValue(pattern: #"\b(?:Sd|Surface\s+Area)\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)"#, text: normText) {
            ts.sd = val
        }
        if let val = findValue(pattern: #"\bX-?max\b[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(?:mm)?"#, text: normText) {
            ts.xmax = val
        }
        
        // 2. Extract Woofer Sensitivity (must be in realistic 80...120 dB range)
        let allDb = findAllNumbersWithUnit(normText, unit: "dB").filter { $0 >= 80.0 && $0 <= 120.0 }
        if let firstSPL = allDb.first {
            ts.spl = firstSPL
        }

        // 3. Dimensionless sequence for Qes, Qms, Qts and Table Context
        let pattern = #"\b(\d+(?:\.\d+)?)\b"#
        var qStartLoc = -1
        var qEndLoc = -1
        if let numRegex = try? NSRegularExpression(pattern: pattern) {
            let nsNorm = normText as NSString
            let matches = numRegex.matches(in: normText, options: [], range: NSRange(location: 0, length: nsNorm.length))
            struct Entry { let val: Double; let loc: Int; let len: Int }
            let entries: [Entry] = matches.compactMap { m in
                guard m.numberOfRanges >= 2, let v = Double(nsNorm.substring(with: m.range(at: 1))) else { return nil }
                return Entry(val: v, loc: m.range(at: 1).location, len: m.range(at: 1).length)
            }
            
            if ts.qes == 0 || ts.qms == 0 || ts.qts == 0 {
                for i in 0..<(entries.count - 2) {
                    let n1 = entries[i].val
                    let n2 = entries[i+1].val
                    let n3 = entries[i+2].val
                    let expectedQts = (n1 * n2) / (n1 + n2)
                    if abs(n3 - expectedQts) < 0.08 || (n3 > 0 && abs(n3 - expectedQts) / n3 < 0.15) {
                        let large = max(n1, n2)
                        let small = min(n1, n2)
                        if large >= 1.0 && large <= 30.0 && small >= 0.05 && small <= 3.0 && n3 >= 0.05 && n3 <= 2.5 {
                            if ts.qms == 0 { ts.qms = large }
                            if ts.qes == 0 { ts.qes = small }
                            if ts.qts == 0 { ts.qts = n3 }
                            qStartLoc = entries[i].loc
                            qEndLoc = entries[i+2].loc + entries[i+2].len
                            break
                        }
                    }
                }
            }
            
            // Recalculate Q parameters if 2 out of 3 are known
            if ts.qes > 0 && ts.qms > 0 && ts.qts == 0 {
                ts.qts = (ts.qes * ts.qms) / (ts.qes + ts.qms)
            } else if ts.qes > 0 && ts.qts > 0 && ts.qms == 0 && ts.qes > ts.qts {
                ts.qms = (ts.qes * ts.qts) / (ts.qes - ts.qts)
            } else if ts.qms > 0 && ts.qts > 0 && ts.qes == 0 && ts.qms > ts.qts {
                ts.qes = (ts.qms * ts.qts) / (ts.qms - ts.qts)
            }

            // Look in block BEFORE Q for Re and Fs (table layout)
            if qStartLoc > 0 {
                let startPos = max(0, qStartLoc - 350)
                let beforeText = nsNorm.substring(with: NSRange(location: startPos, length: qStartLoc - startPos))
                if ts.re == 0.0, let v = findValue(pattern: #"(\d+(?:\.\d+)?)\s*(?:Ω|Ohm)"#, text: beforeText) {
                    if v >= 1.0 && v <= 25.0 { ts.re = v }
                }
                if ts.fs == 0.0, let v = findValue(pattern: #"(\d+(?:\.\d+)?)\s*Hz"#, text: beforeText) {
                    if v >= 18.0 && v <= 200.0 { ts.fs = v }
                }
            }

            // Look in block AFTER Q for Vas, Sd, Xmax, Le (table layout with normalized units)
            if qEndLoc > 0 && qEndLoc < nsNorm.length {
                let len = min(500, nsNorm.length - qEndLoc)
                let afterText = nsNorm.substring(with: NSRange(location: qEndLoc, length: len))
                
                // Vas: L instead of m^3 or cu. ft.
                if ts.vas == 0.0, let v = findValueWithUnit(pattern: #"(\d+(?:\.\d+)?)\s*(l|lt|ltr|liters?|litres?|dm[3³]|m[3³]|m\^3|cu\.?\s*ft\.?|ft[3³])\b"#, text: afterText) {
                    ts.vas = v
                }
                
                // Sd: cm^2 instead of m^2
                if ts.sd == 0.0, let v = findValueWithUnit(pattern: #"(\d+(?:\.\d+)?)\s*(m\s*[2²]|m\^2|cm\s*[2²]|cm\^2)"#, text: afterText) {
                    ts.sd = v
                }
                
                // Xmax: mm
                if ts.xmax == 0.0, let v = findValue(pattern: #"(\d+(?:\.\d+)?)\s*mm\b"#, text: afterText) {
                    if v >= 1.0 && v <= 35.0 { ts.xmax = v }
                }
                
                // Le: mH instead of H
                if ts.le == 0.0, let v = findValueWithUnit(pattern: #"(\d+(?:\.\d+)?)\s*(mH|H)\b"#, text: afterText) {
                    ts.le = v
                }
            }
        }
        
        // Final fallback checks if still 0
        if ts.fs == 0.0 {
            let allHz = findAllNumbersWithUnit(normText, unit: "Hz").filter { $0 >= 18.0 && $0 <= 180.0 }
            if let firstFs = allHz.first {
                ts.fs = firstFs
            }
        }
        if ts.re == 0.0 {
            let allOhm = findAllNumbersWithUnit(normText, unit: "Ω").filter { $0 >= 2.0 && $0 <= 25.0 }
            if let firstRe = allOhm.first {
                ts.re = firstRe
            }
        }
        if ts.le == 0.0 {
            let allMh = findAllNumbersWithUnit(normText, unit: "mH")
            if let maxMh = allMh.max() {
                ts.le = maxMh
            }
        }
        if ts.vas == 0.0 {
            if let v = findValueWithUnit(pattern: #"\b(\d+(?:\.\d+)?)\s*(dm[3³]|liters?|litres?|m[3³]|m\^3)\b"#, text: normText) {
                ts.vas = v
            }
        }
        if ts.sd == 0.0 {
            if let v = findValueWithUnit(pattern: #"(\d+(?:\.\d+)?)\s*m\s*[2²]"#, text: normText) {
                ts.sd = v
            } else if let s = findFirstNumberWithUnit(normText, unit: "cm") {
                ts.sd = s
            }
        }
        if ts.xmax == 0.0 {
            let allMm = findAllNumbersWithUnit(normText, unit: "mm").filter { $0 >= 1.5 && $0 <= 25.0 }
            if let lastMm = allMm.last {
                ts.xmax = lastMm
            }
        }
        
        return ts
    }
    
    /// Extract Tweeter parameters from normalized text.
    public func parseTweeterFromText(_ text: String, recommendedCrossover: Double = 0.0, wooferRe: Double = 0.0) -> TweeterParameters {
        let norm = normalizeCommas(in: text)
        var tw = TweeterParameters(
            fs: 1200.0,
            re: 8.0,
            le: 0.14,
            spl: 95.0,
            pe: 50.0,
            nominalImpedance: 8.0
        )
        
        // 1. Sensitivity in dB (must be 80...120 dB, second unique value is HF)
        let allDb = findAllNumbersWithUnit(norm, unit: "dB").filter { $0 >= 80.0 && $0 <= 125.0 }
        var uniqueDb: [Double] = []
        for v in allDb {
            if !uniqueDb.contains(v) { uniqueDb.append(v) }
        }
        if uniqueDb.count >= 2 {
            tw.spl = uniqueDb[1] // e.g. 105.0 or 106.0 dB
        } else if let first = uniqueDb.first {
            tw.spl = first
        }
        
        // 2. Tweeter Fs (kHz or Hz >= 500)
        if recommendedCrossover > 0 {
            tw.fs = (recommendedCrossover * 0.75).rounded()
        } else if let valKhz = findFirstNumberWithUnit(norm, unit: "kHz") {
            if valKhz < 10.0 {
                tw.fs = valKhz * 1000.0
            }
        }
        
        // 3. Tweeter Re
        let allOhm = findAllNumbersWithUnit(norm, unit: "Ω").filter { $0 >= 3.0 && $0 <= 32.0 }
        let twOhms = allOhm.filter { abs($0 - wooferRe) > 0.5 }
        if let firstTwOhm = twOhms.first {
            tw.re = firstTwOhm
        } else if allOhm.count >= 2 {
            tw.re = allOhm[allOhm.count - 2]
        }
        
        // 4. Tweeter Inductance Le (smaller mH value)
        let allMh = findAllNumbersWithUnit(norm, unit: "mH")
        if let minMh = allMh.min(), minMh < 0.5 {
            tw.le = minMh
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
    
    private func findValueWithUnit(pattern: String, text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard let match = matches.first, match.numberOfRanges >= 3 else { return nil }
        guard let val = Double(nsText.substring(with: match.range(at: 1))) else { return nil }
        let unitStr = nsText.substring(with: match.range(at: 2)).lowercased().trimmingCharacters(in: .whitespaces)
        
        // Normalize Vas: L instead of m^3 or cu. ft.
        if unitStr.contains("m3") || unitStr.contains("m^3") || unitStr.contains("m³") {
            return (val * 1000.0 * 10.0).rounded() / 10.0
        }
        if unitStr.contains("cu") || unitStr.contains("ft") {
            return (val * 28.3168 * 10.0).rounded() / 10.0
        }
        
        // Normalize Sd: cm^2 instead of m^2
        if unitStr.contains("cm") {
            return val
        }
        if unitStr.contains("m") && (unitStr.contains("2") || unitStr.contains("²")) {
            return (val * 10000.0).rounded()
        }
        if unitStr.contains("in") {
            return (val * 6.4516).rounded()
        }
        
        // Normalize Le: mH instead of H
        if unitStr == "h" {
            return (val * 1000.0 * 100.0).rounded() / 100.0
        }
        
        return val
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
    
    public func parseRecommendedCrossover(from text: String) -> Double? {
        let norm = normalizeCommas(in: text)
        let pattern = #"(?:Recom(?:\.|mended)?\s*(?:HF)?\s*Crossover|Crossover\s+Frequency|Suggested\s+Crossover)[^\n\d]*[:=,\s]+(\d+(?:\.\d+)?)\s*(k?Hz)?"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let ns = norm as NSString
            let matches = regex.matches(in: norm, range: NSRange(location: 0, length: ns.length))
            if let m = matches.first, m.numberOfRanges >= 2 {
                var val = Double(ns.substring(with: m.range(at: 1))) ?? 0.0
                if m.numberOfRanges >= 3 && m.range(at: 2).location != NSNotFound {
                    let unitStr = ns.substring(with: m.range(at: 2)).lowercased()
                    if unitStr.hasPrefix("k") || val < 20.0 { val *= 1000.0 }
                } else if val < 20.0 {
                    val *= 1000.0
                }
                if val >= 400.0 && val <= 8000.0 { return val }
            }
        }
        let khzPattern = #"(\d+(?:\.\d+)?)\s*kHz\s*(?:or\s+higher|min(?:\.|\s+slope)?)"#
        if let v = findValue(pattern: khzPattern, text: norm) {
            let hz = v * 1000.0
            if hz >= 400.0 && hz <= 8000.0 { return hz }
        }
        return nil
    }

    private func normalizeCommas(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+),(\d+)"#) else { return text }
        let nsText = text as NSString
        return regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: nsText.length), withTemplate: "$1.$2")
    }

    private func extractDriverName(_ text: String, url: URL) -> String {
        let exclude = ["COAXIALS", "SPECIFICATIONS", "DESCRIPTION", "PARAMETERS", "SERVICE", "FEATURES", "THIELE", "TECHNICAL", "MOUNTING", "DIMENSION", "DRAWINGS", "FREE", "IMPEDANCE", "FILTERED", "FREQUENCY", "RESPONSE", "CURVE", "NOTES", "TRANSDUCER", "LOUDSPEAKER"]
        
        let pattern = #"\b(\d{1,2}[A-Za-z]{1,4}\d{1,4}[A-Za-z0-9]*(?:-[0-9A-Za-z+]+)?)\b"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            for match in matches where match.numberOfRanges >= 2 {
                let candidate = nsText.substring(with: match.range(at: 1))
                if !candidate.lowercased().hasPrefix("www") && !candidate.lowercased().hasSuffix(".com") && !exclude.contains(candidate.uppercased()) {
                    return candidate
                }
            }
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
