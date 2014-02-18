#include <iostream>
#include <ctime>
#include <stdio.h>
#include <stdlib.h>
#include <cuda.h>
#include <cuda_runtime.h>                // Stops underlining of __global__
#include <device_launch_parameters.h>    // Stops underlining of threadIdx etc.
#include <sys/types.h>
#include <sys/stat.h>
#include <thrust/device_vector.h>

#include "kernel.h"
#include "book.h"
#include "SearchStructure.h"

using namespace std;

/*#include <thrust/sort.h>*/
/*#include <thrust/device_ptr.h>*/
/*#include <thrust/inner_product.h>*/
/*#include <thrust/iterator/constant_iterator.h>*/
/*#include <thrust/scan.h>*/

/*void test_histogram(char *point_path, int N){*/

    /*// file input*/
    /*FILE *points_fin;*/
    /*size_t result1;*/

    /*points_fin = fopen(point_path, "rb");*/
    /*if(points_fin==NULL){fputs ("File error: point_fin",stderr); exit (1);}*/

    /*unsigned int *points = new unsigned int[N];*/
    /*unsigned int *d_points;*/
    /*HANDLE_ERROR(cudaMalloc(&d_points, N*sizeof(unsigned int)));*/
    /*if (points == NULL) {fputs ("Memory error: points",stderr); exit (2);}*/

    /*result1 = fread(points,sizeof(unsigned int),N,points_fin);*/

    /*thrust::device_ptr<unsigned int> hashKeys_old_ptr(d_points);*/
    /*HANDLE_ERROR(cudaMemcpy(d_points, points, N*sizeof(unsigned int), cudaMemcpyHostToDevice));*/

    /*thrust::sort(hashKeys_old_ptr, hashKeys_old_ptr+N);*/

    /*// create histogram of hash keys*/
    /*// https://code.google.com/p/thrust/source/browse/examples/histogram.cu*/
    /*unsigned int num_bins = thrust::inner_product(hashKeys_old_ptr, hashKeys_old_ptr + N - 1,*/
                                                  /*hashKeys_old_ptr + 1,*/
                                                  /*(unsigned int) 1,*/
                                                  /*thrust::plus<unsigned int>(),*/
                                                  /*thrust::not_equal_to<unsigned int>());*/

    /*[> DEBUG <]*/
    /*fprintf(stderr, "num_bins: %d\n", num_bins);*/
    /*[> DEBUG <]*/

    /*unsigned int *hashKeys, *ppfCount;*/
    /*HANDLE_ERROR(cudaMalloc(&hashKeys, num_bins*sizeof(unsigned int)));*/
    /*HANDLE_ERROR(cudaMalloc(&ppfCount, num_bins*sizeof(unsigned int)));*/
    /*thrust::device_ptr<unsigned int> hashKeys_ptr(hashKeys);*/
    /*thrust::device_ptr<unsigned int> ppfCount_ptr(ppfCount);*/

    /*thrust::reduce_by_key(hashKeys_old_ptr, hashKeys_old_ptr + N,*/
                          /*thrust::constant_iterator<unsigned int>(1),*/
                          /*hashKeys_ptr,*/
                          /*ppfCount_ptr);*/

    /*unsigned int A[num_bins], B[num_bins];*/
    /*[>HANDLE_ERROR(cudaMemcpy(A, hashKeys, num_bins*sizeof(unsigned int), cudaMemcpyDeviceToHost));<]*/
    /*HANDLE_ERROR(cudaMemcpy(B, ppfCount, num_bins*sizeof(unsigned int), cudaMemcpyDeviceToHost));*/

    /*for (int i=0; i<num_bins; i++){*/
        /*fprintf(stderr, "%u: %u %u\n", i, B[i], A[i]);*/
    /*}*/
/*}*/

