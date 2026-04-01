# SwiftUI Architecture

## Current Structure

The app now follows a feature-first SwiftUI layout:

- `ManagementQuizStem/App`
  - app entry and root routing only
- `ManagementQuizStem/Core`
  - cross-feature services and shared state
- `ManagementQuizStem/Features`
  - each product area owns its own views, view models, and models when needed

## Folder Rules

- Put app startup and global routing in `App`.
- Put Firebase configuration, auth session state, repositories, and shared app state in `Core`.
- Put feature screens in `Features/<Feature>/Views`.
- Put feature-specific `ObservableObject` types in `Features/<Feature>/ViewModels`.
- Put feature-specific models in `Features/<Feature>/Models`.
- Keep legacy or not-yet-wired screens in `Features/Legacy`.

## SwiftUI Conventions

- Prefer feature-first organization over layer-first organization at the project root.
- Keep `App` thin. Route from a dedicated root view instead of placing app flow logic directly in `App`.
- Name screens by purpose, not generically. Prefer `AdminShellView` over `ContentView`.
- Keep model, view model, and view types in separate files once a feature grows beyond a trivial screen.
- Put reusable UI only where at least two features need it. Do not create a shared folder too early.
- Keep Firebase and repository code out of views.
- Let views own local presentation state and let view models own async loading, mutation, and remote side effects.

## Recommended Next Steps

- Move the new CMS shell work into `Features/Shell`.
- Break large feature view models into smaller domain-specific types when behavior starts to split.
- Add lightweight previews or mock data files per feature as the redesign continues.
