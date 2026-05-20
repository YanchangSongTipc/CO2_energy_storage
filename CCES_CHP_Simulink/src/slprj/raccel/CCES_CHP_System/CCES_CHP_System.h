#ifndef CCES_CHP_System_h_
#define CCES_CHP_System_h_
#ifndef CCES_CHP_System_COMMON_INCLUDES_
#define CCES_CHP_System_COMMON_INCLUDES_
#include <stdlib.h>
#include "rtwtypes.h"
#include "sigstream_rtw.h"
#include "simtarget/slSimTgtSigstreamRTW.h"
#include "simtarget/slSimTgtSlioCoreRTW.h"
#include "simtarget/slSimTgtSlioClientsRTW.h"
#include "simtarget/slSimTgtSlioSdiRTW.h"
#include "simstruc.h"
#include "fixedpoint.h"
#include "raccel.h"
#include "slsv_diagnostic_codegen_c_api.h"
#include "rt_logging_simtarget.h"
#include "rt_nonfinite.h"
#include "math.h"
#include "dt_info.h"
#include "ext_work.h"
#endif
#include "CCES_CHP_System_types.h"
#include <stddef.h>
#include "rtw_modelmap_simtarget.h"
#include "rt_defines.h"
#include <string.h>
#include "rtGetInf.h"
#define MODEL_NAME CCES_CHP_System
#define NSAMPLE_TIMES (5) 
#define NINPUTS (0)       
#define NOUTPUTS (0)     
#define NBLOCKIO (2) 
#define NUM_ZC_EVENTS (0) 
#ifndef NCSTATES
#define NCSTATES (2)   
#elif NCSTATES != 2
#error Invalid specification of NCSTATES defined in compiler command
#endif
#ifndef rtmGetDataMapInfo
#define rtmGetDataMapInfo(rtm) (*rt_dataMapInfoPtr)
#endif
#ifndef rtmSetDataMapInfo
#define rtmSetDataMapInfo(rtm, val) (rt_dataMapInfoPtr = &val)
#endif
#ifndef IN_RACCEL_MAIN
#endif
typedef struct { real_T avjqz0ojgy ; real_T pspzpimb4b ; } B ; typedef struct
{ struct { void * LoggedData [ 2 ] ; } fdzdbymafl ; struct { void *
LoggedData [ 2 ] ; } lr3fo3q2kk ; } DW ; typedef struct { real_T kxue0m5tbx ;
real_T n02w2aei15 ; } X ; typedef struct { real_T kxue0m5tbx ; real_T
n02w2aei15 ; } XDot ; typedef struct { boolean_T kxue0m5tbx ; boolean_T
n02w2aei15 ; } XDis ; typedef struct { real_T kxue0m5tbx ; real_T n02w2aei15
; } CStateAbsTol ; typedef struct { real_T kxue0m5tbx ; real_T n02w2aei15 ; }
CXPtMin ; typedef struct { real_T kxue0m5tbx ; real_T n02w2aei15 ; } CXPtMax
; typedef struct { rtwCAPI_ModelMappingInfo mmi ; } DataMapInfo ; struct P_ {
real_T mass_IC ; real_T Q_store_IC ; } ; extern const char_T *
RT_MEMORY_ALLOCATION_ERROR ; extern B rtB ; extern X rtX ; extern DW rtDW ;
extern P rtP ; extern mxArray * mr_CCES_CHP_System_GetDWork ( ) ; extern void
mr_CCES_CHP_System_SetDWork ( const mxArray * ssDW ) ; extern mxArray *
mr_CCES_CHP_System_GetSimStateDisallowedBlocks ( ) ; extern const
rtwCAPI_ModelMappingStaticInfo * CCES_CHP_System_GetCAPIStaticMap ( void ) ;
extern SimStruct * const rtS ; extern DataMapInfo * rt_dataMapInfoPtr ;
extern rtwCAPI_ModelMappingInfo * rt_modelMapInfoPtr ; void MdlOutputs (
int_T tid ) ; void MdlOutputsParameterSampleTime ( int_T tid ) ; void
MdlUpdate ( int_T tid ) ; void MdlTerminate ( void ) ; void
MdlInitializeSizes ( void ) ; void MdlInitializeSampleTimes ( void ) ;
SimStruct * raccel_register_model ( ssExecutionInfo * executionInfo ) ;
#endif
