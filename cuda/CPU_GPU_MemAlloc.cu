#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <cuda_runtime.h>

__global__ void VecAdd(float* A, float* B, float* C, int N)
{
  for (int i=0; i<N; i++) {
    C[i] = A[i] + B[i];
  }
}

void HostVecAdd(float* A, float* B, float* C, int N)
{
  for (int i=0; i<N; i++) {
    C[i] = A[i] + B[i];
  }
}

void TestHostMemory(int LoopNum)
{
  printf(" - Loop %d:\n", LoopNum+1);
  int N = 1024;
  size_t size = N * sizeof(float);
  float* h_A = (float*)malloc(size);
  float* h_B = (float*)malloc(size);
  float* h_D = (float*)malloc(size);
  // Initialize input vectors
  for (int i = 0; i < N; i++) {
    h_A[i] = (float)((i+1)*rand()%1000)/100;
    h_B[i] = (float)((i+2)*rand()%1000)/100;
  }
  //printf("  => Array A first three data: %f, %f, %f\n", h_A[0], h_A[1], h_A[2]);
  //printf("  => Array B first three data: %f, %f, %f\n", h_B[0], h_B[1], h_B[2]);
  HostVecAdd(h_A, h_B, h_D, N);
  //printf("  => Return D first three data: %f, %f, %f\n", h_D[0], h_D[1], h_D[2]);
}

void TestGPUMemory(int LoopNum)
{
  printf(" - Loop %d:\n", LoopNum+1);
  int N = 1024;
  size_t size = N * sizeof(float);
  float* h_A = (float*)malloc(size);
  float* h_B = (float*)malloc(size);
  float* h_D = (float*)malloc(size);
  // Initialize input vectors
  for (int i = 0; i < N; i++) {
    h_A[i] = (float)((i+1)*rand()%1000)/100;
    h_B[i] = (float)((i+2)*rand()%1000)/100;
  }
  //printf("  => Array A first three data: %f, %f, %f\n", h_A[0], h_A[1], h_A[2]);
  //printf("  => Array B first three data: %f, %f, %f\n", h_B[0], h_B[1], h_B[2]);
  float* d_A, *d_B, *d_D;
  cudaMalloc(&d_A, size);
  cudaMalloc(&d_B, size);
  cudaMalloc(&d_D, size);
  cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
  cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);
  // Invoke kernel
  int threadsPerBlock = 256;
  int blocksPerGrid = (N + threadsPerBlock - 1)/ threadsPerBlock;
  VecAdd<<<blocksPerGrid, threadsPerBlock>>>(d_A, d_B, d_D, N);
  cudaDeviceSynchronize();
  cudaMemcpy(h_D, d_D, size, cudaMemcpyDeviceToHost);
  cudaFree(d_A);
  cudaFree(d_B);
  cudaFree(d_D);
  //printf("  => Return D first three data: %f, %f, %f\n", h_D[0], h_D[1], h_D[2]);
  free(h_A);
  free(h_B);
  free(h_D);
}

void TestUnifedMemory(int LoopNum)
{
  printf(" - Loop %d:\n", LoopNum+1);
  int N = 1024;
  size_t size = N * sizeof(float);
  float* h_A, *h_B, *h_D;
  cudaMallocManaged((float**)&h_A, size);
  cudaMallocManaged((float**)&h_B, size);
  cudaMallocManaged((float**)&h_D, size);
  // Initialize input vectors
  for (int i = 0; i < N; i++) {
    h_A[i] = (float)((i+1)*rand()%1000)/100;
    h_B[i] = (float)((i+2)*rand()%1000)/100;
  }
  //printf("  => Array A first three data: %f, %f, %f\n", h_A[0], h_A[1], h_A[2]);
  //printf("  => Array B first three data: %f, %f, %f\n", h_B[0], h_B[1], h_B[2]);
  // Invoke kernel
  int threadsPerBlock = 256;
  int blocksPerGrid = (N + threadsPerBlock - 1)/ threadsPerBlock;
  VecAdd<<<blocksPerGrid, threadsPerBlock>>>(h_A, h_B, h_D, N);
  cudaDeviceSynchronize();
  //printf("  => Return D first three data: %f, %f, %f\n", h_D[0], h_D[1], h_D[2]);
  // Free memory
  cudaFree(h_A);
  cudaFree(h_B);
  cudaFree(h_D);
}

void usage()
{
	printf("Usage: [ options ]\n");
	printf("\t-n <loops>\tRun this number of memcpy loops (default 1)\n");
  printf("\t-m <1|2|3>\tSepecify memory allocation. 1:CPU, 2:GPU, 3: Unified (default 1)\n");
	exit(1);
}

int main(int argc, char *argv[]){
  int LoopCount = 1;
  int MemAllocMode = 1;
  int t;
  struct timeval start, end;
  while (1) {
    int c = getopt(argc, argv, "hn:m:");
    if (c < 0)
      break;
    switch (c) {
    case 'n':
      LoopCount = atoi(optarg);
      break;
    case 'm':
      MemAllocMode = atoi(optarg);
      break;
    case 'h':
      usage();
      break;
    }
  }

  switch (MemAllocMode) {
    case 1:
      printf(">>> Testing Host Memory for %d loop(s)\n", LoopCount);
      gettimeofday(&start, NULL);
      for (int i = 0; i < LoopCount; i++) {
        TestHostMemory(i);
      }
      gettimeofday(&end, NULL);
      break;
    case 2:
      printf(">>> Testing GPU Memory for %d loop(s)\n", LoopCount);
      gettimeofday(&start, NULL);
      for (int i = 0; i < LoopCount; i++) {
        TestGPUMemory(i);
      }
      gettimeofday(&end, NULL);
      break;
    case 3:
      printf(">>> Testing Unified Memory for %d loop(s)\n", LoopCount);
      gettimeofday(&start, NULL);
      for (int i = 0; i < LoopCount; i++) {
        TestUnifedMemory(i);
      }
      gettimeofday(&end, NULL);
      break;
  }
  t = ((end.tv_sec - start.tv_sec)*1000000 + end.tv_usec - start.tv_usec)/LoopCount;
  printf(">>> Average Kernel Runtime is %d uS for %d loops\n", t, LoopCount);
}
