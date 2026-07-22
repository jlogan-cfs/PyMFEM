"""Regression coverage for APIs moved to new headers in MFEM 4.9."""

from __future__ import annotations

import sys

if len(sys.argv) > 1 and sys.argv[1] == "-p":
    import mfem.par as mfem
else:
    import mfem.ser as mfem


def run_test() -> None:
    """Verify ordering constants and inherited integration-rule methods."""
    assert mfem.Ordering.byNODES == 0
    assert mfem.Ordering.byVDIM == 1

    integration_rule = mfem.IntRules.Get(mfem.Geometry.SQUARE, 2)
    for integrator in (
        mfem.MassIntegrator(mfem.ConstantCoefficient(1.0)),
        mfem.DiffusionIntegrator(mfem.ConstantCoefficient(1.0)),
    ):
        integrator.SetIntRule(integration_rule)
        assert integrator.GetIntRule() is not None


if __name__ == "__main__":
    run_test()
