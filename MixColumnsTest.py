import numpy as np 

a = np.array([0x00, 0x10, 0x20, 0x30])

def mixcol(a):
    b = np.zeros(4)
    for i in range(4):
        b[i] = mul2(a[i]) ^ mul3(a[(i+1)%4]) ^ a[(i+2)%4] ^ a[(i+3)%4]
        print("b[%d] = %s"%(i, hex(int(b[i]))))
    return b

def mul2(x):
        if x > 127:
            return 2*x ^ 0x11b
        return 2*x

def mul3(x):
        return mul2(x) ^ x