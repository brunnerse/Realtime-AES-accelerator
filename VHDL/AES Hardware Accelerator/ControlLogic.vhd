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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;



entity ControlLogic is
  Generic (
    LittleEndian : boolean := true
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

-- internal signals for RW port output
signal RW_addr : std_logic_vector(M_RW_addr'RANGE);
signal RW_valid : std_logic;
signal RW_wrData : std_logic_vector(KEY_SIZE-1 downto 0);
signal RW_write : std_logic;


signal En, prevEn : std_logic;


signal dataCounter : std_logic_vector(DATA_WIDTH-1 downto 0);
signal sourceAddress, destAddress : std_logic_vector(M_RW_addr'LENGTH-1 downto 0);

-- status signals TODO anything other than CCF needed?
signal BUSY, WRERR, RDERR, CCF : std_logic;
signal prevCCF : std_logic;
-- control signals
signal ERRIE, CCFIE, ERRC, CCFC : std_logic;

-- Define registers as array
type addr_range is array (0 to ADDR_SUSPR7/4) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal mem : addr_range;

type state_type is (Idle, Fetch, Computing, Writeback);
signal state : state_type;

signal modeSignal : std_logic_vector(MODE_LEN-1 downto 0);
signal chainingModeSignal : std_logic_vector(CHMODE_LEN-1 downto 0);
signal GCMPhaseSignal : std_logic_vector(1 downto 0);

begin

-- forward internal RW port output signals
M_RW_addr <= RW_addr;
M_RW_valid <= RW_valid;
M_RW_wrData <= RW_wrData;
M_RW_write <= RW_write;

key <= mem(ADDR_KEYR0/4) & mem(ADDR_KEYR1/4) & mem(ADDR_KEYR2/4) & mem(ADDR_KEYR3/4);
IV <= mem(ADDR_IVR0/4) & mem(ADDR_IVR1/4) & mem(ADDR_IVR2/4) & mem(ADDR_IVR3/4);
Susp <=  mem(ADDR_SUSPR0/4) & mem(ADDR_SUSPR1/4) & mem(ADDR_SUSPR2/4) & mem(ADDR_SUSPR3/4);
H <=  mem(ADDR_SUSPR4/4) & mem(ADDR_SUSPR5/4) & mem(ADDR_SUSPR6/4) & mem(ADDR_SUSPR7/4);

-- set AES control signals
-- copy mode, chaining_mode and GCMPhase to internal signals first, so we can check them in internal processes
En <= mem(ADDR_CR/4)(0);
-- stores the En and CCF signal of the last cycle, so processes can check if it changed
prevEn <= En when rising_edge(Clock);
prevCCF <= CCF when rising_edge(Clock);

modeSignal <= mem(ADDR_CR/4)(4 downto 3);
mode <= modeSignal;
chainingModeSignal <= mem(ADDR_CR/4)(6 downto 5);
chaining_mode <= chainingModeSignal;
GCMPhaseSignal <= mem(ADDR_CR/4)(14 downto 13);
GCMPhase <= GCMPhaseSignal;
ERRIE <= mem(ADDR_CR/4)(10);
CCFIE <= mem(ADDR_CR/4)(9);
ERRC <= mem(ADDR_CR/4)(8); 
CCFC <= mem(ADDR_CR/4)(7);

-- status register flag
BUSY <= '0' when state = Idle else '1';


 -- process that handles the data fetching, computing and writing back
 process(Clock)
 begin
 if rising_edge(Clock) then
    EnICore <= '0';
    interrupt <= '0';
    
    -- synchronous reset
    if Resetn = '0' then
        state <= Idle;
        RW_valid <= '0';
        WRERR <= '0';
        RDERR <= '0';
        CCF <= '0';
    else
        -- Check if CCF should be cleared
        if CCFC = '1' then
            CCF <= '0';
        end if;
        
        case state is
            when Idle =>
                if En = '1' and prevEn = '0' then
                    -- reset CCF
                    CCF <= '0';
                    -- If mode is keyexpansion or the GCM init mode, start the AES Core immediately, no data reading required
                    if modeSignal = MODE_KEYEXPANSION or (chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_INIT) then
                        EnICore <= '1';
                        state <= Computing;
                        dataCounter <= (others => '0'); -- TODO necessary?
                    else
                        -- start read data transaction;  
                        -- Read addresses and datasize from memory register depending on Endianness
                        if not LittleEndian then
                            destAddress <= mem(ADDR_DOUTADDR/4);
                            sourceAddress <= mem(ADDR_DINADDR/4);
                            RW_addr <= mem(ADDR_DINADDR/4); -- set RW_addr to sourceAddress
                            dataCounter <= mem(ADDR_DATASIZE/4)(31 downto 4) & "0000"; -- Make sure dataCounter is divisible by 16
                        else
                            for i in 3 downto 0 loop
                                destAddress(i*8+7 downto i*8) <= mem(ADDR_DOUTADDR/4)((3-i)*8+7 downto (3-i)*8);
                                sourceAddress(i*8+7 downto i*8) <= mem(ADDR_DINADDR/4)((3-i)*8+7 downto (3-i)*8);
                                RW_addr(i*8+7 downto i*8) <= mem(ADDR_DINADDR/4)((3-i)*8+7 downto (3-i)*8);
                                dataCounter(i*8+7 downto i*8) <= mem(ADDR_DATASIZE/4)((3-i)*8+7 downto (3-i)*8);
                            end loop;
                            -- Make sure dataCounter is divisible by 16
                            dataCounter(3 downto 0) <= (others => '0');
                        end if;
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
                    RDERR <= RDERR or M_RW_error; -- TODO remove or
                    DIN <= M_RW_rdData;
                    -- start core
                    EnICore <= '1';
                    state <= Computing;
                end if;
            when Computing =>
                -- write back once the core has finished
                -- TODO if not at the end and not interrupted, fetch next data while core is computing
                if EnOCore = '1' then
                    -- In KeyExpansion mode or in GCM Phase Init or Header, no writeback is required
                    if modeSignal = MODE_KEYEXPANSION or 
                        (chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_INIT ) then
                        -- set signals that computation has finished
                        CCF <= '1';
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
                    WRERR <= WRERR or M_RW_error; -- TODO remove OR
                    
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
                        CCF <= '1';
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
begin
if rising_edge(Clock) then
    if RdEn = '1' then
        -- If address is in register SR, don't actually read from memory. This way the register appears read-only
        if RdAddr(ADDR_WIDTH-1 downto 2) = std_logic_vector(to_unsigned(ADDR_SR/4, ADDR_WIDTH)) then
            RdData <= x"0000000" & BUSY & WRERR & RDERR & CCF;
        else
            RdData <= mem(to_integer(unsigned(RdAddr(ADDR_WIDTH-1 downto 2)))); -- divide address by four, as array is indexed word-wise
        end if;
    end if;
end if;
end process;

-- write process
process (Clock)
begin
if rising_edge(Clock) then
    if Resetn = '0' then
        for i in 0 to ADDR_SUSPR7/4 loop
            mem(i) <= (others => '0');
        end loop;
    else
        -- Reset the enable bit once CCF switches to 1
        if CCF = '1' and prevCCF = '0' then
            mem(ADDR_CR/4)(0) <= '0';
        end if;
        
        -- Write port 1 (from the Interface)
        if WrEn1 = '1' then
            for i in 3 downto 0 loop
                if WrStrb1(i) = '1' then
                    mem(to_integer(unsigned(WrAddr1(ADDR_WIDTH-1 downto 2))))(i*8+7 downto i*8) <= WrData1(i*8+7 downto i*8);
                end if;
            end loop; 
        end if;
        -- Write port 2 (from the AES Core)
        if WrEn2 = '1' then
            -- write four words, i.e. 128 bit
            for i in 0 to 3 loop
                mem(to_integer(unsigned(WrAddr2(ADDR_WIDTH-1 downto 2))+i)) <= WrData2(127-i*32 downto 96-i*32);
            end loop;
        end if;
        -- Clear susp register when unit is disabled TODO necessary?
        if En = '0' and prevEn = '1' then
            for i in ADDR_SUSPR0/4 to ADDR_SUSPR3/4 loop
                mem(i) <= (others => '0');
            end loop;
        end if;
    end if;
end if;
end process;


end Behavioral;
