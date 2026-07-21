"""Smoke test for serial and collective VTKHDF output through ``mfem.par``."""

from __future__ import annotations

import os
import shutil
import tempfile

from mpi4py import MPI

import mfem.par as mfem


def run_test() -> None:
    """Write two timesteps and verify that MFEM created an HDF5 file."""
    comm = MPI.COMM_WORLD
    output_dir = tempfile.mkdtemp(prefix="pymfem-vtkhdf-") if comm.rank == 0 else None
    output_dir = comm.bcast(output_dir, root=0)

    mesh = mfem.Mesh.MakeCartesian2D(
        4,
        2,
        mfem.Element.QUADRILATERAL,
        True,
        1.0,
        0.5,
    )
    pmesh = mfem.ParMesh(comm, mesh)
    fec = mfem.H1_FECollection(1, pmesh.Dimension())
    fespace = mfem.ParFiniteElementSpace(pmesh, fec)
    temperature = mfem.ParGridFunction(fespace)

    collection_name = "paraview_hdf_smoke"
    collection = mfem.ParaViewHDFDataCollection(collection_name, pmesh)
    collection.SetPrefixPath(output_dir + os.sep)
    collection.SetDataFormat(mfem.VTKFormat_BINARY32)
    collection.SetCompression(False)
    collection.RegisterField("temperature", temperature)

    for cycle, time_s in enumerate((0.0, 0.25)):
        temperature.Assign(8.0 + time_s + comm.rank)
        collection.SetCycle(cycle)
        collection.SetTime(time_s)
        collection.Save()

    del collection
    comm.Barrier()

    if comm.rank == 0:
        output_path = os.path.join(output_dir, collection_name + ".vtkhdf")
        assert os.path.getsize(output_path) > 8
        with open(output_path, "rb") as output_file:
            assert output_file.read(8) == b"\x89HDF\r\n\x1a\n"

    comm.Barrier()
    if comm.rank == 0:
        shutil.rmtree(output_dir)


if __name__ == "__main__":
    run_test()
