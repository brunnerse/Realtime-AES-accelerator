

/***************************** Include Files *******************************/
#include "AES_Unit_2.h"
#include "AES_Unit_2_hw.h"
#include "xparameters.h"
#include "xdebug.h"
#include "xil_assert.h"
/************************** Function Definitions ***************************/




/**************************   Private variables **********************/
AES_Config config =
{
		XPAR_AES_UNIT_2_0_DEVICE_ID,
		XPAR_AES_UNIT_2_0_S_AXI_BASEADDR,
		AES_NUM_CHANNELS
};

/*************************** Private Function declarations **********************/
u32 getBits(u32 val, u32 lowestBitIndex, u32 bitLen);
void setBits(u32* ptr, u32 bits, u32 lowestBitIndex, u32 bitLen);

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
	for (u32 i = 0; i < AES_NUM_CHANNELS; i++)
	{
		InstancePtr->CallbackFn[i] = NULL;
		InstancePtr->CallbackRef[i] = NULL;
	}
    return (s32)(XST_SUCCESS);
}


void AES_SetKey(AES *InstancePtr, u32 channel, u8 key[BLOCK_SIZE])
{
   for (u32 i = 0; i < BLOCK_SIZE; i+=4)
        AES_Write(InstancePtr, channel, AES_KEYR0_OFFSET+i, *(u32*)(key+i));
}

void AES_SetIV(AES* InstancePtr, u32 channel, u8 *IV, u32 IVLen)
{
	for (u32 i = 0; i < IVLen; i+=4)
		AES_Write(InstancePtr, channel, AES_IVR0_OFFSET+i, *(u32*)(IV+i));
}

void AES_SetSusp(AES* InstancePtr, u32 channel, u8 Susp[BLOCK_SIZE*2])
{
	for (u32 i = 0; i < BLOCK_SIZE*2; i+=4)
		AES_Write(InstancePtr, channel, AES_SUSPR0_OFFSET+i, *(u32*)(Susp+i));
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
void AES_Setup(AES* InstancePtr, u32 channel, Mode mode, ChainingMode chainMode, u32 enabled, GCMPhase gcmPhase)
{  
	// Need to read old cr to not overwrite other configuration data like the priority
    u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);

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

    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}


void AES_SetMode(AES *InstancePtr, u32 channel, Mode mode)
{
    u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, (u32)mode, MODE_POS, MODE_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}


void AES_SetChainingMode(AES* InstancePtr, u32 channel, ChainingMode chainMode)
{
    u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    // Set bit 5 and 6
    setBits(&cr, (u32)chainMode & 0x3, CHAIN_MODE_POS, CHAIN_MODE_LEN);
    // Set bit 16
    //setBits(&cr, (u32)chainMode >> 2, CHAIN_MODE_POS2, CHAIN_MODE_LEN2);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}

void AES_SetGCMPhase(AES* InstancePtr, u32 channel, GCMPhase gcmPhase)
{
    u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, (u32)gcmPhase, GCM_PHASE_POS, GCM_PHASE_LEN);

    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}

void AES_SetPriority(AES* InstancePtr, u32 channel, u32 priority)
{
	Xil_AssertVoid(priority <= AES_MAX_PRIORITY);
	u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, priority, PRIORITY_POS, PRIORITY_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}
/**
 * @brief Enable or disable interrupts
 * 
 * @param InstancePtr 
 * @param en 1 for enabling, 0 for disabling interrupts
 */
void AES_SetInterruptEnabled(AES* InstancePtr, u32 channel, u32 en)
{
	u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, en, CCFIE_POS, CCFIE_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}

/**
 * @brief Enables the AES Unit so it starts its calculation according to the configuration
 * 
 * @param InstancePtr 
 */
void AES_startComputation(AES* InstancePtr, u32 channel)
{
    u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, 1, EN_POS, EN_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}


/**
 * @brief Get the susp register content, which holds intermediate results for the GCM calculation
 * 
 * @param InstancePtr 
 * @param outSusp 
 */
void AES_GetSusp(AES* InstancePtr, u32 channel, u8 outSusp[BLOCK_SIZE*2])
{
	for (u32 i = 0; i < BLOCK_SIZE*2; i+=4)
		*(u32*)(outSusp+i) = AES_Read(InstancePtr, channel, AES_SUSPR0_OFFSET+i);
}

void AES_GetIV(AES* InstancePtr, u32 channel, u8 outIV[BLOCK_SIZE])
{
	for (u32 i = 0; i < BLOCK_SIZE; i+=4)
		*(u32*)(outIV+i) = AES_Read(InstancePtr, channel, AES_IVR0_OFFSET+i);
}

void AES_GetKey(AES *InstancePtr, u32 channel, u8 outKey[BLOCK_SIZE])
{
   for (int i = 0; i < BLOCK_SIZE; i+=4)
        *(u32*)(outKey+i) = AES_Read(InstancePtr, channel, AES_KEYR0_OFFSET+i);
}

