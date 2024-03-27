/***************************** Include Files *******************************/
#include "AES_Unit.h"
#include "AES_Unit_hw.h"

// Xilinx file for making assertions
#include "xil_assert.h" // Comment out if file not found
#ifdef Xil_AssertVoid
#define AssertVoid(cond) Xil_AssertVoid(cond)
#else
#define AssertVoid(cond) {if (!(cond))return;}
#endif

#ifndef NULL
#define NULL ((void*)0)
#endif

/************************** Function Definitions ***************************/



/**************************   Private variables **********************/
// Parameter file that should contain the constants in the config;
// Comment it out if it does not exist
//#include "xparameters.h"

AES_Config config =
{
	0, // if this constant is not automatically generated, set it manually (e.g. to 0)
	0xA0000000, // set this constant to the base address of the AES Unit in your design
	AES_NUM_CHANNELS
};

/*************************** Private Function declarations **********************/
uint32_t getBits(uint32_t val, uint32_t lowestBitIndex, uint32_t bitLen);
void setBits(uint32_t* ptr, uint32_t bits, uint32_t lowestBitIndex, uint32_t bitLen);

/*************************** Function definitions **********************/

AES_Config *AES_LookupConfig(uint16_t DeviceId)
{
	if (DeviceId == config.DeviceId)
		return &config;
	else
		return NULL;
}

int32_t AES_CfgInitialize(AES *InstancePtr, const AES_Config *ConfigPtr)
{
    InstancePtr->BaseAddress = ConfigPtr->BaseAddress;
	for (uint32_t i = 0; i < AES_NUM_CHANNELS; i++)
	{
		InstancePtr->CallbackFn[i] = NULL;
		InstancePtr->CallbackRef[i] = NULL;
	}
    return 0;
}


void AES_SetKey(AES *InstancePtr, uint32_t channel, char key[BLOCK_SIZE])
{
   for (uint32_t i = 0; i < BLOCK_SIZE; i+=4)
        AES_Write(InstancePtr, channel, AES_KEYR0_OFFSET+i, *(uint32_t*)(key+i));
}

void AES_SetIV(AES* InstancePtr, uint32_t channel, void *IV, uint32_t IVLen) // TODO somehow no IVLen?
{
	for (uint32_t i = 0; i < IVLen; i+=4)
		AES_Write(InstancePtr, channel, AES_IVR0_OFFSET+i, *(uint32_t*)(IV+i));
}

void AES_SetSusp(AES* InstancePtr, uint32_t channel, char Susp[BLOCK_SIZE*2])
{
	for (uint32_t i = 0; i < BLOCK_SIZE*2; i+=4)
		AES_Write(InstancePtr, channel, AES_SUSPR0_OFFSET+i, *(uint32_t*)(Susp+i));
}

/**
 * @brief Set multiple configuration parameters at once
 * 
 * @param InstancePtr 
 * @param mode 
 * @param chainMode 
 * @param enabled 
 * @param gcmPhase 
 */
void AES_Setup(AES* InstancePtr, uint32_t channel, Mode mode, ChainingMode chainMode, uint32_t enabled, GCMPhase gcmPhase)
{  
	// Need to read old cr to not overwrite other configuration data like the priority
    uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);

    // Set mode
    setBits(&cr, (uint32_t)mode, MODE_POS, MODE_LEN);
    // Set chaining mode: Set bit 5 and 6
    setBits(&cr, (uint32_t)chainMode & 0x3, CHAIN_MODE_POS, CHAIN_MODE_LEN);
    // Set chaining mode: Set bit 16
    //setBits(&cr, (uint32_t)chainMode >> 2, CHAIN_MODE_POS2, CHAIN_MODE_LEN2);
    // Set GCMPhase
    setBits(&cr, (uint32_t)gcmPhase, GCM_PHASE_POS, GCM_PHASE_LEN);
    // Set enabled
    setBits(&cr, enabled, EN_POS, EN_LEN);

    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}


