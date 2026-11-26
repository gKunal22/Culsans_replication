# Static arrays are sized for 1024 processors (134 MB for prefix_tree); the SoC has 2 harts (A11).
s/^#define MAX_PROCESSORS *1024/#define MAX_PROCESSORS 4/
