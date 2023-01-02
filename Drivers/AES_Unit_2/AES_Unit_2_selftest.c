
/***************************** Include Files *******************************/
#include "AES_Unit_2.h"
#include "AES_Unit_2_hw.h"
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
XStatus AES_Mem_SelfTest(void * baseaddr_p)
{
	int offset;
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
	xil_printf("   - write pattern to local BRAM and read back\n\r");
	

	for (u32 channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		for (offset = 0; offset < AES_SR_OFFSET; offset += 4)
		{
			// Careful not to accidentally enable the unit here while writing to CR
			AES_mWriteMemory(baseaddr + (channel<<AES_ADDR_REGISTER_BITS) + offset,
					(0xDEADBEEF % offset + (channel << 8)));
		}
	}

	for (u32 channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		for (offset = 0; offset < AES_SR_OFFSET; offset += 4)
		{
			Mem32Value = AES_mReadMemory(baseaddr + (channel<<AES_ADDR_REGISTER_BITS) + offset);
			if ( Mem32Value != (0xDEADBEEF % offset  + (channel << 8)) )
			{
				xil_printf("   - write/read memory failed on address 0x%08x\n\r", baseaddr+offset);
				return XST_FAILURE;
			}
			// Reset memory value to 0
			AES_mWriteMemory(baseaddr + (channel<<AES_ADDR_REGISTER_BITS) + offset, 0);
		}
	}
	xil_printf("   - write/read memory passed\n\n\r");

	return XST_SUCCESS;
}
