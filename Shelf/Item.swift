//
//  Item.swift
//  Shelf
//
//  Created by Rinko  on 2026/09/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
