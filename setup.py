"""
Minimal setup.py to give a meaningful error when attempting to use legacy install
"""

import sys

def main():
    """
    Main setup function that delegates to scikit-build-core or provides helpful messages.
    """
    print("PyMFEM now uses scikit-build-core for building.")
    print("Please use one of the following commands:\n")
    print("  # Standard build and install")
    print("  pip install .\n")
    print("  # Development/editable install")
    print("  pip install -e .\n")
    print("For legacy build system, use:")
    print("  python setup_legacy.py [options]\n")
    
    # Check if user is trying to use old setup.py commands
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command in ['install', 'build', 'develop', 'build_ext', 'bdist_wheel']:
            print(f"ERROR: 'python setup.py {command}' is no longer supported.")
            print("Please use pip or build commands shown above.")
            sys.exit(1)
        elif command in ['clean']:
            print("For cleaning, please remove the build/ directory manually:")
            print("  rm -rf build/")
            sys.exit(0)
        elif command in ['--help', '-h']:
            pass  # Let the help message show
        else:
            print(f"Unknown command: {command}")
            print("Use 'python setup_legacy.py {command}' for legacy functionality.")
            sys.exit(1)

if __name__ == "__main__":
    main()