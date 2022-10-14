

/***************************** Include Files *******************************/
#include "AES_Interface_M.h"
#include "xparameters.h"
#include "xscugic.h"
/************************** Function Definitions ***************************/

// Comment this line on Big Endian systems
#define LITTLE_ENDIAN


#define AES_CR_OFFSET 0x00
#define AES_SR_OFFSET 0x04
#define AES_DINR_ADDR_OFFSET 0x08
#define AES_DOUTR_ADDR_OFFSET 0x0c
#define AES_DATASIZE_OFFSET 0x30
#define AES_KEYR0_OFFSET 0x10
#define AES_IVR0_OFFSET 0x20
#define AES_SUSPR0_OFFSET 0x40

// Position definitions in the Control Register CR
#ifdef LITTLE_ENDIAN
#define EN_POS 24
#define MODE_POS 27
#define CHAIN_MODE_POS 29
//#define CHAIN_MODE_POS2 8
#define CCFIE_POS 17
#define ERRIE_POS 18
#define GCM_PHASE_POS 21
#define CCFC_POS 31
#define SR_CCF_POS 24
#define MODE_GCM_IV_INIT 0x02000000
#define MODE_GCM_IV_FINAL 0x01000000
#else
// Normal, Big Endian Positions of the bits
#define EN_POS 0
#define MODE_POS 3
#define CHAIN_MODE_POS 5
//#define CHAIN_MODE_POS2 16
#define CCFIE_POS 9
#define ERRIE_POS 10
#define GCM_PHASE_POS 13
#define CCFC_POS 7
#define SR_CCF_POS 1
#define MODE_GCM_IV_INIT 0x00000002
#define MODE_GCM_IV_FINAL 0x00000001
#endif

#define MODE_CTR_IV_INIT 0x00000000
#define EN_LEN 1
#define MODE_LEN 2
#define CHAIN_MODE_LEN 2
//#define CHAIN_MODE_LEN2 1
#define CCFIE_LEN 1
#define ERRIE_LEN 1
#define GCM_PHASE_LEN 2
#define CCFC_LEN 1
#define SR_CCF_LEN 1

/**************************   Private variables **********************/
AES_Config config =
{
		XPAR_AES_INTERFACE_M_0_DEVICE_ID,
		XPAR_AES_INTERFACE_M_0_S_AXI_BASEADDR
};

volatile u32 interruptCalled = 0;

/*************************** Private Function declarations **********************/
u32 getBits(u32 val, u32 lowestBitIndex, u32 bitLen);
void setBits(u32* ptr, u32 bits, u32 lowestBitIndex, u32 bitLen);
void waitUntilInterrupt();
void interruptRoutine(AES* InstancePtr);

/*************************** Function definitions **********************/



AES_Config *AES_LookupConfig(u16 DeviceId)
{
	if (DeviceId == config.DeviceId)
		return &config;
	else
		return NULL;
}

s32 AES_CfgInitialize(AES *InstancePtr, const AES_Config *ConfigPtr)
{
    InstancePtr->BaseAddress = ConfigPtr->BaseAddress;
    return (s32)(XST_SUCCESS);
}

void AES_SetKey(AES *InstancePtr, u8 key[BLOCK_SIZE])
{
   for (u32 i = 0; i < BLOCK_SIZE; i+=4)
        AES_Write(InstancePtr, AES_KEYR0_OFFSET+i, *(u32*)(key+i));
}

void AES_SetIV(AES* InstancePtr, u8 *IV, u32 IVLen)
{
	for (u32 i = 0; i < IVLen; i+=4)
		AES_Write(InstancePtr, AES_IVR0_OFFSET+i, *(u32*)(IV+i));
}

void AES_SetSusp(AES* InstancePtr, u8 Susp[BLOCK_SIZE*2])
{
	for (u32 i = 0; i < BLOCK_SIZE*2; i+=4)
		AES_Write(InstancePtr, AES_SUSPR0_OFFSET+i, *(u32*)(Susp+i));
}

void AES_Setup(AES* InstancePtr, Mode mode, ChainingMode chainMode, u32 enabled, GCMPhase gcmPhase)
{
	// TODO Kann ich lesen hier vermeiden und gleich mit cr = 0 anfangen?
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);

    // Set mode
    setBits(&cr, (u32)mode, MODE_POS, MODE_LEN);
    // Set chaining mode: Set bit 5 and 6
    setBits(&cr, (u32)chainMode & 0x3, CHAIN_MODE_POS, CHAIN_MODE_LEN);
    // Set chaining mode: Set bit 16
    //setBits(&cr, (u32)chainMode >> 2, CHAIN_MODE_POS2, CHAIN_MODE_LEN2);
    // Set GCMPhase
    setBits(&cr, (u32)gcmPhase, GCM_PHASE_POS, GCM_PHASE_LEN);
    // Set enabled
    setBits(&cr, enabled, EN_POS, EN_LEN);

    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
}


