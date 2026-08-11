%module(package="mfem._par") pmesh

%feature("autodoc", "1");

%{
#include <iostream>
#include <sstream>
#include <fstream>
#include <algorithm>
#include <limits>
#include <cmath>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <mpi.h>
#include "mfem.hpp"
#include "numpy/arrayobject.h"
#include "../common/pyoperator.hpp"
#include "../common/io_stream.hpp"
#include "../common/pycoefficient.hpp"
#include "../common/pyintrules.hpp"
%}

%include "../common/mfem_config.i"

%init %{
import_array();
%}

#ifdef MFEM_USE_MPI
%include mpi4py/mpi4py.i
%mpi4py_typemap(Comm, MPI_Comm);
#endif

%include "exception.i"
%include "std_string.i"

 //%include "../common/cpointers.i"
 //%import "cpointers.i"
%import "mesh.i"
%import "pncmesh.i"
%import "hypre.i"
%import "communication.i"
%import "../common/exception.i"

%import "../common/io_stream_typemap.i"
OSTREAM_TYPEMAP(std::ostream&)
ISTREAM_TYPEMAP(std::istream&)

%immutable face_nbr_elements;
%immutable face_nbr_vertices;
%immutable gtopo;

%feature("shadow") mfem::ParMesh::GroupFace %{
def GroupFace(self, group, i, *args):
    if len(args) == 0:
        from mfem.par import intp
        face = intp()
        o = intp()
        $action(self, group, i, face, o)
        return face.value(), o.value()
    else:
        return $action(self, group, i, *args)
%}

%feature("shadow") mfem::ParMesh::GroupEdge %{
def GroupEdge(self, group, i, *args):
    if len(args) == 0:
        from mfem.par import intp
        edge = intp()
        o = intp()
        $action(self, group, i, edge, o)
        return edge.value(), o.value()
    else:
        return $action(self, group, i, *args)
%}

%typemap(out, optimal="1") mfem::Mesh %{
  /* return by value optimization */
  $result = SWIG_NewPointerObj(SWIG_as_voidptr(new $1_ltype($1)), $descriptor(mfem::Mesh *), 1);
%}

%exception; /* undo default director exception */
%include "mesh/pmesh.hpp"

%newobject mfem::LoadAndDistributeParMesh;
%exception mfem::LoadAndDistributeParMesh {
  try {
    $action
  }
  catch (const std::exception &error) {
    SWIG_exception(SWIG_RuntimeError, error.what());
  }
}
%feature("docstring") mfem::LoadAndDistributeParMesh """
Load and distribute a serial MFEM mesh without replicating it on every rank.

Only ``root`` opens ``mesh_file``. It partitions the mesh one part at a time,
sends each part in MFEM parallel-mesh format, and returns the local ``ParMesh``
on every rank. ``timings`` is resized to six entries containing local seconds
for serial read, partitioner setup, extraction/send, receive, ParMesh
construction, and the complete operation.
""";

