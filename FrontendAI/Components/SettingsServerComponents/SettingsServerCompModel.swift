//
//  SettingsServerCompModel.swift
//  FrontendAI
//
//  Created by macbook on 14.04.2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class SSCmodel {
    @Attribute var temperature: Double
    @Attribute var top_k: Double
    @Attribute var top_p: Double
    @Attribute var Max_Context_Length: Int
    @Attribute var Max_Generated_Tokens: Int
    @Attribute var Repeat_Penalty: Double
    @Attribute var avatarSystemName: String

    init(
        temperature: Double = 0.7,
        top_k: Double = 40,
        top_p: Double = 0.9,
        Max_Context_Length: Int = 2048,
        Max_Generated_Tokens: Int = 1024,
        Repeat_Penalty: Double = 1.0,
        avatarSystemName: String = "gear"
    ) {
        self.temperature = temperature
        self.top_k = top_k
        self.top_p = top_p
        self.Max_Context_Length = Max_Context_Length
        self.Max_Generated_Tokens = Max_Generated_Tokens
        self.Repeat_Penalty = Repeat_Penalty
        self.avatarSystemName = avatarSystemName
    }

    convenience init(from settings: SSC) {
        self.init(
            temperature: settings.temperature,
            top_k: settings.top_k,
            top_p: settings.top_p,
            Max_Context_Length: settings.Max_Context_Length,
            Max_Generated_Tokens: settings.Max_Generated_Tokens,
            Repeat_Penalty: settings.Repeat_Penalty,
            avatarSystemName: settings.avatarSystemName
        )
    }

    func asSSC() -> SSC {
        return SSC(
            temperature: self.temperature,
            top_k: self.top_k,
            top_p: self.top_p,
            Max_Context_Length: self.Max_Context_Length,
            Max_Generated_Tokens: self.Max_Generated_Tokens,
            Repeat_Penalty: self.Repeat_Penalty,
            avatarSystemName: self.avatarSystemName
        )
    }
}