void AES_SetMode(AES *InstancePtr, Mode mode)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
    setBits(&cr, (u32)mode, MODE_POS, MODE_LEN);
    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
}


void AES_SetChainingMode(AES* InstancePtr, ChainingMode chainMode)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
    // Set bit 5 and 6
    setBits(&cr, (u32)chainMode & 0x3, CHAIN_MODE_POS, CHAIN_MODE_LEN);
    // Set bit 16
    //setBits(&cr, (u32)chainMode >> 2, CHAIN_MODE_POS2, CHAIN_MODE_LEN2);
    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
}

void AES_SetGCMPhase(AES* InstancePtr, GCMPhase gcmPhase)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
    setBits(&cr, (u32)gcmPhase, GCM_PHASE_POS, GCM_PHASE_LEN);

    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
}

void AES_SetEnabled(AES* InstancePtr, u32 en)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
    setBits(&cr, en, EN_POS, EN_LEN);
    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
}

void AES_SetInterruptEnabled(AES* InstancePtr, u32 en)
{
	u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
    setBits(&cr, en, CCFIE_POS, CCFIE_LEN);
	setBits(&cr, en, ERRIE_POS, ERRIE_LEN);
    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
}


void AES_GetSusp(AES* InstancePtr, u8 outSusp[BLOCK_SIZE*2])
{
	for (u32 i = 0; i < BLOCK_SIZE*2; i+=4)
		*(u32*)(outSusp+i) = AES_Read(InstancePtr, AES_SUSPR0_OFFSET+i);
}

void AES_GetKey(AES *InstancePtr, u8 outKey[BLOCK_SIZE])
{
   for (int i = 0; i < BLOCK_SIZE; i+=4)
        *(u32*)(outKey+i) = AES_Read(InstancePtr, AES_KEYR0_OFFSET+i);
}

Mode AES_GetMode(AES *InstancePtr)
{
    return (Mode)getBits(AES_Read(InstancePtr, AES_CR_OFFSET), MODE_POS, MODE_LEN);
}

ChainingMode AES_GetChainingMode(AES* InstancePtr)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
	// read bit 5 and 6
	u32 chMode = getBits(cr, CHAIN_MODE_POS, CHAIN_MODE_LEN);
	// read bit 16
	//chMode |= getBits(cr, CHAIN_MODE_POS2, CHAIN_MODE_LEN2) << CHAIN_MODE_LEN;
    return (ChainingMode)chMode;
}

GCMPhase AES_GetGCMPhase(AES* InstancePtr)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
    return (GCMPhase)getBits(cr, GCM_PHASE_POS, GCM_PHASE_LEN);
}

u32 AES_GetEnabled(AES* InstancePtr)
{
	return getBits(AES_Read(InstancePtr, AES_CR_OFFSET), EN_POS, EN_LEN);
}





void AES_PerformKeyExpansion(AES *InstancePtr)
{
	Mode prevMode = AES_GetMode(InstancePtr);
	AES_SetMode(InstancePtr, MODE_KEYEXPANSION);
	AES_SetEnabled(InstancePtr, 1);
	AES_waitUntilCompleted(InstancePtr);
	AES_SetEnabled(InstancePtr, 0);
	AES_SetMode(InstancePtr, prevMode);
}

void AES_processDataECB(AES* InstancePtr, int encrypt, u8* data, u8* outData, u32 size)
{
	AES_SetupInterrupt(InstancePtr, XScuGic* InterruptCtrlPtr, AES_InterruptHandler interruptHandler)
	AES_startNewComputationECB(InstancePtr, encrypt, data, outData, size);
	AES_waitUntilCompleted(InstancePtr); // TODO Interrupt!
	// Disable the AES Unit when finished TODO necessary?
	AES_SetEnabled(InstancePtr, 0);

}

void AES_startNewComputationECB(AES* InstancePtr, int encrypt, u8* data, u8* outData, u32 size)
{
	AES_SetDataParameters(InstancePtr, data, outData, size);
	// Setup Data and set Enable = 1 to start the encryption
	AES_Setup(InstancePtr, encrypt == 1 ? MODE_ENCRYPTION : MODE_KEYEXPANSION_AND_DECRYPTION, CHAINING_MODE_ECB, 1, GCM_PHASE_INIT);
}

