%ignore MFEM_GIT_STRING;
%ignore MFEM_HYPRE_VERSION;
%ignore MFEM_SOURCE_DIR;
%ignore MFEM_INSTALL_DIR;
%ignore MFEM_TIMER_TYPE;
%include  "config/_config.hpp" // include mfem MACRO
%include  "config/config.hpp" // include mfem MACRO

// Runtime kernel dispatch tables are internal implementation details. SWIG
// cannot parse their variadic registration macro, and no Python API needs the
// generated static dispatch-table members.
#define MFEM_KERNEL_DISPATCH_HPP
#define MFEM_REGISTER_KERNELS(KernelName, KernelType, ...)
