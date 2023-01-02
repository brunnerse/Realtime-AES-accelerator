#ifndef AES_INTERFACE_M_HW_H_
#define AES_INTERFACE_M_HW_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "AES_Unit_2.h"


// Address offset definitions
#define AES_CR_OFFSET 0x00
#define AES_DINR_ADDR_OFFSET 0x04
#define AES_DOUTR_ADDR_OFFSET 0x08
#define AES_KEYR0_OFFSET 0x0c
#define AES_IVR0_OFFSET 0x1c
#define AES_DATASIZE_OFFSET 0x2c
#define AES_SUSPR0_OFFSET 0x30
#define AES_SR_OFFSET 0x50

// Position definitions in the Control Register CR
#if AES_BYTE_ORDER == LITTLE_ENDIAN
#define EN_POS 24
#define MODE_POS 27
#define CHAIN_MODE_POS 29
#define CCFIE_POS 17
#define GCM_PHASE_POS 21
#define CCFC_POS 31
#define PRIORITY_POS 16
#define SR_IRQ_POS 24
#define SR_CCF_POS 16
#define SR_RDERR_POS 8
#define SR_WRERR_POS 0
#define MODE_GCM_IV_INIT 0x02000000
#define MODE_GCM_IV_FINAL 0x01000000
#else
// Normal, Big Endian Positions of the bits
#define EN_POS 0
#define MODE_POS 3
#define CHAIN_MODE_POS 5
#define CCFIE_POS 9
#define GCM_PHASE_POS 13
#define CCFC_POS 7
#define SR_IRQ_POS 0
#define SR_CCF_POS 8
#define SR_RDERR_POS 16
#define SR_WRERR_POS 24
#define MODE_GCM_IV_INIT 0x00000002
#define MODE_GCM_IV_FINAL 0x00000001
#endif

#define MODE_CTR_IV_INIT 0x00000000
#define EN_LEN 1
#define MODE_LEN 2
#define CHAIN_MODE_LEN 2
#define CCFIE_LEN 1
#define GCM_PHASE_LEN 2
#define CCFC_LEN 1
#define PRIORITY_LEN 3
#define SR_IRQ_LEN AES_NUM_CHANNELS
#define SR_CCF_LEN AES_NUM_CHANNELS
#define SR_WRERR_LEN AES_NUM_CHANNELS
#define SR_RDERR_LEN AES_NUM_CHANNELS


#ifdef __cplusplus
}
#endif

#endif