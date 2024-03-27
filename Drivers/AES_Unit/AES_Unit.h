
#ifndef AES_UNIT_H
#define AES_UNIT_H

#ifdef __cplusplus
extern "C" {
#endif

/****************** Include Files ********************/
#include <stdint.h>

/**************************** Type Definitions *****************************/
#define BLOCK_SIZE 16

#define AES_BYTE_ORDER LITTLE_ENDIAN
#define AES_REG_KEY_WRITEONLY 1
#define AES_NUM_CHANNELS 15

#define AES_ADDR_REGISTER_BITS 7
#define AES_MAX_PRIORITY (AES_NUM_CHANNELS-1)

#define AES_ERROR_NONE 0
#define AES_ERROR_READ 1
#define AES_ERROR_WRITE 2

typedef void (*AES_CallbackFn)(void* CallbackRef);

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
	const uint16_t DeviceId;	 /**< Unique ID  of device */
	const uintptr_t BaseAddress; /**< Base address of device (IPIF) */
    const uint32_t NumChannels;
} AES_Config;

typedef struct {
	uintptr_t BaseAddress;	/**< Device base address */ //TODO make void* instead?
    AES_CallbackFn  CallbackFn[AES_NUM_CHANNELS];
    void *CallbackRef[AES_NUM_CHANNELS];
} AES;



/************************** Function Prototypes ****************************/
AES_Config *AES_LookupConfig(uint16_t DeviceId);
int32_t AES_CfgInitialize(AES *InstancePtr, const AES_Config *ConfigPtr);

void AES_SetKey(AES *InstancePtr, uint32_t channel, char key[BLOCK_SIZE]);
void AES_SetDataParameters(AES* InstancePtr, uint32_t channel, void* source, void* dest, uint32_t size);
void AES_Setup(AES* InstancePtr, uint32_t channel, Mode mode, ChainingMode chMode, uint32_t enabled, GCMPhase gcmPhase);
void AES_SetMode(AES *InstancePtr, uint32_t channel, Mode mode);
void AES_SetChainingMode(AES* InstancePtr, uint32_t channel, ChainingMode chainMode);
void AES_SetGCMPhase(AES* InstancePtr, uint32_t channel, GCMPhase gcmPhase);
void AES_SetPriority(AES* InstancePtr, uint32_t channel, uint32_t priority);
void AES_SetInterruptEnabled(AES* InstancePtr, uint32_t channel, uint32_t en);

void AES_SetInterruptCallback(AES* InstancePtr, uint32_t channel, AES_CallbackFn callbackFn, void* callbackRef);

void AES_startComputation(AES* InstancePtr, uint32_t channel);

void AES_SetIV(AES* InstancePtr, uint32_t channel, void *IV, uint32_t IVLen);
void AES_SetSusp(AES* InstancePtr, uint32_t channel, char Susp[BLOCK_SIZE*2]);

Mode AES_GetMode(AES *InstancePtr, uint32_t channel);
ChainingMode AES_GetChainingMode(AES* InstancePtr, uint32_t channel);
GCMPhase AES_GetGCMPhase(AES* InstancePtr, uint32_t channel);
uint32_t AES_GetPriority(AES* InstancePtr, uint32_t channel);
uint32_t AES_GetInterruptEnabled(AES* InstancePtr, uint32_t channel);

#if !AES_REG_KEY_WRITEONLY
void AES_GetKey(AES *InstancePtr, uint32_t channel, char outKey[BLOCK_SIZE]);
void AES_GetIV(AES* InstancePtr, uint32_t channel, char outIV[BLOCK_SIZE]);
void AES_GetSusp(AES* InstancePtr, uint32_t channel, char outSusp[BLOCK_SIZE*2]);
#endif

uint32_t AES_isActive(AES* InstancePtr, uint32_t channel);

void AES_PerformKeyExpansion(AES *InstancePtr, uint32_t channel);

// Process an entire data chunk at once instead of processing Blocks one by one
void AES_startComputationMode(AES* InstancePtr, uint32_t channel, ChainingMode chmode, int encrypt, void* data, void* outData, uint32_t size,
     char IV[BLOCK_SIZE], AES_CallbackFn callbackFn, void* callbackRef);
void AES_startComputationECB(AES* InstancePtr, uint32_t channel, int encrypt, void* data, void* outData, uint32_t size,
     AES_CallbackFn callbackFn, void* callbackRef);
void AES_startComputationCBC(AES* InstancePtr, uint32_t channel, int encrypt, void* data, void* outData, uint32_t size, 
    char IV[BLOCK_SIZE], AES_CallbackFn callbackFn, void* callbackRef);
