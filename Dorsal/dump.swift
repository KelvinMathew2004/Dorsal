import FoundationModels
import Foundation

func dumpType() {
    print("Methods and Properties of SystemLanguageModel:")
    let mirror = Mirror(reflecting: SystemLanguageModel.default)
    for child in mirror.children {
        print("\(child.label ?? ""): \(type(of: child.value))")
    }
}
dumpType()
