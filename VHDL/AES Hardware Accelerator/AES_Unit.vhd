
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.ALL;
use work.addresses.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity AES_Unit is
  Generic (
    LITTLE_ENDIAN : boolean := true;
    -- Parameters of Axi Slave Bus Interface S_AXI
    C_S_AXI_ID_WIDTH	: integer	:= 1;
    C_S_AXI_DATA_WIDTH	: integer	:= 32;
    C_S_AXI_ADDR_WIDTH	: integer	:= 10;
    C_S_AXI_AWUSER_WIDTH	: integer	:= 1;
    C_S_AXI_ARUSER_WIDTH	: integer	:= 0;
    C_S_AXI_WUSER_WIDTH	: integer	:= 0;
    C_S_AXI_RUSER_WIDTH	: integer	:= 0;
    C_S_AXI_BUSER_WIDTH	: integer	:= 0;
  );
  Port ( 
	-- Ports of Axi Slave Bus Interface S_AXI
	s_axi_aclk	: in std_logic;
	s_axi_aresetn	: in std_logic;
	s_axi_awid	: in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
	s_axi_awaddr	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	s_axi_awlen	: in std_logic_vector(7 downto 0);
	s_axi_awsize	: in std_logic_vector(2 downto 0);
	s_axi_awburst	: in std_logic_vector(1 downto 0);
	s_axi_awlock	: in std_logic;
	s_axi_awcache	: in std_logic_vector(3 downto 0);
	s_axi_awprot	: in std_logic_vector(2 downto 0);
	s_axi_awqos	: in std_logic_vector(3 downto 0);
	s_axi_awregion	: in std_logic_vector(3 downto 0);
	s_axi_awuser	: in std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0);
	s_axi_awvalid	: in std_logic;
	s_axi_awready	: out std_logic;
	s_axi_wdata	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	s_axi_wstrb	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
	s_axi_wlast	: in std_logic;
	s_axi_wuser	: in std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0);
	s_axi_wvalid	: in std_logic;
	s_axi_wready	: out std_logic;
	s_axi_bid	: out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
	s_axi_bresp	: out std_logic_vector(1 downto 0);
	s_axi_buser	: out std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
	s_axi_bvalid	: out std_logic;
	s_axi_bready	: in std_logic;
	s_axi_arid	: in std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
	s_axi_araddr	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	s_axi_arlen	: in std_logic_vector(7 downto 0);
	s_axi_arsize	: in std_logic_vector(2 downto 0);
	s_axi_arburst	: in std_logic_vector(1 downto 0);
	s_axi_arlock	: in std_logic;
	s_axi_arcache	: in std_logic_vector(3 downto 0);
	s_axi_arprot	: in std_logic_vector(2 downto 0);
	s_axi_arqos	: in std_logic_vector(3 downto 0);
	s_axi_arregion	: in std_logic_vector(3 downto 0);
	s_axi_aruser	: in std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0);
	s_axi_arvalid	: in std_logic;
	s_axi_arready	: out std_logic;
	s_axi_rid	: out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
	s_axi_rdata	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	s_axi_rresp	: out std_logic_vector(1 downto 0);
	s_axi_rlast	: out std_logic;
	s_axi_ruser	: out std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
	s_axi_rvalid	: out std_logic;
	s_axi_rready	: in std_logic;
	-- Interrupt out
	aes_introut : out std_logic
  );
end AES_Unit;

architecture Behavioral of AES_Unit is

signal IWrAddr, IRdAddr, WrAddrCore : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
signal WrDataCore : std_logic_vector(KEY_SIZE-1 downto 0);
signal IWrEn, IRdEn, WrEnCore : std_logic;
signal IWrStrb : std_logic_vector(3 downto 0);

-- signals between ControlLogic and Core
signal key, IV, DIN, DOUT, H, Susp : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnICore, EnOCore : std_logic;

signal mode, GCMPhase : std_logic_vector(1 downto 0);
signal chaining_mode : std_logic_vector(1 downto 0);


begin


