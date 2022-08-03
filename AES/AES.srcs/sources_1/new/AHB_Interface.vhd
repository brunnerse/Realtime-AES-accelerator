----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2022 01:11:18
-- Design Name: 
-- Module Name: AHB_Interface - Behavioral
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
use IEEE.std_logic_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AHB_Interface is
    Port ( 
-- to AHB
   -- global signals
    HCLK    : in std_logic;
    HRESETn : in std_logic;
     -- select
    HSELx : in std_logic;
   -- transfer and control 
    HADDR   : in std_logic_vector(31 downto 0);
    HBURST  : in std_logic_vector(2 downto 0);
    HMASTLOCK : in std_logic;
    HSIZE   : in std_logic_vector (2 downto 0);
    HTRANS  : in std_logic_vector (1 downto 0);
    HWRITE  : in std_logic;
  
    HREADY  : in std_logic;
 -- data in
    HWDATA  : in std_logic_vector(31 downto 0);
  -- transfer response + data out
    HRDATA  : out std_logic_vector(31 downto 0);
    HREADYOUT : out std_logic;
    HRESP : out std_logic;
        
-- to banked registers
    key : out std_logic_vector(31 downto 0);
    IV_or_counter : out std_logic_vector(31 downto 0);
    status : in std_logic_vector(31 downto 0);
    control : out std_logic_vector(31 downto 0);
    data_in : out std_logic_vector(31 downto 0);
    data_out : in std_logic_vector(31 downto 0)
    );
end AHB_Interface;

architecture Behavioral of AHB_Interface is

constant ADDR_BASE : integer(31 downto 0) := 0x00;
constant ADDR_CR_OFFSET : integer(31 downto 0) := 0x00;
constant ADDR_SR_OFFSET : integer(31 downto 0) := 0x04;
constant ADDR_DINR_OFFSET : integer(31 downto 0) := 0x08;
constant ADDR_DOUTR_OFFSET : integer(31 downto 0) := 0x0c;
constant ADDR_KEYR0_OFFSET : integer(31 downto 0) := 0x10;
constant ADDR_KEYR1_OFFSET : integer(31 downto 0) := 0x14;
constant ADDR_KEYR2_OFFSET : integer(31 downto 0) := 0x18;
constant ADDR_KEYR3_OFFSET : integer(31 downto 0) := 0x1c;
constant ADDR_IVR0_OFFSET : integer(31 downto 0) := 0x20;
constant ADDR_IVR1_OFFSET : integer(31 downto 0) := 0x24;
constant ADDR_IVR2_OFFSET : integer(31 downto 0) := 0x28;
constant ADDR_IVR3_OFFSET : integer(31 downto 0) := 0x2c;
constant ADDR_SUSPxR_OFFSET : integer(31 downto 0) := 0x040;


begin

process (HRESETn, HCLK)
begin

if HRESETn = '1' then
    control <= '0';
elsif rising_edge(HCLK) then
    if HSELx = '1' then
    
    end if;
end if;

end process;


end Behavioral;
