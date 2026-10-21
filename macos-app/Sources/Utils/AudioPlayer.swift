import AudioToolbox
import AVFoundation

public class AudioPlayer {
    public static let shared = AudioPlayer()
    public var soundEnabled: Bool = true
    
    private init() {}
    
    public func playKeyClick(isEnter: Bool = false) {
        guard soundEnabled else { return }
        if isEnter {
            AudioServicesPlaySystemSound(1104) // macOS system key press sound
        } else {
            AudioServicesPlaySystemSound(1103) // Light mechanical click
        }
    }
    
    public func playSwitchSound() {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(1105) // Toggle switch sound
    }
}
