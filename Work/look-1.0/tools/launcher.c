#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
// launcher <dylib> <executable> [args...] : sets DYLD_INSERT_LIBRARIES (system shells strip it) and runs the app.
int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: launcher dylib exe args\n"); return 2; }
    setenv("DYLD_INSERT_LIBRARIES", argv[1], 1);
    execv(argv[2], argv + 2);
    perror("execv");
    return 1;
}
