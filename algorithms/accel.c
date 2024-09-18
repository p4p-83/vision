#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

#include "accel-compile-time-constants.h"

// struct type to construct a point
typedef struct Point {
	int x, y;
} Point;

/**
 * point
 * Internal helper function the acts as a constructer function for struct Point
 */
static inline Point point(int x, int y) {
	const Point p = {.x = x, .y = y};
	return p;
}

// struct type to represent a centroid
// must match memory layout from Julia
typedef struct Centroid {
	int x, y, weight;
} Centroid;

// type to represent a frame in yuv420p format (i.e. YUV 4:2:0)
typedef struct frame {
	uint8_t y[WIDTH][HEIGHT];
	uint8_t u[WIDTH/2][HEIGHT/2];
	uint8_t v[WIDTH/2][HEIGHT/2];
} *frame;

// type to represent a mask
typedef uint8_t (mask)[WIDTH][HEIGHT];

/**
 * splatSearch
 * Internal helper method that performs the search pattern to capture all pixels of a
 * centroid and then adds it to the list of centroids found.
 * @param m the mask to process (searched pixels will be altered in place to prevent double-counting)
 * @param startX the x coordinate at which to seed the search
 * @param startY "   y "          "  "     "  "    "   "
 * @param centroidsList the buffer into which a centroid can be written if found
 * @param centroidIndex the index at which to write the centroid if one is found
 * @return the new value of centroidIndex (which has been incremented if a centroid was found)
 */
static int splatSearch(mask m, int startX, int startY, Centroid centroidsList[MAX_NUM_CENTROIDS], int centroidIndex) {

	#define pixelAt(x, y) (m[(x)][(y)])

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
		m[thisPoint.x][thisPoint.y] = 2;

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

/**
 * mask2frame
 * Use this to visualise a mask by converting it to a black-and-white
 * frame that can be piped to FFmpeg.
 */
void mask2frame(mask in, frame out) {

	for (int x = 0; x < WIDTH; ++x) for (int y = 0; y < HEIGHT; ++y) {

		out->y[x][y] = in[x][y] ? 255 : 0;
		out->u[x/2][y/2] = 128;
		out->v[y/2][y/2] = 128;

	}

}

/**
 * acceleratedCompositingMaskingLoop
 * Takes the raw camera feeds and works pixelwise to produce the composite video
 * output and the masks for both camera feeds.
 */
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
		
		#define thisY(frame) frame->y[lumax][lumay]
		#define thisU(frame) frame->u[chromax][chromay]
		#define thisV(frame) frame->v[chromax][chromay]

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

	mask2frame(mcomp, fout);

}

/**
 * acceleratedCentroidFinding
 * Takes a mask and reduces it to a list of centroids.
 * @param m the mask to process (will be altered by splatSearch)
 * @param centroidsList a buffer to be overwritten with the centroids as they're found
 * @return the number of centroids found (length of the used buffer)
 */
int acceleratedCentroidFinding(mask m, Centroid centroidsList[MAX_NUM_CENTROIDS]) {

	// prepare for search
	// we impose the condition that all edge pixels must be non-pad
	// this means that the splatSearches will never go out of bounds even with no explicit bounds checking

	for (int x = 0; x < WIDTH; ++x) {
		m[x][0] = 0;
		m[x][HEIGHT-1] = 0;
	}

	for (int y = 0; y < HEIGHT; ++y) {
		m[0][y] = 0;
		m[WIDTH-1][y] = 0;
	}

	// seed the search
	// we'll do this on a grid. No need to try starting it at every single pixel

	int centroidIndex = 0;

	for (int x = 1; x < WIDTH-1; x += GRID_STEP) {
		for (int y = 1; y < HEIGHT-1; y += GRID_STEP) {
			// printf("\n\nhello from (%d, %d)\n", x, y);
			centroidIndex = splatSearch(m, x, y, centroidsList, centroidIndex);
			// printf("centroid index is now %d", centroidIndex);
			if (centroidIndex >= MAX_NUM_CENTROIDS) return MAX_NUM_CENTROIDS - 1;
		}
	}

	// splatSearch will have already populated centroidsList
	// just return the length (as tracked by splatSearch)
	return centroidIndex;

}
