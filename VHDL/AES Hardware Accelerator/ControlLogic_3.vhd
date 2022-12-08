----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2022 21:02:50
-- Design Name: 
-- Module Name: ControlLogic - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.ALL;
use work.addresses.ALL;
use work.register_bit_positions.ALL;
use work.binary_search_types.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_misc.or_reduce;

entity ControlLogic_3 is
  Generic (
    LITTLE_ENDIAN : boolean := true;
    NUM_CHANNELS : integer range 1 to 1024 := 16 -- upper bound must be MAX_CHANNELS, but Vivado doesn't synthesize then
  );
  Port (    
-- Ports to the AES interface: 
-- Classic ReadWritePort with Enable signals
    RdEn : in std_logic;  -- signal to indicate a read access
    RdAddr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    RdData : out std_logic_vector(DATA_WIDTH-1 downto 0);
-- ReadyValid port for memory data transfer
    M_RW_valid : out std_logic;
    M_RW_ready : in std_logic;
    M_RW_addr : out std_logic_vector(31 downto 0);
    M_RW_wrData : out std_logic_vector(KEY_SIZE-1 downto 0);
    M_RW_rdData : in std_logic_vector(KEY_SIZE-1 downto 0);
    M_RW_write : out std_logic; 
    M_RW_error : in std_logic;
    --  write port
    WrEn1 : in std_logic;
    WrAddr1 : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    WrData1: in std_logic_vector(DATA_WIDTH-1 downto 0);
    WrStrb1 : in std_logic_vector(DATA_WIDTH/8-1 downto 0);
-- Ports to the ReadyValid RegMem port
    M_RM_valid : out std_logic;
    M_RM_ready : in std_logic;
    M_RM_addr : out std_logic_vector(31 downto 0);
    M_RM_length : out std_logic_vector(7 downto 0);
    M_RM_write : out std_logic;
    M_RM_error : in std_logic;
    M_RM_RdReady : out std_logic;
    M_RM_RdValid : in std_logic;
    M_RM_RdData : in std_logic_vector(31 downto 0);
    M_RM_WrReady : in std_logic;
    M_RM_WrValid : out std_logic;
    M_RM_WrData : out std_logic_vector(31 downto 0);
    
-- Ports to the AES Core
    -- second write port
    WrEn2 : in std_logic;
    WrAddr2 : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    WrData2 : in std_logic_vector(KEY_SIZE-1 downto 0);
    key : out std_logic_vector (KEY_SIZE-1 downto 0);
    IV : out std_logic_vector (KEY_SIZE-1 downto 0);
    H : out std_logic_vector (KEY_SIZE-1 downto 0);
    Susp : out std_logic_vector (KEY_SIZE-1 downto 0);
    DIN : out std_logic_vector (KEY_SIZE-1 downto 0);
    DOUT : in std_logic_vector (KEY_SIZE-1 downto 0);
-- Control to AES core
    EnICore : out std_logic;
    EnOCore : in std_logic;
    mode : out std_logic_vector (MODE_LEN-1 downto 0);
    chaining_mode : out std_logic_vector (CHMODE_LEN-1 downto 0);
    GCMPhase : out std_logic_vector(1 downto 0);
-- global signals
    aes_introut : out std_logic;
    Clock    : in std_logic;
    Resetn   : in std_logic
  );
end ControlLogic_3;

architecture Behavioral of ControlLogic_3 is

component BinarySearch is
    generic (
        NUM_CHANNELS : natural := 8;
        SIZE_IS_POWER_OF_2 : boolean := false
    );
    Port (
        EnI : in std_logic;
        EnO : out std_logic;
        size : in std_logic_vector(ADDR_CHANNEL_BITS downto 0);
        ChannelPriority: in PrioArrayType(NUM_CHANNELS-1 downto 0);
        ChannelEn : in std_logic_vector(NUM_CHANNELS-1 downto 0);
        avoidChannelIdx : in integer range NUM_CHANNELS-1 downto 0;
        highestChannel : out integer range NUM_CHANNELS -1 downto 0;
        Clock : in std_logic;
        Resetn : in std_logic
           );
end component;


-- helper function, must be at the beginning because it is used in the constants
-- log2 that rounds up
function log2( i : natural) return integer is
    variable temp    : integer := 1;
    variable ret_val : integer := 0; 
  begin					
    while temp < i loop
      ret_val := ret_val + 1;
      temp    := temp * 2;     
    end loop;
    
    return ret_val;
  end function;
 
