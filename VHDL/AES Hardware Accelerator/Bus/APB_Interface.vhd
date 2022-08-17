----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2022 13:10:14
-- Design Name: 
-- Module Name: APB_Interface - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity APB_Interface is
    Port (
-- to APB
           s_apb_paddr : in std_logic_vector (31 downto 0);
           s_apb_penable : in std_logic;
           s_apb_pprot : in std_logic_vector (2 downto 0);
           s_apb_prdata : out std_logic_vector (31 downto 0);
           s_apb_pready : out std_logic_vector (3 downto 0);

           s_apb_psel : in std_logic_vector (3 downto 0);
           s_apb_pslverr : out std_logic (3 downto 0);
           s_apb_pstrb : in std_logic_vector (3 downto 0);
           s_apb_pwdata : in std_logic_vector (31 downto 0);
           s_apb_pwrite : in std_logic;
--         s_apb_PWAKEUP : in STD_LOGIC;
--         s_apb_PAUSER : in STD_LOGIC_VECTOR (0 downto 0);
--         s_apb_PWUSER : in STD_LOGIC_VECTOR (0 downto 0);
--         s_apb_PRUSER : in STD_LOGIC_VECTOR (0 downto 0);
--         s_apb_PBUSER : in STD_LOGIC_VECTOR (0 downto 0);

          pclk : in std_logic;
          presetn : in std_logic;



-- to banked registers
           key : out std_logic_vector (31 downto 0);
           iv_or_counter : out std_logic_vector (31 downto 0);
           status : in std_logic;
           control : out std_logic;
           data_in : out std_logic_vector (31 downto 0);
           data_out : in std_logic_vector (31 downto 0));
end APB_Interface;

architecture Behavioral of APB_Interface is

begin

process (pclk, presetn)
begin
if presetn = '0' then 
    control <= '0';
elsif rising_edge(pclk) then
    control <= '1';
end if;
end process;

end Behavioral;
