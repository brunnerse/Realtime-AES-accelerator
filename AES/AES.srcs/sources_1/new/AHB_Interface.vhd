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
    HCLK    : in std_logic;
    HRESETn : in std_logic;
    HADDR   : in std_logic_vector(31 downto 0);
    HBURST  : in std_logic_vector(2 downto 0);
    HMASTLOCK : in std_logic;
    HSIZE   : in std_logic_vector (2 downto 0);
    HTRANS  : in std_logic_vector (1 downto 0);
    HWDATA  : in std_logic_vector(31 downto 0);
    HWRITE  : in std_logic;
    HRDATA  : out std_logic_vector(31 downto 0);
    HREADYOUT : out std_logic;
    HRESP : out std_logic;
    HSELx : in std_logic;
    HREADY  : in std_logic;
        
-- to banked registers
    key : out std_logic;
    IV_or_counter : out std_logic;
    status : out std_logic;
    control : out std_logic;
    data_in : out std_logic;
    data_out : in std_logic);
end AHB_Interface;

architecture Behavioral of AHB_Interface is

begin



end Behavioral;