i_AES_Interface : entity work.AES_Interface_v1_0(arch_imp)
    generic map (
		LITTLE_ENDIAN	 => LITTLE_ENDIAN,
        C_S_AXI_ID_WIDTH	=> C_S_AXI_ID_WIDTH,	
        C_S_AXI_DATA_WIDTH	=> C_S_AXI_DATA_WIDTH,	
        C_S_AXI_ADDR_WIDTH	=> C_S_AXI_ADDR_WIDTH,	
        C_S_AXI_AWUSER_WIDTH => C_S_AXI_AWUSER_WIDTH,	
        C_S_AXI_ARUSER_WIDTH => C_S_AXI_ARUSER_WIDTH,	
        C_S_AXI_WUSER_WIDTH	=> C_S_AXI_WUSER_WIDTH,	
        C_S_AXI_RUSER_WIDTH	=> C_S_AXI_RUSER_WIDTH,	
        C_S_AXI_BUSER_WIDTH	=> C_S_AXI_BUSER_WIDTH,	
    port map (
        RdEn => IRdEn,
        RdAddr => IRdAddr,
        RdData => IRdData, 
        WrEn => IWrEn,
        WrAddr => IWrAddr, 
        WrData => IWrData,
        WrStrb => IWrStrb,
        -- Slave AXI port
        s_axi_aclk => s_axi_aclk,
		s_axi_aresetn => s_axi_aresetn,
		s_axi_awid => s_axi_awid,
		s_axi_awaddr => s_axi_awaddr,
		s_axi_awlen => s_axi_awlen,
		s_axi_awsize => s_axi_awsize,
		s_axi_awburst => s_axi_awburst,
		s_axi_awlock => s_axi_awlock,
		s_axi_awcache => s_axi_awcache,
		s_axi_awprot => s_axi_awprot,
		s_axi_awqos => s_axi_awqos,
		s_axi_awregion => s_axi_awregion,
		s_axi_awuser => s_axi_awuser,
		s_axi_awvalid => s_axi_awvalid,
		s_axi_awready => s_axi_awready,
		s_axi_wdata => s_axi_wdata,
		s_axi_wstrb => s_axi_wstrb,
		s_axi_wlast => s_axi_wlast,
		s_axi_wuser => s_axi_wuser,
		s_axi_wvalid => s_axi_wvalid,
		s_axi_wready => s_axi_wready,
		s_axi_bid => s_axi_bid,
		s_axi_bresp => s_axi_bresp,
		s_axi_buser => s_axi_buser,
		s_axi_bvalid => s_axi_bvalid,
		s_axi_bready => s_axi_bready,
		s_axi_arid => s_axi_arid,
		s_axi_araddr => s_axi_araddr,
		s_axi_arlen => s_axi_arlen,
		s_axi_arsize => s_axi_arsize,
		s_axi_arburst => s_axi_arburst,
		s_axi_arlock => s_axi_arlock,
		s_axi_arcache => s_axi_arcache,
		s_axi_arprot => s_axi_arprot,
		s_axi_arqos => s_axi_arqos,
		s_axi_arregion => s_axi_arregion,
		s_axi_aruser => s_axi_aruser,
		s_axi_arvalid => s_axi_arvalid,
		s_axi_arready => s_axi_arready,
		s_axi_rid => s_axi_rid,
		s_axi_rdata => s_axi_rdata,
		s_axi_rresp => s_axi_rresp,
		s_axi_rlast => s_axi_rlast,
		s_axi_ruser => s_axi_ruser,
		s_axi_rvalid => s_axi_rvalid,
		s_axi_rready => s_axi_rready,
     );


    
i_ControlLogic : entity work.ControlLogic(Behavioral)
    port map(
        RdEn => IRdEn,
        RdAddr => IRdAddr,
        RdData => IRdData, 
        WrEn1 => IWrEn,
        WrAddr1 => IWrAddr,
        WrData1 => IWrData,
        WrStrb1 => IWrStrb,
        WrEn2 => WrEnCore,
        WrAddr2 => WrAddrCore,
        WrData2 => WrDataCore, 
        key => key,
        IV => IV,
        H => H,
        Susp => Susp,
        DIN => DIN,
        DOUT => DOUT,
        EnOCore => EnOCore,
        EnICore => EnICore,
        mode => mode,
        chaining_mode => chaining_mode,
        GCMPhase => GCMPhase,
        interrupt => aes_introut,
        Clock => s_axi_aclk,
        Resetn => s_axi_aresetn
    );

i_Core : entity work.AES_Core(Behavioral)
    generic map (
        ADDR_IV => ADDR_IVR0,
        ADDR_SUSP => ADDR_SUSPR0,
        ADDR_H => ADDR_HR0)
    port map (
        key => key,
        IV => IV,
        H => H,
        Susp => Susp,
        WrEn => WrEnCore,
        WrAddr => WrAddrCore,
        WrData => WrDataCore,
        DIN => DIN,
        DOUT => DOUT,
        EnI => EnICore,
        EnO => EnOCore,
        mode => mode,
        chaining_mode => chaining_mode,
        GCMPhase => GCMPhase,
        Clock => s_axi_aclk,
        Resetn => s_axi_aresetn
    );

end Behavioral;
