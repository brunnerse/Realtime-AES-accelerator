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


entity ControlLogic is
  Generic (
    LITTLE_ENDIAN : boolean := true;
    NUM_CHANNELS : integer range 1 to 8 := 4 -- upper bound must be MAX_CHANNELS, but Vivado doesn't synthesize then
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
    interrupt : out std_logic;
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

-- The current channel
signal channel : channel_range;
-- The channel with the highest priority that is active
signal highestChannel : channel_range;
-- the priorities of each channel
type priority_arr_type is array (channel_range) of std_logic_vector(NUM_PRIORITY_BITS-1 downto 0);
signal Priority : priority_arr_type;
-- the enable signals of each channel
signal En, prevEn : std_logic_vector(channel_range);

-- status signals for each channel
-- TODO erase BUSY signal?
signal BUSY, WRERR, RDERR, CCF : std_logic_vector(channel_range);
signal prevCCF : std_logic_vector(channel_range);

type state_type is (Idle, Fetch, Computing, Writeback);
signal state : state_type;

-- internal signals for RW port output
signal RW_addr : std_logic_vector(M_RW_addr'RANGE);
signal RW_valid : std_logic;
signal RW_wrData : std_logic_vector(KEY_SIZE-1 downto 0);
signal RW_write : std_logic;


signal dataCounter : std_logic_vector(DATA_WIDTH-1 downto 0);
signal sourceAddress, destAddress : std_logic_vector(M_RW_addr'LENGTH-1 downto 0);
-- control signals
signal ERRIE, CCFIE, ERRC, CCFC : std_logic;
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
    
-- store the En and CCF signal of the last cycle for each channel, so processes can check if it changed
prevEn <= En when rising_edge(Clock);
prevCCF <= CCF when rising_edge(Clock);
-- status register flag
--BUSY(channel) <= '0' when state = Idle else '1';

-- Read key, IV, Susp and H from memory
GenSignals:
for i in 0 to 3 generate -- TODO get channel and IV from highestChannel instead of channel? This could help making a smaller delay
key(127-i*32 downto 96-i*32) <= mem(GetChannelAddr(channel, ADDR_KEYR0 + i*4));
IV (127-i*32 downto 96-i*32) <= mem(GetChannelAddr(channel, ADDR_IVR0 + i*4));
Susp(127-i*32 downto 96-i*32) <= mem(GetChannelAddr(channel, ADDR_SUSPR0 + i*4)); -- TODO funktioniert noch nicht ganz!
H(127-i*32 downto 96-i*32) <= mem(GetChannelAddr(channel, ADDR_SUSPR4 + i*4));
end generate;


-- driver process for highestChannel
-- In each cycle, this process finds the enabled channel with the highest priority
-- if no channel is enabled, channel 0 is selected
-- if multiple channels share the highest priority, the one already running is selected
--process(Clock)

--variable bestChannel : channel_range;
--variable bestPriority : std_logic_vector(NUM_PRIORITY_BITS-1 downto 0);
--begin
--if rising_edge(Clock) then
--    if Resetn = '0' then
--        highestChannel <= 0;
--    else
        -- do linear search for the channel with the highest priority
        
        -- This will ensure that for two channels with the same priority, the one already running will be selected
        --  TODO rather choose the channel with the lower index? In that case, I set bestChannel to 0 and can skip 0 in the for loop 
--        bestChannel := channel; 
--        bestPriority := Priority(channel); 

--        for i in 0 to NUM_CHANNELS-1 loop
            -- Change bestChannel if the new channel is enabled and has a higher priority, or if bestChannel is disabled
--            if En(i) = '1' and (Priority(i) > bestPriority or En(bestChannel) = '0') then
--                bestChannel := i;
--                bestPriority := Priority(i);
--            end if;
--        end loop;
--        highestChannel <= bestChannel;
--    end if;
--end if;
--end process;

 -- process that handles the data fetching, computing and writing back
 -- this process drives the Control signals and channel
 process(Clock)
 
 variable configReg : std_logic_vector(DATA_WIDTH-1 downto 0);
 
 begin
 if rising_edge(Clock) then
    EnICore <= '0';
    interrupt <= '0';
    
    -- synchronous reset
    if Resetn = '0' then
        state <= Idle;
        RW_valid <= '0';
        channel <= 0;
        for i in channel_range loop
            WRERR(i) <= '0';
            RDERR(i) <= '0';
            CCF(i) <= '0';
        end loop;
    else        
        case state is
            when Idle =>
                -- Read CR register of highest channel
                configReg := mem(GetChannelAddr(highestChannel, ADDR_CR));
                
                -- Check if CCF should be cleared  TODO is it ok if this check only happens in Idle?
                if configReg(CR_POS_CCFC) = '1' then
                    CCF(channel) <= '0';
                end if;
                -- switch channel to highestChannel
                channel <= highestChannel;
                -- start if the Enable signal switched to high or the channel changed
                if En(highestChannel) = '1' and (prevEn(highestChannel) = '0' or channel /= highestChannel) then
                    -- copy configuration signals
                    modeSignal <= configReg(CR_POS_MODE);
                    chainingModeSignal <= configReg(CR_POS_CHMODE);
                    GCMPhaseSignal <= configReg(CR_POS_GCMPHASE);
                    ERRIE <= configReg(CR_POS_ERRIE);
                    CCFIE <= configReg(CR_POS_CCFIE);
                    ERRC <= configReg(CR_POS_ERRC); 

                    -- reset CCF
                    CCF(highestChannel) <= '0';
                    -- If mode is keyexpansion or the GCM init mode, start the AES Core immediately, no data reading required
                    -- need to read from configReg instead of the signals, as the signals only update after the process
                    if configReg(CR_POS_MODE) = MODE_KEYEXPANSION or (configReg(CR_POS_CHMODE) = CHAINING_MODE_GCM and configReg(CR_POS_GCMPHASE) = GCM_PHASE_INIT) then
                        EnICore <= '1';
                        state <= Computing;
                        dataCounter <= (others => '0'); -- TODO necessary?
                    else
                        -- start read data transaction;  
                        -- Read addresses and datasize from memory register depending on Endianness
                        if not LITTLE_ENDIAN then 
                            destAddress     <= mem(GetChannelAddr(highestChannel, ADDR_DOUTADDR));
                            sourceAddress   <= mem(GetChannelAddr(highestChannel, ADDR_DINADDR));
                            RW_addr         <= mem(GetChannelAddr(highestChannel, ADDR_DINADDR)); -- set RW_addr to sourceAddress
                            dataCounter     <= mem(GetChannelAddr(highestChannel, ADDR_DATASIZE));
                        else
                            for i in 3 downto 0 loop
                                destAddress(i*8+7 downto i*8)   <= mem(GetChannelAddr(highestChannel, ADDR_DOUTADDR))((3-i)*8+7 downto (3-i)*8);
                                sourceAddress(i*8+7 downto i*8) <= mem(GetChannelAddr(highestChannel, ADDR_DINADDR))((3-i)*8+7 downto (3-i)*8);
                                RW_addr(i*8+7 downto i*8)       <= mem(GetChannelAddr(highestChannel, ADDR_DINADDR))((3-i)*8+7 downto (3-i)*8); -- set RW_addr to sourceAddress
                                dataCounter(i*8+7 downto i*8)   <= mem(GetChannelAddr(highestChannel, ADDR_DATASIZE))((3-i)*8+7 downto (3-i)*8);
                            end loop;
                        end if;
                        -- Make sure dataCounter is divisible by 16
                        dataCounter(3 downto 0) <= (others => '0');
                        RW_write <= '0';
                        RW_valid <= '1';
                        state <= Fetch;
                    end if;
                end if;
            when Fetch =>
                -- wait until data were received
                if M_RW_ready = '1' then
                    -- reset valid signal
                    RW_valid <= '0';
                    RDERR(channel) <= RDERR(channel) or M_RW_error; -- TODO remove or
                    -- check if channel changed, if yes return to Idle state
                    if channel /= highestChannel then
                        state <= Idle;
                    else
                        -- of channel still has the highest priority, start the core
                        DIN <= M_RW_rdData;
                        -- start core
                        EnICore <= '1';
                        state <= Computing;
                    end if;
                end if;
            when Computing =>
                -- write back once the core has finished
                -- TODO if not at the end and not interrupted, fetch next data while core is computing
                if EnOCore = '1' then
                    -- TODO Von KEYEXPANSION_AND_DECRYPTION umschalten auf DECRYPTION Aufpassen bei Kontextwechsel!
                    if modeSignal = MODE_KEYEXPANSION_AND_DECRYPTION and (chainingModeSignal = CHAINING_MODE_ECB or chainingModeSignal = CHAINING_MODE_CBC) then
                        modeSignal <= MODE_DECRYPTION;
                    end if;
                    -- In KeyExpansion mode or in GCM Phase Init or Header, no writeback is required
                    if modeSignal = MODE_KEYEXPANSION or 
                        (chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_INIT ) then
                        -- set signals that computation has finished
                        CCF(channel) <= '1';
                        interrupt <= CCFIE; -- interrupt is set to 1 when CCFIE is 1 (i.e. enabled), otherwise it stays 0;
                        state <= Idle;
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
                -- in GCM Header phase, nothing is written back, so we can continue immediately
                 if M_RW_ready = '1' or
                         (chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_HEADER) then
                    WRERR(channel) <= WRERR(channel) or M_RW_error; -- TODO remove OR
                    
                    dataCounter <= std_logic_vector(unsigned(dataCounter) - to_unsigned(KEY_SIZE/8, dataCounter'LENGTH));
                    -- check if computation is complete
                    if unsigned(dataCounter) > to_unsigned(16, dataCounter'LENGTH) then
                        -- Not complete; Fetch next data block
                        -- increment dest and source address
                        destAddress <= std_logic_vector(unsigned(destAddress) + to_unsigned(KEY_SIZE/8, RW_addr'LENGTH));
                        sourceAddress <= std_logic_vector(unsigned(sourceAddress) + to_unsigned(KEY_SIZE/8, RW_addr'LENGTH));
                        -- set RW_addr to new source address
                        RW_addr <= std_logic_vector(unsigned(sourceAddress) + to_unsigned(KEY_SIZE/8, RW_addr'LENGTH));
                        
                        RW_valid <= '1'; -- RW_valid stays high
                        RW_write <= '0';
                        state <= Fetch;
                    else 
                        -- Computation complete;  set interrupt and CCF, return to Idle state
                        RW_valid <= '0';  
                        state <= Idle;
                        CCF(channel) <= '1';
                        interrupt <= CCFIE;  -- interrupt is set to 1 when CCFIE is 1 (i.e. enabled), otherwise it stays 0
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
            channelIdx := to_integer(unsigned(RdAddr(addr_channel_range)));
            RdData <= (others => '0');
            RdData(3 downto 0) <= BUSY(channelIdx) & WRERR(channelIdx) & RDERR(channelIdx) & CCF(channelIdx);
        else
            RdData <= mem(to_integer(unsigned(RdAddr(addr_range))));
        end if;
    end if;
end if;
end process;

-- write process; also drives Priority, En and highestChannel signals
process (Clock)
variable channelIdx : integer;

-- variables for linear search for channel with highest priority
variable bestChannel : channel_range;
variable bestPriority : std_logic_vector(Priority(0)'RANGE);

begin
if rising_edge(Clock) then
    if Resetn = '0' then
        for i in mem'RANGE loop 
            mem(i) <= (others => '0');
        end loop;
        for i in channel_range loop
            En(i) <= '0';
            Priority(i) <= (others => '0');
        end loop;
        highestChannel <= highestChannel'LOW;
    else
        -- Reset the enable bit and reset the susp register once CCF switches to 1 (i.e. channel is finished)
        if CCF(channel) = '1' and prevCCF(channel) = '0' then -- TODO check if this works even with context switch
            En(channel) <= '0';
            -- select new highestChannel with highest priority
            bestChannel := 0; 
            bestPriority := Priority(0);  
            for i in 1 to NUM_CHANNELS-1 loop
                -- Change bestChannel if the new channel is enabled and has a higher priority, or if bestChannel is disabled
                if En(i) = '1' and (unsigned(Priority(i)) > unsigned(bestPriority) or En(bestChannel) = '0') then
                    bestChannel := i;
                    bestPriority := Priority(i);
                end if;
            end loop;
            highestChannel <= bestChannel;

            -- We could skip the write back to mem and the ControlLogic unit would still work, only the memory would be inconsistent
            mem(GetChannelAddr(channel, ADDR_CR))(CR_POS_EN) <= '0';

            -- Clear susp register, so it is 0 for the next run. 
            -- SUSPR4 - SUSPR7 are not necessary, as they are overwritten in the GCM init phase.
            for i in ADDR_SUSPR0/4 to ADDR_SUSPR3/4 loop
                mem(GetChannelAddr(channel, i*4)) <= (others => '0');
            end loop;
        end if;
        
        -- Write port 1 (from the Interface)
        if WrEn1 = '1' then
            -- ignore WrStrb
            --for i in 3 downto 0 loop
                --if WrStrb1(i) = '1' then
                --    mem(to_integer(unsigned(WrAddr1(addr_register_bits))))(i*8+7 downto i*8) <= WrData1(i*8+7 downto i*8);
                --end if;
           --end loop; 
           mem(to_integer(unsigned(WrAddr1(addr_range)))) <= WrData1;
            -- if the write was to a control register, copy the written data to priority and En
            -- TODO This only works with Write Strobe off!
           if WrAddr1(addr_register_range) = std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH)(addr_register_range)) then
                channelIdx := to_integer(unsigned(WrAddr1(addr_channel_range)));
                En(channelIdx) <= WrData1(CR_POS_EN);
                Priority(channelIdx) <= WrData1(CR_POS_PRIORITY);
                -- If channel is enabled and priority is higher than the one with the highest priority (or highestChannel is disabled), change highestChannel
                if WrData1(CR_POS_EN) = '1' and (unsigned(WrData1(CR_POS_PRIORITY)) > unsigned(Priority(highestChannel)) or En(highestChannel) = '0') then
                    highestChannel <= channelIdx;
                end if;
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


end Behavioral;