// encrypt is indifferent, as decryption and encryption is the same process
void AES_startComputationCTR(AES* InstancePtr, uint32_t channel, void* data, void* outData, uint32_t size, 
    char IV[BLOCK_SIZE-4], AES_CallbackFn callbackFn, void* callbackRef);
void AES_startComputationGCM(AES* InstancePtr, uint32_t channel, int encrypt, void* header, uint32_t headerLen,
     void* payload, void* outProcessedPayload, uint32_t payloadLen, char IV[BLOCK_SIZE-4], AES_CallbackFn callbackFn, void* callbackRef);
void AES_calculateTagGCM(AES* InstancePtr, uint32_t channel, uint32_t headerLen, uint32_t payloadLen, char outTag[BLOCK_SIZE]);

// Functions block until computation has completed
void AES_processDataECB(AES* InstancePtr, uint32_t channel, int encrypt, void* data, void* outData, uint32_t size);
void AES_processDataCBC(AES* InstancePtr, uint32_t channel, int encrypt, void* data, void* outData, uint32_t size, char IV[BLOCK_SIZE]);
// encrypt is indifferent, as decryption and encryption is the same process
void AES_processDataCTR(AES* InstancePtr, uint32_t channel, void* data, void* outData, uint32_t size, char IV[BLOCK_SIZE-4]);
void AES_processDataGCM(AES* InstancePtr, uint32_t channel, int encrypt, void* header, uint32_t headerLen,
     void* payload, void* outProcessedPayload, uint32_t payloadLen, char IV[BLOCK_SIZE-4], char outTag[BLOCK_SIZE]);

// Compares two tags generated by GCM. Returns 0 if identical, otherwise -1
int AES_compareTags(char tag1[BLOCK_SIZE], char tag2[BLOCK_SIZE]);


// returns 1 if most recent computation has completed, otherwise 0
int AES_isComputationCompleted(AES* InstancePtr, uint32_t channel);
// blocks until computation is completed
void AES_waitUntilCompleted(AES* InstancePtr, uint32_t channel);
uint32_t AES_GetError(AES* InstancePtr, uint32_t channel);

void AES_clearCompletedStatus(AES* InstancePtr, uint32_t channel);

void AES_IntrHandler(void *HandlerRef);



// Writing and Reading for the specific microcontroller
// TODO just use bare implementation instead?
/**
 *
 * Write/Read 32 bit value to/from AES_UNIT user logic memory (BRAM).
 *
 * @param   Address is the memory address of the AES device.
 * @param   Data is the value written to user logic memory.
 *
 * @return  The data from the user logic memory.
 *
 * @note
 * C-style signature:
 * 	void AES_mWriteMemory(uint32_t Address, uint32_t Data)
 * 	uint32_t AES_mReadMemory(uint32_t Address)
 *
 */
#include "xil_io.h" // Comment out if file not found
#ifdef XIL_IO_H
#define AES_mWriteMemory(Address, Data) \
    Xil_Out32(Address, (uint32_t)(Data))
#define AES_mReadMemory(Address) \
    Xil_In32(Address)
#else
// Alternative implementation of write and read functions if xil_io is not available
#define AES_mWriteMemory(Address, Data) \
    (*(volatile uint32_t*)(Address) = (uint32_t)(Data))
#define AES_mReadMemory(Address) \
    (*(volatile uint32_t*)(Address))
#endif

// Simple wrappers for mWriteMemory and mReadMemory 
#define AES_Write(InstancePtr, channel, Offset, Data) \
    AES_mWriteMemory((InstancePtr)->BaseAddress + ((channel)<<AES_ADDR_REGISTER_BITS) + (Offset), (uint32_t)(Data))
#define AES_Read(InstancePtr, channel, Offset) \
    AES_mReadMemory((InstancePtr)->BaseAddress + ((channel)<<AES_ADDR_REGISTER_BITS) + (Offset))   

/************************** Function Prototypes ****************************/
/**
 *
 * Run a self-test on the driver/device. Note this may be a destructive test if
 * resets of the device are performed.
 *
 * If the hardware system is not built correctly, this function may never
 * return to the caller.
 *
 * @param   baseaddr_p is the base address of the AES instance to be worked on.
 *
 * @return
 *
 *    - 0   if all self-test code passed
 *    - 1   if any self-test code failed
 *
 * @note    Caching must be turned off for this function to work.
 * @note    Self test may fail if data memory and device are not on the same bus.
 *
 */
int32_t AES_Mem_SelfTest(void * baseaddr_p);


#ifdef __cplusplus
}
#endif
#endif // AES_UNIT_H
