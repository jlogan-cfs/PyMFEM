%module(package="mfem._par") fe_base
%{
#include  "mfem.hpp"
#include "numpy/arrayobject.h"
#include "../common/pyoperator.hpp"
#include "../common/pyintrules.hpp"
%}

%init %{
import_array();
%}
%include "exception.i"
%import "intrules.i"
%import "geom.i"
%import "doftrans.i"
%include "../common/typemap_macros.i"
%include "../common/exception.i"

 //%ignore FE;
namespace mfem{
  class FiniteElement;
}

// MFEM's process-wide polynomial cache owns unique_ptr-backed lookup tables
// and cannot be replaced by assignment from Python.
%immutable mfem::poly1d;

%include "fem/fe/fe_base.hpp"