int ply_load_main(char *point_path, char *norm_path, int N){
    // file input
    FILE *points_fin, *norms_fin;
    size_t result1, result2;

    points_fin = fopen(point_path, "rb");
    norms_fin  = fopen(norm_path, "rb");
    if(points_fin==NULL){fputs ("File error: point_fin",stderr); exit (1);}
    if(norms_fin==NULL){fputs ("File error: norms_fin",stderr); exit (1);}

    float3 *points = new float3[N];
    float3 *norms = new float3[N];
    if (points == NULL) {fputs ("Memory error: points",stderr); exit (2);}
    if (norms  == NULL) {fputs ("Memory error: norms",stderr); exit (2);}

    long startTime0 = clock();
    result1 = fread(points,sizeof(float3),N,points_fin);
    result2 = fread(norms,sizeof(float3),N,norms_fin);
    long finishTime0 = clock();

    if(result1 != N){fputs ("Reading error: points",stderr); exit (3);}
    if(result2 != N){fputs ("Reading error: norms",stderr); exit (3);}

    /*thrust::device_vector<float3> pts(points, points + N*sizeof(float3));*/


    // cuda setup
    cudaDeviceProp  prop;
    HANDLE_ERROR(cudaGetDeviceProperties(&prop, 0));
    int blocks = prop.multiProcessorCount;
    /* DEBUG */
    fprintf(stderr, "blocks: %d\n", blocks);
    /* DEBUG */


    // start cuda timer
    cudaEvent_t start, stop;
    HANDLE_ERROR(cudaEventCreate(&start));
    HANDLE_ERROR(cudaEventCreate(&stop));
    HANDLE_ERROR(cudaEventRecord(start, 0));


    // compute ppfs
    float3 *d_points, *d_norms;
    float4 *d_ppfs;
    HANDLE_ERROR(cudaMalloc(&d_points, N*sizeof(float3)));
    HANDLE_ERROR(cudaMalloc(&d_norms, N*sizeof(float3)));
    HANDLE_ERROR(cudaMalloc(&d_ppfs, N*N*sizeof(float4)));

    HANDLE_ERROR(cudaMemcpy(d_points, points, N*sizeof(float3), cudaMemcpyHostToDevice));
    HANDLE_ERROR(cudaMemcpy(d_norms, norms, N*sizeof(float3), cudaMemcpyHostToDevice));

    ppf_kernel<<<N/BLOCK_SIZE,BLOCK_SIZE>>>(d_points, d_norms, d_ppfs, N);


    // build model description
    SearchStructure *model = new SearchStructure(d_ppfs, N*N);

    // end cuda timer
    HANDLE_ERROR(cudaEventRecord(stop, 0));
    HANDLE_ERROR(cudaEventSynchronize(stop));
    float elapsedTime;
    HANDLE_ERROR(cudaEventElapsedTime(&elapsedTime, start, stop));
    printf("Time to generate:  %3.1f ms\n", elapsedTime);


    // copy ppfs back to host
    float4 *ppfs = new float4[N*N];
    HANDLE_ERROR(cudaMemcpy(ppfs, d_ppfs, N*N*sizeof(float4), cudaMemcpyDeviceToHost));

    // write out ppfs
    for(int i = 0; i < 100; i++){
        cout << "PPF Number: " << i << endl;
        cout << ppfs[i].x << endl;
        cout << ppfs[i].y << endl;
        cout << ppfs[i].z << endl;
        cout << ppfs[i].w << endl;
    }

    cout<<"Data Load Time"<<" "<<(finishTime0 - startTime0)<<" ms"<<endl;

    // Deallocate ram
    delete[] points;
    delete[] norms;
    delete[] ppfs;

    cudaFree(d_points);
    cudaFree(d_norms);
    cudaFree(d_ppfs);

    delete model;

    cudaDeviceReset();

    // close input file
    fclose(points_fin);
    fclose(norms_fin);
    return 0;
}

// int ppf_run(Eigen::MatrixXf &points, Eigen::MatrixXf &normals){
//     float *point_data = points.data();
//     float *normal_data = normals.data();
//     int size = points.rows()*points.cols()*sizeof(float);

//     float *dev_point_data, *dev_normal_data;
//     HANDLE_ERROR(cudaMalloc((void **) &dev_point_data, size));
//     HANDLE_ERROR(cudaMemcpy(dev_point_data, point_data. size));

//     HANDLE_ERROR(cudaMalloc((void **) &dev_normal_data, size));
//     HANDLE_ERROR(cudaMemcpy(dev_normal_data, point_data. size));

//     cudaDeviceProp prop;
//     HANDLE_ERROR(cudaGetDeviceProperties(&prop, 0));
//     int blocks = prop.multiProcessorCount;

//     ppf_kernel<<<blocks*2,256>>>(dev_buffer, SIZE, dev_histo);

// }
