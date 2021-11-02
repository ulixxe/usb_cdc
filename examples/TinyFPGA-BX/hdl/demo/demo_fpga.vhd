library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity demo is
  port (
    clk    : in    std_logic;           -- 16MHz Clock
    led    : out   std_logic;           -- User LED ON=1, OFF=0
    usb_p  : inout std_logic;           -- USB+
    usb_n  : inout std_logic;           -- USB-
    usb_pu : out   std_logic);          -- USB 1.5kOhm Pullup EN
end entity demo;

architecture fpga of demo is
  constant BIT_SAMPLES : integer                := 4;
  constant DIVF        : bit_vector(6 downto 0) := to_bitvector(std_logic_vector(to_unsigned(12*BIT_SAMPLES-1, 7)));
  signal clk_pll       : std_logic;
  signal clk_1mhz      : std_logic;
  signal clk_2mhz      : std_logic;
  signal clk_4mhz      : std_logic;
  signal clk_8mhz      : std_logic;
  signal lock          : std_logic;
  signal rstn_sync     : std_logic_vector(1 downto 0);
  signal rstn          : std_logic;
  signal up_cnt        : unsigned(20 downto 0);
  signal rx_dp         : std_logic;
  signal rx_dn         : std_logic;
  signal tx_dp         : std_logic;
  signal tx_dn         : std_logic;
  signal tx_en         : std_logic;
  signal out_data      : std_logic_vector(7 downto 0);
  signal out_valid     : std_logic;
  signal in_ready      : std_logic;
  signal in_data       : std_logic_vector(7 downto 0);
  signal in_valid      : std_logic;
  signal out_ready     : std_logic;

  component prescaler is
    port (
      clk_16mhz_i : in  std_logic;
      rstn_i      : in  std_logic;
      clk_1mhz_o  : out std_logic;
      clk_2mhz_o  : out std_logic;
      clk_4mhz_o  : out std_logic;
      clk_8mhz_o  : out std_logic);
  end component prescaler;

  component app is
    port (
      clk_i       : in  std_logic;
      rstn_i      : in  std_logic;
      out_data_i  : in  std_logic_vector(7 downto 0);
      out_valid_i : in  std_logic;
      in_ready_i  : in  std_logic;
      out_ready_o : out std_logic;
      in_data_o   : out std_logic_vector(7 downto 0);
      in_valid_o  : out std_logic);
  end component app;

  component usb_cdc is
    generic (
      VENDORID               : std_logic_vector(15 downto 0) := X"0000";
      PRODUCTID              : std_logic_vector(15 downto 0) := X"0000";
      IN_BULK_MAXPACKETSIZE  : integer                       := 8;
      OUT_BULK_MAXPACKETSIZE : integer                       := 8;
      BIT_SAMPLES            : integer                       := 4;
      USE_APP_CLK            : integer                       := 0;
      APP_CLK_RATIO          : integer                       := 4);
    port (
      app_clk_i   : in  std_logic;
      clk_i       : in  std_logic;
      rstn_i      : in  std_logic;
      out_ready_i : in  std_logic;
      in_data_i   : in  std_logic_vector(7 downto 0);
      in_valid_i  : in  std_logic;
      rx_dp_i     : in  std_logic;
      rx_dn_i     : in  std_logic;
      out_data_o  : out std_logic_vector(7 downto 0);
      out_valid_o : out std_logic;
      in_ready_o  : out std_logic;
      tx_en_o     : out std_logic;
      tx_dp_o     : out std_logic;
      tx_dn_o     : out std_logic);
  end component usb_cdc;

  component SB_PLL40_CORE is
    generic (
      FEEDBACK_PATH                  : string                 := "SIMPLE";  -- SIMPLE/DELAY/PHASE_AND_DELAY/EXTERNAL 
      DELAY_ADJUSTMENT_MODE_FEEDBACK : string                 := "FIXED";  -- FIXED/DYNAMIC  
      DELAY_ADJUSTMENT_MODE_RELATIVE : string                 := "FIXED";  -- FIXED/DYNAMIC 
      SHIFTREG_DIV_MODE              : bit_vector(1 downto 0) := "00";  -- 00 (div by 4)/ 01 (div by 7)/11 (div by 5)     
      FDA_FEEDBACK                   : bit_vector(3 downto 0) := "0000";
      FDA_RELATIVE                   : bit_vector(3 downto 0) := "0000";
      PLLOUT_SELECT                  : string                 := "GENCLK";
      DIVR                           : bit_vector(3 downto 0) := "0000";
      DIVF                           : bit_vector(6 downto 0) := "0000000";
      DIVQ                           : bit_vector(2 downto 0) := "000";
      FILTER_RANGE                   : bit_vector(2 downto 0) := "000";
      ENABLE_ICEGATE                 : bit                    := '0';
      TEST_MODE                      : bit                    := '0';
      EXTERNAL_DIVIDE_FACTOR         : integer                := 1);  -- Required for PLL Config Wizard.
    port (
      REFERENCECLK    : in  std_logic;  -- PLL ref clock, driven by core logic   
      PLLOUTCORE      : out std_logic;  -- PLL output to core logic through local routings. 
      PLLOUTGLOBAL    : out std_logic;  -- PLL output to dedicated global clock network
      EXTFEEDBACK     : in  std_logic;  -- FB driven by core logic
      DYNAMICDELAY    : in  std_logic_vector(7 downto 0);  -- driven by core logic
      LOCK            : out std_logic;  -- PLL Lock signal output  
      BYPASS          : in  std_logic;  -- REFCLK passed to PLLOUT when bypass is '1'.Driven by core logic
      RESETB          : in  std_logic;  -- Active low reset,Driven by core logic
      SDI             : in  std_logic;  -- Test Input. Driven by core logic. 
      SDO             : out std_logic;  -- Test output to RB Logic Tile.
      SCLK            : in  std_logic;  -- Test Clk input.Driven by core logic. 
      LATCHINPUTVALUE : in  std_logic);                    -- iCEGate signal
  end component;

  component SB_IO
    generic (
      NEG_TRIGGER : bit                     := '0';
      PIN_TYPE    : bit_vector (5 downto 0) := "000000";
      PULLUP      : bit                     := '0';
      IO_STANDARD : string                  := "SB_LVCMOS");
    port (
      D_OUT_1           : in    std_logic;
      D_OUT_0           : in    std_logic;
      CLOCK_ENABLE      : in    std_logic;
      LATCH_INPUT_VALUE : in    std_logic;
      INPUT_CLK         : in    std_logic;
      D_IN_1            : out   std_logic;
      D_IN_0            : out   std_logic;
      OUTPUT_ENABLE     : in    std_logic := 'H';
      OUTPUT_CLK        : in    std_logic;
      PACKAGE_PIN       : inout std_ulogic);
  end component;
