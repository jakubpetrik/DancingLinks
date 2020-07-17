//
//  DancingLinks.swift
//
//  Created by Michel Tilman on 04/06/2019.
//  Copyright © 2019 Dotted.Pair.
//  Licensed under Apache License v2.0.
//

/**
 Identifies the algorithm implementation to use.
 */
public enum DancingLinksAlgorithm {
    
    case classy, structured, structuredNR
    
    // MARK: Resolving implementations
    
    // Answers the implementation for given algorithm.
    func implementation<G>() -> AnyDancingLinks<G> where G: Grid {
        switch self {
        case .classy: return AnyDancingLinks(ClassyDancingLinks())
        case .structured: return AnyDancingLinks(StructuredDancingLinks())
        case .structuredNR: return AnyDancingLinks(StructuredDancingLinksNR())
        }
    }
    
}


/**
 Type-erased algorithm implementation wrapper.
 */
struct AnyDancingLinks<G>: DancingLinks where G: Grid {
    
    // MARK: Private stored properties
    
    // Solver method of the wrapped implementation.
    private let solve: (G, SearchStrategy, (Solution<G.RowId>, SearchState) -> ()) -> ()
    
    // MARK: Initializing
    
    /// Wraps given algorithm.
    init<A>(_ algorithm: A) where A: DancingLinks, A.G == G {
        solve = algorithm.solve
    }
    
    // MARK: Solving
    
    /// Applies the wrapped algorithm.
    func solve(grid: G, strategy: SearchStrategy, handler: (Solution<G.RowId>, SearchState) -> ()) {
        solve(grid, strategy, handler)
    }
    
}


/**
 DancingLinks input represented as a list of sparse grid rows.
 A valid row has a unique reference and one or more constraints that the row satisfies.
 Rows without constraints are skipped.
 The DancingLinks algorithm does not attribute a specific meaning to the row reference or to the constraints.
 */
protocol Grid {
    
    /// Unique reference of a row.
    associatedtype RowId
    
    /// Generates rows consisting of a reference and a list of constraint columns,
    /// Each row is input into the consumer.
    func generateRows(consume: (RowId, Int...) -> ())
    
    /// Maximum number of mandatory constraints for the DancingLinks input.
    /// Mandatory constraints are specified by index, starting at 0 up to *constraints*.
    /// There must be at least one mandatory constraint.
    var constraints: Int { get }
    
    /// Maximum number of optional constraints for the DancingLinks input.
    /// Optional constraints are specified by index, starting at *constraints* up to *constraints + optionalConstraints*.
    var optionalConstraints: Int { get }
    
}


/**
 Solution consisting of a subset of row references generated by a grid.
 */
struct Solution<RowId> {
    
    /// List of unique row references satisfying the constraints.
    /// Examples:
    /// * For a sudoku, the size of the list = the number of cells in the sudoku.
    /// Each row reference identifies a cell and the correct value for that cell.
    /// * For the 8-Queens problem, the list has size 8. Each row reference
    /// identifies a square on the chessboard for a queen.
    let rows: [RowId]
    
}


/**
 Search strategies.
 At each step in the search process, the DancingLinks algorithm selects a constraint column.
 The search strategy determines how this column is selected.
 * Naive: selects the first available (i.e. uncovered) mandatory column.
 * Minimum size: selects the first available mandatory column with minimum size.
 If no column is available, the options are exhausted and the algorithm backtracks if possible.
 */
enum SearchStrategy {
    case naive
    case minimumSize
}


/**
 Search state.
 By default the algorithm continues until the search space is exhausted.
 The search process can also be marked as terminated by the client in the solution handler.
 After termination the algorithm should stop searching.
 Additional info may be added to the state, such as statistics about the search process.
 */
class SearchState {
    
    // MARK: Stored properties
    
    /// Flag indicating if search should stop.
    public private (set) var terminated = false
    
    // MARK: Updating state
    
    /// Inform the algorithm that the search should stop.
    public func terminate() {
        terminated = true
    }
    
}


/**
 Superclass for the DancingLinks implementations (cf. Donald Knuth's Algorithm X).
 Note. This was originally a protocol, but this caused some performance problems. May revert to protocol in Swift 5.3.
 Note. Convenience solvers no longer in extension, as it affects performance in Swift 5.2 and 5.3.
 */
protocol DancingLinks {
    
    associatedtype G where G: Grid
    
    // MARK: Solving
    
    /// Reads a grid of sparse rows and injects each solution and the search state in the handler.
    /// Grid and solution use the same type of row identification.
    /// The algorithm should stop when the search space has been exhausted or when the handler instructs it to stop.
    /// The handler stops the search by marking the search state as terminated.
    /// The search strategy may affect the performance and the order in which solutions are generated.
    /// Abstract method, must be implemented in adopting types.
    func solve(grid: G, strategy: SearchStrategy, handler: (Solution<G.RowId>, SearchState) -> ())
    
}


/**
 Convenience solvers.
 */
extension DancingLinks {
    
    // MARK: Convenience solving
    
    /// Reads a grid of sparse rows and returns the solutions, optionally up to a limit.
    /// The default search strategy selects the first column with smallest size.
    func solve(grid: G, strategy: SearchStrategy = .minimumSize, limit: Int? = nil) -> [Solution<G.RowId>] {
        var solutions = [Solution<G.RowId>]()

        solve(grid: grid, strategy: strategy) { solution, state in
            guard let limit = limit else { return solutions.append(solution) }
            
            if solutions.count < limit {
                solutions.append(solution)
            }
            if solutions.count >= limit {
                state.terminate()
            }
        }
        
        return solutions
    }
    
    /// Returns the first solution found, or nil if no solution found.
    /// Uses the minimum column size search strategy.
    func solve(grid: G) -> Solution<G.RowId>? {
        solve(grid: grid, limit: 1).first
    }

}