void AES_SetMode(AES *InstancePtr, uint32_t channel, Mode mode)
{
    uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, (uint32_t)mode, MODE_POS, MODE_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}


void AES_SetChainingMode(AES* InstancePtr, uint32_t channel, ChainingMode chainMode)
{
    uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    // Set bit 5 and 6
    setBits(&cr, (uint32_t)chainMode & 0x3, CHAIN_MODE_POS, CHAIN_MODE_LEN);
    // Set bit 16; would only be necessary if chainMode could be >= 4
    //setBits(&cr, (uint32_t)chainMode >> 2, CHAIN_MODE_POS2, CHAIN_MODE_LEN2);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}

void AES_SetGCMPhase(AES* InstancePtr, uint32_t channel, GCMPhase gcmPhase)
{
    uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, (uint32_t)gcmPhase, GCM_PHASE_POS, GCM_PHASE_LEN);

    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}

void AES_SetPriority(AES* InstancePtr, uint32_t channel, uint32_t priority)
{
	AssertVoid(priority <= AES_MAX_PRIORITY);
	uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, priority, PRIORITY_POS, PRIORITY_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}
/**
 * @brief Enable or disable interrupts
 * 
 * @param InstancePtr 
 * @param en 1 for enabling, 0 for disabling interrupts
 */
void AES_SetInterruptEnabled(AES* InstancePtr, uint32_t channel, uint32_t en)
{
	uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, en, CCFIE_POS, CCFIE_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}

void AES_SetInterruptCallback(AES* InstancePtr, uint32_t channel, AES_CallbackFn callbackFn, void* callbackRef)
{
	InstancePtr->CallbackFn[channel] = callbackFn;
	InstancePtr->CallbackRef[channel] = callbackRef;
}


/**
 * @brief Enables the AES Unit so it starts its calculation according to the configuration
 * 
 * @param InstancePtr 
 */
void AES_startComputation(AES* InstancePtr, uint32_t channel)
{
    uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, 1, EN_POS, EN_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}




#if !AES_REG_KEY_WRITEONLY
/**
 * @brief Get the susp register content, which holds intermediate results for the GCM calculation
 * 
 * @param InstancePtr 
 * @param outSusp 
 */
void AES_GetSusp(AES* InstancePtr, uint32_t channel, char outSusp[32])
{
	for (uint32_t i = 0; i < BLOCK_SIZE*2; i+=4)
		*(uint32_t*)(outSusp+i) = AES_Read(InstancePtr, channel, AES_SUSPR0_OFFSET+i);
}

void AES_GetIV(AES* InstancePtr, uint32_t channel, char outIV[BLOCK_SIZE])
{
	for (uint32_t i = 0; i < BLOCK_SIZE; i+=4)
		*(uint32_t*)(outIV+i) = AES_Read(InstancePtr, channel, AES_IVR0_OFFSET+i);
}

void AES_GetKey(AES *InstancePtr, uint32_t channel, char outKey[BLOCK_SIZE])
{
   for (int i = 0; i < BLOCK_SIZE; i+=4)
        *(uint32_t*)(outKey+i) = AES_Read(InstancePtr, channel, AES_KEYR0_OFFSET+i);
}
#endif

Mode AES_GetMode(AES *InstancePtr, uint32_t channel)
{
    return (Mode)getBits(AES_Read(InstancePtr, channel, AES_CR_OFFSET), MODE_POS, MODE_LEN);
}

ChainingMode AES_GetChainingMode(AES* InstancePtr, uint32_t channel)
{
    uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
	// read bit 5 and 6
	uint32_t chMode = getBits(cr, CHAIN_MODE_POS, CHAIN_MODE_LEN);
	// read bit 16
	//chMode |= getBits(cr, CHAIN_MODE_POS2, CHAIN_MODE_LEN2) << CHAIN_MODE_LEN;
    return (ChainingMode)chMode;
}