begin
  -- if FEEDBACK_PATH=SIMPLE, Fpllout=Fref*(DIVF+1)/(2**DIVQ*(DIVR+1))
  u_pll : component SB_PLL40_CORE
    generic map (
      DIVR                           => "0000",
      DIVF                           => DIVF,
      DIVQ                           => "100",
      FILTER_RANGE                   => "001",
      FEEDBACK_PATH                  => "SIMPLE",
      DELAY_ADJUSTMENT_MODE_FEEDBACK => "FIXED",
      FDA_FEEDBACK                   => "0000",
      DELAY_ADJUSTMENT_MODE_RELATIVE => "FIXED",
      FDA_RELATIVE                   => "0000",
      SHIFTREG_DIV_MODE              => "00",
      PLLOUT_SELECT                  => "GENCLK",
      ENABLE_ICEGATE                 => '0')
    port map (
      REFERENCECLK    => clk,
      PLLOUTCORE      => open,
      PLLOUTGLOBAL    => clk_pll,
      EXTFEEDBACK     => '0',
      DYNAMICDELAY    => (others => '0'),
      LOCK            => lock,
      BYPASS          => '0',
      RESETB          => '1',
      SDI             => '0',
      SDO             => open,
      SCLK            => '0',
      LATCHINPUTVALUE => '1');

  u_prescaler : component prescaler
    port map (
      clk_16mhz_i => clk,
      rstn_i      => lock,
      clk_1mhz_o  => clk_1mhz,
      clk_2mhz_o  => clk_2mhz,
      clk_4mhz_o  => clk_4mhz,
      clk_8mhz_o  => clk_8mhz);

  p_rstn : process (clk_1mhz, lock) is
  begin
    if lock = '0' then
      rstn_sync <= (others => '0');
    elsif clk_1mhz'event and clk_1mhz = '1' then
      rstn_sync <= '1' & rstn_sync(1);
    end if;
  end process p_rstn;

  rstn <= rstn_sync(0);

  p_up : process (clk_1mhz, rstn) is
  begin
    if rstn = '0' then
      up_cnt <= (others => '0');
    elsif clk_1mhz'event and clk_1mhz = '1' then
      if up_cnt(up_cnt'high) = '0' then
        up_cnt <= up_cnt + 1;
      end if;
    end if;
  end process p_up;

  led    <= not(up_cnt(up_cnt'high));
  usb_pu <= up_cnt(up_cnt'high);

  u_app : component app
    port map (
      clk_i       => clk_2mhz,
      rstn_i      => rstn,
      out_data_i  => out_data,
      out_valid_i => out_valid,
      in_ready_i  => in_ready,
      out_ready_o => out_ready,
      in_data_o   => in_data,
      in_valid_o  => in_valid);

  u_usb_cdc : component usb_cdc
    generic map (
      VENDORID               => X"1D50",
      PRODUCTID              => X"6130",
      IN_BULK_MAXPACKETSIZE  => 8,
      OUT_BULK_MAXPACKETSIZE => 8,
      BIT_SAMPLES            => BIT_SAMPLES,
      USE_APP_CLK            => 1,
      APP_CLK_RATIO          => BIT_SAMPLES*12/2)  -- BIT_SAMPLES * 12MHz / 2MHz
    port map (
      app_clk_i   => clk_2mhz,
      clk_i       => clk_pll,
      rstn_i      => rstn,
      out_ready_i => out_ready,
      in_data_i   => in_data,
      in_valid_i  => in_valid,
      rx_dp_i     => rx_dp,
      rx_dn_i     => rx_dn,
      out_data_o  => out_data,
      out_valid_o => out_valid,
      in_ready_o  => in_ready,
      tx_en_o     => tx_en,
      tx_dp_o     => tx_dp,
      tx_dn_o     => tx_dn);

  u_usb_p : component SB_IO
    generic map (
      PIN_TYPE => "101001",
      PULLUP   => '0')
    port map (
      PACKAGE_PIN       => usb_p,
      OUTPUT_ENABLE     => tx_en,
      D_OUT_0           => tx_dp,
      D_IN_0            => rx_dp,
      D_OUT_1           => '0',
      D_IN_1            => open,
      CLOCK_ENABLE      => '0',
      LATCH_INPUT_VALUE => '0',
      INPUT_CLK         => '0',
      OUTPUT_CLK        => '0');

  u_usb_n : component SB_IO
    generic map (
      PIN_TYPE => "101001",
      PULLUP   => '0')
    port map (
      PACKAGE_PIN       => usb_n,
      OUTPUT_ENABLE     => tx_en,
      D_OUT_0           => tx_dn,
      D_IN_0            => rx_dn,
      D_OUT_1           => '0',
      D_IN_1            => open,
      CLOCK_ENABLE      => '0',
      LATCH_INPUT_VALUE => '0',
      INPUT_CLK         => '0',
      OUTPUT_CLK        => '0');
end architecture fpga;
