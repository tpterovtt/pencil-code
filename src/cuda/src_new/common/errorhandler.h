#pragma once
#include <stdio.h>
#include <stdlib.h>


#define CRASH(x)\
{\
    printf("%s, %s. Error in file %s line %d.\n", __TIME__, __DATE__, __FILE__, __LINE__);\
    perror(x);\
    exit(EXIT_FAILURE);\
    abort();\
}


#define RAISE_ERROR(x)\
{\
    printf("%s, %s. Error in file %s line %d.\n", __TIME__, __DATE__, __FILE__, __LINE__);\
    perror(x);\
}
