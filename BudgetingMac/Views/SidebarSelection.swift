import Foundation

/// The set of destinations reachable from the sidebar.
///
/// Replaces the magic string literals (`"___ALL___"`, `"___CATEGORIES___"`,
/// `"___PORTFOLIO___"`, `"___DAILY___"`) that were previously scattered across
/// `SidebarView`, `MainContentView`, and `DetailView`. As an enum, the compiler
/// checks every case at the routing site — adding a new view means adding a case
/// here and a branch in `MainContentView`, with no risk of a typo'd string.
///
/// `tag(String)` is the "filter by this tag" case; the associated string is the
/// tag name to filter entries by.
enum SidebarSelection: Hashable {
    case allEntries
    case categories
    case portfolio
    case dailySpend
    case tag(String)
}
