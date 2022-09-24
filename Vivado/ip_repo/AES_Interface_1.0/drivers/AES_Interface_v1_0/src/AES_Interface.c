

/***************************** Include Files *******************************/
#include "AES_Interface.h"
#include "xparameters.h"
/************************** Function Definitions ***************************/

// Comment this line on Big Endian systems
#define LITTLE_ENDIAN


#define AES_CR_OFFSET 0x00
#define AES_SR_OFFSET 0x04
#define AES_DINR_OFFSET 0x08
#define AES_DOUTR_OFFSET 0x0c
#define AES_KEYR0_OFFSET 0x10
#define AES_IVR0_OFFSET 0x20
#define AES_SUSPR0_OFFSET 0x40

// Position definitions in the Control Register CR
#ifdef LITTLE_ENDIAN
#define EN_POS 24
#define MODE_POS 27
#define CHAIN_MODE_POS1 29
#define CHAIN_MODE_POS2 8
#define GCM_PHASE_POS 13
#else // Normal, Big Endian Positions of the bits
#define EN_POS 0
#define MODE_POS 3
#define CHAIN_MODE_POS1 5
#define CHAIN_MODE_POS2 16
#define GCM_PHASE_POS 21
#endif

#define EN_LEN 1
#define MODE_LEN 2
#define CHAIN_MODE_LEN1 2
#define CHAIN_MODE_LEN2 1
#define GCM_PHASE_LEN 2


/*************************** Private Function declarations **********************/
u32 getBits(u32 val, u32 lowestBitIndex, u32 bitLen);
void setBits(u32* ptr, u32 bits, u32 lowestBitIndex, u32 bitLen);

/*************************** Function definitions **********************/
AES_Config config =
{
		XPAR_AES_INTERFACE_0_DEVICE_ID,
		XPAR_AES_INTERFACE_0_S_AXI_BASEADDR
};


AES_Config *AES_LookupConfig(u16 DeviceId)
{
	if (DeviceId == config.DeviceId)
		return &config;
	else
		return (void*)0;
}

int AES_Initialize(AES *InstancePtr, UINTPTR BaseAddr)
{
    InstancePtr->BaseAddress = BaseAddr;
    return (XST_SUCCESS);
}

void AES_SetKey(AES *InstancePtr, u8 key[BLOCK_SIZE])
{
   for (int i = 0; i < 4; i++)
        AES_Write(InstancePtr, AES_KEYR0_OFFSET+i*4, *(u32*)(key+i*4));
}

void AES_Setup(AES* InstancePtr, Mode mode, ChainingMode chainMode, u32 enabled, GCMPhase gcmPhase)
{
	// TODO Kann ich lesen hier vermeiden und gleich mit cr = 0 anfangen?
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);

    // Set mode
    setBits(&cr, (u32)mode, MODE_POS, MODE_LEN);
    // Set chaining mode: Set bit 5 and 6
    setBits(&cr, (u32)chainMode & 0x3, CHAIN_MODE_POS1, CHAIN_MODE_LEN1);
    // Set chaining mode: Set bit 16
    setBits(&cr, (u32)chainMode >> 2, CHAIN_MODE_POS2, CHAIN_MODE_LEN2);
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
    setBits(&cr, (u32)chainMode & 0x3, CHAIN_MODE_POS1, CHAIN_MODE_LEN1);
    // Set bit 16
    setBits(&cr, (u32)chainMode >> 2, CHAIN_MODE_POS2, CHAIN_MODE_LEN2);
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


void AES_GetKey(AES *InstancePtr, u8 outKey[BLOCK_SIZE])
{
   for (int i = 0; i < 4; i++)
        *(u32*)(outKey+i*4) = AES_Read(InstancePtr, AES_KEYR0_OFFSET+i*4);
}
Mode AES_GetMode(AES *InstancePtr)
{
    return (Mode)getBits(AES_Read(InstancePtr, AES_CR_OFFSET), MODE_POS, MODE_LEN);
}

ChainingMode AES_GetChainingMode(AES* InstancePtr)
{
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
	// read bit 5 and 6
	u32 chMode = getBits(cr, CHAIN_MODE_POS1, CHAIN_MODE_LEN1);
	// read bit 16
	chMode |= getBits(cr, CHAIN_MODE_POS2, CHAIN_MODE_LEN2) << CHAIN_MODE_LEN1;
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

void AES_processData(AES* InstancePtr, Mode mode, ChainingMode chMode, u8* data, u8* outData, u32 size)
{
	AES_Setup(InstancePtr, mode, chMode, 1, GCM_PHASE_INIT);
	for (u32 blockOffset = 0; blockOffset < size; blockOffset += BLOCK_SIZE)
	{
		AES_processBlock(InstancePtr, data+blockOffset, outData+blockOffset);
	}
	// Disable the AES Unit when finished
	AES_SetEnabled(InstancePtr, 0);
}


void AES_processBlock(AES* InstancePtr, u8 *dataBlock, u8 *outDataBlock)
{
	// Write four times to DIN
    for (u32 i = 0; i < 4; i++)
		AES_Write(InstancePtr, AES_DINR_OFFSET, *(u32*)(dataBlock+i*4));
    // Wait until computation has completed
    AES_waitUntilCompleted(InstancePtr);
    // Read DOUT for times
    for (u32 i = 0; i < 4; i++)
    	*(u32*)(outDataBlock+i*4) = AES_Read(InstancePtr, AES_DOUTR_OFFSET);
}


void AES_waitUntilCompleted(AES* InstancePtr)
{
	u32 CCF;
	do {
		CCF = getBits(AES_Read(InstancePtr, AES_SR_OFFSET), 0, 1);
	} while (CCF == 0);
	// Clear CCF bit
    u32 cr = AES_Read(InstancePtr, AES_CR_OFFSET);
    setBits(&cr, 1, 7, 1);
    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
    // TODO need to reset CCFC manually?
    setBits(&cr, 0, 7, 1);
    AES_Write(InstancePtr, AES_CR_OFFSET, cr);
}

// -------------
// private functions
// --------------
u32 getBits(u32 val, u32 lowestBitIndex, u32 bitLen)
{
	u32 highBits = (1 << bitLen) - 1; // has bitLen ones, e.g. 0b00000111 for bitLen=3
	return (val >> lowestBitIndex) & highBits;
}

// Sets the bits at lowestBitIndex to lowestBitIndex+bitLen-1 to bits.
void setBits(u32* ptr, u32 bits, u32 lowestBitIndex, u32 bitLen)
{
	u32 highBits = (1 << bitLen) - 1; // has bitLen ones, e.g. 0b00000111 for bitLen=3
	// Set bits to 1
	*ptr |= highBits << lowestBitIndex;
	// At that spot, clear the bits that are 0
	*ptr &= (bits & highBits) << lowestBitIndex;
}
