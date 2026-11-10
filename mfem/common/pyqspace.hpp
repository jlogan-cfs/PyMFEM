#ifndef PYMFEM_PYQSPACE
#define PYMFEM_PYQSPACE

#include "fem/qspace.hpp"

namespace mfem
{
/// Sample coordinates and physical weights for elements [begin, end).
/// Coordinates have shape (space dimension, quadrature points), in space order.
/// Per-element transformations support mixed geometries without a global cache.
inline void SampleQuadratureGeometry(QuadratureSpace &space, int begin, int end,
                                     DenseMatrix &coordinates, Vector &weights)
{
   MFEM_VERIFY(0 <= begin && begin <= end && end <= space.GetNE(),
               "Invalid quadrature element range");
   const int first = space.Offset(begin);
   const int count = space.Offset(end) - first;
   coordinates.SetSize(space.GetMesh()->SpaceDimension(), count);
   weights.SetSize(count);
   for (int e = begin; e < end; ++e)
   {
      ElementTransformation *trans = space.GetTransformation(e);
      const IntegrationRule &rule = space.GetIntRule(e);
      for (int j = 0; j < rule.GetNPoints(); ++j)
      {
         const int row = space.Offset(e) - first + j;
         Vector point(coordinates.GetColumn(row), coordinates.Height());
         const IntegrationPoint &ip = rule.IntPoint(j);
         trans->Transform(ip, point);
         trans->SetIntPoint(&ip);
         weights(row) = ip.weight * trans->Weight();
      }
   }
}
}
#endif