function SwapEndian(x : std_logic_vector) return std_logic_vector is
variable r : std_logic_vector(x'RANGE);
variable idx : integer;
begin
for i in x'LENGTH/8-1 downto 0 loop
    idx := (x'LENGTH/8-1-i)*8;
    r(idx+7 downto idx) := x(i*8+7 downto i*8);
end loop;
return r;
end function;  
  
  -- define constants
constant DATA_WIDTH_BYTES : integer := DATA_WIDTH/8;
-- range of the index for the channel
subtype channel_range is integer range NUM_CHANNELS-1 downto 0;

-- definition of the address dimensions and which part of the address is the channel and which part the register
subtype addr_range is integer range ADDR_WIDTH-1 downto log2(DATA_WIDTH_BYTES);
subtype addr_channel_range is integer range ADDR_WIDTH-1 downto ADDR_REGISTER_BITS;
subtype addr_register_range is integer range ADDR_REGISTER_BITS-1 downto log2(DATA_WIDTH_BYTES);

-- Give the interface ports attributes so Vivado recognizes them as interfaces
ATTRIBUTE X_INTERFACE_INFO : STRING;
ATTRIBUTE X_INTERFACE_INFO of WrEn1: SIGNAL is
    "xilinx.com:user:ReadWritePort:1.0 S_ReadWritePort WrEn";
ATTRIBUTE X_INTERFACE_INFO of RdEn: SIGNAL is
"xilinx.com:user:ReadWritePort:1.0 S_ReadWritePort RdEn";
ATTRIBUTE X_INTERFACE_INFO of WrData1: SIGNAL is
"xilinx.com:user:ReadWritePort:1.0 S_ReadWritePort WrData";
ATTRIBUTE X_INTERFACE_INFO of WrAddr1: SIGNAL is
"xilinx.com:user:ReadWritePort:1.0 S_ReadWritePort WrAddr";
ATTRIBUTE X_INTERFACE_INFO of WrStrb1: SIGNAL is
"xilinx.com:user:ReadWritePort:1.0 S_ReadWritePort WrStrb";
ATTRIBUTE X_INTERFACE_INFO of RdData: SIGNAL is
"xilinx.com:user:ReadWritePort:1.0 S_ReadWritePort RdData";
ATTRIBUTE X_INTERFACE_INFO of RdAddr: SIGNAL is
"xilinx.com:user:ReadWritePort:1.0 S_ReadWritePort RdAddr";

ATTRIBUTE X_INTERFACE_INFO of WrEn2: SIGNAL is
    "xilinx.com:user:ReadWritePort:1.0 S_WritePort_127 WrEn";
ATTRIBUTE X_INTERFACE_INFO of WrData2: SIGNAL is
"xilinx.com:user:ReadWritePort:1.0 S_WritePort_127 WrData";
ATTRIBUTE X_INTERFACE_INFO of WrAddr2: SIGNAL is
"xilinx.com:user:ReadWritePort:1.0 S_WritePort_127 WrAddr";


ATTRIBUTE X_INTERFACE_INFO of M_RW_addr: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort Addr";
ATTRIBUTE X_INTERFACE_INFO of M_RW_wrData: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort WrData";
ATTRIBUTE X_INTERFACE_INFO of M_RW_rdData: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort RdData";
ATTRIBUTE X_INTERFACE_INFO of M_RW_ready: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort ready";
ATTRIBUTE X_INTERFACE_INFO of M_RW_valid: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort valid";
ATTRIBUTE X_INTERFACE_INFO of M_RW_write: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort write";
ATTRIBUTE X_INTERFACE_INFO of M_RW_error: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort error";

ATTRIBUTE X_INTERFACE_INFO of M_RM_addr: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort Addr";
ATTRIBUTE X_INTERFACE_INFO of M_RM_WrData: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort WrData";
ATTRIBUTE X_INTERFACE_INFO of M_RM_RdData: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort RdData";
ATTRIBUTE X_INTERFACE_INFO of M_RM_ready: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort ready";
ATTRIBUTE X_INTERFACE_INFO of M_RM_valid: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort valid";
ATTRIBUTE X_INTERFACE_INFO of M_RM_write: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort write";
ATTRIBUTE X_INTERFACE_INFO of M_RM_error: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort error";
ATTRIBUTE X_INTERFACE_INFO of M_RM_length: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort Length";
ATTRIBUTE X_INTERFACE_INFO of M_RM_RdReady: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort RdReady";
ATTRIBUTE X_INTERFACE_INFO of M_RM_RdValid: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort RdValid";
ATTRIBUTE X_INTERFACE_INFO of M_RM_WrReady: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort WrReady";
ATTRIBUTE X_INTERFACE_INFO of M_RM_WrValid: SIGNAL is
"xilinx.com:user:ReadyValid_RegMem_Port:1.0 M_RegMemPort WrValid";

-- Define registers as array out of words with DATA_WIDTH bits
-- For each register, there is 2**ADDR_REGISTER_BITS ( = 2**7 = 128) bytes of memory, i.e. 128/4 words per channel
-- TODO kleiner machen?
type mem_type is array (0 to (2**ADDR_REGISTER_BITS) / DATA_WIDTH_BYTES - 1) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal mem : mem_type;

signal baseAddr : std_logic_vector(31 downto 0);

-- The current channel
signal channel : channel_range;
-- The channel with the highest priority that is active
signal highestChannel, nextHighestChannel: channel_range;
-- the priorities of each channel
signal Priority : PrioArrayType(channel_range);
-- the enable signals of each channel
signal En, prevEn : std_logic_vector(channel_range);
-- the chaining mode of each channel
type ChModeArrayType is array(natural range<>) of std_logic_vector(CHMODE_LEN-1 downto 0);
signal ChMode : ChModeArrayType(channel_range);

-- signals for the highestChannel search process
signal runSearch, waitForSearchEnd : boolean;

-- signals for binary search
signal EnISearch, ENOSearch : std_logic;
signal resultSearch : channel_range;

-- status signals for each channel
signal WRERR, RDERR, CCF : std_logic_vector(channel_range);
signal prevCCF : std_logic_vector(channel_range);
signal CCFC : std_logic_vector(channel_range);
signal isChannelInterrupted : std_logic_vector(channel_range);

-- internal signals for RW port output
signal RW_addr : std_logic_vector(M_RW_addr'RANGE);
signal RW_valid : std_logic;
signal RW_wrData : std_logic_vector(KEY_SIZE-1 downto 0);
signal RW_write : std_logic;

-- internal signals for RM  port output
signal RM_addr : std_logic_vector(M_RM_addr'RANGE);
signal RM_valid : std_logic;
signal RM_length : std_logic_vector(M_RM_length'RANGE);
signal RM_write : std_logic;
signal RM_RdReady : std_logic;
signal RM_WrValid : std_logic;
signal RM_WrData : std_logic_vector(M_RM_WrData'RANGE); 

signal RM_valid_prev : std_logic;
signal write_index, read_index : std_logic_vector(4 downto 0); -- maximum is 84/4 = 21
signal startMemIdx : integer range mem_type'RANGE;

-- signals for the DMA process
type state_type is (Idle, Fetch, Computing, Writeback, LoadReg, SaveReg);
signal state : state_type;
signal dataCount : std_logic_vector(DATA_WIDTH-1 downto 0);
signal dataSize : std_logic_vector(DATA_WIDTH-1 downto 0);
signal sourceAddress, destAddress : std_logic_vector(M_RW_addr'LENGTH-1 downto 0);

-- control/status signals
signal interrupt, clearInterrupt : std_logic_vector(channel_range); -- stores for each channel whether it requests an interrupt
signal CCFIE : std_logic;
signal modeSignal : std_logic_vector(MODE_LEN-1 downto 0);
signal chainingModeSignal : std_logic_vector(CHMODE_LEN-1 downto 0);
signal GCMPhaseSignal : std_logic_vector(1 downto 0);


begin

-- forward internal RW port output signals
M_RW_addr <= RW_addr;
M_RW_valid <= RW_valid;
M_RW_wrData <= RW_wrData;
M_RW_write <= RW_write;

-- forward internal RM port output signals
M_RM_addr <= RM_addr;
M_RM_valid <= RM_valid;
M_RM_length <= RM_length;
M_RM_write <= RM_write;
M_RM_RdReady <= RM_RdReady;
M_RM_WrValid <= RM_WrValid;
M_RM_WrData <= RM_WrData;

RM_valid_prev <= RM_valid when rising_edge(Clock);
        
-- forward internal AES control signals
mode <= modeSignal;
GCMPhase <= GCMPhaseSignal;
chaining_mode <= chainingModeSignal;

-- merge interrupt requests into one interrupt signal
aes_introut <= or_reduce(interrupt);
    
-- store the En and CCF signal of the last cycle for each channel, so processes can check if it changed
prevEn <= En when rising_edge(Clock);
prevCCF <= CCF when rising_edge(Clock);

-- instantitate binary search component
BinSearch: BinarySearch
    generic map(
        NUM_CHANNELS => 2**log2(NUM_CHANNELS),
        SIZE_IS_POWER_OF_2 => true)
    port map(
        EnI => EnISearch,
        EnO => EnOSearch, 
        size => std_logic_vector(to_unsigned(2**log2(NUM_CHANNELS), ADDR_CHANNEL_BITS+1)),
        ChannelPriority => Priority,
        ChannelEn => En,
        avoidChannelIdx => highestChannel,
        highestChannel => resultSearch,
        Clock => Clock,
        Resetn => Resetn
    );
    
    
 -- process that handles the data fetching, computing and writing back
 -- this process drives the Control signals and channel
process(Clock)

variable configReg : std_logic_vector(DATA_WIDTH-1 downto 0);
variable destAddrVar, sourceAddrVar, dataCountVar : std_logic_vector(DATA_WIDTH-1 downto 0);

-- TODO necessary or just hardcode instead?
procedure UpdateCoreSignals is 
begin
for i in 3 downto 0 loop
    key(127-i*32 downto 96-i*32) <= mem(ADDR_KEYR0/4 + i);
    IV (127-i*32 downto 96-i*32) <= mem(ADDR_IVR0/4 + i);
    Susp(127-i*32 downto 96-i*32) <= mem(ADDR_SUSPR0/4 + i);
    H(127-i*32 downto 96-i*32) <= mem(ADDR_HR0/4 + i);
end loop;
end procedure;

procedure ChangeStateToComputing is
begin
    UpdateCoreSignals;
    EnICore <= '1';
    state <= Computing;
end procedure;

procedure ChangeToIdleAndMarkAsComplete is
begin
    CCF(channel) <= '1';
    interrupt(channel) <= CCFIE; -- interrupt is set to 1 when CCFIE is 1 (i.e. enabled), otherwise it stays 0
    isChannelInterrupted(channel) <= '0';
    state <= Idle;
end procedure;
 
procedure ChangeStateToLoadReg is
begin
    state <= LoadReg;               
    -- start the RegMem port read transaction
    RM_write <= '0';
    RM_valid <= '1';
    RM_addr <= std_logic_vector(unsigned(baseAddr) + (channel * REGSET_SIZE));
    
    -- How many registers need to be loaded depends on the mode
    if ChMode(channel) = CHAINING_MODE_GCM then
        -- In GCM mode, all registers have to be loaded
        RM_length <= std_logic_vector(to_unsigned((ADDR_HR3+4)/4, RM_length'LENGTH));
    else
        -- ECB, CBC, CTR
        if isChannelInterrupted(channel) = '1' then
                -- load up until dataprocessedsize
                RM_length <= std_logic_vector(to_unsigned((ADDR_DATAPROCESSEDSIZE+4)/4, RM_length'LENGTH));
        else
            if ChMode(channel) = CHAINING_MODE_ECB then
                -- only need to load up until key
                RM_length <= std_logic_vector(to_unsigned((ADDR_KEYR3+4)/4, RM_length'LENGTH));
            else -- CBC or CTR mode: Load up until IV
                RM_length <=  std_logic_vector(to_unsigned((ADDR_IVR3+4)/4, RM_length'LENGTH));
            end if;
        end if;
    end if;       
end procedure; 
 
 
procedure ChangeStateToSaveReg(addrOffset : integer; length : integer) is
begin
    state <= SaveReg;
    RM_write <= '1';
    RM_valid <= '1';
    RM_addr <= std_logic_vector(unsigned(baseAddr) + (channel * REGSET_SIZE) + addrOffset);
    RM_length <= std_logic_vector(to_unsigned(length/4, RM_length'LENGTH));
    startMemIdx <= addrOffset/4; 
end procedure;
 
 begin
 if rising_edge(Clock) then
    -- set pulse signals to 0 at the start of the process
    EnICore <= '0';
    
    -- synchronous reset
    if Resetn = '0' then
        state <= Idle;
        RW_valid <= '0';
        RM_valid <= '0';
        channel <= 0;
        interrupt <= (others => '0');
        CCF <= (others => '0');
        isChannelInterrupted <= (others => '0');
    else
        -- Check all channels if the status flags should be cleared
        for i in channel_range loop
            -- Check if CCF  should be cleared, either because the user flag is set or the channel was just enabled
            if CCFC(i) = '1' or (En(i) = '1' and prevEn(i) = '0') then
                CCF(i) <= '0';
            end if;
            if clearInterrupt(i) = '1' then
                interrupt(i) <= '0';
            end if;

        end loop;
       
             
        case state is
            when Idle =>
                -- switch channel to highestChannel
                channel <= highestChannel;
                -- start if the Enable signal switched to high or the channel changed
                if En(highestChannel) = '1' and (prevEn(highestChannel) = '0' or channel /= highestChannel) then
                    ChangeStateToLoadReg;               
                    
                    -- set isChannelInterrupted signal if channel is Enabled and not already finished
                    if En(channel) = '1' and CCF(channel) = '0' and channel /= highestChannel then
                        isChannelInterrupted(channel) <= '1';
                    end if;      
                end if;
                 
           when LoadReg =>
                -- wait until RegMem port transaction is finished
                if M_RM_ready = '1' then
                    RM_valid <= '0';    
                    -- copy configuration signals
                    configReg := mem(ADDR_CR/4); 
                    -- if mode is decryption but the channel has changed, the keyexpansion data aren't valid anymore 
                    --     therefore start in keyexpansion_and_decryption mode to regenerate the keyexpansion data
                    if configReg(CR_RANGE_MODE) = MODE_DECRYPTION and channel /= highestChannel then
                        modeSignal <= MODE_KEYEXPANSION_AND_DECRYPTION;
                    else
                        modeSignal <= configReg(CR_RANGE_MODE);
                    end if;
                    chainingModeSignal <= configReg(CR_RANGE_CHMODE);
                    GCMPhaseSignal <= configReg(CR_RANGE_GCMPHASE);
                    CCFIE <= configReg(CR_POS_CCFIE);
                    
                    -- Read addresses and datasize from memory register depending on Endianness
                    if not LITTLE_ENDIAN then 
                        destAddrVar     := mem(ADDR_DOUTADDR/4);
                        sourceAddrVar   := mem(ADDR_DINADDR/4);
                        dataSize        <= mem(ADDR_DATASIZE/4);
                        dataCountVar    := mem(ADDR_DATAPROCESSEDSIZE/4);
                    else
                        destAddrVar := SwapEndian(mem(ADDR_DOUTADDR/4));
                        sourceAddrVar := SwapEndian(mem(ADDR_DINADDR/4));
                        dataSize <= SwapEndian(mem(ADDR_DATASIZE/4));
                        dataCountVar := SwapEndian(mem(ADDR_DATAPROCESSEDSIZE/4));
                    end if;
                     -- Make sure dataCounter is divisible by 16
                    dataSize(3 downto 0) <= (others => '0');
                   
                    -- If channel was interrupted, use the old dataCount, otherwise init dataCount with 0
                    if isChannelInterrupted(channel) = '1' then
                        dataCount <= dataCountVar;
                        -- add dataCount to addresses
                        destAddrVar := std_logic_vector(unsigned(destAddrVar) + unsigned(dataCountVar));
                        sourceAddrVar := std_logic_vector(unsigned(sourceAddrVar) + unsigned(dataCountVar));
                    else
                        dataCount <= (others => '0');
                    end if;
                    
                    destAddress <= destAddrVar;
                    sourceAddress <= sourceAddrVar;


                    -- If mode is keyexpansion or the GCM init mode, start the AES Core immediately, no data reading required
                    -- need to read from configReg instead of the signals, as the signals only update after the process
                    if configReg(CR_RANGE_MODE) = MODE_KEYEXPANSION or (configReg(CR_RANGE_CHMODE) = CHAINING_MODE_GCM and configReg(CR_RANGE_GCMPHASE) = GCM_PHASE_INIT) then
                        ChangeStateToComputing;
                    else        
                        -- perform the read request
                        -- set RW addr to source address
                        RW_addr         <= sourceAddrVar; -- set RW_addr to sourceAddress
                        RW_write        <= '0';
                        RW_valid        <= '1';
                        state           <= Fetch;
                    end if;
                end if;
            when Fetch =>
                -- wait until data were received
                if M_RW_ready = '1' then
                    -- reset valid signal
                    RW_valid <= '0';
                    DIN <= M_RW_rdData;
                    -- start core
                    ChangeStateToComputing;
                end if;
            when Computing =>
                -- write back once the core has finished
                if EnOCore = '1' then
                    -- if mode was KEYEXPANSION_AND_DECRYPTION, we can switch to DECRYPTION to save time in the next computation
                    if modeSignal = MODE_KEYEXPANSION_AND_DECRYPTION and (chainingModeSignal = CHAINING_MODE_ECB or chainingModeSignal = CHAINING_MODE_CBC) then
                        modeSignal <= MODE_DECRYPTION;
                    end if;
                    -- In KeyExpansion mode, no writeback is required, as the computation is only one cycle
                    if modeSignal = MODE_KEYEXPANSION then
                        ChangeToIdleAndMarkAsComplete;
                    -- In GCM Phase Init, no writeback is required, but a SaveReg is
                    elsif (chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_INIT ) then
                        ChangeStateToSaveReg(ADDR_HR0, BLOCK_SIZE);
                        state <= SaveReg;
                    -- In the GCM Header Phase, there's no writeback either, but it has to be checked in the Writeback state
                    -- whether there is another block to process
                    elsif chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_HEADER then
                         -- change to writeback so it checks in the next cycle whether there are more data to process
                         state <= Writeback;
                    else
                        RW_addr <= destAddress;
                        RW_write <= '1';
                        RW_wrData <= DOUT;
                        RW_valid <= '1';
                        state <= Writeback;
                   end if;
                end if;
            when Writeback =>
                -- either memory request as completed or we are in GCM Header phase, so nothing is written back and we can continue immediately
                 if M_RW_ready = '1' or
                         (chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_HEADER) then
                         
                    RW_valid <= '0';    
                    -- increment dataCount of this channel
                    dataCount <= std_logic_vector(unsigned(dataCount) + to_unsigned(BLOCK_SIZE, RW_addr'LENGTH));
                    
                    -- check if computation is complete
                    if (unsigned(dataSize) - unsigned(dataCount)) <= to_unsigned(16, dataSize'LENGTH) then
                        if chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal /= GCM_PHASE_FINAL then
                            ChangeStateToSaveReg(ADDR_SUSPR0, BLOCK_SIZE);
                        else
                           ChangeToIdleAndMarkAsComplete;
                        end if;           
                    -- if there are more datablocks to process and the channel still has the highest priority, continue with fetch
                    elsif channel = highestChannel then
                        -- Not complete; Fetch next data block
                        -- increment addresses
                        destAddress <= std_logic_vector(unsigned(destAddress) + to_unsigned(BLOCK_SIZE, RW_addr'LENGTH));
                        sourceAddress <= std_logic_vector(unsigned(sourceAddress) + to_unsigned(BLOCK_SIZE, RW_addr'LENGTH));
                        -- set RW_addr to new source address
                        RW_addr <= std_logic_vector(unsigned(sourceAddress) + to_unsigned(BLOCK_SIZE, RW_addr'LENGTH));           
                        RW_valid <= '1'; -- new memory request
                        RW_write <= '0';
                        state <= Fetch;
                    else
                        -- channel interrupted: start SaveReg
                        if chainingModeSignal = CHAINING_MODE_ECB then
                            ChangeStateToSaveReg(ADDR_DATAPROCESSEDSIZE, 4);
                        elsif chainingModeSignal = CHAINING_MODE_CBC then
                            ChangeStateToSaveReg(ADDR_IVR0, BLOCK_SIZE+4);
                        elsif chainingModeSignal = CHAINING_MODE_CTR then
                            ChangeStateToSaveReg(ADDR_IVR3, 4 + 4);
                        else -- GCM
                            ChangeStateToSaveReg(ADDR_IVR3, 4 + 4 + BLOCK_SIZE);
                        end if;
                    end if;    
                end if;
            
            when SaveReg =>
                if M_RM_ready = '1' then
                    RM_valid <= '0';
                   -- Check for special case GCM mode if the channel work is complete,
                   -- for other modi the channel was interrupted 
                   if chainingModeSignal = CHAINING_MODE_GCM and 
                     (GCMPhaseSignal = GCM_PHASE_INIT or GCMPhaseSignal = GCM_PHASE_FINAL or dataSize = dataCount) then
                        ChangeToIdleAndMarkAsComplete;
                   else
                        state <= Idle;
                   end if;
                end if;
            when others =>
       end case;
    end if;
end if;
end process;


-- Error process
process(Clock)
begin
if rising_edge(Clock) then
    if Resetn = '0' then
        RDERR <= (others => '0');
        WRERR <= (others => '0');
    else
       for i in channel_range loop
            -- Clear error signals when channel is enabled
            if (En(i) = '1' and prevEn(i) = '0') then
                RDERR(i) <= '0';
                WRERR(i) <= '0';
            end if;
       end loop;
       -- update error when a port finishes
       if RW_valid = '1' and M_RW_ready = '1' then
            if RW_write = '1' then
                WRERR(channel) <= WRERR(channel) or M_RW_error;
            else
                RDERR(channel) <= RDERR(channel) or M_RW_error;
            end if;
       end if;
       if RM_valid = '1' and M_RM_ready = '1' then
            if RM_write = '1' then
                WRERR(channel) <= WRERR(channel) or M_RM_error;
            else
                RDERR(channel) <= RDERR(channel) or M_RM_error;
            end if;
       end if; 
    end if;
end if;
end process;

-- RM write process, driving RM_WrValid and RM_WrData
process (Clock)
procedure AssignWrData(memidx: integer) is
begin
if memidx = ADDR_DATAPROCESSEDSIZE/4 then
    if LITTLE_ENDIAN then
        RM_WrData <= SwapEndian(dataCount);
    else
        RM_WrData <= dataCount;
    end if;       
else
    RM_WrData <= mem(memidx);
end if;
end procedure;

begin
if rising_edge(Clock) then
    if Resetn = '0' then
        RM_WrValid <= '0';
    else
        -- use RM_valid as start signal instead of pulse_RegMemWrite 
        -- so that RM_addr and RM_length are already set and can be used here
        -- also that RM_WrValid isnt too early
        if RM_valid = '1' and RM_valid_prev = '0' and RM_write = '1' then
            -- init WrData and WrValid at start of transaction
            RM_WrValid <= '1';
            write_index <= (others => '0');
            AssignWrData(startMemIdx);  
        -- go to next data at each handshake    
        elsif RM_WrValid = '1' and M_RM_WrReady = '1' then
            write_index <= std_logic_vector(unsigned(write_index) + 1); 
            -- At each Write Handshake, set WrData to next data register
            AssignWrData(startMemIdx + to_integer(unsigned(write_index)) + 1);
            -- check if WrValid can be deactivated, which is when the next write index equals RM_length/4
            if unsigned(write_index) + 1 = unsigned(RM_length) then
                RM_WrValid <= '0';
            end if;    
        end if;    
    end if;
end if;
end process;


-- read process
process (Clock)
variable channelIdx : channel_range;
begin
if rising_edge(Clock) then
    if RdEn = '1' then
        channelIdx :=  to_integer(unsigned(RdAddr(addr_channel_range)));
        -- If address is in register SR, don't actually read from memory. This way the register appears read-only
        if RdAddr(addr_register_range) = std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH)(addr_register_range)) then
            -- fill RdData :   WRERR | RDERR |  CCF  | IRQ
            RdData <= (others => '0');
            RdData(SR_POS_IRQ) <= interrupt(channelIdx);
            RdData(SR_POS_CCF) <= CCF(channelIdx);
            RdData(SR_POS_RDERR) <= RDERR(channelIdx);
            RdData(SR_POS_WRERR) <= WRERR(channelIdx);
        else
            -- TODO Return the same or something different when channel /= channelIdx?
            if channelIdx = channel then
                RdData <= mem(to_integer(unsigned(RdAddr(addr_register_range))));
            else -- return 111111 when channel is not loaded
                RdData <= (others => '1');    
            end if;
        end if;
    end if;
end if;
end process;

-- write process driving baseAddr
process (Clock)
variable channelIdx : integer;

begin
if rising_edge(Clock) then
    if Resetn = '0' then
        baseAddr <= (others => '0');
    else
        -- Check if register part of the address equals the baseAddr and set baseAddr in that case
        if WrEn1 = '1' and WrAddr1(addr_register_range) = std_logic_vector(to_unsigned(ADDR_BASEADDR, WrAddr1'LENGTH)(addr_register_range))  then
            -- WriteStrobes other than 1111 must be prevented by the driver
            if not LITTLE_ENDIAN then
                baseAddr <= WrData1;
            else
                baseAddr <= SwapEndian(WrData1);
            end if;
        end if;
    end if;
end if;
end process;


-- write process driving En, CCFC, Priority and ChMode: if there's a write to the CR register, it updates the signals
process (Clock)
variable channelIdx : integer;

begin
if rising_edge(Clock) then   
    if Resetn = '0' then
        En <= (others => '0');
        CCFC <= (others => '0');
        for i in channel_range loop
            Priority(i) <= (others => '0');
        end loop;
    else
        -- Check if channel is finished: Reset the enable bit
        if CCF(channel) = '1' and prevCCF(channel) = '0' then
            En(channel) <= '0';
        end if;
        
        -- Set enable and priority signals if it was a write to the CR register
        if WrEn1 = '1' and WrAddr1(addr_register_range) = std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH)(addr_register_range)) then
            channelIdx :=  to_integer(unsigned(WrAddr1(addr_channel_range)));
            -- WriteStrobe ignored for simplicity; 
            -- Because of that, WriteStrobes other than 1111 for the CR register have to be prevented in the driver
             En(channelIdx) <= WrData1(CR_POS_EN);
             Priority(channelIdx) <= WrData1(CR_RANGE_PRIORITY);
             CCFC(channelIdx) <= WrData1(CR_POS_CCFC);
             ChMode(channelIdx) <= WrData1(CR_RANGE_CHMODE);
        end if;
    end if;
end if;
end process;

-- write process driving interruptClear
process (Clock)
variable channelIdx : integer;
begin
if rising_edge(Clock) then
    clearInterrupt <= (others => '0');
     -- if Write is to Status Register, it contains the Clear Interrupt Flags
    if WrEn1 = '1' and WrAddr1(addr_register_range) = std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH)(addr_register_range)) then
        channelIdx :=  to_integer(unsigned(WrAddr1(addr_channel_range)));
        clearInterrupt(channelIdx) <= WrData1(SR_POS_IRQ);
     end if;
end if;
end process;



-- write process driving mem
process (Clock)
variable channelIdx : integer;

begin
if rising_edge(Clock) then   
    if Resetn = '0' then
        for i in mem'RANGE loop 
            mem(i) <= (others => '0');
        end loop;
        RM_RdReady <= '0';
    else 
          
        -- Write port 1 (from the Interface)
        if WrEn1 = '1' then
            -- TODO forward WritePort1 to memory or just ignore it always?
            channelIdx :=  to_integer(unsigned(WrAddr1(addr_channel_range)));
            --TODO ignore certain registers like baseaddr?
            if channelIdx = channel then
                -- TODO simplify by ignoring WrStrb?
                for i in 3 downto 0 loop
                    if WrStrb1(i) = '1' then
                        mem(to_integer(unsigned(WrAddr1(addr_register_range))))(i*8+7 downto i*8) <= WrData1(i*8+7 downto i*8);
                    end if;
               end loop;
           end if;  
        end if;         
        -- Write port 2 (from the AES Core)
        if WrEn2 = '1' then
            -- write four words, i.e. 128 bit
            for i in 0 to 3 loop
                -- Write to WrAddr2 register
                mem(to_integer(unsigned(WrAddr2(addr_register_range)))+i) <= WrData2(127-i*32 downto 96-i*32);
            end loop;
        end if;
        
        -- Write Port 3 : from RegMem Port
        -- Prepare to read M_RM_RdData into memory once RM_valid is asserted
        if RM_Valid = '1' and RM_RdReady = '0' then
            read_index <= (others => '0');
            RM_RdReady <= '1';
        elsif RM_RdReady = '1' and M_RM_RdValid = '1' then
            -- at every Read-Handshake, read the data into memory
            read_index <= std_logic_vector(unsigned(read_index) + 1);
            mem(to_integer(unsigned(read_index))) <= M_RM_RdData;
        end if;
        -- reset RdReady when transaction is complete
        if M_RM_Ready = '1' then
            RM_RdReady <= '0';
        end if;
    end if;
end if;
end process;


-- driver process for nextHighestChannel
-- In each cycle, this process finds the enabled channel with the highest priority that is not currently active
-- if no channel is enabled, channel 0 is selected
process(Clock)

variable channelIdx: channel_range;

begin
if rising_edge(Clock) then
    EnISearch <= '0';
    if Resetn = '0' then
        highestChannel <= channel_range'LOW;
        nextHighestChannel <= channel_range'HIGH; -- choose a random channel different from highestChannel
        runSearch <= false;
        waitForSearchEnd <= false;
    else
         -- Check if highestChannel is completed, in that case set highestChannel to the next highest Channel
         -- if the search is still running, assert waitForSearchEnd and wait until the search has finished
        if CCF(highestChannel) = '1' or waitForSearchEnd then
            if runSearch then
                -- search is currently running
                waitForSearchEnd <= true;
            else 
                -- search is finished; set highestChannel to nextHighestChannel, then restart the search
                 highestChannel <= nextHighestChannel;
                 -- set nextHighestChannel to a disabled channel; highestChannel is good for this, as En is set to 0 in this cycle by another process
                 nextHighestChannel <= highestChannel; 
                 -- start new search
                 runSearch <= true; 
                 EnISearch <= '1';
                 waitForSearchEnd <= false;
            end if;
        end if;

        if EnOSearch = '1' then
            nextHighestChannel <= resultSearch;
            runSearch <= false;
        end if;

        -- check if a new write to CR happened
        --  WriteStrobes other than 1111 for the CR register have to be prevented in the driver, otherwise this code must become more complex
        if WrEn1 = '1' and WrAddr1(addr_register_range) = std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH)(addr_register_range)) then
                channelIdx := to_integer(unsigned(WrAddr1(addr_channel_range)));
                -- Update highest Channel if the update channel has a higher priority than the current one 
                -- check if channel is now enabled
                if WrData1(CR_POS_EN) = '1' then
                    -- Make this channel the highest channel if it has a higher priority,
                    -- or if there's no other channel enabled (highestChannel and nextHighestChanel both disabled)
                    if unsigned(WrData1(CR_RANGE_PRIORITY)) > unsigned(Priority(highestChannel)) or (En(highestChannel) = '0' and En(nextHighestChannel) = '0') then
                        highestChannel <= channelIdx;
                        -- abort any running search
                        waitForSearchEnd <= false;
                        -- restart search for next highest channel
                        runSearch <= true;
                        EnISearch <= '1';
                    -- compare channelIdx to nextHighestChannel; if it is higher, replace nextHighestChannel with channelIdx             
                    elsif unsigned(WrData1(CR_RANGE_PRIORITY)) > unsigned(Priority(nextHighestChannel)) or En(nextHighestChannel) = '0' or nextHighestChannel = highestChannel then 
                        -- if search is currently running and process isn't waiting for the result, restart the search, as it is not definite that channelIdx is really the nextHighestChannel
                        -- the "not waitForSearchEnd" makes sure the search doesn't restart while a new channel is searched, so the search time is fixed
                        if runSearch and not waitForSearchEnd then
                             EnISearch <= '1';
                        -- if search is not running, this channel is definitely the next highest one
                        else
                            nextHighestChannel <= channelIdx;  -- TODO??
                        end if;
                    -- if channelIdx is lower than nextHighestChannel, we don't need to restart the search, as nextHighestChannel stays the same
                    end if;
                end if;
         end if;
    end if;
end if;
end process;



end Behavioral;
