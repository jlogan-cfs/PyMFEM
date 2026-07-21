%module(package="mfem._ser") ode
%{
#include  "mfem.hpp"
#include "linalg/ode.hpp"
#include "../common/pyoperator.hpp"
#include "numpy/arrayobject.h"
#include "../common/io_stream.hpp"
%}

%init %{
import_array();
%}

%include "exception.i"
%import "vector.i"
%import "array.i"
%import "operators.i"
%import "../common/exception.i"
%import "../common/io_stream_typemap.i"
OSTREAM_TYPEMAP(std::ostream&)


%typemap(in) double &t (double temp){
  temp = PyFloat_AsDouble($input);
  $1 = &temp;
 }
%typemap(in) double &dt (double dtemp){
  dtemp = PyFloat_AsDouble($input);
  $1 = &dtemp;
}
%typemap(argout) double &t {
  %append_output(PyFloat_FromDouble(*$1));
}
%typemap(argout) double &dt {
  %append_output(PyFloat_FromDouble(*$1));
 }


// The public method signatures use a protected ODESolver type alias that
// generated wrapper code cannot name.
%ignore mfem::ODESolver::SupportsImplicitVariableType;
%ignore mfem::BackwardEulerSolver::SupportsImplicitVariableType;
%ignore mfem::ImplicitMidpointSolver::SupportsImplicitVariableType;
%ignore mfem::SDIRK23Solver::SupportsImplicitVariableType;
%ignore mfem::SDIRK34Solver::SupportsImplicitVariableType;
%ignore mfem::SDIRK33Solver::SupportsImplicitVariableType;
%ignore mfem::TrapezoidalRuleSolver::SupportsImplicitVariableType;
%ignore mfem::ESDIRK32Solver::SupportsImplicitVariableType;
%ignore mfem::ESDIRK33Solver::SupportsImplicitVariableType;
%ignore mfem::GeneralizedAlphaSolver::SupportsImplicitVariableType;

%include "linalg/ode.hpp"
