import Foundation

struct SimpleError: LocalizedError, CustomStringConvertible {
    var message: String
    
    var errorDescription: String? {
        message
    }
    
    var description: String {
        message
    }
    
    init(_ message: String) {
        self.message = message
    }
}
