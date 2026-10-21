import AppKit
import Combine

public class KeyboardMonitor {
    private var monitor: Any?
    
    public init() {}
    
    public func startMonitoring(engine: RPNEngine, activeKeyPressed: @escaping (String) -> Void) {
        stopMonitoring()
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak engine] event in
            guard let engine = engine, engine.powerOn else { return event }
            
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let keyCode = event.keyCode
            
            // Highlight helper
            let flashKey: (String) -> Void = { keyId in
                activeKeyPressed(keyId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    activeKeyPressed("")
                }
            }
            
            // 1. European Dead Key (^°) physical key code 10 or caret or Y or **
            if keyCode == 10 || chars == "^" || chars == "y" {
                engine.binaryOp(.pow)
                flashKey("pow")
                return nil // Consume event to prevent dead key composition
            }
            
            // 2. Digits & decimal
            if let first = chars.first, first.isNumber || first == "." {
                engine.digit(String(first))
                flashKey(first == "." ? "dot" : String(first))
                return nil
            }
            
            // 3. Enter & Space
            if keyCode == 36 || keyCode == 49 { // Return or Space
                engine.enter()
                flashKey("enter")
                return nil
            }
            
            // 4. Backspace (Clear X)
            if keyCode == 51 {
                engine.clearX()
                flashKey("clx")
                return nil
            }
            
            // 5. Escape or Forward Delete (Clear All)
            if keyCode == 53 || keyCode == 117 {
                engine.clearAll()
                flashKey("clr")
                return nil
            }
            
            // 6. Basic Math
            switch chars {
            case "+":
                engine.binaryOp(.add)
                flashKey("add")
                return nil
            case "-":
                engine.binaryOp(.sub)
                flashKey("sub")
                return nil
            case "*":
                engine.binaryOp(.mul)
                flashKey("mul")
                return nil
            case "/":
                engine.binaryOp(.div)
                flashKey("div")
                return nil
            case "v":
                engine.unaryOp(.sqrt)
                flashKey("sqrt")
                return nil
            case "g":
                engine.unaryOp(.log)
                flashKey("log")
                return nil
            case "h":
                engine.unaryOp(.ln)
                flashKey("ln")
                return nil
            case "d":
                engine.unaryOp(.exp)
                flashKey("exp")
                return nil
            case "u":
                engine.unaryOp(.inv)
                flashKey("inv")
                return nil
            case "r", "q":
                engine.rollDown()
                flashKey("roll")
                return nil
            case "x", "w":
                engine.swap()
                flashKey("swap")
                return nil
            case "s":
                engine.unaryOp(.sin)
                flashKey("sin")
                return nil
            case "c":
                engine.unaryOp(.cos)
                flashKey("cos")
                return nil
            case "t":
                engine.unaryOp(.tan)
                flashKey("tan")
                return nil
            case "a", "i":
                engine.toggleArc()
                flashKey("arc")
                return nil
            case "m":
                engine.storeMemory()
                flashKey("sto")
                return nil
            case "l", "k":
                engine.recallMemory()
                flashKey("rcl")
                return nil
            case "e":
                engine.enterExponent()
                flashKey("eex")
                return nil
            case "p":
                engine.pi()
                flashKey("pi")
                return nil
            case "n", "~":
                engine.changeSign()
                flashKey("chs")
                return nil
            default:
                break
            }
            
            return event
        }
    }
    
    public func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
