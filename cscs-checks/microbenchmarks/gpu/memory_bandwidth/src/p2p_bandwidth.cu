
/*
 Benchmark test case to measure the copy bandwidth across different devices within the same node.
 The output of this test is a matrix showing each bandwidth measure across each of the devices.
 For comparative purposes across devices, this matrix has an extra column with the sum of the
 bandwidths from the same sending device (excluding itself).

 Test flags:
   - P2P: if defined, this flag enables the sending device to have direct access to
     the memory from the target device.
   - SYMM: if defined, it computes only half of the matrix, assuming that the bandwidth is the
     same both ways.
*/

#include "testHeaders.hpp"

#ifdef P2P
# define PEER_ACCESS 1
#else
# define PEER_ACCESS 0 
#endif

// Forward declaration of the bandwidth map function.
void p2pBandwidthMap(int, int, size_t, int, char*);


int main()
{
  char* nid_name = (char*)calloc(80, sizeof(char));
  gethostname(nid_name, 80);

  int number_of_devices;
  XGetDeviceCount(number_of_devices);

  // Make sure we've got devices aboard.g
  if (number_of_devices == 0) 
  {
    std::cout << "No devices found on host " << nid_name << std::endl;
    return 1;
  }
  else
  {
    printf("[%s] Found %d device(s).\n\n", nid_name, number_of_devices); 
  }

  //Test parameters
  size_t copy_size = COPY_SIZE;
  int copy_repeats = NUMBER_OF_COPIES;

  // Do the device to device copy bandwidth.
  p2pBandwidthMap(number_of_devices, PEER_ACCESS, copy_size, copy_repeats, nid_name); 

  // Do some basic error checking
  if (!XGetLastError())
  {
    printf("[%s] Test Result = PASS\n", nid_name);
  } 
  else
  {
    printf("[%s] Test Result = FAIL\n", nid_name);
  }

  return 0;
}


void p2pBandwidthMap(int devices, int p2p, size_t copy_size, int repeats, char * nid_name)
{
  /*
   This function evaluates the GPU to GPU copy bandwith in all GPU to GPU combinations.
   If symmetry is assumed, compile with -DSYMM to compute only the upper matrix triangle.
   The data is printed as a matrix (see description above). 
  
   ** The "Totals" column excludes the diagonal terms from the sum **

   Mote that this function sets the CPU affinity for the sending GPU.

   Arguments:
     - devices: number of devices
     - p2p: bool flag to enable or not direct memory access across GPUs
     - copy_size: in bytes, the copy size.
     - repeats: number of copies to be carried out.
     - nid_name: node name - just for reporting purposes.
  */

#ifdef SYMM
# define LIMITS ds
#else
# define LIMITS 0
#endif

  float fact = (float)copy_size/(float)1e6;

  // Create a device set to tune the device's cpu affinity.
  DeviceSet dSet;

  /*
   Test the Peer to Peer bandwidth.
  */
  const char * p2pOut = (p2p ? "enabled" : "disabled");
  printf("[%s] P2P Memory bandwidth (GB/s) with peer access %s\n", nid_name, p2pOut);
  printf("[%s] %10s", nid_name, "From \\ To ");
  for (int ds = 0; ds < devices; ds++)
  {
    printf("%4sGPU %2d", "", ds);
  } printf("%10s\n", "Totals");

  for (int ds = 0; ds < devices; ds++)
  {
    // Track the sum of the bandwidths
    float totals = 0; 
 
    // Set the CPU affinity to the sending device.
    dSet.setCpuAffinity(ds);

    printf("[%s] GPU %2d%4s", nid_name, ds, " ");
    for (int dr = 0; dr < LIMITS; dr++)
    {
      printf("%10s", "X");
    }

    for (int dr = LIMITS; dr < devices; dr++)
    {
      float same = ( (ds==dr) ? float(2) : float(1) );
      float bw = fact / p2pBandwidth(copy_size, ds, dr, repeats, p2p) * same;
      if (ds != dr)
      {
        totals += bw;
      }
      printf("%10.2f", bw);
    } printf("%10.2f\n", totals);

  }

}
