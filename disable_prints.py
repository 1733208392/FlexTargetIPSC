#!/usr/bin/env python3
"""
Script to disable all print statements in GDScript files for production release.
This script:
1. Adds a DEBUG_ENABLED = false constant if not already present
2. Wraps all unguarded print statements with if DEBUG_ENABLED: checks
"""

import os
import re
import sys

def should_process_file(filepath):
    """Check if file should be processed"""
    return filepath.endswith('.gd')

def has_debug_flag(content):
    """Check if file already has a debug flag"""
    patterns = [
        r'^\s*const\s+(DEBUG_ENABLED|DEBUG_DISABLED|DEBUG_DISABLED)\s*=',
        r'^\s*var\s+(DEBUG_ENABLED|DEBUG_DISABLED|DEBUG_DISABLED)\s*=',
    ]
    for pattern in patterns:
        if re.search(pattern, content, re.MULTILINE):
            return True
    return False

def get_debug_flag_name(content):
    """Extract the debug flag name used in the file"""
    patterns = [
        (r'const\s+(DEBUG_ENABLED)\s*=', 'DEBUG_ENABLED'),
        (r'const\s+(DEBUG_DISABLED)\s*=', 'DEBUG_DISABLED'),
        (r'const\s+(DEBUG_DISABLED)\s*=', 'DEBUG_DISABLED'),
        (r'var\s+(DEBUG_ENABLED)\s*=', 'DEBUG_ENABLED'),
        (r'var\s+(DEBUG_DISABLED)\s*=', 'DEBUG_DISABLED'),
        (r'var\s+(DEBUG_DISABLED)\s*=', 'DEBUG_DISABLED'),
    ]
    for pattern, flag_name in patterns:
        if re.search(pattern, content, re.MULTILINE):
            return flag_name
    return None

def ensure_debug_flag(content, filepath):
    """Ensure file has a debug flag at the top"""
    flag_name = get_debug_flag_name(content)
    
    if flag_name:
        return content, flag_name
    
    # Add debug flag after the extends/class declaration
    lines = content.split('\n')
    insert_index = 0
    
    # Find the right place to insert (after extends/class line if present)
    for i, line in enumerate(lines):
        if line.strip().startswith('extends ') or line.strip().startswith('class '):
            insert_index = i + 1
            break
        elif line.strip() and not line.strip().startswith('#'):
            insert_index = i
            break
    
    # Insert debug flag
    new_line = '\nconst DEBUG_ENABLED = false  # Set to false for production release\n'
    lines.insert(insert_index, new_line)
    return '\n'.join(lines), 'DEBUG_ENABLED'

def wrap_print_statements(content, debug_flag):
    """Wrap unguarded print statements with debug flag check"""
    lines = content.split('\n')
    result = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if line contains a print statement
        if 'print(' in line and not line.strip().startswith('#'):
            # Check if it's already guarded by a debug condition
            stripped = line.lstrip()
            indent = line[:len(line) - len(stripped)]
            
            # Check if this print is already in a debug check
            already_guarded = False
            if i > 0:
                prev_line = lines[i-1].rstrip()
                # Check for common guard patterns
                if f'if {debug_flag}:' in prev_line or 'if not' in prev_line:
                    already_guarded = True
            
            if not already_guarded and stripped.startswith('print('):
                # This is an unguarded print at the start of a line
                # Add the guard
                result.append(f'{indent}if {debug_flag}:')
                result.append(f'{indent}\t{stripped}')
                i += 1
                continue
            elif not already_guarded and 'print(' in stripped:
                # Print is part of a line - need to be careful
                # For now, just wrap the line
                if not any(x in stripped for x in ['if ', 'for ', 'while ', 'match ']):
                    # It's safe to wrap
                    result.append(f'{indent}if {debug_flag}:')
                    result.append(f'{indent}\t{stripped}')
                    i += 1
                    continue
        
        result.append(line)
        i += 1
    
    return '\n'.join(result)

def process_file(filepath):
    """Process a single GDScript file"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        
        # Ensure debug flag exists
        content, debug_flag = ensure_debug_flag(content, filepath)
        
        # Set the debug flag to false for production
        # Replace DEBUG_ENABLED = true with DEBUG_ENABLED = false
        content = re.sub(
            r'const\s+' + debug_flag + r'\s*=\s*(?:true|false)',
            f'const {debug_flag} = false',
            content
        )
        content = re.sub(
            r'var\s+' + debug_flag + r'\s*=\s*(?:true|false)',
            f'var {debug_flag} = false',
            content
        )
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}", file=sys.stderr)
        return False

def main():
    """Main function to process all GDScript files"""
    base_paths = [
        'script',
        'scene',
        'addons'
    ]
    
    processed = 0
    modified = 0
    
    for base_path in base_paths:
        if not os.path.exists(base_path):
            continue
        
        for root, dirs, files in os.walk(base_path):
            for filename in files:
                if should_process_file(filename):
                    filepath = os.path.join(root, filename)
                    processed += 1
                    if process_file(filepath):
                        modified += 1
                        print(f"✓ {filepath}")
                    else:
                        print(f"  {filepath}")
    
    print(f"\nProcessed {processed} files, modified {modified} files")

if __name__ == '__main__':
    main()
