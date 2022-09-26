
#ifndef AES_INTERFACE_H
#define AES_INTERFACE_H


/****************** Include Files ********************/
#include "xil_types.h"
#include "xstatus.h"
#include "xil_io.h"

/**************************** Type Definitions *****************************/

#define BLOCK_SIZE 16

typedef enum {
    MODE_ENCRYPTION = 0,
    MODE_KEYEXPANSION = 1,
    MODE_DECRYPTION = 2,
    MODE_KEYEXPANSION_AND_DECRYPTION = 3
} Mode;

typedef enum {
    CHAINING_MODE_ECB = 0,
    CHAINING_MODE_CBC = 1,
    CHAINING_MODE_CTR = 2
} ChainingMode;

typedef enum {
	GCM_PHASE_INIT = 0,
	GCM_PHASE_HEADER = 1,
	GCM_PHASE_PAYLOAD = 2,
	GCM_PHASE_FINAL = 3
} GCMPhase;


typedef struct {
	u16 DeviceId;	 /**< Unique ID  of device */
	u32 BaseAddress; /**< Base address of device (IPIF) */
} AES_Config;

typedef struct {
	UINTPTR BaseAddress;	/**< Device base address */
} AES;


AES_Config *AES_LookupConfig(u16 DeviceId);
int AES_Initialize(AES *InstancePtr, UINTPTR BaseAddr);

void AES_SetKey(AES *InstancePtr, u8 key[BLOCK_SIZE]);

void AES_Setup(AES* InstancePtr, Mode mode, ChainingMode chMode, u32 enabled, GCMPhase gcmPhase);
void AES_SetMode(AES *InstancePtr, Mode mode);
void AES_SetChainingMode(AES* InstancePtr, ChainingMode chainMode);
void AES_SetGCMPhase(AES* InstancePtr, GCMPhase gcmPhase);
void AES_SetEnabled(AES* InstancePtr, u32 en);

void AES_GetKey(AES *InstancePtr, u8 outKey[BLOCK_SIZE]);
Mode AES_GetMode(AES *InstancePtr);
ChainingMode AES_GetChainingMode(AES* InstancePtr);
void AES_SetGCMPhase(AES* InstancePtr, GCMPhase gcmPhase);
GCMPhase AES_GetGCMPhase(AES* InstancePtr);
u32 AES_GetEnabled(AES* InstancePtr);


void AES_PerformKeyExpansion(AES *InstancePtr);

// Process an entire data chunk at once instead of processing Blocks one by one
void AES_processData(AES* InstancePtr, Mode mode, ChainingMode chMode, u8* data, u8* outData, u32 size);

// Runs dataBlock through the AES unit and writes the output to outDataBlock.
// Arrays must have size BLOCK_SIZE (16 bytes)
void AES_processBlock(AES* InstancePtr, u8 *dataBlock, u8 *outDataBlock);

void AES_waitUntilCompleted(AES* InstancePtr);

/**
 *
 * Write/Read 32 bit value to/from AES_INTERFACE user logic memory (BRAM).
 *
 * @param   Address is the memory address of the AES_INTERFACE device.
 * @param   Data is the value written to user logic memory.
 *
 * @return  The data from the user logic memory.
 *
 * @note
 * C-style signature:
 * 	void AES_mWriteMemory(u32 Address, u32 Data)
 * 	u32 AES_mReadMemory(u32 Address)
 *
 */
#define AES_mWriteMemory(Address, Data) \
    Xil_Out32(Address, (u32)(Data))
#define AES_mReadMemory(Address) \
    Xil_In32(Address)
    
#define AES_Write(InstancePtr, Offset, Data) AES_mWriteMemory((InstancePtr)->BaseAddress+(Offset), (u32)(Data))
#define AES_Read(InstancePtr, Offset) AES_mReadMemory((InstancePtr)->BaseAddress+(Offset))
    
/************************** Function Prototypes ****************************/
/**
 *
 * Run a self-test on the driver/device. Note this may be a destructive test if
 * resets of the device are performed.
 *
 * If the hardware system is not built correctly, this function may never
 * return to the caller.
 *
 * @param   baseaddr_p is the base address of the AES_INTERFACEinstance to be worked on.
 *
 * @return
 *
 *    - XST_SUCCESS   if all self-test code passed
 *    - XST_FAILURE   if any self-test code failed
 *
 * @note    Caching must be turned off for this function to work.
 * @note    Self test may fail if data memory and device are not on the same bus.
 *
 */
XStatus AES_Mem_SelfTest(void * baseaddr_p);

#endif // AES_INTERFACE_H