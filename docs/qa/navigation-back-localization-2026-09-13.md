# Explicit navigation back localization

The system NavigationStack back item continued displaying the OS-language label after selecting English inside Pushnow. Native-title settings and secure message routes now hide that item and use one leading button whose visible and accessibility text resolve `Back` with the current SwiftUI locale and the explicit app bundle. The button invokes the destination's `dismiss` action, returning one navigation level.

Nested settings, device-management and discovery-timezone NavigationLink destinations use the same modifier. Auth, reminder editor and legacy detail retain their existing custom arrow and hide the redundant native back item. The custom arrow's accessibility name is localized too.

The catalog lacked `Back`; `localization-back-entries.json` supplies all six languages for coordinator merge. No catalog was edited in this subtask. The modifier is in the existing JZChrome.swift, requiring no project-reference edits.

JSON completeness and `git diff --check` passed. No simulator, UI interaction or app build was performed. Device verification should check visible Back text, a single button, one-level navigation, and the swipe-back gesture (hiding native back can affect that gesture).
