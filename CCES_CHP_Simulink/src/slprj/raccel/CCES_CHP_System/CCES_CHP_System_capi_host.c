#include "CCES_CHP_System_capi_host.h"
static CCES_CHP_System_host_DataMapInfo_T root;
static int initialized = 0;
rtwCAPI_ModelMappingInfo *getRootMappingInfo()
{
    if (initialized == 0) {
        initialized = 1;
        CCES_CHP_System_host_InitializeDataMapInfo(&(root), "CCES_CHP_System");
    }
    return &root.mmi;
}

rtwCAPI_ModelMappingInfo *mexFunction(){return(getRootMappingInfo());}