GCMPhase AES_GetGCMPhase(AES* InstancePtr, uint32_t channel)
{
    uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    return (GCMPhase)getBits(cr, GCM_PHASE_POS, GCM_PHASE_LEN);
}

uint32_t AES_GetPriority(AES* InstancePtr, uint32_t channel)
{
    uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    return getBits(cr, PRIORITY_POS, PRIORITY_LEN);
}

uint32_t AES_GetInterruptEnabled(AES* InstancePtr, uint32_t channel)
{
	uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    return getBits(cr, CCFIE_POS, CCFIE_LEN);
}

/**
 * @brief Whether the AES unit has a pending computation job for this channel
 * 
 * @param InstancePtr 
 * @return uint32_t 1 when active, 0 when inactive
 */
uint32_t AES_isActive(AES* InstancePtr, uint32_t channel)
{
	return getBits(AES_Read(InstancePtr, channel, AES_CR_OFFSET), EN_POS, EN_LEN);
}


void AES_PerformKeyExpansion(AES *InstancePtr, uint32_t channel)
{
	Mode prevMode = AES_GetMode(InstancePtr, channel);
	AES_SetMode(InstancePtr, channel, MODE_KEYEXPANSION);
	AES_startComputation(InstancePtr, channel);
	AES_waitUntilCompleted(InstancePtr, channel);
	AES_SetMode(InstancePtr, channel, prevMode);
}

/*
 * Start the Computation in Chaining mode chmode. 
 * @param chmode   The chaining mode. Only ECB, CBC and CTR are supported
 * @param IV       The initialization vector. In ECB, it is ignored, in CTR mode, the last 4 bytes are ignored
*/
void AES_startComputationMode(AES* InstancePtr, uint32_t channel, ChainingMode chmode, int encrypt, void* data, void* outData, uint32_t size,
	 char IV[BLOCK_SIZE], AES_CallbackFn callbackFn, void* callbackRef)
{
	AssertVoid(chmode != CHAINING_MODE_GCM);

	InstancePtr->CallbackFn[channel] = callbackFn;
	InstancePtr->CallbackRef[channel] = callbackRef;

	if (chmode == CHAINING_MODE_CBC)
	{
		AES_SetIV(InstancePtr, channel, IV, BLOCK_SIZE);
	}
	else if (chmode == CHAINING_MODE_CTR)
	{
		AES_SetIV(InstancePtr, channel, IV, 12);
		// Write last word of the IV manually
		AES_Write(InstancePtr, channel, AES_IVR0_OFFSET+12, MODE_CTR_IV_INIT);
	}
	
	AES_SetDataParameters(InstancePtr, channel, data, outData, size);
	AES_Setup(InstancePtr, channel, encrypt == 1 ? MODE_ENCRYPTION : MODE_DECRYPTION, chmode, 1, GCM_PHASE_INIT);
}


void AES_startComputationECB(AES* InstancePtr, uint32_t channel, int encrypt, void* data, void* outData, uint32_t size,
 	AES_CallbackFn callbackFn, void* callbackRef)
{	
	InstancePtr->CallbackFn[channel] = callbackFn;
	InstancePtr->CallbackRef[channel] = callbackRef;
	
	AES_SetDataParameters(InstancePtr, channel, data, outData, size);
	// Setup Data and set Enable = 1 to start the encryption/decryption
	AES_Setup(InstancePtr, channel, encrypt == 1 ? MODE_ENCRYPTION : MODE_DECRYPTION, CHAINING_MODE_ECB, 1, GCM_PHASE_INIT);
}