Mode AES_GetMode(AES *InstancePtr, u32 channel)
{
    return (Mode)getBits(AES_Read(InstancePtr, channel, AES_CR_OFFSET), MODE_POS, MODE_LEN);
}

ChainingMode AES_GetChainingMode(AES* InstancePtr, u32 channel)
{
    u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
	// read bit 5 and 6
	u32 chMode = getBits(cr, CHAIN_MODE_POS, CHAIN_MODE_LEN);
	// read bit 16
	//chMode |= getBits(cr, CHAIN_MODE_POS2, CHAIN_MODE_LEN2) << CHAIN_MODE_LEN;
    return (ChainingMode)chMode;
}

GCMPhase AES_GetGCMPhase(AES* InstancePtr, u32 channel)
{
    u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    return (GCMPhase)getBits(cr, GCM_PHASE_POS, GCM_PHASE_LEN);
}

u32 AES_GetPriority(AES* InstancePtr, u32 channel)
{
    u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    return getBits(cr, PRIORITY_POS, PRIORITY_LEN);
}

u32 AES_GetInterruptEnabled(AES* InstancePtr, u32 channel)
{
	u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    return getBits(cr, CCFIE_POS, CCFIE_LEN);
}

/**
 * @brief Whether the AES unit has a pending computation job for this channel
 * 
 * @param InstancePtr 
 * @return u32 1 when active, 0 when inactive
 */
u32 AES_isActive(AES* InstancePtr, u32 channel)
{
	return getBits(AES_Read(InstancePtr, channel, AES_CR_OFFSET), EN_POS, EN_LEN);
}



void AES_PerformKeyExpansion(AES *InstancePtr, u32 channel)
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
void AES_startComputationMode(AES* InstancePtr, u32 channel, ChainingMode chmode, int encrypt, u8* data, u8* outData, u32 size, u8 IV[BLOCK_SIZE],
 AES_CallbackFn callbackFn, void* callbackRef)
{
	Xil_AssertVoid(chmode != CHAINING_MODE_GCM);

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


void AES_startComputationECB(AES* InstancePtr, u32 channel, int encrypt, u8* data, u8* outData, u32 size, AES_CallbackFn callbackFn, void* callbackRef)
{	
	InstancePtr->CallbackFn[channel] = callbackFn;
	InstancePtr->CallbackRef[channel] = callbackRef;
	
	AES_SetDataParameters(InstancePtr, channel, data, outData, size);
	// Setup Data and set Enable = 1 to start the encryption/decryption
	AES_Setup(InstancePtr, channel, encrypt == 1 ? MODE_ENCRYPTION : MODE_DECRYPTION, CHAINING_MODE_ECB, 1, GCM_PHASE_INIT);
}

void AES_startComputationCBC(AES* InstancePtr, u32 channel, int encrypt, u8* data, u8* outData, u32 size, u8 IV[BLOCK_SIZE], AES_CallbackFn callbackFn, void* callbackRef)
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
void AES_startComputationCTR(AES* InstancePtr, u32 channel, u8* data, u8* outData, u32 size, u8 IV[12], AES_CallbackFn callbackFn, void* callbackRef)
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

void AES_startComputationGCM(AES* InstancePtr, u32 channel, int encrypt, u8* header, u32 headerLen, u8* payload, u8* outProcessedPayload, u32 payloadLen, u8 IV[12], AES_CallbackFn callbackFn, void* callbackRef)
{
	InstancePtr->CallbackFn[channel] = callbackFn;
	InstancePtr->CallbackRef[channel] = callbackRef;
	
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
		AES_SetDataParameters(InstancePtr, channel, header, NULL, headerLen);
		// enable with Phase Header
		AES_Setup(InstancePtr, channel, MODE_ENCRYPTION, CHAINING_MODE_GCM, 1, GCM_PHASE_HEADER);
	}
	// Process Payload
	if (payloadLen > 0)
	{
		// wait until Init / Header Phase is complete
		AES_waitUntilCompleted(InstancePtr, channel);
		AES_SetDataParameters(InstancePtr, channel, payload, outProcessedPayload, payloadLen);
		// enable with Phase Payload
		AES_Setup(InstancePtr, channel, encrypt == 1 ? MODE_ENCRYPTION : MODE_DECRYPTION, CHAINING_MODE_GCM, 1, GCM_PHASE_PAYLOAD);
	}
}

void AES_calculateTagGCM(AES* InstancePtr, u32 channel, u32 headerLen, u32 payloadLen, u8 outTag[BLOCK_SIZE])
{
	AES_SetGCMPhase(InstancePtr, channel, GCM_PHASE_FINAL);
	// Set the IV in the final round:  First 12 bytes are the Nonce, last 4 bytes are 0x000000001
	// No need to write the Nonce again, as it is already there from the payload phase: Only need to write last word
	AES_Write(InstancePtr, channel, AES_IVR0_OFFSET+12, MODE_GCM_IV_FINAL);

	// Use headerLen (64 bit) ||  payloadLen(64 bit) as data block in final round
	u8 finalData[BLOCK_SIZE];
	*(u32*)finalData = 0;
	*(u32*)(finalData+8) = 0;
#ifdef LITTLE_ENDIAN
	*(u32*)(finalData+4) = Xil_EndianSwap32(headerLen*8);
	*(u32*)(finalData+12) = Xil_EndianSwap32(payloadLen*8);
#else
	*(u32*)(finalData+4) = headerLen*8;
	*(u32*)(finalData+12) = payloadLen*8;
#endif
	AES_SetDataParameters(InstancePtr, channel, finalData, outTag, BLOCK_SIZE);
	AES_startComputation(InstancePtr, channel);
	AES_waitUntilCompleted(InstancePtr, channel);
}


