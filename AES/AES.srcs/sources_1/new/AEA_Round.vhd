----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.08.2022 16:38:31
-- Design Name: 
-- Module Name: AEA_Round - Behavioral
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


entity AEA_Round is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           isLastRound : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end AEA_Round;

architecture Behavioral of AEA_Round is

component SubBytes is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end component;

component ShiftRows is
    Port ( din : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dout : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end component;

component AddRoundKey is
    Port ( din : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dout : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end component;

component MixColumns is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end component;


signal dInARK, dInMC, dInSB, dInSR : std_logic_vector(KEY_SIZE-1 downto 0);
signal dOutARK, dOutMC, dOutSB, dOutSR : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnIARK, EnIMC, EnISB, EnISR : std_logic;
signal EnOARK, EnOMC, EnOSB, EnOSR : std_logic;

begin

roundSB : SubBytes port map(dInSB, dOutSB, encrypt, EnISB, EnOSB, Clock, Reset);
roundSR : ShiftRows port map(dInSR, dOutSR, encrypt, EnISR, EnOSR, Clock, Reset); 
roundMC : MixColumns port map(dInMC, dOutMC, encrypt, EnIMC, EnOMC, Clock, Reset); 
roundARK : AddRoundKey port map(dInARK, dOutARK, key, EnIARK, EnOARK, Clock, Reset);

-- Define data between the components; for decryption, the order is reversed
-- Left side is encryption, right side is decryption
dInSB <= dIn when encrypt = '1' else        dOutSR;
dInSR <= dOutSB when encrypt = '1' else     
                                            dOutMC when isLastRound = '0' else
                                            dOutARK; -- skip MixColumns in the last round
dInMC <= dOutSR when encrypt = '1' else     dOutARK;
dInARK <=                                   dIn when encrypt = '0' else 
    dOutMC when isLastRound = '0' else
    dOutSR; -- Skip MixColumns in the last round
dOut <= dOutARK when encrypt = '1' else     dOutSB;

-- Define the enable signal connections between the components in the same scheme
EnISB <= EnI when encrypt = '1' else        EnOSR;
EnISR <= EnOSB when encrypt = '1' else     
                                            EnOMC when isLastRound = '0' else
                                            EnOARK; -- skip MixColumns in the last round
EnIMC <= EnOSR when encrypt = '1' else     EnOARK;
EnIARK <=                                   EnI when encrypt = '0' else 
    EnOMC when isLastRound = '0' else
    EnOSR; -- Skip MixColumns in the last round
EnO <= EnOARK when encrypt = '1' else     EnOSB;


end Behavioral;