void AES_startNewComputationCBC(AES* InstancePtr, int encrypt, u8* data, u8* outData, u32 size, u8 IV[BLOCK_SIZE])
{
	AES_SetIV(InstancePtr, IV, BLOCK_SIZE);
	AES_SetDataParameters(InstancePtr, data, outData, size);
	// Setup Control and set Enable = 1 to start the encryption
	AES_Setup(InstancePtr, encrypt == 1 ? MODE_ENCRYPTION : MODE_KEYEXPANSION_AND_DECRYPTION, CHAINING_MODE_CBC, 1, GCM_PHASE_INIT);
}

void AES_startNewComputationCTR(AES* InstancePtr, u8* data, u8* outData, u32 size, u8 IV[12])
{
	AES_SetIV(InstancePtr, IV, 12);
	// Write last word of the IV manually
	AES_Write(InstancePtr, AES_IVR0_OFFSET+12, MODE_CTR_IV_INIT);
	AES_SetDataParameters(InstancePtr, data, outData, size);
	// Setup Control and set Enable = 1 to start the encryption
	AES_Setup(InstancePtr, MODE_ENCRYPTION, CHAINING_MODE_CTR, 1, GCM_PHASE_INIT);
}

void AES_startNewComputationGCM(AES* InstancePtr, int encrypt, u8* header, u32 headerLen, u8* payload, u8* outProcessedPayload, u32 payloadLen, u8 IV[12])
{
	AES_SetIV(InstancePtr, IV, 12);
	// Write last word of the IV manually
	AES_Write(InstancePtr, AES_IVR0_OFFSET+12, MODE_GCM_IV_INIT);
	// Start Init phase
	AES_Setup(InstancePtr, MODE_ENCRYPTION, CHAINING_MODE_GCM, 1, GCM_PHASE_INIT);
	AES_waitUntilCompleted(InstancePtr);
	AES_SetEnabled(InstancePtr, 0);  // TODO necessary?
	
	// Process Header
	AES_Write(InstancePtr, AES_DINR_ADDR_OFFSET, (u32)header);
	AES_Write(InstancePtr, AES_DATASIZE_OFFSET, headerLen);
	// enable with Phase Header
	AES_Setup(InstancePtr, MODE_ENCRYPTION, CHAINING_MODE_GCM, 1, GCM_PHASE_HEADER);
	AES_waitUntilCompleted(InstancePtr);
	AES_SetEnabled(InstancePtr, 0);  // TODO necessary?
	
	// Process Payload
	AES_SetDataParameters(InstancePtr, payload ,outProcessedPayload, payloadLen);
	// enable with Phase Payload
	AES_Setup(InstancePtr, encrypt == 1 ? MODE_ENCRYPTION : MODE_DECRYPTION, CHAINING_MODE_GCM, 1, GCM_PHASE_PAYLOAD);
}

void AES_calculateTagGCM(AES* InstancePtr, u32 headerLen, u32 payloadLen, u8 IV[12], u8 outTag[BLOCK_SIZE])
{
	AES_SetGCMPhase(InstancePtr, GCM_PHASE_FINAL);
	// Set the IV in the final round:  First 12 bytes are the Nonce, last 4 bytes are 0x000000001
    AES_SetIV(InstancePtr, IV, 12); // TODO remove: This should not be necessary, as the counter is only 32 bits
	// Write last word of the IV manually
	AES_Write(InstancePtr, AES_IVR0_OFFSET+12, MODE_GCM_IV_FINAL);
	// Use headerLen (64 bit) ||  payloadLen(64 bit) as data block in final round
	u8 finalData[BLOCK_SIZE];
	*(u32*)finalData = 0;
	*(u32*)(finalData+4) = headerLen*8;
	*(u32*)(finalData+8) = 0;
	*(u32*)(finalData+12) = payloadLen*8;

	AES_SetDataParameters(InstancePtr, finalData, outTag, BLOCK_SIZE);
	AES_SetEnabled(InstancePtr, 1);
	AES_waitUntilCompleted(InstancePtr);
}


void AES_SetDataParameters(AES* InstancePtr, u8* source, u8* dest, u32 size)
{
	AES_Write(InstancePtr, AES_DINR_ADDR_OFFSET, (u32)source);
	AES_Write(InstancePtr, AES_DOUTR_ADDR_OFFSET, (u32)dest);
	AES_Write(InstancePtr, AES_DATASIZE_OFFSET, size);
}

