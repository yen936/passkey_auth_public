//
//  CothuraApp.swift
//  Cothura
//
//  Created by Benji Magnelli on 7/6/23.
//

import SwiftUI

@main
struct CothuraApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
