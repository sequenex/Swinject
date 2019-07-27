//
//  Copyright © 2019 Swinject Contributors. All rights reserved.
//

struct BinderVariation {
    let args: Int
    let hasResolver: Bool
    let hasContext: Bool
    let isMatchable: Bool
    let isScoped: Bool
    let isContexted: Bool
}

extension BinderVariation {
    var argTypes: String {
        join((1 ..< args + 1).map { "Arg\($0)" })
    }

    var argTypesOrNil: String? {
        argTypes.isEmpty ? nil : argTypes
    }

    var genericTypes: String {
        join("Type", argTypesOrNil)
    }

    var builderInputTypes: String {
        join(
            hasResolver ? "Resolver" : nil,
            hasContext ? "Context" : nil,
            argTypesOrNil
        )
    }

    var params: String {
        join(
            isScoped ? "ref: @escaping ReferenceMaker<Type> = strongRef" : nil,
            "_ builder: @escaping (\(builderInputTypes)) throws -> Type"
        )
    }

    var scopeType: String {
        isContexted ? "AScope" : "UnboundScope"
    }

    var scopeVar: String {
        isContexted ? "scope" : ".root"
    }

    var contextType: String {
        isContexted ? "Context" : "Any"
    }

    var argReturnType: String {
        switch args {
        case 0: return "Void"
        case 1: return isMatchable ? "MatchableBox1<Arg1>" : "Arg1"
        default: return isMatchable ? "MatchableBox\(args)<\(argTypes)>" : "(\(argTypes))"
        }
    }

    var returnType: String {
        if isScoped {
            return "ScopedBinding.Builder<Type, \(scopeType), \(argReturnType)>"
        } else {
            return "SimpleBinding.Builder<Type, \(contextType), \(argReturnType)>"
        }
    }

    var hashableArgTypes: String {
        join((1 ..< args + 1).map { "Arg\($0): Hashable" })
    }

    var constraints: String {
        isMatchable && args > 0 ? "where \(hashableArgTypes) " : ""
    }

    var functionName: String {
        switch (isScoped, args > 0) {
        case (true, true): return "multiton"
        case (true, false): return "singleton"
        case (false, true): return "factory"
        case (false, false): return "provider"
        }
    }

    var initVars: String {
        isScoped ? "(\(join(scopeVar, "ref")))" : ""
    }

    var argVarsOrNil: String? {
        switch args {
        case 0: return nil
        case 1: return isMatchable ? "a.arg1" : "a"
        default: return join((1 ... args).map { isMatchable ? "a.arg\($0)" : "a.\($0 - 1)" })
        }
    }

    var builderInputs: String {
        join(
            hasResolver ? "r" : "_",
            hasContext ? "c" : "_",
            args > 0 ? "a" : "_"
        )
    }

    var builderVars: String {
        join(
            hasResolver ? "r" : nil,
            hasContext ? "c" : nil,
            argVarsOrNil
        )
    }
}

extension BinderVariation {
    static let maxArgs = 5

    static let allCases = (0 ... maxArgs)
        .flatMap { t in [false, true].map { (t, $0) } }
        .flatMap { t in [false, true].map { (t.0, t.1, $0) } }
        .flatMap { t in [false, true].map { (t.0, t.1, t.2, $0) } }
        .flatMap { t in [false, true].map { (t.0, t.1, t.2, t.3, $0) } }
        .flatMap { t in [false, true].map { (t.0, t.1, t.2, t.3, t.4, $0) } }
        .map(BinderVariation.init)

    static let sortedCases = allCases.sorted { [
        !$0.isScoped && $1.isScoped,
        $0.args < $1.args,
        !$0.isMatchable && $1.isMatchable && $0.args == $1.args,
    ].contains(true) }

    static let publicCases = sortedCases
        .filter { !($0.hasContext && !$0.isContexted) }
        .filter { !($0.hasContext && !$0.hasResolver) }
        .filter { !($0.args == 0 && !$0.isMatchable) }
        .filter { !($0.args > 0 && !$0.hasResolver) }
        .filter { !($0.args > 0 && $0.isContexted && !$0.hasContext) }
        .filter { !($0.isScoped && !$0.isMatchable) }
}

extension BinderVariation {
    func render(_ indent: Bool) -> String {
        let prefix = indent ? "    " : ""
        return """
        \(prefix)public func \(functionName)<\(genericTypes)>(\(params)) -> \(returnType) \(constraints){
        \(prefix)    .init\(initVars) { \(builderInputs) in try builder(\(builderVars)) }
        \(prefix)}
        """
    }
}