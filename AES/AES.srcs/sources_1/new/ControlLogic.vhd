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
    key0   : in std_logic_vector (31 downto 0);
    key1   : in std_logic_vector (31 downto 0);
    key2   : in std_logic_vector (31 downto 0);
    key3   : in std_logic_vector (31 downto 0);
    IV0   : in std_logic_vector (31 downto 0);
    IV1   : in std_logic_vector (31 downto 0);
    IV2   : in std_logic_vector (31 downto 0);
    IV3   : in std_logic_vector (31 downto 0);
    status : out std_logic_vector (31 downto 0);
    control : in std_logic_vector (31 downto 0);
    data_in : in std_logic_vector (31 downto 0);
    data_out: out std_logic_vector (31 downto 0);
-- Ports to the AES Core
    key : out std_logic_vector (KEY_SIZE-1 downto 0);
    IVI : out std_logic_vector (KEY_SIZE-1 downto 0);
    DIN : out std_logic_vector (KEY_SIZE-1 downto 0); -- TODO 32 oder 128 bit?
    DOUT : in std_logic_vector (KEY_SIZE-1 downto 0);
-- Control to AES core
    en : out std_logic;
    mode : out std_logic_vector (1 downto 0);
    chaining_mode : out std_logic_vector (2 downto 0)
  );
end ControlLogic;

architecture Behavioral of ControlLogic is



signal AES_KEYRx   : std_logic_vector (KEY_SIZE-1 downto 0);
signal AES_IVRx    : std_logic_vector (KEY_SIZE-1 downto 0);
signal AES_SR      : std_logic_vector (31 downto 0);
signal AES_CR      : std_logic_vector (31 downto 0);
signal AES_DINR    : std_logic_vector (31 downto 0);
signal AES_DOUTR   : std_logic_vector (31 downto 0);
signal AES_SUSPRx  : std_logic_vector (31 downto 0);

begin

AES_KEYRx <= key0 & key1 & key2 & key3;
AES_IVRx <= IV0 & IV1 & IV2 & IV3;     

status <= AES_SR;
AES_CR <= control;

AES_DINR <= data_in;
data_out <= AES_DOUTR;

key <= AES_KEYRx;
IVI <= AES_IVRx;

-- set AES control signals
en <= AES_CR(0);
mode <= AES_CR(4 downto 3);
chaining_mode <= AES_CR(6 downto 5);


process (RESETn)
begin
if RESETn = '0' then
    for i in KEY_SIZE-1 downto 0 loop
        AES_KEYRx(i) <= '0';
        AES_IVRx(i) <= '0';
    end loop;
    AES_SR <= x"00000000";
    
end if;
end process;


end Behavioral;
