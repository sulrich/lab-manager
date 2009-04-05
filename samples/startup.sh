#!/bin/sh 

IOURC="/export/home/http/htdocs/iourc"
export IOURC
cd %%POD_PATH%%
./%%WRAPPER%% -m ./%%IMAGE%% -p %%PORT%% -- -e2 -s2 -m48 %%31%% >.startlog-%%31%% 2>&1 &
./%%WRAPPER%% -m ./%%IMAGE%% -p %%PORT%% -- -e2 -s2 -m48 %%32%% >.startlog-%%32%% 2>&1 &
./%%WRAPPER%% -m ./%%IMAGE%% -p %%PORT%% -- -e2 -s2 -m48 %%33%% >.startlog-%%33%% 2>&1 &
./%%WRAPPER%% -m ./%%IMAGE%% -p %%PORT%% -- -e2 -s2 -m48 %%34%% >.startlog-%%34%% 2>&1 &
./%%WRAPPER%% -m ./%%IMAGE%% -p %%PORT%% -- -e2 -s2 -m48 %%35%% >.startlog-%%35%% 2>&1 &
./%%WRAPPER%% -m ./%%IMAGE%% -p %%PORT%% -- -e2 -s2 -m48 %%36%% >.startlog-%%36%% 2>&1 &
