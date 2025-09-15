#!/usr/bin/env python3
"""
Script to fix imports in generated SWIG Python files for serial build.
Changes mfem._par.* imports to mfem._ser.* imports.
"""

import sys
import re

def fix_imports(filename):
    """Fix imports in a Python file from _par to _ser"""
    try:
        with open(filename, 'r') as f:
            content = f.read()
        
        # Replace imports
        content = re.sub("_par", "_ser", content)
        
        with open(filename, 'w') as f:
            f.write(content)
            
        print(f"Fixed imports in {filename}")
        return True
        
    except Exception as e:
        print(f"Error fixing imports in {filename}: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: fix_ser_imports.py <filename>")
        sys.exit(1)
    
    filename = sys.argv[1]
    success = fix_imports(filename)
    sys.exit(0 if success else 1)