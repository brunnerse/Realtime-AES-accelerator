from enum import Enum

Config = Enum("Config", ["ECB_Encrypt", "ECB_Decrypt",
                         "CBC_Encrypt", "CBC_Decrypt",
                         "CTR",
                         "GCM_Pay_Encrypt", "CBC_Pay_Decrypt",
                         "GCM_Init", "GCM_Header", "GCM_Final"])


class Job:
    def __init__(self, a,N,M):
        self.a = a
        self.N = N
        self.M = M
    def __str__(self):
        return "(%d,%d,%s)"%(self.a, self.N, self.M)

def getAESCoreTime(cfg, isFirstBlock=False):
    assert(type(cfg) == Config)
    if cfg == Config.ECB_Decrypt and isFirstBlock:
        return 30+10
    elif cfg == Config.ECB_Decrypt or cfg == Config.ECB_Encrypt:
        return 30
    if cfg == Config.ECB_Decrypt and isFirstBlock:
        return 32+10
    elif cfg == Config.ECB_Decrypt or cfg == Config.ECB_Encrypt:
        return 32
    elif cfg == Config.CTR:
        return 31
    elif cfg == Config.GCM_Init:
        return 31
    elif cfg == Config.GCM_Init:
        return 30
    elif cfg == Config.GCM_Header:
        return 5
    elif cfg == Config.GCM_Pay_Encrypt:
        return 35
    elif cfg == Config.GCM_Pay_Decrypt:
        return 31
    elif cfg == Config.GCM_Final:
        return 31
    else:
        assert("Config not found")


def N_read(cfg):
    assert(type(cfg) == Config)
    #TODO
    return 12

def N_write(cfg):
    assert(type(cfg) == Config)
    if cfg == Config.GCM_Init:
        return 8
    elif cfg in [Config.GCM_Header, Config.GCM_Pay_Encrypt, Config.GCM_Pay_Decrypt]:
        return 4
    else:
        return 0
    
def N_read_int(cfg):
    if cfg in [Config.ECB_Encrypt, Config.ECB_Decrypt]:
        return 8
    elif cfg in [Config.CBC_Encrypt, Config.CBC_Decrypt, Config.CTR]:
        return 12
    else:
        return 21
    


NUM_CHANNELS = 8
channels = [[]] * NUM_CHANNELS


channels[0] = [Job(5,1,Config.ECB_Encrypt), ]






