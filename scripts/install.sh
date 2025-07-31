#!/bin/bash
# Pogocache Installation Script
# Installs pogocache binary and headers system-wide

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PREFIX="/usr/local"
INSTALL_BIN=1
INSTALL_HEADERS=1
INSTALL_EXAMPLES=0
FORCE=0

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Installation options:
  --prefix PREFIX      Installation prefix (default: /usr/local)
  --bin-only          Install binary only (no headers)
  --headers-only      Install headers only (no binary)
  --examples          Install example programs
  --force             Force overwrite existing files
  
Other options:
  -h, --help          Show this help message

Installation paths:
  Binary:    \$PREFIX/bin/pogocache
  Headers:   \$PREFIX/include/pogocache/
  Examples:  \$PREFIX/share/pogocache/examples/

Examples:
  $0                           # Standard installation
  $0 --prefix /opt/pogocache   # Custom prefix
  $0 --headers-only            # Headers only
  sudo $0                      # System-wide installation
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --bin-only)
            INSTALL_HEADERS=0
            shift
            ;;
        --headers-only)
            INSTALL_BIN=0
            shift
            ;;
        --examples)
            INSTALL_EXAMPLES=1
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

echo "=== Pogocache Installation ==="
echo "Installation prefix: $PREFIX"
echo "Install binary: $INSTALL_BIN"
echo "Install headers: $INSTALL_HEADERS"
echo "Install examples: $INSTALL_EXAMPLES"

cd "$PROJECT_ROOT"

# Check if we need root permissions
if [[ "$PREFIX" == "/usr"* ]] && [[ $EUID -ne 0 ]]; then
    echo "Warning: Installing to system prefix may require root permissions"
    echo "Consider running with 'sudo' if installation fails"
fi

# Create installation directories
echo "Creating installation directories..."
if [[ $INSTALL_BIN -eq 1 ]]; then
    mkdir -p "$PREFIX/bin"
fi

if [[ $INSTALL_HEADERS -eq 1 ]]; then
    mkdir -p "$PREFIX/include"
fi

if [[ $INSTALL_EXAMPLES -eq 1 ]]; then
    mkdir -p "$PREFIX/share/pogocache"
fi

# Install binary
if [[ $INSTALL_BIN -eq 1 ]]; then
    if [[ ! -f "pogocache" ]]; then
        echo "Error: pogocache binary not found. Run build script first." >&2
        exit 1
    fi
    
    DEST_BIN="$PREFIX/bin/pogocache"
    if [[ -f "$DEST_BIN" ]] && [[ $FORCE -eq 0 ]]; then
        echo "Warning: $DEST_BIN already exists. Use --force to overwrite."
        echo "Skipping binary installation."
    else
        echo "Installing binary: $DEST_BIN"
        cp "pogocache" "$DEST_BIN"
        chmod 755 "$DEST_BIN"
        echo "✓ Binary installed"
    fi
fi

# Install headers
if [[ $INSTALL_HEADERS -eq 1 ]]; then
    if [[ ! -d "include/pogocache" ]]; then
        echo "Error: include/pogocache directory not found." >&2
        exit 1
    fi
    
    DEST_INCLUDE="$PREFIX/include/pogocache"
    if [[ -d "$DEST_INCLUDE" ]] && [[ $FORCE -eq 0 ]]; then
        echo "Warning: $DEST_INCLUDE already exists. Use --force to overwrite."
        echo "Skipping header installation."
    else
        echo "Installing headers: $DEST_INCLUDE"
        rm -rf "$DEST_INCLUDE" 2>/dev/null || true
        cp -r "include/pogocache" "$PREFIX/include/"
        find "$PREFIX/include/pogocache" -type f -exec chmod 644 {} \;
        echo "✓ Headers installed"
    fi
fi

# Install examples
if [[ $INSTALL_EXAMPLES -eq 1 ]]; then
    if [[ ! -d "examples" ]]; then
        echo "Warning: examples directory not found. Skipping examples installation."
    else
        DEST_EXAMPLES="$PREFIX/share/pogocache/examples"
        echo "Installing examples: $DEST_EXAMPLES"
        rm -rf "$DEST_EXAMPLES" 2>/dev/null || true
        cp -r "examples" "$PREFIX/share/pogocache/"
        find "$PREFIX/share/pogocache/examples" -type f -exec chmod 644 {} \;
        # Make example binaries executable if they exist
        find "$PREFIX/share/pogocache/examples" -name "*.out" -exec chmod 755 {} \; 2>/dev/null || true
        echo "✓ Examples installed"
    fi
fi

# Create pkg-config file if headers were installed
if [[ $INSTALL_HEADERS -eq 1 ]]; then
    PKGCONFIG_DIR="$PREFIX/lib/pkgconfig"
    mkdir -p "$PKGCONFIG_DIR"
    
    cat > "$PKGCONFIG_DIR/pogocache.pc" << EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: pogocache
Description: High-performance caching system
Version: 1.0.0
Cflags: -I\${includedir}
Libs: -L\${libdir} -lpogocache
EOF
    
    echo "✓ pkg-config file created"
fi

echo ""
echo "=== Installation Summary ==="
if [[ $INSTALL_BIN -eq 1 ]]; then
    echo "✓ Binary installed: $PREFIX/bin/pogocache"
fi
if [[ $INSTALL_HEADERS -eq 1 ]]; then
    echo "✓ Headers installed: $PREFIX/include/pogocache/"
    echo "✓ pkg-config file: $PREFIX/lib/pkgconfig/pogocache.pc"
fi
if [[ $INSTALL_EXAMPLES -eq 1 ]]; then
    echo "✓ Examples installed: $PREFIX/share/pogocache/examples/"
fi

echo ""
echo "Usage:"
echo "  \$ pogocache --help"
if [[ $INSTALL_HEADERS -eq 1 ]]; then
    echo "  \$ gcc -o myapp myapp.c \$(pkg-config --cflags --libs pogocache)"
fi

# Add to PATH suggestion if not in standard location
if [[ "$PREFIX/bin" != "/usr/bin" ]] && [[ "$PREFIX/bin" != "/usr/local/bin" ]]; then
    echo ""
    echo "Note: Add $PREFIX/bin to your PATH to use pogocache from anywhere:"
    echo "  export PATH=\"$PREFIX/bin:\$PATH\""
fi

echo ""
echo "Installation complete!"