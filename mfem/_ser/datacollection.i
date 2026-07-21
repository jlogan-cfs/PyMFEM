%module(package="mfem._ser") datacollection
%{
#include "mfem.hpp"
#include "numpy/arrayobject.h"
#include "../common/pyoperator.hpp"
#include "../common/pycoefficient.hpp"
#include "../common/pyintrules.hpp"
%}

%init %{
import_array();
%}
%include "exception.i"
%include "../common/typemap_macros.i"
%include "../common/exception.i"

%import "globals.i"
%import "mesh.i"
%import "gridfunc.i"

// These accessors expose private C++ type aliases that SWIG cannot name in
// generated wrapper code. Python callers use the field registration API.
%ignore mfem::ParaViewDataCollection::GetCoeffFieldMap;
%ignore mfem::ParaViewDataCollection::GetVCoeffFieldMap;

%include "fem/datacollection.hpp"
