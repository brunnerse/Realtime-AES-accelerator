----------------------------------------------------------------------------------
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_misc.or_reduce;

entity ControlLogic is
  Generic (
    LITTLE_ENDIAN : boolean := true;
    NUM_CHANNELS : integer range 1 to 16 := 8 -- upper bound must be MAX_CHANNELS, but Vivado doesn't synthesize then
  );
  Port (    
-- Ports to the AES interface: 
-- Classic ReadWritePort with Enable signals
    RdEn : in std_logic;  -- signal to indicate a read access
    RdAddr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    RdData : out std_logic_vector(DATA_WIDTH-1 downto 0);
-- ReadyValid port for memory data transfer
    M_RV_valid : out std_logic;
    M_RV_ready : in std_logic;
    M_RV_addr : out std_logic_vector(31 downto 0);
    M_RV_wrData : out std_logic_vector(KEY_SIZE-1 downto 0);
    M_RV_rdData : in std_logic_vector(KEY_SIZE-1 downto 0);
    M_RV_write : out std_logic; 
    M_RV_error : in std_logic;
    --  write port
    WrEn1 : in std_logic;
    WrAddr1 : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    WrData1: in std_logic_vector(DATA_WIDTH-1 downto 0);
    WrStrb1 : in std_logic_vector(DATA_WIDTH/8-1 downto 0);
 
-- Ports to the AES Core
    -- second write port
    WrEn2 : in std_logic;
    WrAddr2 : in std_logic_vector(ADDR_REGISTER_BITS-1 downto 0);
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
end ControlLogic;

architecture Behavioral of ControlLogic is
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


component BinarySearch is
    generic (
        NUM_CHANNELS_IN : natural := 8
    );
    Port (
        EnI : in std_logic;
        EnO : out std_logic;
        ChannelPriority: in PrioArrayType(NUM_CHANNELS_IN-1 downto 0);
        ChannelEn : in std_logic_vector(NUM_CHANNELS_IN-1 downto 0);
        highestChannel : out integer range NUM_CHANNELS_IN -1 downto 0;
        Clock : in std_logic;
        Resetn : in std_logic
           );
end component; 
  
  -- define constants
constant DATA_WIDTH_BYTES : integer := DATA_WIDTH/8;
-- range of the index for the channel
subtype channel_range is integer range NUM_CHANNELS-1 downto 0;
subtype channel_ext_range is integer range ((NUM_CHANNELS+7)/8)*8-1 downto 0; -- channel_range extended so it is divisible by 8

-- definition of the address dimensions and which part of the address is the channel and which part the register
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


ATTRIBUTE X_INTERFACE_INFO of M_RV_addr: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort Addr";
ATTRIBUTE X_INTERFACE_INFO of M_RV_wrData: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort WrData";
ATTRIBUTE X_INTERFACE_INFO of M_RV_rdData: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort RdData";
ATTRIBUTE X_INTERFACE_INFO of M_RV_ready: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort ready";
ATTRIBUTE X_INTERFACE_INFO of M_RV_valid: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort valid";
ATTRIBUTE X_INTERFACE_INFO of M_RV_write: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort write";
ATTRIBUTE X_INTERFACE_INFO of M_RV_error: SIGNAL is
"xilinx.com:user:ReadyValid_RW_Port:1.0 M_DataPort error";

-- Define registers as array out of words with DATA_WIDTH bits
-- For each register, there is 2**ADDR_REGISTER_BITS ( = 2**7 = 128) bytes of memory, i.e. 128/4 words per channel
--type mem_type is array (0 to (2**ADDR_REGISTER_BITS) * NUM_CHANNELS / DATA_WIDTH_BYTES - 1) of std_logic_vector(DATA_WIDTH-1 downto 0);
--signal mem : mem_type;

type single_mem_type is array (0 to (ADDR_HR3+4)/4-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
type multi_mem_type is array (channel_range) of single_mem_type;
signal mem : multi_mem_type;

-- The current channel
signal channel : channel_range;
-- The channel with the highest priority that is active
signal highestChannel: channel_range;
-- the priorities of each channel
signal Priority : PrioArrayType(channel_range);
-- the enable signals of each channel
signal En, prevEn : std_logic_vector(channel_range);

-- signals for binary search
signal EnISearch, ENOSearch : std_logic;
signal resultSearch : channel_range;

-- signals for scheduler to store any channels arriving during a search
signal duringChannel : channel_range;
signal isDuringChannelSet : boolean;
signal isSearchRunning : boolean;


-- status signals for each channel
signal WRERR, RDERR, CCF : std_logic_vector(channel_ext_range);
-- control signals
signal interrupt, clearInterrupt : std_logic_vector(channel_ext_range);
signal prevCCF : std_logic_vector(channel_ext_range);

signal isChannelInterrupted : std_logic_vector(channel_range);

type state_type is (Idle, Fetch, Computing, Writeback);
signal state : state_type;

-- internal signals for RW port output
signal RV_addr : std_logic_vector(M_RV_addr'RANGE);
signal RV_valid : std_logic;
signal RV_wrData : std_logic_vector(KEY_SIZE-1 downto 0);
signal RV_write : std_logic;


type dataCountArray is array (channel_range) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal dataCount : dataCountArray;
signal dataSize : std_logic_vector(DATA_WIDTH-1 downto 0);
signal sourceAddress, destAddress : std_logic_vector(M_RV_addr'LENGTH-1 downto 0);

signal CCFIE : std_logic;
signal modeSignal : std_logic_vector(MODE_LEN-1 downto 0);
signal chainingModeSignal : std_logic_vector(CHMODE_LEN-1 downto 0);
signal GCMPhaseSignal : std_logic_vector(1 downto 0);

begin


-- forward internal RW port output signals
M_RV_addr <= RV_addr;
M_RV_valid <= RV_valid;
M_RV_wrData <= RV_wrData;
M_RV_write <= RV_write;

-- set AES control signals
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
        NUM_CHANNELS_IN => NUM_CHANNELS
    )
    port map(
        EnI => EnISearch,
        EnO => EnOSearch, 
        ChannelPriority => Priority,
        ChannelEn => En,
        highestChannel => resultSearch,
        Clock => Clock,
        Resetn => Resetn
    );


 -- process that handles the data fetching, computing and writing back
 -- this process drives the Control signals and channel
process(Clock)

variable configReg : std_logic_vector(DATA_WIDTH-1 downto 0);
variable destAddrVar, sourceAddrVar : std_logic_vector(DATA_WIDTH-1 downto 0);

procedure UpdateCoreSignals(ch : channel_range) is 
begin
for i in 3 downto 0 loop
    key(127-i*32 downto 96-i*32) <= mem(ch)(ADDR_KEYR0/4 + i);
    IV (127-i*32 downto 96-i*32) <= mem(ch)(ADDR_IVR0/4 + i);
    Susp(127-i*32 downto 96-i*32) <= mem(ch)(ADDR_SUSPR0/4 + i);
    H(127-i*32 downto 96-i*32) <= mem(ch)(ADDR_HR0/4 + i);
end loop;
end procedure;

procedure ChangeStateToComputing(ch: channel_range) is
begin
    UpdateCoreSignals(ch);
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

 
 begin
 if rising_edge(Clock) then
    EnICore <= '0';
    
    -- synchronous reset
    if Resetn = '0' then
        state <= Idle;
        RV_valid <= '0';
        channel <= 0;
        interrupt <= (others => '0');
        isChannelInterrupted <= (others => '0');
        CCF <= (others => '0');
        for i in channel_range loop
            dataCount(i) <= (others => '0');
        end loop;
    else
        -- Check all channels if the status flags should be cleared
        for i in channel_range loop
            -- Check if CCF should be cleared, either because the user flag is set or the channel was just enabled
            if mem(i)(ADDR_CR/4)(CR_POS_CCFC) = '1' or (En(i) = '1' and prevEn(i) = '0') then
                CCF(i) <= '0';
            end if;
            if clearInterrupt(i) = '1' then
                interrupt(i) <= '0';
            end if;
        end loop;
             
        case state is
            when Idle =>
                -- Read CR register of highest channel
                configReg := mem(highestChannel)(ADDR_CR/4); 
                -- start if the Enable signal is high
                -- and the search for the highest channel already finished
                -- to avoid restarting a channel that just finished, check CCF first
                -- If a channel just restarted (i.e. prevEn='0'), we can start immediately
                if En(highestChannel) = '1' and (CCF(highestChannel) = '0' or prevEn(highestChannel) = '0') and not isSearchRunning then
                    -- switch channel to highestChannel
                    channel <= highestChannel;
                    -- copy configuration signals
                    
                    -- if mode is decryption, the expanded roundkeys aren't valid yet 
                    --     therefore start in keyexpansion_and_decryption mode
                    if configReg(CR_RANGE_MODE) = MODE_DECRYPTION then
                        modeSignal <= MODE_KEYEXPANSION_AND_DECRYPTION;
                    else
                        modeSignal <= configReg(CR_RANGE_MODE);
                    end if;
                    chainingModeSignal <= configReg(CR_RANGE_CHMODE);
                    GCMPhaseSignal <= configReg(CR_RANGE_GCMPHASE);
                    CCFIE <= configReg(CR_POS_CCFIE);
                    
                    -- Read addresses and datasize from memory register depending on Endianness
                    if not LITTLE_ENDIAN then 
                        destAddrVar     := mem(highestChannel)(ADDR_DOUTADDR/4);
                        sourceAddrVar   := mem(highestChannel)(ADDR_DINADDR/4);
                        dataSize        <= mem(highestChannel)(ADDR_DATASIZE/4);
                    else
                        destAddrVar := SwapEndian(mem(highestChannel)(ADDR_DOUTADDR/4));
                        sourceAddrVar := SwapEndian(mem(highestChannel)(ADDR_DINADDR/4));
                        dataSize <= SwapEndian(mem(highestChannel)(ADDR_DATASIZE/4));
                    end if;
                     -- Make sure dataCounter is divisible by 16
                    dataSize(3 downto 0) <= (others => '0');
                    
                    -- add dataCount to addresses, reset dataCount if necessary
                    if isChannelInterrupted(highestChannel) = '1' then
                        destAddrVar := std_logic_vector(unsigned(destAddrVar) + unsigned(dataCount(highestChannel)));
                        sourceAddrVar := std_logic_vector(unsigned(sourceAddrVar) + unsigned(dataCount(highestChannel)));
                    else
                        dataCount(highestChannel) <= (others => '0');
                    end if;
                    destAddress <= destAddrVar;
                    sourceAddress <= sourceAddrVar;

                    -- If mode is keyexpansion or the GCM init mode, start the AES Core immediately, no data reading required
                    -- need to read from configReg instead of the signals, as the signals only update after this cycle
                    if configReg(CR_RANGE_MODE) = MODE_KEYEXPANSION or
                            (configReg(CR_RANGE_CHMODE) = CHAINING_MODE_GCM and configReg(CR_RANGE_GCMPHASE) = GCM_PHASE_INIT) then
                        ChangeStateToComputing(highestChannel);
                    else
                        -- start read data transaction
                        -- set RW addr to source address
                        RV_addr         <= sourceAddrVar; -- set RV_addr to sourceAddress
                        RV_write        <= '0';
                        RV_valid        <= '1';
                        state           <= Fetch;
                    end if;
                end if;
            when Fetch =>
                -- wait until data were received
                if M_RV_ready = '1' then
                    -- reset valid signal
                    RV_valid <= '0';
                    -- start the core
                    DIN <= M_RV_rdData;
                    ChangeStateToComputing(channel);
                end if;
            when Computing =>
                -- write back once the core has finished
                if EnOCore = '1' then
                    -- if mode was KEYEXPANSION_AND_DECRYPTION, we can switch to DECRYPTION to save time in the next computation
                    if modeSignal = MODE_KEYEXPANSION_AND_DECRYPTION then 
                        modeSignal <= MODE_DECRYPTION;
                    end if;
                    -- In KeyExpansion mode or in GCM Phase Init, no writeback is required
                    if modeSignal = MODE_KEYEXPANSION or 
                            (chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_INIT ) then
                        
                        ChangeToIdleAndMarkAsComplete;
                        
                    -- In the GCM Header Phase, there's no writeback either, but it has to be checked in the Writeback state
                    -- whether there is another block to process
                    elsif chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_HEADER then
                         -- change to writeback so it checks in the next cycle whether there are more data to process
                         state <= Writeback;
                    -- in all other cases, write back the result data
                    else
                        RV_addr <= destAddress;
                        RV_write <= '1';
                        RV_wrData <= DOUT;
                        RV_valid <= '1';
                        state <= Writeback;
                   end if;
                end if;
            when Writeback =>
                -- either memory request as completed or we are in GCM Header phase, so nothing is written back and we can continue immediately
                 if M_RV_ready = '1' or
                         (chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_HEADER) then
                         
                    RV_valid <= '0';
                    -- increment dataCount of this channel
                    dataCount(channel) <= std_logic_vector(unsigned(dataCount(channel)) + to_unsigned(BLOCK_SIZE, RV_addr'LENGTH));
                    
                    -- check if computation is complete
                    if (unsigned(dataSize) - unsigned(dataCount(channel))) <= to_unsigned(BLOCK_SIZE, dataSize'LENGTH) then
                        -- Computation complete;  set interrupt and CCF
                        ChangeToIdleAndMarkAsComplete;                        
                    -- if there are more datablocks to process and the channel still has the highest priority, continue with fetch
                    elsif channel = highestChannel then
                        -- Not complete; Fetch next data block
                        -- increment addresses
                        destAddress <= std_logic_vector(unsigned(destAddress) + to_unsigned(BLOCK_SIZE, RV_addr'LENGTH));
                        sourceAddress <= std_logic_vector(unsigned(sourceAddress) + to_unsigned(BLOCK_SIZE, RV_addr'LENGTH));
                        -- set RV_addr to new source address
                        RV_addr <= std_logic_vector(unsigned(sourceAddress) + to_unsigned(BLOCK_SIZE, RV_addr'LENGTH));           
                        RV_valid <= '1'; -- new memory request
                        RV_write <= '0';
                        state <= Fetch;
                    -- Channel is being interrupted
                    else
                        isChannelInterrupted(channel) <= '1';
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
       -- update error when a transaction is complete
       if RV_valid = '1' and M_RV_ready = '1' then
            if RV_write = '1' then
                WRERR(channel) <= WRERR(channel) or M_RV_error;
            else
                RDERR(channel) <= RDERR(channel) or M_RV_error;
            end if;
       end if;
    end if;
end if;
end process;



-- read process
process (Clock)
variable channelIdx : integer;
variable srIdx : integer;
begin
if rising_edge(Clock) then
    if RdEn = '1' then
        -- If address is in register SR, don't actually read from memory. This way the register appears read-only
        if RdAddr(addr_register_range) = std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH)(addr_register_range)) then
            -- divide channel bit by 8 to get the sr index
            srIdx := to_integer(unsigned(RdAddr(addr_channel_range'HIGH downto addr_channel_range'LOW+3)));
            -- fill RdData :   WRERR | RDERR |  CCF  | IRQ
            RdData <= (others => '0');
            RdData(SR_POS_IRQ+7 downto SR_POS_IRQ) <= interrupt(srIdx*8+7 downto srIdx*8);
            RdData(SR_POS_CCF+7 downto SR_POS_CCF) <= CCF(srIdx*8+7 downto srIdx*8);
            RdData(SR_POS_RDERR+7 downto SR_POS_RDERR) <= RDERR(srIdx*8+7 downto srIdx*8);
            RdData(SR_POS_WRERR+7 downto SR_POS_WRERR) <= WRERR(srIdx*8+7 downto srIdx*8);
        else
            channelIdx :=  to_integer(unsigned(RdAddr(addr_channel_range)));
            RdData <= mem(channelIdx)(to_integer(unsigned(RdAddr(addr_register_range))));
        end if;
    end if;
end if;
end process;

-- write process
-- drives the En and Priority signals; if there's a write to the CR register, it copies the values to En and Priority
-- drives clearInterrupt
process (Clock)
variable channelIdx : integer;
variable srIdx : integer;
begin
if rising_edge(Clock) then
    clearInterrupt <= (others => '0');
    
    if Resetn = '0' then
        for i in mem'RANGE loop
            for j in mem(i)'RANGE loop 
                mem(i)(j) <= (others => '0');
            end loop;
        end loop;
        for i in channel_range loop
            En(i) <= '0';
            Priority(i) <= (others => '0');
        end loop;
    else
        -- Check if channel is finished: Reset the enable bit
        if CCF(channel) = '1' and prevCCF(channel) = '0' then
            -- Set En to 0 and write back to memory
            mem(channel)(ADDR_CR/4)(CR_POS_EN) <= '0';
            En(channel) <= '0';
        end if;
        
        -- Write port 1 (from the Interface)
        if WrEn1 = '1' then
           channelIdx :=  to_integer(unsigned(WrAddr1(addr_channel_range)));
           -- Write to mem, but only if the address is still in the mem region
           if unsigned(WrAddr1(addr_register_range)) < to_unsigned(ADDR_SR,ADDR_WIDTH)(addr_register_range) then
               for i in 3 downto 0 loop
                    if WrStrb1(i) = '1' then
                        mem(channelIdx)(to_integer(unsigned(WrAddr1(addr_register_range))))(i*8+7 downto i*8) <= WrData1(i*8+7 downto i*8);
                    end if;
               end loop;
           end if;
           -- Set enable and priority signals if it was a write to the CR register
           if WrAddr1(addr_register_range) = std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH)(addr_register_range)) then
                -- WriteStrobe ignored for simplicity; 
                -- Because of that, WriteStrobes other than 1111 for the CR register have to be prevented in the driver
                --if WrStrb1(0) = '1' then
                    En(channelIdx) <= WrData1(CR_POS_EN);
                --end if;
                --if WrStrb1(2) = '1' then
                    Priority(channelIdx) <= WrData1(CR_RANGE_PRIORITY);
                --end if;
          end if;
          -- if Write is to Status Register, it contains the Clear Interrupt Flags
          if WrAddr1(addr_register_range) = std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH)(addr_register_range)) then
                srIdx := to_integer(unsigned(WrAddr1(addr_channel_range'HIGH downto addr_channel_range'LOW+3)));
                clearInterrupt(srIdx*8+7 downto srIdx*8) <= WrData1(SR_POS_IRQ+7 downto SR_POS_IRQ);
           end if;
        end if;
        -- Write port 2 (from the AES Core)
        if WrEn2 = '1' then
            -- write four words, i.e. 128 bit
            for i in 0 to 3 loop
                -- Write to WrAddr2 register of current channel
                mem(channel)(to_integer(unsigned(WrAddr2(addr_register_range)))+i) <= WrData2(127-i*32 downto 96-i*32);
            end loop;
        end if;
    end if;
end if;
end process;


-- driver process for highestChannel
-- In each cycle, this process finds the enabled channel with the highest priority that is not currently active
-- if no channel is enabled, channel 0 is selected
process(Clock)

variable channelIdx : channel_range;
begin
if rising_edge(Clock) then
    EnISearch <= '0';
    
    if Resetn = '0' then
        highestChannel <= channel_range'LOW;
        isSearchRunning <= false;
    else
        if EnOSearch = '1' then -- and EnISearch = '0' then
            isSearchRunning <= false;
            -- check if another channel arrived during the search and compare the priorities
            if not isDuringChannelSet or (unsigned(Priority(resultSearch)) >= unsigned(Priority(duringChannel)) and En(resultSearch) = '1') then
                highestChannel <= resultSearch;
            elsif isDuringChannelSet then -- if clause technically not necessary
                highestChannel <= duringChannel;
            end if;
        end if;
        
         -- Check if highestChannel has just completed and start the search for the new highestChannel in that case 
        if CCF(highestChannel) = '1' and prevCCF(highestChannel) = '0' then
            EnISearch <= '1';
            isSearchRunning <= true;
            isDuringChannelSet <= false;
        end if;
        -- check if a new channel was just enabled
        if WrEn1 = '1' and WrAddr1(addr_register_range) = std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH)(addr_register_range)) and
                WrData1(CR_POS_EN) = '1' then
                
            channelIdx := to_integer(unsigned(WrAddr1(addr_channel_range)));
            -- Update highest Channel if the update channel has a higher priority than the current one, or if no channel is active yet
            -- this means that if a high channel arrives during a search, the search is aborted and the high channel starts immediately
            if isSearchRunning then
                 -- check if channelIdx has the highest priority of all channels that arrived during the search
                if not isDuringChannelSet or unsigned(WrData1(CR_RANGE_PRIORITY)) > unsigned(Priority(duringChannel)) then  
                    -- check if search finishes in the same cycle
                    if EnOSearch = '1' then
                        if unsigned(WrData1(CR_RANGE_PRIORITY)) > unsigned(Priority(resultSearch)) or En(resultSearch) = '0' then
                            highestChannel <= channelIdx;
                        end if;
                    else
                        isDuringChannelSet <= true;
                        duringChannel <= channelIdx;
                    end if;
                end if; 
            elsif unsigned(WrData1(CR_RANGE_PRIORITY)) > unsigned(Priority(highestChannel)) or or_reduce(En) = '0' then 
                highestChannel <= channelIdx;
            end if;
        end if;
    end if;
end if;
end process;

end Behavioral;