void AES_processDataCBC(AES* InstancePtr, int encrypt, u8* data, u8* outData, u32 size, u8 IV[BLOCK_SIZE])
{
	AES_startNewComputationCBC(InstancePtr, encrypt, data, outData, size, IV);
	AES_waitUntilCompleted(InstancePtr); // TODO Interrupt!
}

void AES_processDataCTR(AES* InstancePtr,  u8* data, u8* outData, u32 size, u8 IV[12])
{
	AES_startNewComputationCTR(InstancePtr, data, outData, size, IV);
	AES_waitUntilCompleted(InstancePtr); // TODO Interrupt!
}

void AES_processDataGCM(AES* InstancePtr, int encrypt, u8* header, u32 headerLen, u8* payload, u8* outProcessedPayload, u32 payloadLen, u8 IV[12], u8 outTag[BLOCK_SIZE])
{
	AES_startNewComputationGCM(InstancePtr, encrypt, header, headerLen, payload, outProcessedPayload, payloadLen, IV);
	AES_waitUntilCompleted(InstancePtr); // TODO Interrupt!
	// Final
	AES_calculateTagGCM(InstancePtr, headerLen, payloadLen, IV, u8 outTag);
}

int AES_compareTags(u8 tag1[BLOCK_SIZE], u8 tag2[BLOCK_SIZE])
{
	for (u32 i = 0; i < BLOCK_SIZE; i += 4)
	{
	    // Compare four bytes at once by casting to u32
		if (*(u32*)(tag1+i) != *(u32*)(tag2+i))
			return -1;
	}
	return 0;
}


void AES_clearCompletedStatus(AES* InstancePtr)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
    setBits(&cr, 1, CCFC_POS, CCFC_LEN);
    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
    setBits(&cr, 0, CCFC_POS, CCFC_LEN);
    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
}

void AES_waitUntilCompleted(AES* InstancePtr)
{
	while (AES_isComputationCompleted(InstancePtr) == 0)
		;
}

int AES_isComputationCompleted(AES* InstancePtr)
{
	return getBits(AES_Read(InstancePtr, AES_SR_OFFSET), SR_CCF_POS, SR_CCF_LEN);
}




s32 AES_SetupInterrupt(AES* InstancePtr, XScuGic* InterruptCtrlPtr, AES_InterruptHandler interruptHandler)
{
	s32 status = XST_SUCCESS;

	// Set the priority of the interrupt to 0xA0 (highest 0xF8, lowest 0x00) and a trigger for a rising edge 0x3
	XScuGic_SetPriorityTriggerType(InterruptCtrlPtr, XPAR_FABRIC_CONTROLLOGIC_0_INTERRUPT_INTR, 0xA0, 0x3);
	// Connect a device driver handler that will be called when an interrupt for the device occurs
	// the device driver handler performs the specific interrupt processing for the device
	status |= XScuGic_Connect(InterruptCtrlPtr, XPAR_FABRIC_CONTROLLOGIC_0_INTERRUPT_INTR, (Xil_ExceptionHandler)interruptHandler, InstancePtr);
	// Enable the interrupt for the ControlLogic peripheral
	XScuGic_Enable(InterruptCtrlPtr, XPAR_FABRIC_CONTROLLOGIC_0_INTERRUPT_INTR);

	AES_SetInterruptEnabled(InstancePtr, 1);
	return status;
}




// -------------
// private functions
// --------------
inline u32 getBits(u32 val, u32 lowestBitIndex, u32 bitLen)
{
	u32 highBits = (1 << bitLen) - 1; // has bitLen ones, e.g. 0b00000111 for bitLen=3
	return (val >> lowestBitIndex) & highBits;
}

// Sets the bits at lowestBitIndex to lowestBitIndex+bitLen-1 to bits.
inline void setBits(u32* ptr, u32 bits, u32 lowestBitIndex, u32 bitLen)
{
	u32 highBits = (1 << bitLen) - 1; // has bitLen ones, e.g. 0b00000111 for bitLen=3
	// Clear bits
	u32 clearMask = ~(highBits << lowestBitIndex);
	*ptr &= clearMask;
	// Set the bits
	*ptr |= (bits & highBits) << lowestBitIndex;
}

void waitUntilInterrupt()
{
	while (interruptCalled == 0)
		;
	interruptCalled = 0;
}
void interruptRoutine(AES* InstancePtr)
{
	interruptCalled = 1;
}

