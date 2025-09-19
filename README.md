# Repository Overview

This is the **Amphora Technologies Code Standards Repository** - a centralized configuration system for linting and formatting across all company projects. The repository provides global ESLint and Python linting configurations that can be applied consistently across JavaScript, TypeScript, React, React Native, Vue, and Python projects.

## Key Architecture

### Directory Structure

- `AmphoraExperience/code-standards/` - Main code standards directory
- `AmphoraExperience/code-standards/configs/` - Configuration files
  - `configs/eslint/` - ESLint configurations for JS/TS projects
  - `configs/python/` - Python linting configurations (Flake8, Black, etc.)
- `AmphoraExperience/code-standards/.vscode/` - VSCode/Cursor IDE settings and extensions

### Core Configuration System

**ESLint Configuration**: The system uses a sophisticated auto-detection approach:

- `eslint.common.js` - Base rules applied to all projects
- `eslint.config.js` - Framework-specific extensions that auto-detect project type
- Auto-detection logic checks `package.json` dependencies and `tsconfig.json` to determine if project is React, React Native, Vue, TypeScript, or vanilla JavaScript
- Supports universal React JSX handling for all JS/TS files

**Python Configuration**: Comprehensive Python linting setup:

- `.flake8` config with 88 character line length
- `pyproject.toml` for Black formatter and isort
- `requirements-linting.txt` with all necessary Python linting tools

**IDE Integration**: Global settings for VSCode/Cursor with:

- Auto-formatting on save
- ESLint integration with custom config path
- Python linting integration
- Recommended extensions for development

## Essential Commands

### Initial Setup

```bash
# Run the global setup script to install and configure linting
./AmphoraExperience/code-standards/setup-global-eslint.sh
```

This script will:

- Move the standards to `~/Desktop/AmphoraExperience`
- Install ESLint dependencies via npm
- Configure VSCode/Cursor global settings
- Install recommended IDE extensions automatically
- Set up Python linting tools (when enabled)
- All code repositories from Amphora MUST be used under the folder AmphoraExperience/repos/

### Cleanup Local Configs

```bash
# Remove local linting configs to use global standards
./AmphoraExperience/code-standards/clean-up.sh
```

This removes local ESLint, Prettier, and Python linting configuration files that would override the global standards.

### Linting Operations

```bash
# Install ESLint dependencies (run from configs/eslint/)
cd AmphoraExperience/code-standards/configs/eslint
npm install

# Install Python linting tools
pip install -r AmphoraExperience/code-standards/configs/python/requirements-linting.txt

# Test ESLint configuration
npx eslint --config ./configs/eslint/eslint.config.js [file/directory]
```

## Code Standards Rules

### JavaScript/TypeScript Standards

- **Indentation**: 3 spaces (not 2 or 4)
- **Quotes**: Single quotes enforced
- **Line Length**: 160 characters maximum
- **Objects**: Properties on separate lines when 3+ properties
- **Imports**: Sorted with specific member syntax order
- **Spacing**: Enforced around operators, function calls, blocks
- **Comma Style**: Trailing commas never allowed
- **Padding**: Required blank lines between statements and blocks

### Framework-Specific Rules

- **React**: JSX component detection, hooks rules, prop-types disabled
- **React Native**: More lenient console warnings, RN-specific style rules
- **Vue**: Component naming in PascalCase, explicit emits required
- **TypeScript**: Flexible any usage, no explicit return types required

### Python Standards

- **Line Length**: 88 characters (Black standard)
- **Formatting**: Black for code formatting
- **Import Sorting**: isort with consistent organization
- **Linting**: Flake8 with multiple plugin extensions
- **Type Checking**: mypy integration available

### Custom Business Logic Rules

The configuration includes specific exceptions for logistics domain terms:

- Allows snake_case for business-specific fields: `shipping_number`, `wh_packed`, `is_printed`, `created_at`, `updated_at`, `user_id`, `station_id`

## Architecture Notes

**Global vs Local Configuration**: This system is designed to eliminate local linting configurations in favor of a single, centralized approach. The setup script automatically detects and configures VSCode/Cursor to use the global settings.

**Auto-Detection Logic**: The ESLint configuration intelligently adapts to different project types by examining `package.json` dependencies and file presence, eliminating the need for manual configuration per project.

**Cross-Platform Support**: Setup scripts detect macOS, Linux, and Windows environments and configure appropriate IDE paths and settings.

**Extension Management**: The system automatically installs required VSCode/Cursor extensions including ESLint, Prettier, React Native tools, Vue support, and Python linting extensions.

## Development Workflow

1. **New Project Setup**: Run `setup-global-eslint.sh` to configure global standards
2. **Existing Project Migration**: Run `clean-up.sh` to remove local configs, then restart IDE
3. **Standards Updates**: Changes to configs are automatically picked up by all projects using the global configuration
4. **IDE Integration**: Format-on-save and auto-fix are enabled by default through global settings

## File Associations and Language Support

The system supports comprehensive file type detection and appropriate linting:

- JavaScript/TypeScript: `.js`, `.jsx`, `.ts`, `.tsx`, `.mjs`, `.cjs`
- Vue: `.vue` files with special parser configuration
- Python: `.py` files with Black formatting and Flake8 linting
- Configuration: JSON, YAML, TOML files with appropriate formatters
- Special handling for React Native platform-specific files

## Amphora Technologies

[![StackShare](http://img.shields.io/badge/tech-stack-0690fa.svg?style=flat)](https://stackshare.io/amphora-logistics/amphora-logistics)

## About us

<https://www.amphoralogistics.com/?lang=en>

## Want to work with us?

<info@amphoralogistics.com>
