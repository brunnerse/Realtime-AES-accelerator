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
modeSignal <= mem(ADDR_CR/4)(4 downto 3);
mode <= modeSignal;
chainingModeSignal <= mem(ADDR_CR/4)(6 downto 5);
chaining_mode <= chainingModeSignal;
GCMPhaseSignal <= mem(ADDR_CR/4)(14 downto 13);
GCMPhase <= GCMPhaseSignal;
DMAOUTEN <= mem(ADDR_CR/4)(12);
DMAINEN <= mem(ADDR_CR/4)(11);
ERRIE <= mem(ADDR_CR/4)(10);
CCFIE <= mem(ADDR_CR/4)(9);
ERRC <= mem(ADDR_CR/4)(8);
CCFC <= mem(ADDR_CR/4)(7);


-- set unused status flags to 0 for now 
BUSY <= '0';


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
                    CCf <= '0';
                    -- If mode is keyexpansion or the GCM init mode, start the AES Core immediately, no data reading required
                    if modeSignal = MODE_KEYEXPANSION or (chainingModeSignal = CHAINING_MODE_GCM and GCMPhaseSignal = GCM_PHASE_INIT) then
                        EnICore <= '1';
                        state <= Computing;
                    else
                        -- start read data transaction
                        RW_addr <= mem(ADDR_DINADDR/4);
                        RW_write <= '0';
                        RW_valid <= '1';
                        state <= Fetch;
                    end if;
                end if;
            when Fetch =>
                -- wait until data were received
                if RW_ready = '1' then
                    -- reset valid signal
                    RW_valid <= '0';
                    RDERR <= RDERR or RW_error;
                    DIN <= RW_rdData;
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
                        (chainingModeSignal = CHAINING_MODE_GCM and (GCMPhaseSignal = GCM_PHASE_INIT or GCMPhaseSignal = GCM_PHASE_HEADER)) then
                        -- set signals that computation has finished
                        -- TODO in Header phase, check if at the end before setting CCF
                        CCF <= '1';
                        interrupt <= '1';
                        state <= Idle;
                    else
                        RW_addr <= mem(ADDR_DOUTADDR/4);
                        RW_write <= '1';
                        RW_wrData <= DOUT;
                        RW_valid <= '1';
                        state <= Writeback;
                   end if;
                end if;
            when Writeback =>
                 if RW_ready = '1' then
                    -- reset valid signal
                    RW_valid <= '0';  
                    WRERR <= WRERR or RW_error;
                    -- set signals that computation has finished TODO only if at the end! If not at the end, return to computation
                    CCF <= '1';
                    interrupt <= '1';
                    state <= Idle;
                end if;
            when others =>
       end case;
    end if;
end if;
end process;

-- process to store the previous enable signal, so other processes can check if it changed
process(Clock)
begin
    if rising_edge(Clock) then
        prevEn <= En;
    end if;
end process;

-- read process
process (Clock)
begin
if rising_edge(Clock) then
    if RdEn = '1' then
        -- For register SR, don't actually read from memory. This way the register appears read-only
        if RdAddr = std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH)) then
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
        -- TODO reset the enable bit once CCF bit is set
        --if CCF = '1' then
        --    mem(ADDR_CR/4)(0) <= '0';
        --end if;
        -- TODO reset CCFC automatically?
        
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
