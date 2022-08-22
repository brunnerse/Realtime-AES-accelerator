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
-- global signals
    Clock    : in std_logic;
    RESETn   : in std_logic;
-- Ports to the AHB interface: Classic register ports
    RdEn : in std_logic;  -- signal to indicate a read access
    RdAddr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    RdData : out std_logic_vector(DATA_WIDTH-1 downto 0);
    -- define two write ports
    WrEn1 : in std_logic;
    WrAddr1 : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    WrData1: in std_logic_vector(DATA_WIDTH-1 downto 0);
    WrEn2 : in std_logic;
    WrAddr2 : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    WrData2 : in std_logic_vector(KEY_SIZE-1 downto 0);
-- Ports to the AES Core
    key : out std_logic_vector (KEY_SIZE-1 downto 0);
    IV : out std_logic_vector (KEY_SIZE-1 downto 0);
    H : out std_logic_vector (KEY_SIZE-1 downto 0);
    Susp : out std_logic_vector (KEY_SIZE-1 downto 0);
    DIN : out std_logic_vector (KEY_SIZE-1 downto 0);
    DOUT : in std_logic_vector (KEY_SIZE-1 downto 0);
-- Control to AES core
    EnICore : out std_logic;
    EnOCore : in std_logic;
    mode : out std_logic_vector (1 downto 0);
    chaining_mode : out std_logic_vector (2 downto 0);
    GCMPhase : out std_logic_vector(1 downto 0)
  );
end ControlLogic;

architecture Behavioral of ControlLogic is


signal En, prevEn : std_logic;

-- status signals TODO anything other than CCF needed?
signal BUSY, WRERR, RDERR, CCF : std_logic;
-- control signals
signal DMAOUTEN, DMAINEN, ERRIE, CCFIE, ERRC, CCFC : std_logic;

-- Define registers as array
type addr_range is array (0 to ADDR_SUSPR7/4) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal mem : addr_range;

-- Define 128-bit signals for data in and data out
signal dataIn, dataOut : std_logic_vector(KEY_SIZE-1 downto 0);

signal readCounter, writeCounter : unsigned(1 downto 0);
signal modeSignal : std_logic_vector(1 downto 0);

begin

-- connect memory addresses
DIN <= dataIn;
dataOut <= DOUT;

key <= mem(ADDR_KEYR0/4) & mem(ADDR_KEYR1/4) & mem(ADDR_KEYR2/4) & mem(ADDR_KEYR3/4);
IV <= mem(ADDR_IVR0/4) & mem(ADDR_IVR1/4) & mem(ADDR_IVR2/4) & mem(ADDR_IVR3/4);
Susp <=  mem(ADDR_SUSPR0/4) & mem(ADDR_SUSPR1/4) & mem(ADDR_SUSPR2/4) & mem(ADDR_SUSPR3/4);
H <=  mem(ADDR_SUSPR4/4) & mem(ADDR_SUSPR5/4) & mem(ADDR_SUSPR6/4) & mem(ADDR_SUSPR7/4);

-- set AES control signals
En <= mem(ADDR_CR/4)(0);
modeSignal <= mem(ADDR_CR/4)(4 downto 3);
mode <= modeSignal;
chaining_mode <= mem(ADDR_CR/4)(16) & mem(ADDR_CR/4)(6 downto 5);
DMAOUTEN <= mem(ADDR_CR/4)(12);
DMAINEN <= mem(ADDR_CR/4)(11);
ERRIE <= mem(ADDR_CR/4)(10);
CCFIE <= mem(ADDR_CR/4)(9);
ERRC <= mem(ADDR_CR/4)(8);
CCFC <= mem(ADDR_CR/4)(7);
GCMPhase <= mem(ADDR_CR/4)(14 downto 13);


-- set unused status flags to 0 for now 
BUSY <= '0';
WRERR <= '0';
RDERR <= '0';


