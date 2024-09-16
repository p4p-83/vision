#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

#include "accel-compile-time-constants.h"

typedef struct Point {
	int x, y;
} Point;

typedef struct Centroid {
	int x, y, weight;
} Centroid;

inline Point point(int x, int y) {
	const Point p = {.x = x, .y = y};
	return p;
}

int splatSearch(int width, int height, int (mat)[width][height], int startX, int startY, Centroid *centroidsList, int centroidIndex) {

	#define pixelAt(x, y) (mat[(x)][(y)])

	// printf("attempting to search (%d, %d)\n", startX, startY);

	if (pixelAt(startX, startY) != 1) {
		// pixel is either irrelevant or has already been searched
		// printf("nothing to see here\n");
		return centroidIndex;
	}

	// keep track of search
	Point search[MAX_SEARCH_BUF];
	int searchIndex = 0;

	int xsum = 0, ysum = 0, count = 0;

	// pixel is clearly worth searching
	// seed the search
	search[searchIndex++] = point(startX, startY);

	// keep searching until there are no more search points
	while (searchIndex) {

		// note that this is --searchIndex because we've used searchIndex++ to add: they MUST be coordinated
		const Point thisPoint = search[--searchIndex];

		// printf("pad at (%d, %d)\n", thisPoint.x, thisPoint.y);

		// we already know this pixel is 1 (else it would not be in the search array)
		// record in statistics
		++count;
		xsum += thisPoint.x;
		ysum += thisPoint.y;

		// update pixel to show we've been here
		mat[thisPoint.x][thisPoint.y] = 2;

		// helper macro
		// test if pixel needs to be added to search, and then add it if so
		#define trySearching(dx, dy) {														\
			if (pixelAt((thisPoint.x + (dx)), (thisPoint.y + (dy))) == 1) {					\
				search[searchIndex++] = point((thisPoint.x + (dx)), (thisPoint.y + (dy)));	\
			}																				\
		}

		// see if neighbouring pixels are also pad
		trySearching(-1,  0);
		trySearching( 1,  0);
		trySearching( 0, -1);
		trySearching( 0,  1);

		#undef trySearching

		// bounds check
		if (searchIndex + 4 >= MAX_SEARCH_BUF)
			// abort this splat search
			return centroidIndex;

	}

	#undef pixelAt

	// summarise the search
	const Centroid thisCentroid = {
		.x = xsum / count,
		.y = ysum / count,
		.weight = count
	};

	// return results
	centroidsList[centroidIndex] = thisCentroid;
	return centroidIndex + 1;

}

int findPads(int width, int height, int (mat)[width][height], Centroid *centroidsList) {

	// prepare for search
	// we impose the condition that all edge pixels must be non-pad
	// this means that the splatSearches will never go out of bounds even with no explicit bounds checking

	for (int x = 0; x < width; ++x) {
		mat[x][0] = 0;
		mat[x][height-1] = 0;
	}

	for (int y = 0; y < height; ++y) {
		mat[0][y] = 0;
		mat[width-1][y] = 0;
	}

	// seed the search
	// we'll do this on a grid. No need to try starting it at every single pixel

	int centroidIndex = 0;

	for (int x = 1; x < width-1; x += GRID_STEP) {
		for (int y = 1; y < height-1; y += GRID_STEP) {
			// printf("\n\nhello from (%d, %d)\n", x, y);
			centroidIndex = splatSearch(width, height, mat, x, y, centroidsList, centroidIndex);
			// printf("centroid index is now %d", centroidIndex);
			if (centroidIndex >= MAX_NUM_CENTROIDS) return MAX_NUM_CENTROIDS - 1;
		}
	}

	// splatSearch will have already populated centroidsList
	// just return the length (as tracked by splatSearch)
	return centroidIndex;

}

// #define frameWithName(name) uint8_t (name)[width][height]
// #define framePtrWithName(name) uint8_t (*name)[width][height]

// int acceleratedCompositingMaskingLoop(
// 	int width, int height,
// 	frameWithName(frameA),
// 	frameWithName(frameB),
// 	framePtrWithName(frameOut),
// 	framePtrWithName(maskA),
// 	framePtrWithName(maskB)
// ) {

// 	#define luma

// 	for (int x = 0; x < width; ++x) for (int y = 0; y < height; ++y) {

// 	}


// }

#define rawFrameWithName(name) uint8_t (name)[(WIDTH * HEIGHT * 3) / 2]
#define grayFrameWithName(name) uint8_t (name)[WIDTH][HEIGHT]

typedef struct frame {
	uint8_t y[WIDTH][HEIGHT];
	uint8_t u[WIDTH/2][HEIGHT/2];
	uint8_t v[WIDTH/2][HEIGHT/2];
} frame;

typedef struct mask {
	uint8_t a[WIDTH][HEIGHT];
} mask;

void acceleratedCompositingMaskingLoop(
	rawFrameWithName(frameA),
	rawFrameWithName(frameB),
	rawFrameWithName(frameOut),
	grayFrameWithName(maskA),
	grayFrameWithName(maskB)
) {

	// define helper macros
	#define pixelsInLumaChannel (WIDTH*HEIGHT)
	#define pixelsInChromaChannel ((WIDTH*HEIGHT)/4)

	#define pixelsBeforeY (0)
	#define pixelsBeforeU (pixelsBeforeY+pixelsInLumaChannel)
	#define pixelsBeforeV (pixelsBeforeU+pixelsInLumaChannel)

	// typedef uint8_t (*lumaChannel)[width][height];
	// typedef uint8_t (chromaChannel)[width/2][height/2];
	// uint8_t (* frame1luma)[width][height] = (uint8_t (*)[width][height])&frameA[0];

	frame *fa = (frame *)frameA;
	fa->y[0][0] = 0;
	
	for (int x = 0; x < WIDTH; ++x) for (int y = 0; y < HEIGHT; ++y) {
		
		// #define pixelY(frame) (((lumaChannel)(frame+pixelsBeforeY)))[x][y]
		// #define pixelU(frame) (((chromaChannel)(frame+pixelsBeforeU)))[x/2][y/2]
		// #define pixelV(frame) (((chromaChannel)(frame+pixelsBeforeV)))[x/2][y/2]

		// https://stackoverflow.com/a/2565048
		#define pixelY(frame) ((frame)[pixelsBeforeY + HEIGHT*x + y])
		#define pixelU(frame) ((frame)[pixelsBeforeU + (HEIGHT/2)*(x/2) + (y/2)])
		#define pixelV(frame) ((frame)[pixelsBeforeV + (HEIGHT/2)*(x/2) + (y/2)])
		
		#define mean(pixel1, pixel2) ((typeof(pixel1))(((int)(pixel1)+(int)pixel2)/2))

		pixelY(frameOut) = mean(pixelY(frameA), pixelY(frameB));
		pixelU(frameOut) = mean(pixelU(frameA), pixelU(frameB));
		pixelV(frameOut) = mean(pixelV(frameA), pixelV(frameB));

		#undef pixelY
		#undef pixelU
		#undef pixelV

	}

	// manually remove helper macros from "scope"
	#undef pixelsInLumaChannel
	#undef pixelsInChromaChannel
	#undef pixelsBeforeY
	#undef pixelsBeforeU
	#undef pixelsBeforeV

}