void AES_startComputationCBC(AES* InstancePtr, uint32_t channel, int encrypt, void* data, void* outData, uint32_t size,
	 char IV[BLOCK_SIZE], AES_CallbackFn callbackFn, void* callbackRef)
{
	InstancePtr->CallbackFn[channel] = callbackFn;
	InstancePtr->CallbackRef[channel] = callbackRef;
	
	AES_SetIV(InstancePtr, channel, IV, BLOCK_SIZE);
	AES_SetDataParameters(InstancePtr, channel, data, outData, size);
	// Setup Control and set Enable = 1 to start the encryption/decryption
	AES_Setup(InstancePtr, channel, encrypt == 1 ? MODE_ENCRYPTION : MODE_DECRYPTION, CHAINING_MODE_CBC, 1, GCM_PHASE_INIT);
}

/*
 * Chaining mode CTR.  As encryption and decryption are the same operation, this function doesnt have an encrypt parameter
*/
void AES_startComputationCTR(AES* InstancePtr, uint32_t channel, void* data, void* outData, uint32_t size,
	 char IV[BLOCK_SIZE-4], AES_CallbackFn callbackFn, void* callbackRef)
{
	InstancePtr->CallbackFn[channel] = callbackFn;
	InstancePtr->CallbackRef[channel] = callbackRef;

	AES_SetIV(InstancePtr, channel, IV, 12);
	// Write last word of the IV manually
	AES_Write(InstancePtr, channel, AES_IVR0_OFFSET+12, MODE_CTR_IV_INIT);
	AES_SetDataParameters(InstancePtr, channel, data, outData, size);
	// Setup Control and set Enable = 1 to start the encryption/decryption
	AES_Setup(InstancePtr, channel, MODE_ENCRYPTION, CHAINING_MODE_CTR, 1, GCM_PHASE_INIT);
}

void AES_startComputationGCM(AES* InstancePtr, uint32_t channel, int encrypt, void* header, uint32_t headerLen,
	 void* payload, void* outProcessedPayload, uint32_t payloadLen, char IV[12], AES_CallbackFn callbackFn, void* callbackRef)
{
	AES_SetIV(InstancePtr, channel, IV, 12);
	// Write last word of the IV manually
	AES_Write(InstancePtr, channel, AES_IVR0_OFFSET+12, MODE_GCM_IV_INIT);
	// Start Init phase
	AES_Setup(InstancePtr, channel, MODE_ENCRYPTION, CHAINING_MODE_GCM, 1, GCM_PHASE_INIT);
	// Process Header
	if (headerLen > 0)
	{
		// wait until Init Phase is complete
		AES_waitUntilCompleted(InstancePtr, channel);
		// If there's no payload phase, register callbacks now so they're called after the header phase
		if (payloadLen == 0) {
			InstancePtr->CallbackFn[channel] = callbackFn;
			InstancePtr->CallbackRef[channel] = callbackRef;
		}
		AES_SetDataParameters(InstancePtr, channel, header, NULL, headerLen);
		// enable with Phase Header
		AES_Setup(InstancePtr, channel, MODE_ENCRYPTION, CHAINING_MODE_GCM, 1, GCM_PHASE_HEADER);
	}
	// Process Payload
	if (payloadLen > 0)
	{
		// wait until Init / Header Phase is complete
		AES_waitUntilCompleted(InstancePtr, channel);
		// Register callbacks
		InstancePtr->CallbackFn[channel] = callbackFn;
		InstancePtr->CallbackRef[channel] = callbackRef;

		AES_SetDataParameters(InstancePtr, channel, payload, outProcessedPayload, payloadLen);
		// enable with Phase Payload
		AES_Setup(InstancePtr, channel, encrypt == 1 ? MODE_ENCRYPTION : MODE_DECRYPTION, CHAINING_MODE_GCM, 1, GCM_PHASE_PAYLOAD);
	}
}

uint32_t prvEndianSwap32(uint32_t i) {
	uint32_t x = (i & 0xff) << 24;
	x |= (i & 0xff00) << 8;
	x |= (i & 0xff0000) >> 8;
	x |= (i & 0xff000000) >> 24;
	return x;
}

