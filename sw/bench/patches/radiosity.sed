# Object pools are sized for large runs (175 MB); shrink them to fit the 32 MiB simulated DRAM (A11).
s/^#define MAX_PROCESSORS (1024)/#define MAX_PROCESSORS (4)/
s/^#define MAX_TASKQUEUES (1024)/#define MAX_TASKQUEUES (4)/
s/^#define MAX_TASKS    (3276800)/#define MAX_TASKS    (32768)/
s/long MAX_ELEMENTS = 100000;/long MAX_ELEMENTS = 20000;/
s/long MAX_INTERACTIONS = 1000000;/long MAX_INTERACTIONS = 200000;/
s/long MAX_ELEMVERTICES = 100000;/long MAX_ELEMVERTICES = 20000;/
s/long MAX_EDGES = 100000;/long MAX_EDGES = 20000;/
