# Debug Test Script for Metasploit Framework

A comprehensive testing and debugging script designed to help developers, researchers, and users quickly diagnose issues with the Metasploit Framework.

## Overview

The Debug Test Script provides an easy-to-use interface for testing various components of the Metasploit Framework, including:

- Module loading and validation
- Payload functionality 
- Exploit module testing
- Auxiliary module testing
- Framework component testing
- Debug information collection

## Usage

### Basic Usage

```bash
# Run all tests with default settings
./tools/dev/debug_test

# Or run the script directly
ruby tools/dev/debug_test_script.rb
```

### Command Line Options

```bash
-v, --verbose           Enable verbose output
-f, --format FORMAT     Output format (text, json, xml)
-m, --modules           Test module loading and validation
-p, --payloads          Test payload functionality
-e, --exploits          Test exploit modules
-a, --auxiliary         Test auxiliary modules
-A, --all               Run all available tests (default)
-q, --quick             Run quick tests only (faster execution)
-s, --save [FILE]       Save results to file (optional filename)
    --filter PATTERN    Filter modules by name pattern
-h, --help              Show help message
    --version           Show version information
```

### Examples

```bash
# Run only payload tests with verbose output
./tools/dev/debug_test -p -v

# Run all tests and save results as JSON
./tools/dev/debug_test -A -f json -s debug_results.json

# Quick test of modules only
./tools/dev/debug_test -m -q

# Test exploits with pattern filtering
./tools/dev/debug_test -e --filter "multi/handler"

# Comprehensive test with verbose output and XML results
./tools/dev/debug_test -A -v -f xml -s comprehensive_test.xml
```

## Features

### 1. Framework Initialization Testing
- Verifies Metasploit Framework can be properly initialized
- Collects system and environment information
- Tests basic framework components

### 2. Module Testing
- **Module Loading**: Tests loading of different module types (exploits, auxiliary, payloads, etc.)
- **Module Enumeration**: Verifies all module categories are accessible
- **Sample Module Testing**: Loads and validates sample modules from each category

### 3. Payload Testing
- Tests payload enumeration and availability
- Validates basic payload creation
- Checks payload option structures

### 4. Exploit Testing
- Tests exploit module loading
- Validates exploit module structure and required methods
- Verifies exploit enumeration

### 5. Auxiliary Testing
- Tests auxiliary module loading and enumeration
- Validates auxiliary module structure
- Tests basic auxiliary functionality

### 6. Framework Component Testing
- **Datastore Testing**: Validates datastore operations (set/get/delete)
- **Module Manager**: Tests module manager functionality
- **Debug Module**: Tests the framework's built-in debug capabilities

### 7. Output Formats

#### Text Format (Default)
Human-readable output with color coding:
- ✓ Green checkmarks for passed tests
- ✗ Red X marks for failed tests  
- Color-coded log levels (info, success, error, warning, debug)

#### JSON Format
Structured JSON output suitable for programmatic parsing:
```json
{
  "tests_run": 15,
  "tests_passed": 14,
  "tests_failed": 1,
  "errors": [...],
  "warnings": [...],
  "debug_info": {...}
}
```

#### XML Format
XML-structured output for integration with reporting tools.

## Integration with Metasploit Framework

### Command Line Integration
The script can be easily integrated into development workflows:

```bash
# Add to your PATH for global access
export PATH=$PATH:/path/to/metasploit-framework/tools/dev

# Run from any directory
debug_test --help
```

### Framework Integration
The script uses the Metasploit Framework's native APIs and follows framework conventions:

- Uses `Msf::Simple::Framework.create()` for initialization
- Leverages existing debug infrastructure (`Msf::Ui::Debug`)
- Compatible with framework module loading mechanisms
- Respects framework configuration and environment

### Hook Integration
The script can be hooked into other testing frameworks or CI/CD pipelines:

```bash
# Exit codes for CI integration
# 0 = all tests passed
# 1 = one or more tests failed

# Example CI usage
if ! ./tools/dev/debug_test -q; then
    echo "Debug tests failed - see output above"
    exit 1
fi
```

## Debugging Scenarios

### 1. Module Loading Issues
```bash
# Test if modules are loading properly
./tools/dev/debug_test -m -v
```

### 2. Payload Problems
```bash
# Focused payload testing
./tools/dev/debug_test -p -v --filter "shell"
```

### 3. Framework Installation Issues
```bash
# Quick comprehensive test
./tools/dev/debug_test -A -q
```

### 4. Development Testing
```bash
# Full test suite with detailed output and results saving
./tools/dev/debug_test -A -v -s development_test_results.json
```

## Error Handling and Reporting

The script provides comprehensive error handling:

- **Graceful Degradation**: Tests continue even if some components fail
- **Detailed Error Reporting**: Full stack traces and context for debugging
- **Categorized Results**: Clear separation of passed/failed tests
- **Debug Information Collection**: System info, framework version, configuration details

## Performance Considerations

- **Quick Mode (`-q`)**: Runs essential tests only for faster feedback
- **Selective Testing**: Run only specific test categories as needed
- **Resource Management**: Proper cleanup of framework resources
- **Timeout Handling**: Prevents hanging on problematic modules

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure the script has execute permissions
   ```bash
   chmod +x tools/dev/debug_test_script.rb
   chmod +x tools/dev/debug_test
   ```

2. **Module Path Issues**: The script automatically detects framework paths
   
3. **Ruby Load Path**: The script automatically adds the framework lib directory

4. **Database Errors**: The script runs with database disabled by default

### Debug Output
Enable verbose mode for detailed debugging information:
```bash
./tools/dev/debug_test -v
```

## Contributing

When contributing to the debug test script:

1. Follow existing code patterns and style
2. Add comprehensive error handling for new test cases
3. Update documentation for new features
4. Test with various framework configurations
5. Ensure compatibility with different Ruby versions

## License

This script is part of the Metasploit Framework and is subject to the same license terms.