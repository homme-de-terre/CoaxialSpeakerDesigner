import Foundation

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
        
        let rawText = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        
        // Extract parameters using regex patterns
        let ts = parseTSFromText(rawText)
        let tweeter = parseTweeterFromText(rawText)
        let driverName = extractDriverName(rawText, url: url)
        
        return (ts, tweeter, driverName, rawText)
    }
    
    /// Extract Thiele-Small parameters from raw text using regex matching.
    public func parseTSFromText(_ text: String) -> WooferTSParameters {
        var ts = WooferTSParameters()
        
        if let val = findValue(pattern: #"\bFs\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.fs = val }
        if let val = findValue(pattern: #"\bQes\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.qes = val }
        if let val = findValue(pattern: #"\bQms\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.qms = val }
        if let val = findValue(pattern: #"\bQts\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.qts = val }
        if let val = findValue(pattern: #"\bVas\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.vas = val }
        if let val = findValue(pattern: #"\bRe\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.re = val }
        if let val = findValue(pattern: #"\bLe\b\s*(?:\([^)]*\))?\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.le = val }
        if let val = findValue(pattern: #"\bSd\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.sd = val }
        if let val = findValue(pattern: #"\bX-?max\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.xmax = val }
        if let val = findValue(pattern: #"\b(?:Sensitivity|SPL)\b\s*[:=.]*\s*([\d.]+)"#, text: text) { ts.spl = val }
        
        // Recalculate Qts if Qes and Qms were found
        if ts.qes > 0 && ts.qms > 0 {
            ts.qts = (ts.qes * ts.qms) / (ts.qes + ts.qms)
        }
        
        return ts
    }
    
    /// Extract Tweeter parameters from raw text.
    public func parseTweeterFromText(_ text: String) -> TweeterParameters {
        var tw = TweeterParameters()
        if let val = findValue(pattern: #"(?:Tweeter\s*Fs|HF\s*Fs)\s*[:=.]*\s*([\d.]+)"#, text: text) { tw.fs = val }
        if let val = findValue(pattern: #"(?:Tweeter\s*Re|HF\s*Re)\s*[:=.]*\s*([\d.]+)"#, text: text) { tw.re = val }
        if let val = findValue(pattern: #"(?:Tweeter\s*SPL|HF\s*Sensitivity|HF\s*SPL)\s*[:=.]*\s*([\d.]+)"#, text: text) { tw.spl = val }
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
    
    private func extractDriverName(_ text: String, url: URL) -> String {
        let filename = url.lastPathComponent.replacingOccurrences(of: ".pdf", with: "").replacingOccurrences(of: ".html", with: "")
        if !filename.isEmpty && filename != "/" {
            return filename.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return "Coaxial Loudspeaker Driver"
    }
}
