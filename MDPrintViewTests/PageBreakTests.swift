import Testing
import Foundation
@testable import MDPrintView

@MainActor
@Suite("PageBreakStore")
struct PageBreakTests {

    @Test("fingerprint normalizes whitespace and truncates to 64")
    func fingerprintNormalization() {
        #expect(PageBreak.fingerprint(of: "  a\n\n b\t c  ") == "a b c")
        let long = String(repeating: "x", count: 100)
        #expect(PageBreak.fingerprint(of: long).count == 64)
    }

    @Test("add stores a break at a boundary")
    func add() {
        let store = PageBreakStore()
        store.add(afterBlock: 2, fingerprint: "abc")
        #expect(store.breaks == [PageBreak(afterBlock: 2, fingerprint: "abc")])
    }

    @Test("add on an existing boundary is a no-op")
    func addDuplicate() {
        let store = PageBreakStore()
        store.add(afterBlock: 1, fingerprint: "a")
        store.add(afterBlock: 1, fingerprint: "a")
        #expect(store.breaks.count == 1)
    }

    @Test("remove deletes the break at a boundary")
    func remove() {
        let store = PageBreakStore()
        store.add(afterBlock: 1, fingerprint: "a")
        store.remove(afterBlock: 1)
        #expect(store.breaks.isEmpty)
    }

    // MARK: resolution

    @Test("stable document resolves at the stored boundary")
    func resolveStable() {
        let store = PageBreakStore()
        store.add(afterBlock: 1, fingerprint: "beta")
        #expect(store.resolve(against: ["alpha", "beta", "gamma"]) == [1])
    }

    @Test("block inserted above: fingerprint pulls the break down")
    func resolveInsertAbove() {
        let store = PageBreakStore()
        store.add(afterBlock: 1, fingerprint: "beta")
        // "new" inserted at 0; beta is now index 2
        #expect(store.resolve(against: ["new", "alpha", "beta", "gamma"]) == [2])
    }

    @Test("edited preceding block: index fallback keeps the break")
    func resolveEditedBlock() {
        let store = PageBreakStore()
        store.add(afterBlock: 1, fingerprint: "beta")
        // beta's text changed -> no fingerprint match, but index 1 still exists
        #expect(store.resolve(against: ["alpha", "beta EDITED", "gamma"]) == [1])
    }

    @Test("orphan (doc truncated) is dropped")
    func resolveOrphan() {
        let store = PageBreakStore()
        store.add(afterBlock: 5, fingerprint: "zeta")
        #expect(store.resolve(against: ["alpha"]).isEmpty)
        #expect(store.breaks.isEmpty)   // write-back removed it
    }

    @Test("two anchors resolving to one boundary dedupe")
    func resolveDedupe() {
        let store = PageBreakStore()
        store.add(afterBlock: 1, fingerprint: "beta")
        store.add(afterBlock: 2, fingerprint: "beta")   // same text elsewhere collapsed
        let resolved = store.resolve(against: ["alpha", "beta"])
        #expect(resolved == [1])
        #expect(store.breaks.count == 1)
    }

    @Test("resolution writes back fresh anchors")
    func resolveWriteBack() {
        let store = PageBreakStore()
        store.add(afterBlock: 1, fingerprint: "beta")
        _ = store.resolve(against: ["new", "alpha", "beta"])
        #expect(store.breaks == [PageBreak(afterBlock: 2, fingerprint: "beta")])
    }
}
