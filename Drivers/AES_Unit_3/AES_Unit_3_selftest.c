
/***************************** Include Files *******************************/
#include "AES_Unit_3.h"
#include "AES_Unit_3_hw.h"
#include "xparameters.h"
#include "stdio.h"
#include "xil_io.h"

/************************** Constant Definitions ***************************/
/************************** Function Definitions ***************************/
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
XStatus AES_Mem_SelfTest(AES* InstancePtr, void * baseaddr_p)
{
	u32 offset;
	u32 baseaddr;
	u32 Mem32Value;

	baseaddr = (u32) baseaddr_p;

	xil_printf("******************************\n\r");
	xil_printf("* User Peripheral Self Test\n\r");
	xil_printf("******************************\n\n\r");

	/*
	 * Write data to user logic BRAMs and read back
	 */
	xil_printf("User logic memory test...\n\r");
	xil_printf("   - local memory address is 0x%08x\n\r", baseaddr);
	xil_printf("   - write pattern to RAM and signal the Unit to read it \n\r");

	RegisterSet regset;

	// Write pattern into regset
	for (offset = 4; offset < sizeof(RegisterSet); offset += 4)
	{
		*(u32*)((void*)&regset + offset) = offset;
	}
	// Set datasize to 0
	regset.DataSize = 0;
	regset.DataProcessedSize = 0;
	// Assert the enable flag, set mode to KeyExpansion for a simple test
	// and chaining mode to GCM (Header Phase) to load the full regset 
	regset.CR = (1 << EN_POS) |  (MODE_KEYEXPANSION << MODE_POS) |
		 (CHAINING_MODE_GCM << CHAIN_MODE_POS)  | (GCM_PHASE_FINAL << GCM_PHASE_POS);

	xil_printf("   - Starting AES Unit...\n\r");
	// Set the registerset address
	AES_mWriteMemory(baseaddr + AES_BASEADDR_OFFSET, (u32)&regset); 
	// Start the KeyExpansion
	AES_mWriteMemory(baseaddr + AES_CR_OFFSET, regset.CR);

	// wait until finished
	while (((AES_mReadMemory(baseaddr + AES_SR_OFFSET) >> SR_CCF_POS) & 0x1) == 0)
		;
	
	xil_printf("   - AES Unit finished\n\r");
	xil_printf("   - Checking if local BRAM of the Unit contains the write pattern...\n\r");

	// Check if content of AES matches the regset	
	for ( offset = 0; offset < sizeof(RegisterSet); offset += 4)
	{
		// ignore read- or write-only register addresses
		if (offset == AES_SR_OFFSET || offset == AES_BASEADDR_OFFSET)
		{
			continue;
		}
		Mem32Value = AES_mReadMemory(baseaddr+offset);
	    if ( Mem32Value != *(u32*)((void*)&regset + offset) )
		{
	    	xil_printf("   - write/read memory failed on address 0x%08x\n\r", baseaddr+offset);
			return XST_FAILURE;
		}
	    // Reset memory value to 0
	    AES_mWriteMemory(baseaddr+offset, 0);
	}
	xil_printf("   - write/read memory passed\n\n\r");

	// Restore old baseaddr of registerset
	AES_mWriteMemory(baseaddr + AES_BASEADDR_OFFSET, (u32)InstancePtr->Registers); 
	
	return XST_SUCCESS;
}
