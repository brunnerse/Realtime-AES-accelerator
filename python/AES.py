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
h = printAsHex

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

print("\n=====\nDECRYPTION\n========\n")
cipher = AES.new(key, AES.MODE_ECB)
cipherCBC = AES.new(key, AES.MODE_CBC, iv=IV)
cipherCTR = AES.new(key, AES.MODE_CTR, nonce=IV[:12])

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
        printAsHex(cipherMode.decrypt(d))   
        print()




# GCM MODE TESTING
def gf2_mul(x, y):

    res = 0
    for i in range(127, -1, -1):
        res ^= x * ((y >> i) & 1)  # branchless
        x = (x >> 1) ^ ((x & 1) * 0xE1000000000000000000000000000000)
    assert res < 1 << 128
    return res


def bytesToInt(b):
    x = 0
    for i in range(len(b)):
        x |= b[i] << (len(b)-1-i)*8
    return x
def intToBytes(i):
    l = []
    while i > 0:
        l.append(i & 0xff)
        i >>= 8
    return bytes(l[::-1])

b = lambda x : format(x, "b")


print("\n===\nGCM TESTS\n===")
cipherGCM = AES.new(key, AES.MODE_GCM, nonce=IV[:12])
print("Cipher blocks (same for Encryption and Decryption):")
cipherGCM.update(data)
cipherGCM.update(data3)
dataGCM = cipherGCM.encrypt(data)
printAsHex(dataGCM)
dataGCM += cipherGCM.encrypt(data)
printAsHex(dataGCM[-16:])
dataGCM += cipherGCM.encrypt(data2)
printAsHex(dataGCM[-16:])
tag = cipherGCM.digest()

H = cipher.encrypt(bytes(16))
print("H: ")
printAsHex(H)

print("Tag:")
printAsHex(tag)

print("Tag (Decryption):")
cipherGCM = AES.new(key, AES.MODE_GCM, nonce=IV[:12])
cipherGCM.update(data + data3)
cipherGCM.encrypt(dataGCM)
tagDecrypt = cipherGCM.digest()
# Verify that the calculated tag is correct
cipherGCM = AES.new(key, AES.MODE_GCM, nonce=IV[:12])
cipherGCM.update(data + data3)
cipherGCM.decrypt(data+data+data2)
cipherGCM.verify(tagDecrypt)
# print the tag
printAsHex(tagDecrypt)

