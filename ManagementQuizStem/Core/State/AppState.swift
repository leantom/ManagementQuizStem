//
//  AppState.swift
//  ManagementQuizStem
//
//  Created by QuangHo on 21/11/24.
//


import SwiftUI

class AppState: ObservableObject {
    static let shared = AppState()
    
    var topics: [Topic] = []
    @Published var selectedDifficulty: DifficultyLevel = .beginner
    
    init() {
       
    }
 
    
}
