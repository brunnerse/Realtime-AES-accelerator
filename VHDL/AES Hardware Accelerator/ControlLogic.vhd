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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;




entity ControlLogic is
  Port ( 
-- global signals
    RESETn   : in std_logic;
-- Ports to the AHB interface
    AES_KEYRx   : in std_logic_vector (KEY_SIZE-1 downto 0);
    AES_IVRx    : in std_logic_vector (KEY_SIZE-1 downto 0);
    AES_SR  : out std_logic_vector (31 downto 0);
    AES_CR : in std_logic_vector (31 downto 0);
    AES_DINR : in std_logic_vector (31 downto 0);
    AES_DOUTR : out std_logic_vector (31 downto 0);
-- Ports to the AES Core
    key : out std_logic_vector (KEY_SIZE-1 downto 0);
    IV : out std_logic_vector (KEY_SIZE-1 downto 0);
    DIN : out std_logic_vector (KEY_SIZE-1 downto 0); -- TODO 32 oder 128 bit?
    DOUT : in std_logic_vector (KEY_SIZE-1 downto 0);
-- Control to AES core
    enCoreOut : out std_logic;
    enCoreIn : in std_logic;
    mode : out std_logic_vector (1 downto 0);
    chaining_mode : out std_logic_vector (2 downto 0)
  );
end ControlLogic;

architecture Behavioral of ControlLogic is


-- TODO Was mit SUSPRx anfangen?
signal AES_SUSPRx  : std_logic_vector (31 downto 0);

-- status signals TODO anything other than CCF needed?
signal BUSY, WRERR, RDERR, CCF : std_logic;
-- control signals
signal DMAOUTEN, DMAINEN, ERRIE, CCFIE, ERRC, CCFC : std_logic;

begin

-- connect inputs with outputs
DIN <= AES_DINR & x"000000000000000000000000"; -- TODO DIn is written by four consecutive writes to DINR
AES_DOUTR <= (others => '0'); -- TODO Dout is written by four consecutive reads to DOUT
key <= AES_KEYRx;
IV <= AES_IVRx;

-- set AES control signals
enCoreOut <= AES_CR(0);
mode <= AES_CR(4 downto 3);
chaining_mode <= AES_CR(16) & AES_CR(6 downto 5);
DMAOUTEN <= AES_CR(12);
DMAINEN <= AES_CR(11);
ERRIE <= AES_CR(10);
CCFIE <= AES_CR(9);
ERRC <= AES_CR(8);
CCFC <= AES_CR(7);

-- set status signal
AES_SR <= x"0000000" & BUSY & WRERR & RDERR & CCF;

-- set unused status flags to 0 for now 
BUSY <= '0';
WRERR <= '0';
RDERR <= '0';


-- driver process for CCF status signal
process (RESETn, EnCoreIn, CCFC)
begin
if RESETn = '0' or CCFC = '1' then -- Clear flag when CCFC is set or reset is asserted
    CCF <= '0';
elsif EnCoreIn = '1' then
    CCF <= '1';
end if;
end process;



end Behavioral;
