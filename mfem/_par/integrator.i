%module(package="mfem._par") integrator

%{
#include "mfem.hpp"
#include "../common/pyintrules.hpp"
%}

%include "exception.i"
%import "intrules.i"

%include "fem/integrator.hpp"
