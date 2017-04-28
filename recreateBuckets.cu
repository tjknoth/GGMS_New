


  /* Function to split existing buckets into sub-buckets and allocate data accordingly
   *
   * Notes: Make sure slopes is allocated. Get endpoints.
   */
  template <typename T>
  __global__ void recreateBuckets (T * d_vector, int numBuckets, double * originalSlopes, double * pivots,
                                   uint * elementToBucket, uint* d_bucketCount
                                   , uint offset, int length, int sumsRowIndex, const int numBigBuckets, int precount
                                   , uint * d_uniqueBuckets, uint* bucketBounds, uint * reindexCounts) {

    __shared__ double minimum;
    __shared__ double slope;
    __shared__ int previousBuckets;
    __shared__ int numSubBuckets;


    extern __shared__ uint array[];
    uint* counts = (uint*) array;    


    
    // if (idx < 1) {
    //   printf ("LENGTH: %d\n", length);
    //   //bucketBounds[numBigBuckets] = length;
    //   bucketBounds[0] = 0;
    //   for (int i = 1; i <= numBigBuckets; i++) {
    //     bucketBounds[i] = bucketBounds[i - 1] + d_bucketCount[d_uniqueBuckets[i - 1] + sumsRowIndex];
    //     printf ("adding: %u\n", d_bucketCount[d_uniqueBuckets[i - 1] + sumsRowIndex]);
    //   } // end if-else
    //   //for (int i = 0; i < numBigBuckets + 1; i++)
    //     //        printf ("bucketBounds[%d] = %u\n", i, bucketBounds[i]);
    // }
    if (threadIdx.x < 1) {  //printf("In the loop \n");
      for (int i = 0; i < numBigBuckets; i++)
        bucketBounds[i] = reindexCounts[i];
      bucketBounds[numBigBuckets] = length;
    }


    syncthreads();

    // One block is dedicated to each big bucket
    if (blockIdx.x < numBigBuckets) {
      // One thread calculates shared values of slope, min and number of previous buckets for this block
      if (threadIdx.x < 1) {
        //printf ("BUCKETS 0: %u, BUCKETS 1: %u, 2: %u, 3: %u\n", bucketBounds[0], bucketBounds[1], bucketBounds[2], bucketBounds[3]);

        // Find which of the previous buckets we are in
        int hugeBucket = (int) (d_uniqueBuckets[blockIdx.x] / precount);

        // Calculate number of subbuckets per big bucket
        numSubBuckets = (int) (numBuckets / numBigBuckets); 
	//printf("\n subBuckets: %d \n",numSubBuckets);
	//printf("\n d_uniqueBuckets[blockIdx.x] %u \n precount %d \n hugeBucket %d \n originalSlopes[hugeBucket]) %lf \n pivot %lf \n",
               //d_uniqueBuckets[blockIdx.x],precount,hugeBucket,originalSlopes[hugeBucket],(float) pivots[hugeBucket]);
	int localBucket = d_uniqueBuckets[blockIdx.x] - (precount * hugeBucket);				
	//printf("\n local bucket: %d \n",localBucket);

        // Calculate and store min and slope
        minimum = localBucket / originalSlopes[hugeBucket] + pivots[hugeBucket];   
	//printf("\n Min: %lf \n",minimum);
        //        T maximum = ((localBucket + 1) / originalSlopes[hugeBucket]) + pivots[hugeBucket];
        //	printf("\n Max: %lf \n",maximum);
        slope = numSubBuckets * originalSlopes[hugeBucket];
	//printf("\n Slope v1: %lf \n",slope);


        // Calculate number of subbuckets for the previous big buckets
        previousBuckets = (int) numSubBuckets * blockIdx.x;


        //        precount[0] = numSubBuckets;	// wont work precount is on the host
         // update the original slopes, make sure it is the right size
      } // end if (threadIdx.x < 1)


      // Initialize counts
      for (int i = threadIdx.x; i < numBuckets; i += blockDim.x) {
        counts[i] = 0;
      }  // end for


      syncthreads();

      if (threadIdx.x+blockIdx.x < 1) {	
	for (int i = 0; i < numBuckets; i++){
	  if (d_bucketCount[i + sumsRowIndex] != 0) {
	    //printf("d_buckcount[%d]=%d\n",i + sumsRowIndex,d_bucketCount[i + sumsRowIndex]);
	    //d_bucketCount[i + sumsRowIndex] = 0;
	    //printf("count[%d]=%d\n",i,d_bucketCount[i]);
	  }
	}
      }

      syncthreads(); 

	
      // reassign bucket numbers

      // if (threadIdx.x<1) { printf("blockId = %d, start=%u bucketEnd=%u, previousBuckets=%d\n",blockIdx.x,bucketBounds[blockIdx.x],bucketBounds[blockIdx.x+1], previousBuckets);}

      syncthreads();

      for (int i = threadIdx.x + bucketBounds[blockIdx.x]; i < bucketBounds[blockIdx.x + 1]; i += blockDim.x) {
        int bucketIndex = (int) (slope * (d_vector[i] - minimum)) + previousBuckets;
	if (bucketIndex > numBuckets - 1) bucketIndex = numBuckets - 1;
	elementToBucket[i] = bucketIndex;
        //printf("bucketIndex=%u and elementToBucket[%d]=%u\n",bucketIndex,i,elementToBucket[i]);
        atomicInc(counts + bucketIndex, length);
      }		
	
      syncthreads();

      // counts to d_bucketCount	
      //      int sumsRowIndex= numBuckets * (numBlocks-1);
      for (int i = threadIdx.x; i < numBuckets; i += blockDim.x) {
        if (counts[i]!=0) { 
          //printf("counts[%d]=%d\n",i,counts[i]); 
          atomicAdd(d_bucketCount + i + sumsRowIndex, counts[i]);
        }
      }
    } // end if (blockIdx.x < numBigBuckets)
//    syncthreads(); 
    if (threadIdx.x < 1) {
      originalSlopes[blockIdx.x] = slope; 	
      //for (int i = 0; i < numBuckets; i++){
        //if (d_bucketCount[i + sumsRowIndex] != 0) {
          //printf("d_buckcount[%d]=%d\n",i,d_bucketCount[i + sumsRowIndex]);
        }
      }
    }
  } // end recreateBuckets kernel


