//
//  ActorIsolated.swift
//  FrontendAI
//
//  Created by macbook on 31.05.2025.
//


// ActorIsolated.swift
import Foundation

actor ActorIsolated<Value> {
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withValue(_ operation: (inout Value) -> Void) {
        operation(&value)
    }

    func replace(with newValue: Value) -> Value {
        let oldValue = value
        value = newValue
        return oldValue
    }
}