void AES_SetDataParameters(AES* InstancePtr, u32 channel, volatile u8* source, volatile u8* dest, u32 size)
{
	AES_Write(InstancePtr, channel, AES_DINR_ADDR_OFFSET, (u32)source);
	AES_Write(InstancePtr, channel, AES_DOUTR_ADDR_OFFSET, (u32)dest);
	AES_Write(InstancePtr, channel, AES_DATASIZE_OFFSET, size);
}

void AES_processDataECB(AES* InstancePtr, u32 channel, int encrypt, u8* data, u8* outData, u32 size)
{
	AES_startComputationECB(InstancePtr, channel, encrypt, data, outData, size, NULL, NULL);
	AES_waitUntilCompleted(InstancePtr, channel);
}

void AES_processDataCBC(AES* InstancePtr, u32 channel, int encrypt, u8* data, u8* outData, u32 size, u8 IV[BLOCK_SIZE])
{
	AES_startComputationCBC(InstancePtr, channel, encrypt, data, outData, size, IV, NULL, NULL);
	AES_waitUntilCompleted(InstancePtr, channel);
}

void AES_processDataCTR(AES* InstancePtr, u32 channel,  u8* data, u8* outData, u32 size, u8 IV[12])
{
	AES_startComputationCTR(InstancePtr, channel, data, outData, size, IV, NULL, NULL);
	AES_waitUntilCompleted(InstancePtr, channel); 
}

void AES_processDataGCM(AES* InstancePtr, u32 channel, int encrypt, u8* header, u32 headerLen, u8* payload, u8* outProcessedPayload, u32 payloadLen, u8 IV[12], u8 outTag[BLOCK_SIZE])
{
	AES_startComputationGCM(InstancePtr, channel, encrypt, header, headerLen, payload, outProcessedPayload, payloadLen, IV, NULL, NULL);
	AES_waitUntilCompleted(InstancePtr, channel);
	AES_calculateTagGCM(InstancePtr, channel, headerLen, payloadLen, outTag);
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

/**
 * @brief clears the CCF flag, which indicates that the computation has completed.
 *  This should usually not be necessary, as the flag is cleared automatically when a new computation starts
 * @param InstancePtr 
 * @param channel 
 */
void AES_clearCompletedStatus(AES* InstancePtr, u32 channel)
{
    u32 cr = AES_Read(InstancePtr, channel, AES_CR_OFFSET);
    setBits(&cr, 1, CCFC_POS, CCFC_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
    setBits(&cr, 0, CCFC_POS, CCFC_LEN);
    AES_Write(InstancePtr, channel, AES_CR_OFFSET, cr);
}

void AES_waitUntilCompleted(AES* InstancePtr, u32 channel)
{
	while (AES_isComputationCompleted(InstancePtr, channel) == 0)
		;
}

int AES_isComputationCompleted(AES* InstancePtr, u32 channel)
{
	u32 CCF = getBits(AES_Read(InstancePtr, channel, AES_SR_OFFSET), SR_CCF_POS, SR_CCF_LEN);
	return  (CCF & (1 << channel)) != 0;
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
u32 AES_GetError(AES* InstancePtr, u32 channel)
{
	u32 sr = AES_Read(InstancePtr, channel, AES_SR_OFFSET);
	return getBits(sr, SR_RDERR_POS+channel, 1) * ERROR_READ  |  getBits(sr, SR_WRERR_POS+channel, 1) * ERROR_WRITE;
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
	u32 SR = AES_Read(InstancePtr, 0, AES_SR_OFFSET);
	u32 Irq = getBits(SR, SR_IRQ_POS, SR_IRQ_LEN);

	if (Irq == 0x0) {
		xdbg_printf(XDBG_DEBUG_ERROR, "Intr handler called, but no interrupt occured\r\n");
		return;
	}

    // Clear interrupts by writing the Status register back
    AES_Write(InstancePtr, 0, AES_SR_OFFSET, SR);

    // Call Callback function for each interrupt
    for (int i = 0; i < AES_NUM_CHANNELS; i++)
    {
        if ((Irq & (1 << i)) && InstancePtr->CallbackFn[i])
        {
            (InstancePtr->CallbackFn[i])(InstancePtr->CallbackRef[i]);
			// Set CallbackFn to NULL so it isn't called later unintentionally
            InstancePtr->CallbackFn[i] = NULL;
        }
    }
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
