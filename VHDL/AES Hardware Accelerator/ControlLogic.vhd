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
use work.control_register_positions.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_misc.or_reduce;

entity ControlLogic is
  Generic (
    LITTLE_ENDIAN : boolean := true;
    NUM_CHANNELS : integer range 1 to 8 := 8 -- upper bound must be MAX_CHANNELS, but Vivado doesn't synthesize then
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
end ControlLogic;

architecture Behavioral of ControlLogic is
-- helper function, must be at the beginning because it is used in the constants
function log2( i : natural) return integer is
    variable temp    : integer := i;
    variable ret_val : integer := 0; 
  begin					
    while temp > 1 loop
      ret_val := ret_val + 1;
      temp    := temp / 2;     
    end loop;
    
    return ret_val;
  end function;
  
  
  -- define constants
constant DATA_WIDTH_BYTES : integer := DATA_WIDTH/8;
-- range of the index for the channel
subtype channel_range is integer range NUM_CHANNELS-1 downto 0;

-- definition of the address dimensions and which part of the address is the channel and which part the register
subtype addr_range is integer range ADDR_WIDTH-1 downto log2(DATA_WIDTH_BYTES);
subtype addr_channel_range is integer range ADDR_WIDTH-1 downto ADDR_REGISTER_BITS;
subtype addr_register_range is integer range ADDR_REGISTER_BITS-1 downto log2(DATA_WIDTH_BYTES);

 
 function GetChannelAddr(channel : channel_range; addr : integer) return integer is
    variable totalAddr : unsigned(addr_range);
    variable addrInt : integer;
    begin
        --report "Called with channel " & integer'image(channel) & " and addr " & integer'image(addr);
        totalAddr := (others => '0');
        totalAddr(addr_channel_range) := to_unsigned(channel, totalAddr(addr_channel_range)'LENGTH);
        totalAddr(addr_register_range) := to_unsigned(addr, ADDR_WIDTH)(addr_register_range);
        return to_integer(totalAddr);
end function;

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

-- Define registers as array out of words with DATA_WIDTH bits
-- For each register, there is 2**ADDR_REGISTER_BITS ( = 2**7 = 128) bytes of memory, i.e. 128/4 words per channel
type mem_type is array (0 to (2**ADDR_REGISTER_BITS) * NUM_CHANNELS / DATA_WIDTH_BYTES - 1) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal mem : mem_type;

-- TODO test this
--type single_mem_type is array (0 to 84/4-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
--type multi_mem_type is array (channel_range) of single_mem_type;
--signal multi_mem : multi_mem_type;

-- The current channel
signal channel : channel_range;
-- The channel with the highest priority that is active
signal highestChannel, nextHighestChannel: channel_range;
-- the priorities of each channel
type priority_arr_type is array (channel_range) of std_logic_vector(NUM_PRIORITY_BITS-1 downto 0);
signal Priority : priority_arr_type;
-- the enable signals of each channel
signal En, prevEn : std_logic_vector(channel_range);

-- signals for the highestChannel search process
signal runSearch, waitForSearchEnd : boolean;

-- status signals for each channel
signal WRERR, RDERR, CCF : std_logic_vector(channel_range);
signal prevCCF : std_logic_vector(channel_range);

type state_type is (Idle, Fetch, Computing, Writeback);
signal state : state_type;

-- internal signals for RW port output
signal RW_addr : std_logic_vector(M_RW_addr'RANGE);
signal RW_valid : std_logic;
signal RW_wrData : std_logic_vector(KEY_SIZE-1 downto 0);
signal RW_write : std_logic;


type dataCountArray is array (channel_range) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal dataCount : dataCountArray;
signal dataSize : std_logic_vector(DATA_WIDTH-1 downto 0);
signal sourceAddress, destAddress : std_logic_vector(M_RW_addr'LENGTH-1 downto 0);
-- control signals
signal interrupt, clearInterrupt : std_logic_vector(channel_range); -- stores for each channel whether it request an interrupt
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

-- set AES control signals
mode <= modeSignal;
GCMPhase <= GCMPhaseSignal;
chaining_mode <= chainingModeSignal;

-- merge interrupt requests into one interrupt signal
aes_introut <= or_reduce(interrupt);
    
-- store the En and CCF signal of the last cycle for each channel, so processes can check if it changed
prevEn <= En when rising_edge(Clock);
prevCCF <= CCF when rising_edge(Clock);

-- Read key, IV, Susp and H from memory
-- TODO Klappt Timing auch mit concurrent statements?
--GenSignals:
--for i in 0 to 3 generate -- TODO get channel and IV from highestChannel instead of channel? This could help making a smaller delay
--key(127-i*32 downto 96-i*32) <= mem(GetChannelAddr(channel, ADDR_KEYR0 + i*4));
--IV (127-i*32 downto 96-i*32) <= mem(GetChannelAddr(channel, ADDR_IVR0 + i*4));
--Susp(127-i*32 downto 96-i*32) <= mem(GetChannelAddr(channel, ADDR_SUSPR0 + i*4)); -- TODO funktioniert noch nicht ganz!
--H(127-i*32 downto 96-i*32) <= mem(GetChannelAddr(channel, ADDR_SUSPR4 + i*4));
--end generate;




 -- process that handles the data fetching, computing and writing back
 -- this process drives the Control signals and channel
process(Clock)

variable configReg : std_logic_vector(DATA_WIDTH-1 downto 0);
variable destAddrVar, sourceAddrVar : std_logic_vector(DATA_WIDTH-1 downto 0);

procedure UpdateCoreSignals(ch : channel_range) is 
begin
for i in 3 downto 0 loop
    key(127-i*32 downto 96-i*32) <= mem(GetChannelAddr(ch, ADDR_KEYR0 + i*4));
    IV (127-i*32 downto 96-i*32) <= mem(GetChannelAddr(ch, ADDR_IVR0 + i*4));
    Susp(127-i*32 downto 96-i*32) <= mem(GetChannelAddr(ch, ADDR_SUSPR0 + i*4));
    H(127-i*32 downto 96-i*32) <= mem(GetChannelAddr(ch, ADDR_SUSPR4 + i*4));
end loop;
end procedure;
 
 begin
 if rising_edge(Clock) then
    EnICore <= '0';
    
    -- synchronous reset
    if Resetn = '0' then
        state <= Idle;
        RW_valid <= '0';
        channel <= 0;
        interrupt <= (others => '0');
        WRERR <= (others => '0');
        RDERR <= (others => '0');
        CCF <= (others => '0');
        for i in channel_range loop
            dataCount(i) <= (others => '0');
        end loop;
    else
        -- Check all channels if the status flags should be cleared
        for i in channel_range loop
            -- Check if CCF  should be cleared, either because the user flag is set or the channel was just enabled
            if mem(GetChannelAddr(i, ADDR_CR))(CR_POS_CCFC) = '1' or (En(i) = '1' and prevEn(i) = '0') then
                CCF(i) <= '0';
            end if;
            if clearInterrupt(i) = '1' then
                interrupt(i) <= '0';
            end if;
           -- Clear error signals when channel is enabled
            if (En(i) = '1' and prevEn(i) = '0') then
                RDERR(i) <= '0';
                WRERR(i) <= '0';
            end if;
        end loop;
             
        case state is
            when Idle =>
                -- Read CR register of highest channel
                configReg := mem(GetChannelAddr(highestChannel, ADDR_CR)); 
                -- switch channel to highestChannel
                channel <= highestChannel;
                -- update core signals
                UpdateCoreSignals(highestChannel);
                -- start if the Enable signal switched to high or the channel changed
                if En(highestChannel) = '1' and (prevEn(highestChannel) = '0' or channel /= highestChannel) then
                
                    -- copy configuration signals
                    
                    -- if mode is decryption but the channel has changed, the keyexpansion data aren't valid anymore 
                    --     therefore start in keyexpansion_and_decryption mode to regenerate the keyexpansion data
                    if configReg(CR_POS_MODE) = MODE_DECRYPTION and channel /= highestChannel then
                        modeSignal <= MODE_KEYEXPANSION_AND_DECRYPTION;
                    else
                        modeSignal <= configReg(CR_POS_MODE);
                    end if;
                    chainingModeSignal <= configReg(CR_POS_CHMODE);
                    GCMPhaseSignal <= configReg(CR_POS_GCMPHASE);
                    CCFIE <= configReg(CR_POS_CCFIE);

                    -- If mode is keyexpansion or the GCM init mode, start the AES Core immediately, no data reading required
                    -- need to read from configReg instead of the signals, as the signals only update after the process
                    if configReg(CR_POS_MODE) = MODE_KEYEXPANSION or (configReg(CR_POS_CHMODE) = CHAINING_MODE_GCM and configReg(CR_POS_GCMPHASE) = GCM_PHASE_INIT) then
                        EnICore <= '1';
                        state <= Computing;
                        dataSize <= (others => '0'); -- TODO necessary?
                    else
                        -- start read data transaction;  
                        -- Read addresses and datasize from memory register depending on Endianness
                        if not LITTLE_ENDIAN then 
                            destAddrVar     := mem(GetChannelAddr(highestChannel, ADDR_DOUTADDR));
                            sourceAddrVar   := mem(GetChannelAddr(highestChannel, ADDR_DINADDR));
                            dataSize        <= mem(GetChannelAddr(highestChannel, ADDR_DATASIZE));
                        else
                            for i in 3 downto 0 loop
                                destAddrVar(i*8+7 downto i*8)   := mem(GetChannelAddr(highestChannel, ADDR_DOUTADDR))((3-i)*8+7 downto (3-i)*8);
                                sourceAddrVar(i*8+7 downto i*8) := mem(GetChannelAddr(highestChannel, ADDR_DINADDR))((3-i)*8+7 downto (3-i)*8);
                                dataSize(i*8+7 downto i*8)      <= mem(GetChannelAddr(highestChannel, ADDR_DATASIZE))((3-i)*8+7 downto (3-i)*8);
                            end loop;
                        end if;
                         -- Make sure dataCounter is divisible by 16
                        dataSize(3 downto 0) <= (others => '0');
                        
                        -- add dataCount to addresses
                        destAddrVar := std_logic_vector(unsigned(destAddrVar) + unsigned(dataCount(highestChannel)));
                        sourceAddrVar := std_logic_vector(unsigned(sourceAddrVar) + unsigned(dataCount(highestChannel)));
                        destAddress <= destAddrVar;
                        sourceAddress <= sourceAddrVar;
                        
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
                    RDERR(channel) <= RDERR(channel) or M_RW_error;
                    -- check if channel changed, if yes abort and return to Idle state without starting the core
                    if channel /= highestChannel then -- TODO should I be able to stop after fetch?
                        state <= Idle;
                    else
                        -- of channel still has the highest priority, start the core
                        DIN <= M_RW_rdData;
                        -- start core
                        EnICore <= '1';
                        -- update core signals before starting the core
                        UpdateCoreSignals(channel);
                        state <= Computing;
                    end if;
                end if;
            when Computing =>
                -- write back once the core has finished
                -- TODO if not at the end and not interrupted, fetch next data while core is computing
                if EnOCore = '1' then
                    -- if mode was KEYEXPANSION_AND_DECRYPTION, we can switch to DECRYPTION to save time in the next computation
                    if modeSignal = MODE_KEYEXPANSION_AND_DECRYPTION and (chainingModeSignal = CHAINING_MODE_ECB or chainingModeSignal = CHAINING_MODE_CBC) then
                        modeSignal <= MODE_DECRYPTION;
                    end if;
                    -- In KeyExpansion mode or in GCM Phase Init, no writeback is required
                    if modeSignal = MODE_KEYEXPANSION or 
                        (chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_INIT ) then
                        -- set signals that computation has finished
                        CCF(channel) <= '1';
                        interrupt(channel) <= CCFIE; -- interrupt is set to 1 when CCFIE is 1 (i.e. enabled), otherwise it stays 0;
                        state <= Idle;
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
                    WRERR(channel) <= WRERR(channel) or M_RW_error;         
                    -- increment dataCount of this channel
                    dataCount(channel) <= std_logic_vector(unsigned(dataCount(channel)) + to_unsigned(KEY_SIZE/8, RW_addr'LENGTH));
                    
                    -- Change to Idle per default,
                    --  unless the following evaluation show that the channel is still the highestChannel and there are more data to process
                    state <= Idle; 
                    
                    -- check if computation is complete
                    if (unsigned(dataSize) - unsigned(dataCount(channel))) <= to_unsigned(16, dataSize'LENGTH) then
                        -- Computation complete;  set interrupt and CCF, reset dataCount
                        dataCount(channel) <= (others => '0');
                        CCF(channel) <= '1';
                        interrupt(channel) <= CCFIE;  -- interrupt is set to 1 when CCFIE is 1 (i.e. enabled), otherwise it stays 0
                                  
                    -- if there are more datablocks to process and the channel still has the highest priority, continue with fetch
                    elsif channel = highestChannel then
                        -- Not complete; Fetch next data block
                        -- increment addresses
                        destAddress <= std_logic_vector(unsigned(destAddress) + to_unsigned(KEY_SIZE/8, RW_addr'LENGTH));
                        sourceAddress <= std_logic_vector(unsigned(sourceAddress) + to_unsigned(KEY_SIZE/8, RW_addr'LENGTH));
                        -- set RW_addr to new source address
                        RW_addr <= std_logic_vector(unsigned(sourceAddress) + to_unsigned(KEY_SIZE/8, RW_addr'LENGTH));           
                        RW_valid <= '1'; -- new memory request
                        RW_write <= '0';
                        state <= Fetch;
                    end if;    
                end if;
            when others =>
       end case;
    end if;
end if;
end process;

-- read process
process (Clock)
variable channelIdx : integer;
begin
if rising_edge(Clock) then
    if RdEn = '1' then
        -- If address is in register SR, don't actually read from memory. This way the register appears read-only
        if RdAddr(addr_register_range) = std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH)(addr_register_range)) then
            -- fill RdData :   WRERR | RDERR |  CCF  | IRQ
            RdData <= (others => '0');
            RdData(interrupt'RANGE) <= interrupt;
            RdData(CCF'HIGH+8 downto 8) <= CCF;
            RdData(RDERR'HIGH+16 downto 16) <= RDERR;
            RdData(WRERR'HIGH+24 downto 24) <= WRERR;
        else
            RdData <= mem(to_integer(unsigned(RdAddr(addr_range))));
        end if;
    end if;
end if;
end process;

-- write process
-- drives the En and Priority signals; if there's a write to the CR register, it copies the values to En and Priority
-- drives clearInterrupt
process (Clock)
variable channelIdx : integer;

begin
if rising_edge(Clock) then
    clearInterrupt <= (others => '0');
    
    if Resetn = '0' then
        for i in mem'RANGE loop 
            mem(i) <= (others => '0');
        end loop;
        for i in channel_range loop
            En(i) <= '0';
            Priority(i) <= (others => '0');
        end loop;
    else
        -- Check if channel is finished: Reset the enable bit and reset the susp register
        if CCF(channel) = '1' and prevCCF(channel) = '0' then
            -- Set En to 0 and write back to memory
            mem(GetChannelAddr(channel, ADDR_CR))(CR_POS_EN) <= '0';
            En(channel) <= '0';
            -- Clear susp register, so it is 0 for the next run. 
            -- SUSPR4 - SUSPR7 are not necessary, as they are overwritten in the GCM init phase.
            for i in ADDR_SUSPR0/4 to ADDR_SUSPR3/4 loop
                mem(GetChannelAddr(channel, i*4)) <= (others => '0');
            end loop;
        end if;
        
        -- Write port 1 (from the Interface)
        if WrEn1 = '1' then
            for i in 3 downto 0 loop
                if WrStrb1(i) = '1' then
                    mem(to_integer(unsigned(WrAddr1(addr_range))))(i*8+7 downto i*8) <= WrData1(i*8+7 downto i*8);
                end if;
           end loop;
           -- Set enable and priority signals if it was a write to the CR register
           if WrAddr1(addr_register_range) = std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH)(addr_register_range)) then
                channelIdx :=  to_integer(unsigned(WrAddr1(addr_channel_range)));
                -- WriteStrobe ignored for simplicity; 
                -- Because of that, WriteStrobes other than 1111 for the CR register have to be prevented in the driver
                --if WrStrb1(0) = '1' then
                    En(channelIdx) <= WrData1(CR_POS_EN);
                --end if;
                --if WrStrb1(2) = '1' then
                    Priority(channelIdx) <= WrData1(CR_POS_PRIORITY);
                --end if;
          end if;
          -- if Write is to Status Register, it contains the Clear Interrupt Flags
          if WrAddr1(addr_register_range) = std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH)(addr_register_range)) then
                clearInterrupt <= WrData1(clearInterrupt'RANGE);
           end if;
        end if;
        -- Write port 2 (from the AES Core)
        if WrEn2 = '1' then
            -- write four words, i.e. 128 bit
            for i in 0 to 3 loop
                -- append to current channel to WrAddr2 -- TODO check if it is written to the correct channel during a context switch
                mem(GetChannelAddr(channel, to_integer(unsigned(WrAddr2)))+i) <= WrData2(127-i*32 downto 96-i*32);
            end loop;
        end if;
    end if;
end if;
end process;


-- driver process for nextHighestChannel
-- In each cycle, this process finds the enabled channel with the highest priority that is not currently active
-- if no channel is enabled, channel 0 is selected
process(Clock)

variable channelIdx, checkedChannel, nextHighestChannelVar : channel_range;

constant CHECK_CHANNELS_PER_CYCLE : integer := 2;

begin
if rising_edge(Clock) then
    if Resetn = '0' then
        highestChannel <= channel_range'LOW;
        nextHighestChannel <= channel_range'HIGH; -- choose a random channel different from highestChannel
        checkedChannel := channel_range'LOW;
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
                 checkedChannel := channel_range'LOW;
                 waitForSearchEnd <= false;
            end if;
        end if;
        
        -- search; check the next CHECK_CHANNELS_PER_CYCLE channels if they are the next highest channel
        if runSearch then
            -- use a variable for nextHighestChannel so we can search multiple channels per cycle
            nextHighestChannelVar := nextHighestChannel;
            for i in 0 to CHECK_CHANNELS_PER_CYCLE-1 loop
            -- continuously search for the second highest channel, one check per cycle
                if checkedChannel /= highestChannel and En(checkedChannel) = '1' then
                    if ( unsigned(Priority(checkedChannel)) > unsigned(Priority(nextHighestChannelVar))) or En(nextHighestChannelVar) = '0' then
                        nextHighestChannelVar := checkedChannel;
                    end if;
                end if;
                nextHighestChannel <= nextHighestChannelVar;
                -- increment checkedChannel
                if checkedChannel = channel_range'HIGH then
                    checkedChannel := channel_range'LOW;
                    runSearch <= false;
                else
                    checkedChannel := checkedChannel + 1;
                end if;
            end loop;
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
                    if unsigned(WrData1(CR_POS_PRIORITY)) > unsigned(Priority(highestChannel)) or (En(highestChannel) = '0' and En(nextHighestChannel) = '0') then
                        highestChannel <= channelIdx;
                        -- abort any running search
                        waitForSearchEnd <= false;
                        -- restart search for next highest channel
                        runSearch <= true;
                        checkedChannel := channel_range'LOW;
                    -- compare channelIdx to nextHighestChannel; if it is higher, replace nextHighestChannel with channelIdx             
                    elsif unsigned(WrData1(CR_POS_PRIORITY)) > unsigned(Priority(nextHighestChannel)) or En(nextHighestChannel) = '0' or nextHighestChannel = highestChannel then 
                        -- if search is currently running and process isn't waiting for the result, restart the search, as it is not definite that channelIdx is really the nextHighestChannel
                        -- the "not waitForSearchEnd" makes sure the search doesn't restart while a new channel is searched, so the search time is fixed
                        if runSearch and not waitForSearchEnd then
                             checkedChannel := channel_range'LOW;
                        -- if search is not running, this channel is definitely the next highest one
                        else
                            nextHighestChannel <= channelIdx;
                        end if;
                    -- if channelIdx is lower than nextHighestChannel, we don't need to restart the search, as nextHighestChannel stays the same
                    end if;
                end if;
         end if;
    end if;
end if;
end process;



end Behavioral;
