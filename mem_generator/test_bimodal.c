#include<stdint.h>
int main() {
    volatile int sum = 0;
    int array[10];

    // ---------------------------------------------------------
    // TEST 1: The Loop (Tests "Strongly Taken" state)
    // ---------------------------------------------------------
    // The branch at the end of this loop will jump back to the 
    // top 9 times, and fall through 1 time.
    for (int i = 0; i < 10; i++) {
        array[i] = i;
        sum = sum + i;
    }

    // ---------------------------------------------------------
    // TEST 2: The Static Condition (Tests "Not Taken" state)
    // ---------------------------------------------------------
    // sum is exactly 45 right now. This 'if' is true. 
    // The branch instruction here will NOT be taken.
    if (sum == 45) {
        sum = sum * 2; // Expected path
    } else {
        sum = 0;       // Dead code, should never jump here
    }

    // Infinite loop to stop the processor gracefully
    while(1) {}

    return 0;
}