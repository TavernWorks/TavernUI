# Developer Setup Guide

This guide explains how to set up the TavernUI development environment, including downloading required libraries.

## Prerequisites

- Git installed
- [BigWigs Packager](https://github.com/BigWigsMods/packager) (for library management)
- SVN client (for CurseForge repositories) - Optional but recommended

## Library Management

TavernUI uses embedded libraries managed via .pkgmeta. The libs/ folder is gitignored and must be downloaded separately.

### Method 1: Using BigWigs Packager (Recommended)

The BigWigs Packager is the standard tool for managing WoW addon libraries.

#### Installation

1. **Download the Packager:**
   - Visit: https://github.com/BigWigsMods/packager/releases
   - Download the latest release
   - Extract to a location in your PATH, or use it directly

2. **Install via pip (Alternative):**
   ```Bash
   pip install bigwigs-packager
   ```

#### Downloading Libraries

1. **Run the packager:**
   ```Bash
   # From the TavernUI directory
   bash release.sh -d -z
   ```
   
   Flags:
   - -d - Skip uploading
   - -z - Skip zip file creation
   - -o - Overwrite existing package directory (use if updating)

2. **Copy libraries to development folder:**
   
   The packager downloads libraries to .release/TavernUI/libs/. Copy them to your main libs/ folder:
   
   ```Bash
   # Windows (PowerShell)
   Copy-Item -Path ".release\TavernUI\libs\*" -Destination "libs\" -Recurse -Force
   
   # Linux/Mac
   cp -r .release/TavernUI/libs/* libs/
   ```

3. **Verify libraries are present:**
   ```Bash
   # Check that libs folder contains the libraries
   ls libs/
   ```

4. **EditModeExpanded-1.0:** If the packager does not support the `path` option and `libs/EditModeExpanded-1.0` is missing or contains the full repo, copy only the library folder: clone [EditModeExpanded](https://github.com/teelolws/EditModeExpanded), then copy `Source/libs/EditModeExpanded-1.0` into `TavernUI/libs/EditModeExpanded-1.0`. The library is used for Resource Bars Edit Mode integration (credit: Teelo).

#### Troubleshooting

**Error: "svn is not available"**
- Install SVN client (TortoiseSVN on Windows, or svn package on Linux/Mac)
- Or use Git alternatives in .pkgmeta (see Method 2)

**Libraries not downloading:**
- Check .pkgmeta syntax
- Ensure all URLs are correct
- Check network connectivity
- Review packager output for errors

## Need Help?

- Check existing issues on GitHub
- Review the code and comments
- Ask in discussions or open an issue
