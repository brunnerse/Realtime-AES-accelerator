
#ifndef AES_INTERFACE_M_H
#define AES_INTERFACE_M_H


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
    CHAINING_MODE_CTR = 2,
	CHAINING_MODE_GCM = 3
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


typedef void (*AES_InterruptHandler)(AES* instancePtr);


/************************** Function Prototypes ****************************/
AES_Config *AES_LookupConfig(u16 DeviceId);
s32 AES_CfgInitialize(AES *InstancePtr, const AES_Config *ConfigPtr);

s32 AES_SetupInterrupt(AES* InstancePtr, XScuGic* InterruptCtrlPtr, AES_InterruptHandler interruptHandler);

void AES_SetKey(AES *InstancePtr, u8 key[BLOCK_SIZE]);

void AES_Setup(AES* InstancePtr, Mode mode, ChainingMode chMode, u32 enabled, GCMPhase gcmPhase);
void AES_SetMode(AES *InstancePtr, Mode mode);
void AES_SetChainingMode(AES* InstancePtr, ChainingMode chainMode);
void AES_SetGCMPhase(AES* InstancePtr, GCMPhase gcmPhase);
void AES_SetEnabled(AES* InstancePtr, u32 en);
void AES_SetIV(AES* InstancePtr, u8 *IV, u32 IVLen);
void AES_SetSusp(AES* InstancePtr, u8 Susp[BLOCK_SIZE]);


void AES_GetKey(AES *InstancePtr, u8 outKey[BLOCK_SIZE]);
Mode AES_GetMode(AES *InstancePtr);
ChainingMode AES_GetChainingMode(AES* InstancePtr);
void AES_SetGCMPhase(AES* InstancePtr, GCMPhase gcmPhase);
GCMPhase AES_GetGCMPhase(AES* InstancePtr);
u32 AES_GetEnabled(AES* InstancePtr);


void AES_PerformKeyExpansion(AES *InstancePtr);

// Process an entire data chunk at once instead of processing Blocks one by one
void AES_processDataECB(AES* InstancePtr, int encrypt, u8* data, u8* outData, u32 size);
void AES_processDataCBC(AES* InstancePtr, int encrypt, u8* data, u8* outData, u32 size, u8 IV[16]);
// encrypt is indifferent, as decryption and encryption is the same process
void AES_processDataCTR(AES* InstancePtr, u8* data, u8* outData, u32 size, u8 IV[12]);
void AES_processDataGCM(AES* InstancePtr, int encrypt, u8* header, u32 headerLen, u8* payload, u8* outProcessedPayload, u32 payloadLen, u8 IV[12], u8 outTag[BLOCK_SIZE]);

// Compares two tags. Returns 0 if identical, otherwise -1
int AES_compareTags(u8 tag1[BLOCK_SIZE], u8 tag2[BLOCK_SIZE]);
// Runs dataBlock through the AES unit and writes the output to outDataBlock.
// Arrays must have size BLOCK_SIZE (16 bytes)
void AES_processBlock(AES* InstancePtr, u8 *dataBlock, u8 *outDataBlock);

void AES_waitUntilCompleted(AES* InstancePtr);

/**
 *
 * Write/Read 32 bit value to/from AES_INTERFACE_M user logic memory (BRAM).
 *
 * @param   Address is the memory address of the AES_INTERFACE_M device.
 * @param   Data is the value written to user logic memory.
 *
 * @return  The data from the user logic memory.
 *
 * @note
 * C-style signature:
 * 	void AES_INTERFACE_M_mWriteMemory(u32 Address, u32 Data)
 * 	u32 AES_INTERFACE_M_mReadMemory(u32 Address)
 *
 */
#define AES_mWriteMemory(Address, Data) \
    Xil_Out32(Address, (u32)(Data))
#define AES_mReadMemory(Address) \
    Xil_In32(Address)
    
// Simple wrappers for mWriteMemory and mReadMemory 
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
 * @param   baseaddr_p is the base address of the AES_INTERFACE_Minstance to be worked on.
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

#endif // AES_INTERFACE_M_H
