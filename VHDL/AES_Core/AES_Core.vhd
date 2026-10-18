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
use work.addresses.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity AES_Core is
    generic (
        ADDR_IV : integer := ADDR_IVR0;
        ADDR_SUSP : integer := ADDR_SUSPR0;
        ADDR_H  : integer := ADDR_HR0
        );
    Port ( Key : in key_t;
           IV : in block_t;
           H  : in block_t;
           Susp : in block_t;
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_REGISTER_BITS-1 downto 0);
           WrData : out block_t;
           dIn : in block_t;
           dOut : out block_t;
           EnI : in std_logic;
           EnO : out std_logic;
-- keysize : in std_logic_vector(MODE_LEN-1 downto 0)
           mode : in mode_t;
           chaining_mode : in mode_t; 
           GCMPhase : in mode_t; 
           Clock : in std_logic;
           Resetn : in std_logic
           );
end AES_Core;

architecture Behavioral of AES_Core is

-- Give the interface ports attributes so Vivado recognizes them as interface
ATTRIBUTE X_INTERFACE_INFO : STRING;
ATTRIBUTE X_INTERFACE_INFO of WrEn: SIGNAL is
    "xilinx.com:user:ReadWritePort:1.0 M_WritePort_127 WrEn";
ATTRIBUTE X_INTERFACE_INFO of WrData: SIGNAL is
"xilinx.com:user:ReadWritePort:1.0 M_WritePort_127 WrData";
ATTRIBUTE X_INTERFACE_INFO of WrAddr: SIGNAL is
"xilinx.com:user:ReadWritePort:1.0 M_WritePort_127 WrAddr";


component AEA is
    Port ( dIn : in block_t;
           dOut : out block_t;
           key : in key_t;
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
           IV : in block_t;
           dIn : in block_t;
           dOut : out block_t;
           EnI : in std_logic;
           EnO : out std_logic;
            -- signals to control the AEA unit
           EnIAEA : out std_logic;
           EnOAEA : in std_logic;
           dInAEA : out block_t; 
           dOutAEA : in block_t; 
           -- signals to write to register set
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_REGISTER_BITS-1 downto 0);
           WrData : out block_t;
           mode : in mode_t; 
           chaining_mode : in mode_t; 
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
           IV : in block_t;
           -- specific signals for GCM mode
           H  : in block_t;
           Susp : in block_t; -- for the first block, this signals MUST be 0
           dIn : in block_t;
           dOut : out block_t;
           EnI : in std_logic;
           EnO : out std_logic;
           encrypt : in std_logic;
           GCMPhase : in mode_t; 
           -- signals to control the AEA unit
           EnIAEA : out std_logic;
           EnOAEA : in std_logic;
           dInAEA : out block_t ;
           dOutAEA : in block_t; 
           -- signals to write to register set
           WrEn   : out STD_LOGIC;
           WrAddr : out STD_LOGIC_VECTOR(ADDR_REGISTER_BITS-1 downto 0);
           WrData : out block_t;
           Clock : in std_logic;
           Resetn : in std_logic
           );
end component;



-- signal definitions
signal dInAEA, dOutAEA : block_t;
signal encryptGCM, encryptAEA, EnIAEA, EnOAEA, keyExpandFlagAEA : std_logic;

-- signal to mode components
signal EnIMNT, EnIGCM, EnOMNT, EnOGCM, EnIAEAMNT, EnIAEAGCM, EnOAEAMNT, EnOAEAGCM, WrEnMNT, WrEnGCM : std_logic;
signal dOutMNT, dOutGCM, dInAEAMNT, dInAEAGCM, WrDataMNT, WrDataGCM : block_t;
signal WrAddrMNT, WrAddrGCM : std_logic_vector(ADDR_REGISTER_BITS-1 downto 0);
begin

algorithm : AEA port map (dInaEA, dOutAEA, Key, encryptAEA, keyExpandFlagAEA, EnIAEA, EnOAEA, Clock, Resetn);

modeNonTag : AES_Mode_ECBCBCCTR 
            generic map(ADDR_IV => ADDR_IV)
            port map(IV, dIn, dOutMNT, EnIMNT, EnOMNT,
                     EnIAEAMNT, EnOAEAMNT, dInAEAMNT, dOutAEA, 
                     WrEnMNT, WrAddrMNT, WrDataMNT, mode, chaining_mode, Clock, Resetn); 
modeGCM  : AES_Mode_GCM 
            generic map (ADDR_IV => ADDR_IV,
                        ADDR_SUSP => ADDR_SUSP, 
                        ADDR_H => ADDR_H)
            port map(IV => IV, H => H, Susp => Susp,
                     dIn => dIn, dOut => dOutGCM, EnI => EnIGCM, EnO => EnOGCM, 
                     encrypt => encryptGCM, GCMPhase => GCMPhase, 
                     EnIAEA => EnIAEAGCM, EnOAEA => EnOAEAGCM, dInAEA => dInAEAGCM, dOutAEA => dOutAEA, 
                     WrEn => WrEnGCM, WrAddr => WrAddrGCM, WrData => WrDataGCM,
                     Clock => Clock, Resetn => Resetn); 

-- signal GCM unit whether to apply encryption or decryption
encryptGCM <= not mode(1);
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
