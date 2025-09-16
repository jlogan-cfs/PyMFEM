# PyMFEM Migration to scikit-build-core

## Quick Start

### Standard Installation
```bash
pip install .
```

### Development Installation
```bash
pip install -e .
```

### Building Wheels
```bash
python -m build
```

## Configuration Options

Configuration is now done via environment variables or `pyproject.toml` settings:

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PYMFEM_BUILD_PARALLEL` | Build parallel version | `ON` |
| `PYMFEM_BUILD_METIS` | Build METIS library | `ON` |
| `PYMFEM_BUILD_HYPRE` | Build HYPRE library | `ON` |
| `PYMFEM_BUILD_LIBCEED` | Build libCEED library | `ON` |
| `PYMFEM_BUILD_GSLIB` | Build gslib library | `ON` |
| `PYMFEM_ENABLE_CUDA` | Enable CUDA support | `OFF` |
| `PYMFEM_CUDA_ARCH` | CUDA compute capability | `75;80;86` |
| `PYMFEM_CUDA_PREFIX` | CUDA installation path | `/usr/local/cuda` |
| `PYMFEM_ENABLE_SUITESPARSE` | Enable SuiteSparse | `OFF` |
| `PYMFEM_ENABLE_LAPACK` | Enable LAPACK | `ON` |
| `PYMFEM_MFEM_SOURCE` | MFEM source directory | `./external/mfem` |
| `PYMFEM_EXT_PREFIX` | External libraries prefix | `external` |

### Examples

```bash
# Build with parallel support
PYMFEM_BUILD_PARALLEL=ON pip install .

# Build with CUDA support (local builds only - requires CUDA toolkit)
PYMFEM_ENABLE_CUDA=ON pip install . --no-build-isolation

# Build with specific CUDA architecture (e.g., RTX 30-series = 86)
PYMFEM_ENABLE_CUDA=ON PYMFEM_CUDA_ARCH="75;80;86" pip install . --no-build-isolation

# Build with external dependencies
PYMFEM_BUILD_METIS=ON PYMFEM_BUILD_HYPRE=ON pip install .
```

## Migration from Legacy setup.py

### Old Command → New Command

| Old | New |
|-----|-----|
| `python setup.py install` | `pip install .` |
| `python setup.py develop` | `pip install -e .` |
| `python setup.py build` | `python -m build` |
| `python setup.py bdist_wheel` | `python -m build --wheel` |
| `python setup.py clean` | `rm -rf build/` |

### Old Options → New Environment Variables

| Old Option | New Environment Variable |
|------------|--------------------------|
| `--with-parallel` | `PYMFEM_BUILD_PARALLEL=ON` |
| `--with-cuda` | `PYMFEM_ENABLE_CUDA=ON` |
| `--mfem-source=<path>` | `PYMFEM_MFEM_SOURCE=<path>` |
| `--hypre-prefix=<path>` | Set via CMake configuration |
| `--metis-prefix=<path>` | Set via CMake configuration |

## Legacy System

The original `setup.py` has been renamed to `setup_legacy.py` and is still available for:

- Complex build scenarios not yet supported by the new system
- Debugging build issues
- Transition period while the new system is tested

To use the legacy system:
```bash
python setup_legacy.py install [options]
```
