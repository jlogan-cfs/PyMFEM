#ifndef PYMFEM_PYBILININTEG
#define PYMFEM_PYBILININTEG

#include <iostream>
#include "fem/bilininteg.hpp"
#include "fem/qspace.hpp"

namespace mfem{
class PyBilinearFormIntegrator : public BilinearFormIntegrator
{
public:
  PyBilinearFormIntegrator(const IntegrationRule *ir = NULL):BilinearFormIntegrator(ir){}
  virtual ~PyBilinearFormIntegrator() { }  
};

/// Mass assembly with the same element rules as a sampled coefficient.
/// The caller must keep the coefficient and quadrature space alive.
class QuadratureMassIntegrator : public MassIntegrator
{
   const QuadratureSpace &space;

protected:
   const IntegrationRule *GetDefaultIntegrationRule(
      const FiniteElement &, const FiniteElement &,
      const ElementTransformation &trans) const override
   { return &space.GetIntRule(trans.ElementNo); }

public:
   QuadratureMassIntegrator(Coefficient &coefficient,
                            const QuadratureSpace &space_)
      : MassIntegrator(coefficient), space(space_) { }
};

/// Diffusion assembly with the same element rules as a sampled coefficient.
/// The caller must keep the coefficient and quadrature space alive.
class QuadratureDiffusionIntegrator : public DiffusionIntegrator
{
   const QuadratureSpace &space;

protected:
   const IntegrationRule *GetDefaultIntegrationRule(
      const FiniteElement &, const FiniteElement &,
      const ElementTransformation &trans) const override
   { return &space.GetIntRule(trans.ElementNo); }

public:
   QuadratureDiffusionIntegrator(Coefficient &coefficient,
                                 const QuadratureSpace &space_)
      : DiffusionIntegrator(coefficient), space(space_) { }
};
} // end of namespace

#endif //PYMFEM_PYBILININTEG
