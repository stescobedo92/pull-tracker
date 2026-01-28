# PR Tracker

A native macOS menu bar application to track your GitHub Pull Requests across all repositories and organizations.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- 🎯 **Menu Bar Integration** — Quick access to all your PRs from the menu bar
- 🔍 **Search** — Filter PRs by ID, title, or repository name
- 🏷️ **Smart Filtering** — Filter by status: All, Open, Merged, Closed, or Draft
- 🎨 **Dynamic Icon** — Menu bar icon color changes based on selected filter
- 🔄 **Auto Refresh** — Background sync every 5 minutes (1 min when visible)
- 🔐 **Secure** — Token stored in macOS Keychain
- 📊 **Grouped View** — PRs organized by repository

## Screenshots

| Authentication | PR List | Filter |
|:-:|:-:|:-:|
| ![Auth](docs/auth.png) | ![List](docs/list.png) | ![Filter](docs/filter.png) |

## Requirements

- macOS 14.0 (Sonoma) or later
- GitHub Personal Access Token with `repo` and `read:org` scopes

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/sergiotrianaescobedo/pull-tracker.git
cd pull-tracker

# Build and run
swift build
swift run
```

### Build for Release

```bash
swift build -c release
```

The binary will be at `.build/release/PRTracker`

## Setup

1. Create a [GitHub Personal Access Token](https://github.com/settings/tokens/new?scopes=repo,read:org) with:
   - `repo` — Full control of private repositories
   - `read:org` — Read organization membership

2. Launch PR Tracker from the menu bar

3. Paste your token and click **Connect**

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
