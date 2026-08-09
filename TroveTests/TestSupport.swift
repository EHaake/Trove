import Foundation
import SwiftData
@testable import Trove

/// A fresh in-memory store holding the real schema — real persistence
/// semantics, no disk, no CloudKit. Each call is an isolated store, so tests
/// can't leak state into one another.
func makeInMemoryContext() throws -> ModelContext {
    let configuration = ModelConfiguration(schema: TroveSchema.schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: TroveSchema.schema, configurations: configuration)
    return ModelContext(container)
}
