----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2022 01:09:13
-- Design Name: 
-- Module Name: AES_Core - Behavioral
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
use work.common.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity AES_Core is
    Port ( Key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           --SaveRestore : inout std_logic;
           EnI : in std_logic;
           EnO : out std_logic;
           mode : in std_logic_vector (1 downto 0);
           chaining_mode : in std_logic_vector (2 downto 0);
           Clock : in std_logic;
           Reset : in std_logic
           );
end AES_Core;

architecture Behavioral of AES_Core is

component KeyExpansion is
    Port ( userKey : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           roundKeys : out ROUNDKEYARRAY;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end component;

component PipelinedAEA is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end component;


-- constant definitions
constant MODE_ENCRYPTION : std_logic_vector := "00";
constant MODE_KEYEXPANSION : std_logic_vector := "01";
constant MODE_DECRYPTION : std_logic_vector := "10";
constant MODE_KEYEXPANSION_AND_DECRYPT : std_logic_vector := "11";

constant CHAINING_MODE_ECB : std_logic_vector := "000";
constant CHAINING_MODE_CBC : std_logic_vector := "001";
constant CHAINING_MODE_CTR : std_logic_vector := "010";
constant CHAINING_MODE_GCM : std_logic_vector := "011";
-- TODO GMAC?
constant CHAINING_MODE_CCM : std_logic_vector := "100";

-- signal definitions

type state_type is (Idle, Busy);

signal state : state_type;

signal dInAEA, dOutAEA, keyAEA : std_logic_vector(KEY_SIZE-1 downto 0);
signal encryptAEA, EnIAEA, EnOAEA : std_logic;

begin

-- TODO signal KeyExpansionOnly?
algorithm : PipelinedAEA port map (dInaEA, dOutAEA, keyAEA, encryptAEA, EnIAEA, EnOAEA, Clock, Reset);


process (Clock, Reset)
begin
if Reset = '0' then
    dout <= (others => '0');
    state <= Idle;
    EnIAEA <= '0';
    EnO <= '0';
elsif rising_edge(Clock) then
    case state is
        when Idle =>
            -- Start calculation on EnI = '1'
            if EnI = '1' then
                case mode is
                    when MODE_ENCRYPTION =>
                        encryptAEA <= '1';
                        
                    when MODE_KEYEXPANSION =>
                        
                    when MODE_DECRYPTION =>
                        encryptAEA <= '0';
                    when MODE_KEYEXPANSION_AND_DECRYPT =>
                        encryptAEA <= '0';
                end case;
                case chaining_mode is
                    when CHAINING_MODE_ECB =>
                        -- No extra action needed
                    when CHAINING_MODE_CBC =>
                    
                    when CHAINING_MODE_CTR =>
                    
                    when CHAINING_MODE_GCM =>
                    
                    when others =>
                        -- error state? As other modes are not implemented
                end case;
            end if;
        when Busy =>
            -- TODO wait for AEA to finish, then set control bit
    end case;
end if;
end process;


end Behavioral;