%inline %{
namespace mfem
{
namespace pymfem_detail
{
constexpr int distributed_mesh_status_tag = 27101;
constexpr int distributed_mesh_size_tag = 27102;
constexpr int distributed_mesh_payload_tag = 27103;

inline void BroadcastString(MPI_Comm comm, int root, std::string &value,
                            unsigned long long max_chunk_bytes)
{
   int rank;
   MPI_Comm_rank(comm, &rank);
   unsigned long long size = rank == root
                             ? static_cast<unsigned long long>(value.size())
                             : 0ULL;
   MPI_Bcast(&size, 1, MPI_UNSIGNED_LONG_LONG, root, comm);
   if (rank != root) { value.resize(static_cast<std::size_t>(size)); }

   // MPI message counts are signed ints, so large diagnostics use the same
   // bounded transfer size as mesh payloads.
   unsigned long long offset = 0;
   while (offset < size)
   {
      const int count = static_cast<int>(
                           std::min(max_chunk_bytes, size - offset));
      MPI_Bcast(value.data() + offset, count, MPI_CHAR, root, comm);
      offset += static_cast<unsigned long long>(count);
   }
}

inline void ValidateDistributedMeshArguments(MPI_Comm comm, int root,
                                             int part_method,
                                             int generate_edges, int refine,
                                             int fix_orientation,
                                             unsigned long long max_chunk_bytes)
{
   int size;
   MPI_Comm_size(comm, &size);
   const int local[] = {root, part_method, generate_edges, refine,
                        fix_orientation};
   int minimum[5];
   int maximum[5];
   // Validate collective arguments collectively. If ranks used different
   // roots or options, entering the later broadcasts could deadlock.
   MPI_Allreduce(local, minimum, 5, MPI_INT, MPI_MIN, comm);
   MPI_Allreduce(local, maximum, 5, MPI_INT, MPI_MAX, comm);
   for (int i = 0; i < 5; ++i)
   {
      if (minimum[i] != maximum[i])
      {
         throw std::runtime_error(
                  "LoadAndDistributeParMesh arguments differ between ranks");
      }
   }

   unsigned long long minimum_chunk;
   unsigned long long maximum_chunk;
   MPI_Allreduce(&max_chunk_bytes, &minimum_chunk, 1,
                 MPI_UNSIGNED_LONG_LONG, MPI_MIN, comm);
   MPI_Allreduce(&max_chunk_bytes, &maximum_chunk, 1,
                 MPI_UNSIGNED_LONG_LONG, MPI_MAX, comm);
   if (minimum_chunk != maximum_chunk)
   {
      throw std::runtime_error(
               "LoadAndDistributeParMesh max_chunk_bytes differs between ranks");
   }
   if (root < 0 || root >= size)
   {
      throw std::runtime_error(
               "LoadAndDistributeParMesh root is outside the communicator");
   }
   if (part_method < 0)
   {
      throw std::runtime_error(
               "LoadAndDistributeParMesh part_method must be nonnegative");
   }
   if (generate_edges < 0 || (refine != 0 && refine != 1) ||
       (fix_orientation != 0 && fix_orientation != 1))
   {
      throw std::runtime_error(
               "LoadAndDistributeParMesh received invalid mesh loading flags");
   }
   if (max_chunk_bytes == 0ULL ||
       max_chunk_bytes > static_cast<unsigned long long>(
                            std::numeric_limits<int>::max()))
   {
      throw std::runtime_error(
               "LoadAndDistributeParMesh max_chunk_bytes must be in [1, INT_MAX]");
   }
}
} // namespace pymfem_detail

ParMesh *LoadAndDistributeParMesh(
   MPI_Comm comm, const char *mesh_file, Vector &timings, int root = 0,
   int part_method = 1, int generate_edges = 0, bool refine = false,
   bool fix_orientation = false,
   unsigned long long max_chunk_bytes = 64ULL * 1024ULL * 1024ULL)
{
   using namespace pymfem_detail;
   const double total_start = MPI_Wtime();
   timings.SetSize(6);
   timings = 0.0;

   int rank;
   int size;
   MPI_Comm_rank(comm, &rank);
   MPI_Comm_size(comm, &size);
   ValidateDistributedMeshArguments(
      comm, root, part_method, generate_edges, refine ? 1 : 0,
      fix_orientation ? 1 : 0, max_chunk_bytes);

   std::unique_ptr<Mesh> serial_mesh;
   std::unique_ptr<MeshPartitioner> partitioner;
   std::string root_error;
   int initialized = 1;
   if (rank == root)
   {
      try
      {
         // The central memory-saving property of this helper is that this
         // complete serial mesh exists on root only.
         const double read_start = MPI_Wtime();
         std::ifstream input(mesh_file);
         if (!input)
         {
            throw std::runtime_error(std::string("cannot open serial mesh: ") +
                                     mesh_file);
         }
         serial_mesh.reset(new Mesh(input, generate_edges, refine,
                                    fix_orientation));
         timings(0) = MPI_Wtime() - read_start;
         if (serial_mesh->Nonconforming())
         {
            throw std::runtime_error(
                     "MeshPartitioner does not support nonconforming meshes");
         }

         const double setup_start = MPI_Wtime();
         partitioner.reset(
            new MeshPartitioner(*serial_mesh, size, nullptr, part_method));
         timings(1) = MPI_Wtime() - setup_start;
      }
      catch (const std::exception &error)
      {
         initialized = 0;
         root_error = error.what();
      }
   }

   // No worker enters a receive unless every rank knows root initialized the
   // partitioner successfully.
   MPI_Bcast(&initialized, 1, MPI_INT, root, comm);
   BroadcastString(comm, root, root_error, max_chunk_bytes);
   if (!initialized)
   {
      throw std::runtime_error(
               std::string("LoadAndDistributeParMesh initialization failed: ") +
               root_error);
   }

   std::string local_payload;
   int distribution_succeeded = 1;
   std::string distribution_error;
   if (rank == root)
   {
      const double distribution_start = MPI_Wtime();
      bool can_extract = true;
      MeshPart mesh_part;
      // Reuse one MeshPart and serialize one destination at a time. Root's
      // transient storage is therefore bounded by the largest partition, not
      // the sum of every partition.
      for (int destination = 0; destination < size; ++destination)
      {
         std::string payload;
         int part_succeeded = can_extract ? 1 : 0;
         if (can_extract)
         {
            try
            {
               partitioner->ExtractPart(destination, mesh_part);
               std::ostringstream output;
               output.precision(16);
               mesh_part.Print(output);
               payload = output.str();
               if (payload.empty())
               {
                  throw std::runtime_error(
                           "MeshPart serialization produced an empty payload");
               }
            }
            catch (const std::exception &error)
            {
               part_succeeded = 0;
               can_extract = false;
               distribution_error =
                  std::string("failed to extract part ") +
                  std::to_string(destination) + ": " + error.what();
            }
         }

         if (destination == root)
         {
            if (part_succeeded) { local_payload = std::move(payload); }
         }
         else
         {
            // Status is always sent first. After an extraction failure, every
            // remaining worker still receives a failure status and can reach
            // the collective error path instead of waiting indefinitely.
            MPI_Send(&part_succeeded, 1, MPI_INT, destination,
                     distributed_mesh_status_tag, comm);
            if (part_succeeded)
            {
               const unsigned long long payload_size =
                  static_cast<unsigned long long>(payload.size());
               MPI_Send(&payload_size, 1, MPI_UNSIGNED_LONG_LONG, destination,
                        distributed_mesh_size_tag, comm);
               unsigned long long offset = 0;
               while (offset < payload_size)
               {
                  const int count = static_cast<int>(
                                       std::min(max_chunk_bytes,
                                                payload_size - offset));
                  MPI_Send(payload.data() + offset, count, MPI_CHAR,
                           destination, distributed_mesh_payload_tag, comm);
                  offset += static_cast<unsigned long long>(count);
               }
            }
         }
      }
      distribution_succeeded = can_extract ? 1 : 0;
      timings(2) = MPI_Wtime() - distribution_start;

      // MeshPartitioner retains references into the serial mesh. Destroy it
      // first, then release the global mesh before allocating the local one.
      partitioner.reset();
      serial_mesh.reset();
   }
   else
   {
      const double receive_start = MPI_Wtime();
      int part_succeeded = 0;
      MPI_Recv(&part_succeeded, 1, MPI_INT, root,
               distributed_mesh_status_tag, comm, MPI_STATUS_IGNORE);
      if (part_succeeded)
      {
         unsigned long long payload_size = 0;
         MPI_Recv(&payload_size, 1, MPI_UNSIGNED_LONG_LONG, root,
                  distributed_mesh_size_tag, comm, MPI_STATUS_IGNORE);
         if (payload_size == 0ULL ||
             payload_size > static_cast<unsigned long long>(
                               std::numeric_limits<std::size_t>::max()))
         {
            throw std::runtime_error(
                     "LoadAndDistributeParMesh received an invalid payload size");
         }
         local_payload.resize(static_cast<std::size_t>(payload_size));
         unsigned long long offset = 0;
         while (offset < payload_size)
         {
            const int count = static_cast<int>(
                                 std::min(max_chunk_bytes,
                                          payload_size - offset));
            MPI_Recv(local_payload.data() + offset, count, MPI_CHAR, root,
                     distributed_mesh_payload_tag, comm, MPI_STATUS_IGNORE);
            offset += static_cast<unsigned long long>(count);
         }
      }
      timings(3) = MPI_Wtime() - receive_start;
   }

   // This broadcast is also a phase boundary: all point-to-point transfers
   // finish before any rank enters ParMesh's collective constructor.
   MPI_Bcast(&distribution_succeeded, 1, MPI_INT, root, comm);
   BroadcastString(comm, root, distribution_error, max_chunk_bytes);
   if (!distribution_succeeded)
   {
      throw std::runtime_error(
               std::string("LoadAndDistributeParMesh distribution failed: ") +
               distribution_error);
   }

   std::unique_ptr<ParMesh> parallel_mesh;
   std::string construction_error;
   int construction_succeeded = 1;
   const double construction_start = MPI_Wtime();
   try
   {
      // MeshPart::Print emits MFEM's parallel mesh format, which preserves the
      // shared-entity groups needed by the stream-based ParMesh constructor.
      std::istringstream input(local_payload);
      parallel_mesh.reset(new ParMesh(comm, input, refine, generate_edges,
                                      fix_orientation));
      if (!input && !input.eof())
      {
         throw std::runtime_error("parallel mesh input stream failed");
      }
   }
   catch (const std::exception &error)
   {
      construction_succeeded = 0;
      construction_error = error.what();
   }
   timings(4) = MPI_Wtime() - construction_start;
   local_payload.clear();
   local_payload.shrink_to_fit();

   // Delay the Python exception until every rank has left the constructor and
   // agreed whether construction succeeded.
   int all_constructed = 0;
   MPI_Allreduce(&construction_succeeded, &all_constructed, 1, MPI_INT,
                 MPI_MIN, comm);
   if (!all_constructed)
   {
      int failing_rank = construction_succeeded ? size : rank;
      int first_failing_rank = size;
      MPI_Allreduce(&failing_rank, &first_failing_rank, 1, MPI_INT,
                    MPI_MIN, comm);
      BroadcastString(comm, first_failing_rank, construction_error,
                      max_chunk_bytes);
      throw std::runtime_error(
               std::string("LoadAndDistributeParMesh construction failed on rank ") +
               std::to_string(first_failing_rank) + ": " + construction_error);
   }

   timings(5) = MPI_Wtime() - total_start;
   return parallel_mesh.release();
}
} // namespace mfem
%}

