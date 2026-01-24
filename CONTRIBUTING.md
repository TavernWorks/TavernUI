# Contributing to TavernUI

Thank you for your interest in contributing to TavernUI! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and considerate
- Provide constructive feedback
- Help others learn and grow

## Getting Started

### Prerequisites

- Git installed on your system
- A code editor (VS Code recommended)
- World of Warcraft installed for testing
- [BigWigs Packager](https://github.com/BigWigsMods/packager) (for library management)

### Development Setup

1. **Fork and Clone the Repository**
   `Bash
   git clone https://github.com/your-username/TavernUI.git
   cd TavernUI
   `

2. **Set Up Libraries**
   
   See [DEVELOPER.md](DEVELOPER.md) for detailed instructions on downloading libraries.

   Quick start:
   `Bash
   # Using BigWigs Packager (recommended)
   bash release.sh -d -z
   
   # Then copy libraries from .release/TavernUI/libs/ to libs/
   # Or use the setup script if available
   `

3. **Link to WoW AddOns Directory**
   
   Create a symlink or copy the addon to your WoW AddOns folder for testing:
   `Bash
   # Windows (PowerShell as Administrator)
   New-Item -ItemType SymbolicLink -Path "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\TavernUI" -Target "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\TavernUI"
   `

## Development Workflow

### Branch Naming

- feature/description - New features
- fix/description - Bug fixes
- refactor/description - Code refactoring
- docs/description - Documentation updates

### Making Changes

1. Create a new branch from main:
   `Bash
   git checkout -b feature/your-feature-name
   `

2. Make your changes
   - Follow the existing code style
   - Add comments for complex logic
   - Test your changes in-game

3. Commit your changes:
   `Bash
   git add .
   git commit -m "Description of your changes"
   `
   
   **Commit Message Guidelines:**
   - Use clear, descriptive messages
   - Start with a verb (Add, Fix, Update, Remove, etc.)
   - Keep the first line under 72 characters
   - Add detailed description if needed

4. Push to your fork:
   `Bash
   git push origin feature/your-feature-name
   `

5. Create a Pull Request on GitHub

## Code Style

### Lua Style Guide

- Use 4 spaces for indentation (no tabs)
- Use camelCase for local variables
- Use PascalCase for global namespaces
- Use UPPER_CASE for constants
- Add comments for complex logic
- Keep functions focused and small

### Example

`lua
-- Good
local function calculateHealth(unit)
    local health = UnitHealth(unit)
    local maxHealth = UnitHealthMax(unit)
    return health, maxHealth
end

-- Avoid
local function calc(u) return UnitHealth(u),UnitHealthMax(u) end
`

## Testing

- Test all changes in-game before submitting
- Test with and without optional dependencies
- Test on different resolutions if UI-related
- Check for Lua errors in the console (/script)

## Pull Request Process

1. **Update Documentation**
   - Update README.md if adding features
   - Add/update code comments
   - Update CHANGELOG.md if applicable

2. **Describe Your Changes**
   - What does this PR do?
   - Why is this change needed?
   - How was it tested?

3. **Keep PRs Focused**
   - One feature/fix per PR
   - Keep changes reasonably sized
   - Rebase on main if needed

4. **Respond to Feedback**
   - Address review comments
   - Make requested changes
   - Be open to suggestions

## Reporting Issues

When reporting bugs or requesting features:

1. **Check Existing Issues**
   - Search for similar issues
   - Check if it's already fixed in a newer version

2. **Provide Information**
   - WoW version
   - Addon version
   - Steps to reproduce
   - Error messages (if any)
   - Screenshots if relevant

3. **Use Issue Templates**
   - Bug reports
   - Feature requests
   - Questions

## Questions?

- Open a discussion on GitHub
- Check existing issues and PRs
- Review the code and documentation

Thank you for contributing to TavernUI!
