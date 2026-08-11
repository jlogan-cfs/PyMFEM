"""MPI regression tests for root-owned serial mesh distribution."""

from __future__ import annotations

import shutil
import tempfile
from pathlib import Path

from mpi4py import MPI

import mfem.par as mfem


def _local_signature(mesh: mfem.ParMesh) -> tuple[object, ...]:
    """Return local topology and attribute values for exact comparisons."""

    element_attributes = tuple(mesh.GetElement(index).GetAttribute() for index in range(mesh.GetNE()))
    boundary_attributes = tuple(
        mesh.GetBdrElement(index).GetAttribute() for index in range(mesh.GetNBE())
    )
    return (
        mesh.GetNE(),
        mesh.GetNBE(),
        mesh.GetNV(),
        mesh.GetNEdges(),
        mesh.GetNFaces(),
        mesh.GetNGroups(),
        mesh.GetNSharedFaces(),
        element_attributes,
        boundary_attributes,
    )


def run_test() -> None:
    """Compare distributed loading with MFEM's replicated serial constructor."""

    comm = MPI.COMM_WORLD
    root = comm.size - 1
    output_dir = Path(tempfile.mkdtemp(prefix="pymfem-distribute-")) if comm.rank == root else None
    output_dir = Path(comm.bcast(str(output_dir) if output_dir is not None else None, root=root))
    mesh_path = output_dir / "serial.mesh"

    serial = mfem.Mesh.MakeCartesian3D(
        5,
        4,
        3,
        mfem.Element.TETRAHEDRON,
        1.0,
        0.8,
        0.6,
    )
    for element in range(serial.GetNE()):
        serial.GetElement(element).SetAttribute(1 + element % 3)
    for boundary in range(serial.GetNBE()):
        serial.GetBdrElement(boundary).SetAttribute(1 + boundary % 4)
    serial.SetAttributes()

    reference = mfem.ParMesh(comm, serial, None, 1)
    reference_signature = _local_signature(reference)
    if comm.rank == root:
        serial.Print(str(mesh_path))
    comm.Barrier()

    timings = mfem.Vector()
    distributed = mfem.LoadAndDistributeParMesh(
        comm,
        str(mesh_path),
        timings,
        root,
        1,
        0,
        False,
        False,
        97,
    )
    assert _local_signature(distributed) == reference_signature
    assert timings.Size() == 6
    assert all(timings[index] >= 0.0 for index in range(timings.Size()))

    comm.Barrier()
    missing_error = None
    try:
        mfem.LoadAndDistributeParMesh(
            comm,
            str(output_dir / "missing.mesh"),
            mfem.Vector(),
            root,
        )
    except RuntimeError as error:
        missing_error = str(error)
    errors = comm.allgather(missing_error)
    assert all(error is not None and "cannot open serial mesh" in error for error in errors)

    comm.Barrier()
    if comm.rank == root:
        shutil.rmtree(output_dir)


if __name__ == "__main__":
    run_test()
