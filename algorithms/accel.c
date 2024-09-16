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




typedef struct frame {
	uint8_t y[WIDTH][HEIGHT];
	uint8_t u[WIDTH/2][HEIGHT/2];
	uint8_t v[WIDTH/2][HEIGHT/2];
} frame;

typedef uint8_t (mask)[WIDTH][HEIGHT];

void acceleratedCompositingMaskingLoop(
	frame fboard,
	frame fcomp,
	frame fout,
	mask mboard,
	mask mcomp
) {
	
	for (int x = 0; x < WIDTH; ++x) for (int y = 0; y < HEIGHT; ++y) {

		const int lumax = x, lumay = y, chromax = x/2, chromay = y/2;
		#define mean(pixel1, pixel2) ((typeof(pixel1))(((int)(pixel1)+(int)(pixel2))/2))
		
		#define thisY(frame) frame.y[lumax][lumay]
		#define thisU(frame) frame.u[chromax][chromay]
		#define thisV(frame) frame.v[chromax][chromay]

		// basic compositing
		thisY(fout) = mean(thisY(fcomp), thisY(fboard));
		thisU(fout) = mean(thisU(fcomp), thisU(fboard));
		thisV(fout) = mean(thisV(fcomp), thisV(fboard));

		#define isInRange(value, lowerBound, upperBound) (((value) >= (lowerBound)) && ((value) <= (upperBound)))

		// basic masking
		mboard[x][y] = isInRange(thisY(fboard), MASK_BOARD_CUT_IN, MASK_BOARD_CUT_OUT);
		mcomp[x][y] = isInRange(thisY(fcomp), MASK_COMP_CUT_IN, MASK_COMP_CUT_OUT);

		#undef mean
		#undef thisY
		#undef thisU
		#undef thisV
		#undef inRange

	}

}

// for visualisation and testing purposes
// converts a mask to a raw frame suitable for piping to FFmpeg.
void mask2frame(mask in, frame out) {

	for (int x = 0; x < WIDTH; ++x) for (int y = 0; y < HEIGHT; ++y) {

		out.y[x][y] = in[x][y] ? 255 : 0;
		out.u[x/2][y/2] = 128;
		out.v[y/2][y/2] = 128;

	}

}
