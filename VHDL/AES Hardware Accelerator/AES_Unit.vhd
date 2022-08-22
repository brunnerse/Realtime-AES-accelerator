
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.ALL;
use work.addresses.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity AES_Unit is
  Port ( 
    --  AHB Interface ports 
     s_ahb_hclk        : in std_logic;
     s_ahb_hresetn     : in std_logic;                     
     s_ahb_hsel        : in  std_logic;
       
     s_ahb_haddr       : in  std_logic_vector(31 downto 0); 
     s_ahb_hprot       : in  std_logic_vector(3 downto 0); -- Protection control is ignored
     s_ahb_htrans      : in  std_logic_vector(1 downto 0); 
     s_ahb_hsize       : in  std_logic_vector(2 downto 0); 
     s_ahb_hwrite      : in  std_logic; 
     s_ahb_hburst      : in  std_logic_vector(2 downto 0 );
     s_ahb_hwdata      : in  std_logic_vector(31 downto 0 );
     s_ahb_hready      : out  std_logic; 
                      
     s_ahb_hrdata      : out std_logic_vector(31 downto 0 );
     s_ahb_hresp       : out std_logic
  );
end AES_Unit;

architecture Behavioral of AES_Unit is

-- Define ahb ports as xiling AHB_INTERFACE
ATTRIBUTE X_INTERFACE_INFO : STRING;
ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hresp: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE HRESP";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hrdata: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE HRDATA";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hready: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE HREADY";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hwdata: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE HWDATA";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hburst: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE HBURST";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hwrite: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE HWRITE";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hsize: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE HSIZE";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_htrans: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE HTRANS";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hprot: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE HPROT";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_haddr: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE HADDR";
ATTRIBUTE X_INTERFACE_PARAMETER OF s_ahb_hsel: SIGNAL IS "XIL_INTERFACENAME AHB_INTERFACE, BD_ATTRIBUTE.TYPE INTERIOR";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hsel: SIGNAL IS "xilinx.com:interface:ahblite:2.0 AHB_INTERFACE SEL";
ATTRIBUTE X_INTERFACE_PARAMETER OF s_ahb_hresetn: SIGNAL IS "XIL_INTERFACENAME AHB_RESETN, POLARITY ACTIVE_LOW, INSERT_VIP 0";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hresetn: SIGNAL IS "xilinx.com:signal:reset:1.0 AHB_RESETN RST";
ATTRIBUTE X_INTERFACE_PARAMETER OF s_ahb_hclk: SIGNAL IS "XIL_INTERFACENAME AHB_CLK, ASSOCIATED_BUSIF AHB_INTERFACE:M_AXI, ASSOCIATED_RESET s_ahb_hresetn, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0";
ATTRIBUTE X_INTERFACE_INFO OF s_ahb_hclk: SIGNAL IS "xilinx.com:signal:clock:1.0 AHB_CLK CLK";



signal WrDataAHB, RdDataAHB, WrAddrAHB, RdAddrAHB, WrAddrCore : std_logic_vector(DATA_WIDTH-1 downto 0);
signal WrDataCore : std_logic_vector(KEY_SIZE-1 downto 0);
signal WrEnAHB, RdEnAHB, WrEnCore : std_logic;

-- signals between ControlLogic and Core
signal key, IV, DIN, DOUT, H, Susp : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnICore, EnOCore : std_logic;
signal mode, GCMPhase : std_logic_vector(1 downto 0);
signal chaining_mode : std_logic_vector(2 downto 0);

begin


i_AHB_Interface : entity work.AHB_Interface(Behavioral) 
    generic map(ADDR_BASE => ADDR_BASE)
    port map(
        s_ahb_hclk, s_ahb_hresetn, s_ahb_hsel, s_ahb_haddr, s_ahb_hprot,s_ahb_htrans, s_ahb_hsize, 
        s_ahb_hwrite, s_ahb_hburst, s_ahb_hwdata, s_ahb_hready, s_ahb_hrdata, s_ahb_hresp,
        WrDataAHB, RdDataAHB, WrAddrAHB, RdAddrAHB, WrEnAHB, RdEnAHB
     );

i_ControlLogic : entity work.ControlLogic(Behavioral)
    port map(
        s_ahb_hclk, s_ahb_hresetn, RdEnAHB, RdAddrAHB, RdDataAHB, 
        WrEnAHB, WrAddrAHB, WrDataAHB, WrEnCore, WrAddrCore, WrDataCore,
        key, IV, H, Susp, DIN, DOUT, EnOCore, EnICore, mode, chaining_mode, GCMPhase
    );

i_Core : entity work.AES_Core(Behavioral)
    generic map (ADDR_IV => ADDR_IVR0,
                ADDR_SUSP => ADDR_SUSPR0,
                ADDR_H => ADDR_SUSPR4)
    port map (
        key, IV, H, Susp, WrEnCore, WrAddrCore, WrDataCore, DIN, DOUT, EnICore, EnOCore,
        mode, chaining_mode, GCMPhase, s_ahb_hclk, s_ahb_hresetn
    );




end Behavioral;
