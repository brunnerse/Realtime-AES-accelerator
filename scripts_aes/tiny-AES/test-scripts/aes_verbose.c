#include <stdio.h>
#include <string.h>
#include <stdint.h>

//#include "aes_constants.h"
#include "test_data.h"

// Hack: Including aes.c so we can call the static functions inside 
#include "aes.c"


#define PRINT_STATE_AFTER_EACH_STEP 1

static void CipherVerbose(state_t* state, const uint8_t* RoundKey);
static void InvCipherVerbose(state_t* state, const uint8_t* RoundKey);


// prints string as hex
void __attribute__((weak)) phex(uint8_t* str) {
    unsigned char i;
    for (i = 0; i < Nb * 4; ++i)
        printf("%.2x ", str[i]);
    printf("\n");
}




int main() 
{
    uint8_t *key = key1; 
    uint8_t *in = plaintext1; 
    
    printf("Plaintext data:\n\t");
    phex(key);

    // Generate round keys
    struct AES_ctx ctx;

    AES_init_ctx(&ctx, key);

    printf("\n\nECB encrypt:\n\t");
    phex(in);
    CipherVerbose((state_t*)in, ctx.RoundKey);
    printf("-----------\nCiphertext:\n\t");
    phex(in);
    printf("\n\n");


    printf("\n\nECB decrypt:\n\t");
    phex(in);
    InvCipherVerbose((state_t*)in, ctx.RoundKey);
    printf("\nDecrypted plaintext:\n\t");
    phex(in);
    printf("\n\n");
}


/*
* Redefining Cipher() and InvCipher() functions to include printing after each step
*/

static void CipherVerbose(state_t* state, const uint8_t* RoundKey)
{
  uint8_t round = 0;

  // Add the First round key to the state before starting the rounds.
  AddRoundKey(0, state, RoundKey);

  // There will be Nr rounds.
  // The first Nr-1 rounds are identical.
  // These Nr rounds are executed in the loop below.
  // Last one without MixColumns()
  for (round = 1; ; ++round)
  {
#if PRINT_STATE_AFTER_EACH_STEP
    printf("---------\n");
#endif
    printf("Round state before round %u:\n\t", round);

    phex((uint8_t*)state);

    SubBytes(state);
#if PRINT_STATE_AFTER_EACH_STEP
    printf("-- SB:\t");
    phex((uint8_t*)state);
#endif
    ShiftRows(state);
#if PRINT_STATE_AFTER_EACH_STEP
    printf("-- SR:\t");
    phex((uint8_t*)state);
#endif

    if (round == Nr) {
      break;
    }
    MixColumns(state);
#if PRINT_STATE_AFTER_EACH_STEP
    printf("-- MC:\t");
    phex((uint8_t*)state);
#endif
    AddRoundKey(round, state, RoundKey);
#if PRINT_STATE_AFTER_EACH_STEP
    printf("-- AK:\t");
    phex((uint8_t*)state);
#endif
  }
  // Add round key to last round
  AddRoundKey(Nr, state, RoundKey);
}



static void InvCipherVerbose(state_t* state, const uint8_t* RoundKey)
{
  uint8_t round = 0;

  // Add the First round key to the state before starting the rounds.
  AddRoundKey(Nr, state, RoundKey);

  // There will be Nr rounds.
  // The first Nr-1 rounds are identical.
  // These Nr rounds are executed in the loop below.
  // Last one without InvMixColumn()
  for (round = (Nr - 1); ; --round)
  {
#if PRINT_STATE_AFTER_EACH_STEP
    printf("---------\n");
#endif
    printf("Round state before round %u:\n\t", round);
    phex((uint8_t*)state);

	InvShiftRows(state);
#if PRINT_STATE_AFTER_EACH_STEP
    printf("-- SR:\t");
    phex((uint8_t*)state);
#endif
	InvSubBytes(state);
#if PRINT_STATE_AFTER_EACH_STEP
    printf("-- SB:\t");
    phex((uint8_t*)state);
#endif
	AddRoundKey(round, state, RoundKey);
#if PRINT_STATE_AFTER_EACH_STEP
    printf("-- ARK:\t");
    phex((uint8_t*)state);
#endif
	if (round == 0) {
	    break;
	}
	InvMixColumns(state);
#if PRINT_STATE_AFTER_EACH_STEP
    printf("-- MC:\t");
    phex((uint8_t*)state);
#endif
  	}

}