void AES_calculateTagGCM(AES* InstancePtr, uint32_t channel, uint32_t headerLen, uint32_t payloadLen, char outTag[BLOCK_SIZE])
{
	AES_SetGCMPhase(InstancePtr, channel, GCM_PHASE_FINAL);
	// Set the IV in the final round:  First 12 bytes are the Nonce, last 4 bytes are 0x000000001
	// No need to write the Nonce again, as it is already there from the payload phase: Only need to write last word
	AES_Write(InstancePtr, channel, AES_IVR0_OFFSET+12, MODE_GCM_IV_FINAL);

	// Use headerLen (64 bit) ||  payloadLen(64 bit) as data block in final round
	char finalData[BLOCK_SIZE];
	*(uint32_t*)finalData = 0;
	*(uint32_t*)(finalData+8) = 0;
#if AES_BYTE_ORDER == LITTLE_ENDIAN
	*(uint32_t*)(finalData+4) = prvEndianSwap32(headerLen*8);
	*(uint32_t*)(finalData+12) = prvEndianSwap32(payloadLen*8);
#else
	*(uint32_t*)(finalData+4) = headerLen*8;
	*(uint32_t*)(finalData+12) = payloadLen*8;
#endif
	AES_SetDataParameters(InstancePtr, channel, finalData, outTag, BLOCK_SIZE);
	AES_startComputation(InstancePtr, channel);
	AES_waitUntilCompleted(InstancePtr, channel);
}


void AES_SetDataParameters(AES* InstancePtr, uint32_t channel, void* source, void* dest, uint32_t size)
{
	AES_Write(InstancePtr, channel, AES_DINR_ADDR_OFFSET, (uintptr_t)source);
	AES_Write(InstancePtr, channel, AES_DOUTR_ADDR_OFFSET, (uintptr_t)dest);
	AES_Write(InstancePtr, channel, AES_DATASIZE_OFFSET, size);
}

void AES_processDataECB(AES* InstancePtr, uint32_t channel, int encrypt, void* data, void* outData, uint32_t size)
{
	AES_startComputationECB(InstancePtr, channel, encrypt, data, outData, size, NULL, NULL);
	AES_waitUntilCompleted(InstancePtr, channel);
}

void AES_processDataCBC(AES* InstancePtr, uint32_t channel, int encrypt, void* data, void* outData, uint32_t size, char IV[BLOCK_SIZE])
{
	AES_startComputationCBC(InstancePtr, channel, encrypt, data, outData, size, IV, NULL, NULL);
	AES_waitUntilCompleted(InstancePtr, channel);
}

void AES_processDataCTR(AES* InstancePtr, uint32_t channel, void* data, void* outData, uint32_t size, char IV[BLOCK_SIZE-4])
{
	AES_startComputationCTR(InstancePtr, channel, data, outData, size, IV, NULL, NULL);
	AES_waitUntilCompleted(InstancePtr, channel); 
}

void AES_processDataGCM(AES* InstancePtr, uint32_t channel, int encrypt, void* header, uint32_t headerLen, 
	void* payload, void* outProcessedPayload, uint32_t payloadLen, char IV[12], char outTag[BLOCK_SIZE])
{
	AES_startComputationGCM(InstancePtr, channel, encrypt, header, headerLen, payload, outProcessedPayload, payloadLen, IV, NULL, NULL);
	AES_waitUntilCompleted(InstancePtr, channel);
	AES_calculateTagGCM(InstancePtr, channel, headerLen, payloadLen, outTag);
}

int AES_compareTags(char tag1[BLOCK_SIZE], char tag2[BLOCK_SIZE])
{
	for (uint32_t i = 0; i < BLOCK_SIZE; i += 4)
	{
	    // Compare four bytes at once by casting to uint32_t
		if (*(uint32_t*)(tag1+i) != *(uint32_t*)(tag2+i))
			return -1;
	}
	return 0;
}

/**
 * @brief clears the CCF flag, which indicates that the computation has completed.
 *  This should usually not be necessary, as the flag is cleared automatically when a new computation starts
 * @param InstancePtr 
 * @param channel 
 */
