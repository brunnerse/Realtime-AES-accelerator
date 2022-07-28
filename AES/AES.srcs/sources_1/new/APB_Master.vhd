----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2022 13:34:51
-- Design Name: 
-- Module Name: APB_Master - Behavioral
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

entity APB_Master is
    Port (
           m_apb_paddr : out std_logic_vector (31 downto 0);
           m_apb_penable : out std_logic;
           m_apb_pprot : out std_logic_vector (2 downto 0);
           m_apb_prdata : in std_logic_vector (31 downto 0);
           m_apb_pready : in std_logic_vector (3 downto 0);

           m_apb_psel : out std_logic_vector (3 downto 0);
           m_apb_pslverr : in std_logic (3 downto 0);
           m_apb_pstrb : out std_logic_vector (3 downto 0);
           m_apb_pwdata : out std_logic_vector (31 downto 0);
           m_apb_pwrite : out std_logic;
--         s_apb_PWAKEUP : in STD_LOGIC;
--         s_apb_PAUSER : in STD_LOGIC_VECTOR (0 downto 0);
--         s_apb_PWUSER : in STD_LOGIC_VECTOR (0 downto 0);
--         s_apb_PRUSER : in STD_LOGIC_VECTOR (0 downto 0);
--         s_apb_PBUSER : in STD_LOGIC_VECTOR (0 downto 0);

          clk : in std_logic;
          resetn : in std_logic
    );
end APB_Master;

architecture Behavioral of APB_Master is

begin


end Behavioral;
