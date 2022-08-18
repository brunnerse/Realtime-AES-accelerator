from Cryptodome.Cipher import AES
from Cryptodome.Random import get_random_bytes

def xorBytes(bytes1, bytes2):
    outBytes = [0] * len(bytes1)
    for i in range(len(bytes1)):
        outBytes[i] = bytes1[i] ^ bytes2[i]
    return bytes(outBytes)

def printAsHex(byteArray):
    for b in byteArray:
        print(format(b, "02x"), end=" ")
    print()
# define shorter function name
hex = printAsHex

key = bytes([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f])

data = bytes([0x00, 0x10, 0x20, 0x30, 0x01, 0x11, 0x21, 0x31, 0x02, 0x12, 0x22, 0x32, 0x03, 0x13, 0x23, 0x33])
data2 = bytes([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f])
data3 = bytes([0xaf, 0xfe, 0xde, 0xad, 0xbe, 0xef, 0xda, 0xdc, 0xab, 0xbe, 0xad, 0xbe, 0xec, 0x0c, 0xab, 0xad])

IV = bytes([0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00])

cipher = AES.new(key, AES.MODE_ECB)
cipherCBC = AES.new(key, AES.MODE_CBC, iv=IV)
cipherCTR = AES.new(key, AES.MODE_CTR, nonce=IV[:12])



ciphertext = cipher.encrypt(data)

print("Key:\t")
printAsHex(key)

print("IV:\t")
printAsHex(IV)

for cipherMode in [cipher, cipherCBC, cipherCTR]:
    if cipherMode == cipher:
        print("\nECB:")
    elif cipherMode == cipherCBC:
        print("\nCBC:")
    elif cipherMode == cipherCTR:
        print("\nCTR:")

    for d in [data, data2, data3]:
        print("Plain:\t", end="")
        printAsHex(d)
        print("Cipher:\t", end="")
        printAsHex(cipherMode.encrypt(d))   
        print()

# For GCM mode: In last cycle do  ciphertext, tag = cipher.encrypt_and_digest(data)