-- driver process for CCF status signal
process (Resetn, EnOCore, En, CCFC)
begin
if Resetn = '0' or CCFC = '1' or En = '0' then -- Clear flag when CCFC is set, reset is asserted or module is disabled
    CCF <= '0';
elsif EnOCore = '1' then
    CCF <= '1'; -- Set CCF flag whenever the Core finished a calculation
end if;
end process;

-- read process;
process (Clock, Resetn)
begin
if Resetn = '0' then -- reset counter when unit is disabled
    readCounter <= "00";
elsif rising_edge(Clock) then
    if RdEn = '1' then
        -- For registers DOUTR and SR, don't actually read from memory. This way the registers appear read-only
        if RdAddr =  std_logic_vector(to_unsigned(ADDR_DOUTR, ADDR_WIDTH)) then
            RdData <= dataOut(127-to_integer(readCounter)*32 downto 96-to_integer(readCounter)*32);
            readCounter <= readCounter + to_unsigned(1, 2);
        elsif RdAddr =  std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH)) then
            RdData <= x"0000000" & BUSY & WRERR & RDERR & CCF;
        else
            RdData <= mem(to_integer(unsigned(RdAddr(ADDR_WIDTH-1 downto 2)))); -- divide address by four, as array is indexed word-wise
        end if;
    end if;
    -- Reset counter when unit is disabled
    if En = '0' and prevEn = '1' then
        readCounter <= "00";
    end if;
end if;
end process;

process(Clock)
begin
    if rising_edge(Clock) then
        prevEn <= En;
    end if;
end process;

-- write process
process (Clock, Resetn)
begin
if Resetn = '0' then
    for i in 0 to ADDR_SUSPR7/4 loop
        mem(i) <= (others => '0');
    end loop;
    writeCounter <= "00";
    EnICore <= '0';
elsif rising_edge(Clock) then
    EnICore <= '0';
    -- Only Write if address is not the read-only registers SR and DOUTR
    if WrEn1 = '1' then
        mem(to_integer(unsigned(WrAddr1(ADDR_WIDTH-1 downto 2)))) <= WrData1;
        -- Remember write accesses to DINR, start the AES Core after four write accesses
        if En = '1' and WrAddr1 = std_logic_vector(to_unsigned(ADDR_DINR, ADDR_WIDTH)) then
            writeCounter <= writeCounter + to_unsigned(1,2);
            dataIn(127-to_integer(writeCounter)*32 downto 96-to_integer(writeCounter)*32) <= WrData1;
            if writeCounter = to_unsigned(3,2) then
                -- All four bytes have been written, enable the AES Core
                EnICore <= '1';
            end if;
        end if;
    end if;
    if WrEn2 = '1' then
        -- write four words, i.e. 128 bit
        mem(to_integer(unsigned(WrAddr2(ADDR_WIDTH-1 downto 2)))) <= WrData2(127 downto 96);
        mem(to_integer(unsigned(WrAddr2(ADDR_WIDTH-1 downto 2)))+1) <= WrData2(95 downto 64);
        mem(to_integer(unsigned(WrAddr2(ADDR_WIDTH-1 downto 2)))+2) <= WrData2(63 downto 32);
        mem(to_integer(unsigned(WrAddr2(ADDR_WIDTH-1 downto 2)))+3) <= WrData2(31 downto 0);
    end if;
    -- Reset counter and clear susp register when unit is disabled
    if En = '0' and prevEn = '1' then
        writeCounter <= "00";
        for i in ADDR_SUSPR0/4 to ADDR_SUSPR3/4 loop
            mem(i) <= (others => '0');
        end loop;
    end if;
    -- If mode is keyexpansion, start the AES Core without waiting for the four write accesses
    if modeSignal = MODE_KEYEXPANSION and En = '1' and prevEn = '0' then
        EnICore <= '1';
    end if;
end if;
end process;


end Behavioral;
