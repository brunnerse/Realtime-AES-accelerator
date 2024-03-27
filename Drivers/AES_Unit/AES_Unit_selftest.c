
/***************************** Include Files *******************************/
#include "AES_Unit.h"
#include "AES_Unit_hw.h"
#include "stdio.h"

/************************** Constant Definitions ***************************/
#if AES_REG_KEY_WRITEONLY
#define AES_SELFTEST_REGSET_LENGTH AES_KEYR0_OFFSET
#else
#define AES_SELFTEST_REGSET_LENGTH AES_SR_OFFSET
#endif

/************************** Function Definitions ***************************/
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
int32_t AES_Mem_SelfTest(void * baseaddr_p)
{
	int offset;
	uint32_t Mem32Value;
	uintptr_t baseaddr = (uintptr_t)baseaddr_p;

	printf("******************************\n\r");
	printf("* User Peripheral Self Test Of AES Unit\n\r");
	printf("******************************\n\n\r");

	/*
	 * Write data to user logic BRAMs and read back
	 */
	printf("User logic memory test...\n\r");
	printf("   - local memory address is 0x%08x\n\r", (uint32_t)baseaddr);
	printf("   - write pattern to local BRAM and read back\n\r");
	

	for (uint32_t channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		for (offset = 0; offset < AES_SELFTEST_REGSET_LENGTH; offset += 4)
		{
			// Careful not to accidentally enable the unit here while writing to CR
			AES_mWriteMemory(baseaddr + (channel<<AES_ADDR_REGISTER_BITS) + offset,
					(0xDEADBEEF % offset + (channel << 8)));
		}
	}

	for (uint32_t channel = 0; channel < AES_NUM_CHANNELS; channel++)
	{
		for (offset = 0; offset < AES_SELFTEST_REGSET_LENGTH; offset += 4)
		{
			Mem32Value = AES_mReadMemory(baseaddr + (channel<<AES_ADDR_REGISTER_BITS) + offset);
			if ( Mem32Value != (0xDEADBEEF % offset  + (channel << 8)) )
			{
				printf("   - write/read memory failed on address 0x%08x\n\r",
								(uint32_t)(baseaddr + (channel<<AES_ADDR_REGISTER_BITS) + offset));
				return 1;
			}
			// Reset memory value to 0
			AES_mWriteMemory(baseaddr + (channel<<AES_ADDR_REGISTER_BITS) + offset, 0);
		}
	}
	printf("   - write/read memory passed\n\n\r");

	return 0;
}