void AES_clearCompletedStatus(AES* InstancePtr, uint32_t channel)
{
    uint32_t cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, 1, CCFC_POS, CCFC_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
    setBits(&cr, 0, CCFC_POS, CCFC_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}

void AES_waitUntilCompleted(AES* InstancePtr, uint32_t channel)
{
	while (AES_isComputationCompleted(InstancePtr, channel) == 0)
		;
}

int AES_isComputationCompleted(AES* InstancePtr, uint32_t channel)
{
	uint32_t CCF = getBits(AES_Read(InstancePtr, channel, AES_SR_OFFSET), SR_CCF_POS, SR_CCF_LEN);
	return  (CCF & (1 << (channel%8))) != 0;
}

/*****************************************************************************/
/**
 * This function gets the error bits in the status.
 *
 * @param	InstancePtr is the driver instance we are working on
 *
 * @return	The error bits of the channel in the status register. 
 * 			The ERROR_WRITE bit indicates a write error, the ERROR_READ bit indicates a read error
 *
 *****************************************************************************/
uint32_t AES_GetError(AES* InstancePtr, uint32_t channel)
{
	uint32_t sr = AES_Read(InstancePtr, channel, AES_SR_OFFSET);
	return getBits(sr, SR_RDERR_POS+(channel%8), 1) * AES_ERROR_READ  |  getBits(sr, SR_WRERR_POS+(channel%8), 1) * AES_ERROR_WRITE;
}


/**
 * This function is the interrupt handler for the driver, it handles all the
 * interrupts. For the completion of a computation that has a callback function,
 * the callback function is called.
 *
 * @param	HandlerRef is a reference pointer passed to the interrupt
 *			registration function. It will be a pointer to the driver
 *			instance we are working on
 *
 * @return	None
 * */
void AES_IntrHandler(void *HandlerRef)
{
    AES* InstancePtr = (AES*)HandlerRef;

	/* Check what interrupts have fired
	 */
    for (int channelIdx = 0; channelIdx < AES_NUM_CHANNELS; channelIdx += 8) {
		uint32_t SR = AES_Read(InstancePtr, channelIdx, AES_SR_OFFSET);
		uint32_t Irq = getBits(SR, SR_IRQ_POS, 8);

		// Clear interrupts by writing the Status register back
		AES_Write(InstancePtr, channelIdx, AES_SR_OFFSET, SR);

		// Call Callback function for each interrupt
		for (int i = 0; i < 8 && i + channelIdx < AES_NUM_CHANNELS; i++)
		{
			if ((Irq & (1 << i)) && InstancePtr->CallbackFn[i+channelIdx])
			{
				(InstancePtr->CallbackFn[i+channelIdx])(InstancePtr->CallbackRef[i+channelIdx]);
				// Set CallbackFn to NULL so it isn't called later unintentionally
				InstancePtr->CallbackFn[i+channelIdx] = NULL;
			}
		}
    }
}






// -------------
// private functions
// --------------
inline uint32_t getBits(uint32_t val, uint32_t lowestBitIndex, uint32_t bitLen)
{
	uint32_t highBits = (1 << bitLen) - 1; // has bitLen ones, e.g. 0b00000111 for bitLen=3
	return (val >> lowestBitIndex) & highBits;
}

// Sets the bits at lowestBitIndex to lowestBitIndex+bitLen-1 to bits.
inline void setBits(uint32_t* ptr, uint32_t bits, uint32_t lowestBitIndex, uint32_t bitLen)
{
	uint32_t highBits = (1 << bitLen) - 1; // has bitLen ones, e.g. 0b00000111 for bitLen=3
	// Clear bits
	uint32_t clearMask = ~(highBits << lowestBitIndex);
	*ptr &= clearMask;
	// Set the bits
	*ptr |= (bits & highBits) << lowestBitIndex;
}