namespace mfem{
%extend ParMesh{
     //
     //ParMesh(MPI_Comm comm, const char *mesh_file){
     //mfem::ParMesh *mesh;
     //std::ifstream imesh(mesh_file);
     //if (!imesh)
     //{
     //std::cerr << "\nCan not open mesh file: " << mesh_file << '\n' << std::endl;
     //return NULL;
     //}
     //mesh = new mfem::ParMesh(comm, imesh);
     //return mesh;
     //}
void ParPrintToFile(const char *mesh_file, const int precision) const
    {
    std::ofstream mesh_ofs(mesh_file);
    mesh_ofs.precision(precision);
    self->ParPrint(mesh_ofs);
    }
};
}

/*
  virtual void Print(std::ostream &out = mfem::out) const;
  virtual void PrintXG(std::ostream &out = mfem::out) const;
  void PrintAsOne(std::ostream &out = mfem::out);
  void PrintAsOneXG(std::ostream &out = mfem::out);
  virtual void PrintInfo(std::ostream &out = mfem::out);
  void ParPrint(std::ostream &out) const;
*/

#ifndef SWIGIMPORTED
OSTREAM_ADD_DEFAULT_FILE(ParMesh, Print)
OSTREAM_ADD_DEFAULT_FILE(ParMesh, PrintXG)
OSTREAM_ADD_DEFAULT_FILE(ParMesh, PrintAsOne)
OSTREAM_ADD_DEFAULT_FILE(ParMesh, PrintAsOneXG)
OSTREAM_ADD_DEFAULT_FILE(ParMesh, PrintInfo)
OSTREAM_ADD_DEFAULT_STDOUT_FILE(ParMesh, ParPrint)
#endif
