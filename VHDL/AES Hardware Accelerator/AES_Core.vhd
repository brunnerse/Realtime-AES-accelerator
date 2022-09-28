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
    generic (
        ADDR_IV : integer;
        ADDR_SUSP : integer;
        ADDR_H  : integer
        );
    Port ( Key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           H  : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           Susp : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
           WrData : out STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in std_logic;
           EnO : out std_logic;
           mode : in std_logic_vector (MODE_LEN-1 downto 0);
           chaining_mode : in std_logic_vector (CHMODE_LEN-1 downto 0);
           GCMPhase : in std_logic_vector(1 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end AES_Core;

architecture Behavioral of AES_Core is

component AddRoundKey is
    Port ( din : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dout : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;

component PipelinedAEA is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
	       keyExpandFlag : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;
component AEA is
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           key : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
	       keyExpandFlag : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;

component AES_Mode_ECBCBCCTR is
    generic (
        ADDR_IV : integer
        );
    Port (
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in std_logic;
           EnO : out std_logic;
           encrypt : in std_logic;
            -- signals to control the AEA unit
           EnIAEA : out std_logic;
           EnOAEA : in std_logic;
           dInAEA : out std_logic_vector (KEY_SIZE-1 downto 0);
           dOutAEA : in std_logic_vector (KEY_SIZE-1 downto 0);
           -- signals to write to register set
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
           WrData : out STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
           mode : in std_logic_vector (MODE_LEN-1 downto 0);
           chaining_mode : in std_logic_vector (CHMODE_LEN-1 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end component;

component AES_Mode_GCM is
    generic (
        ADDR_IV : integer;
        ADDR_SUSP : integer;
        ADDR_H  : integer
        );
    Port (
           IV : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           -- specific signals for GCM mode
           H  : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           Susp : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0); -- for the first block, this signals MUST be 0
           dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           EnI : in std_logic;
           EnO : out std_logic;
           encrypt : in std_logic;
           GCMPhase : in std_logic_vector(1 downto 0);
           -- signals to control the AEA unit
           EnIAEA : out std_logic;
           EnOAEA : in std_logic;
           dInAEA : out std_logic_vector (KEY_SIZE-1 downto 0);
           dOutAEA : in std_logic_vector (KEY_SIZE-1 downto 0);
           -- signals to write to register set
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
           WrData : out STD_LOGIC_VECTOR(KEY_SIZE-1 downto 0);
           Clock : in std_logic;
           Resetn : in std_logic
           );
end component;



-- signal definitions
signal dInAEA, dOutAEA : std_logic_vector(KEY_SIZE-1 downto 0);
signal encryptAEA, EnIAEA, EnOAEA, keyExpandFlagAEA : std_logic;

-- signal to mode components
signal EnIMNT, EnIGCM, EnOMNT, EnOGCM, EnIAEAMNT, EnIAEAGCM, EnOAEAMNT, EnOAEAGCM, WrEnMNT, WrEnGCM : std_logic;
signal dOutMNT, dOutGCM, newIVGCM, dInAEAMNT, dInAEAGCM, WrDataMNT, WrDataGCM : std_logic_vector(KEY_SIZE-1 downto 0);
signal WrAddrMNT, WrAddrGCM : std_logic_vector(ADDR_WIDTH-1 downto 0);
begin

algorithm : AEA port map (dInaEA, dOutAEA, Key, encryptAEA, keyExpandFlagAEA, EnIAEA, EnOAEA, Clock, Resetn);

modeNonTag : AES_Mode_ECBCBCCTR 
            generic map(ADDR_IV)
            port map(IV, dIn, dOutMNT, EnIMNT, EnOMNT, encryptAEA, 
                     EnIAEAMNT, EnOAEAMNT, dInAEAMNT, dOutAEA, 
                     WrEnMNT, WrAddrMNT, WrDataMNT, mode, chaining_mode, Clock, Resetn); 
--modeGCM  : AES_Mode_GCM 
--            generic map (ADDR_IV, ADDR_SUSP, ADDR_H)
--            port map(IV, H, Susp, dIn, dOutGCM, EnIGCM, EnOGCM, not mode(1), GCMPhase, 
--                     EnIAEAGCM, EnOAEAGCM, dInAEAGCM, dOutAEA, 
--                     WrEnGCM, WrAddrGCM, WrDataGCM,Clock, Resetn); 


-- Set encrypt and keyExpandFlag signals according to the mode
encryptAEA <= not mode(1) when chaining_mode = CHAINING_MODE_ECB or chaining_mode = CHAINING_MODE_CBC else
            '1'; -- always set AEA unit to encryption in CTR or GCMmode
keyExpandFlagAEA <= mode(0) when chaining_mode = CHAINING_MODE_ECB or chaining_mode = CHAINING_MODE_CBC else
            '0'; -- never key expand in CTR or GCM mode

EnIGCM <= EnI when chaining_mode = CHAINING_MODE_GCM else
 '0';
with chaining_mode select
EnIMNT <= EnI when CHAINING_MODE_ECB | CHAINING_MODE_CBC | CHAINING_MODE_CTR,
          '0' when others;

--  forward the data from the Mode Unit to the AEA      
EnIAEA <=   EnIAEAGCM when chaining_mode = CHAINING_MODE_GCM else
            EnIAEAMNT;
dInAEA <=   dInAEAGCM when chaining_mode = CHAINING_MODE_GCM else
            dInAEAMNT;
            
-- activate the Mode Unit again after the AEA finished
EnOAEAGCM <=    EnOAEA when chaining_mode = CHAINING_MODE_GCM else
                '0';
with chaining_mode select
EnOAEAMNT <=    EnOAEA when CHAINING_MODE_ECB | CHAINING_MODE_CBC | CHAINING_MODE_CTR,
                '0' when others;

-- forward the final data from the Mode Unit to the outputs
EnO <=      EnOGCM when chaining_mode = CHAINING_MODE_GCM else
            EnOMNT;
dOut <=     dOutGCM when chaining_mode = CHAINING_MODE_GCM else
            dOutMNT;

-- forward the write signals of the modes
WrEn <=     WrEnGCM when chaining_mode = CHAINING_MODE_GCM else
            WrEnMNT;
WrData <=   WrDataGCM when chaining_mode = CHAINING_MODE_GCM else
            WrDataMNT;
WrAddr <=   WrAddrGCM when chaining_mode = CHAINING_MODE_GCM else
            WrAddrMNT;       
end Behavioral;
