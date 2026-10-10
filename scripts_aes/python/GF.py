import numpy as np

def mulGF(a,b, length=8, poly=0x11b):
    z = 0
    for i in range(0, length):
        if b & (1 << i):
            z ^= a
        if a & (1<<length-1):
            a = (a << 1)^(poly)
        else:
            a <<= 1
      #  print(hex(z), hex(a))
    return z

def addGF(a,b, length=8):
    return (a ^ b) & ((1<<length)-1)
 
def matmulGF(M1, M2):
    R = np.zeros((np.size(M1, 0),np.size(M2,1)), dtype=int)
    for i in range(0,np.size(R,0)):
        for j in range(0,np.size(R,1)):
            for h in range(0, np.size(M1, 1)):
               # print(R[i][j], mulGF(M1[i][h], M2[h][j]))
                R[i][j] = addGF(R[i][j], mulGF(M1[i][h], M2[h][j]))
    return R




C = np.array([[2,3,1,1],[1,2,3,1],[1,1,2,3], [3,1,1,2]], dtype=int)
C_inv = np.array([[14,11,13,9],[9,14,11,13],[13,9,14,11],[11,13,9,14]], dtype=int)

I_prod = matmulGF(C, C_inv)

