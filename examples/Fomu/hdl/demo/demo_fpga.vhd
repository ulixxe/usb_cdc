library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library sb_ice40_components_syn;
use sb_ice40_components_syn.components.all;

entity demo is
  port (
    clki      : in    std_logic;        -- 48MHz Clock
    rgb0      : out   std_logic;        -- Red LED
    rgb1      : out   std_logic;        -- Green LED
    rgb2      : out   std_logic;        -- Blue LED
    usb_dp    : inout std_logic;        -- USB+
    usb_dn    : inout std_logic;        -- USB-
    usb_dp_pu : out   std_logic);       -- USB 1.5kOhm Pullup EN
end entity demo;

architecture fpga of demo is
  signal clk_3mhz      : std_logic;
  signal clk_6mhz      : std_logic;
  signal clk_12mhz     : std_logic;
  signal clk_24mhz     : std_logic;
  signal rstn_sync     : std_logic_vector(1 downto 0) := "00";
  signal rstn          : std_logic;
  signal clk           : std_logic;
  signal usb_dp_pu_int : std_logic;
  signal dp_pu         : std_logic;
  signal led           : unsigned(2 downto 0);
  signal dp_rx         : std_logic;
  signal dn_rx         : std_logic;
  signal dp_tx         : std_logic;
  signal dn_tx         : std_logic;
  signal tx_en         : std_logic;
  signal out_data      : std_logic_vector(7 downto 0);
  signal out_valid     : std_logic;
  signal in_ready      : std_logic;
  signal in_data       : std_logic_vector(7 downto 0);
  signal in_valid      : std_logic;
  signal out_ready     : std_logic;

  component prescaler is
    port (
      clk_i       : in  std_logic;
      rstn_i      : in  std_logic;
      clk_div16_o : out std_logic;
      clk_div8_o  : out std_logic;
      clk_div4_o  : out std_logic;
      clk_div2_o  : out std_logic);
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
      app_clk_i    : in  std_logic;
      clk_i        : in  std_logic;
      rstn_i       : in  std_logic;
      out_ready_i  : in  std_logic;
      in_data_i    : in  std_logic_vector(7 downto 0);
      in_valid_i   : in  std_logic;
      dp_rx_i      : in  std_logic;
      dn_rx_i      : in  std_logic;
      frame_o      : out std_logic_vector(10 downto 0);
      configured_o : out std_logic;
      out_data_o   : out std_logic_vector(7 downto 0);
      out_valid_o  : out std_logic;
      in_ready_o   : out std_logic;
      dp_pu_o      : out std_logic;
      tx_en_o      : out std_logic;
      dp_tx_o      : out std_logic;
      dn_tx_o      : out std_logic);
  end component usb_cdc;

  component SB_GB
    port (
      GLOBAL_BUFFER_OUTPUT         : out std_logic;
      USER_SIGNAL_TO_GLOBAL_BUFFER : in  std_logic);
  end component;

  component SB_RGBA_DRV
    generic (
      CURRENT_MODE : string := "0b0";
      RGB0_CURRENT : string := "0b000000";
      RGB1_CURRENT : string := "0b000000";
      RGB2_CURRENT : string := "0b000000");
    port (
      CURREN   : in  std_logic;
      RGB0PWM  : in  std_logic;
      RGB1PWM  : in  std_logic;
      RGB2PWM  : in  std_logic;
      RGBLEDEN : in  std_logic;
      RGB0     : out std_logic;
      RGB1     : out std_logic;
      RGB2     : out std_logic);
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
  led <= "00" & not(dp_pu);

  -- Connect to system clock (with buffering)
  u_gb : component SB_GB
    port map (
      USER_SIGNAL_TO_GLOBAL_BUFFER => clki,
      GLOBAL_BUFFER_OUTPUT         => clk);

  p_rstn : process (clk) is
  begin
    if clk'event and clk = '1' then
      rstn_sync <= '1' & rstn_sync(1);
    end if;
  end process p_rstn;

  rstn <= rstn_sync(0);

  u_prescaler : component prescaler
    port map (
      clk_i       => clk,
      rstn_i      => rstn,
      clk_div16_o => clk_3mhz,
      clk_div8_o  => clk_6mhz,
      clk_div4_o  => clk_12mhz,
      clk_div2_o  => clk_24mhz);

  -- Instantiate iCE40 LED driver hard logic.
  --
  -- Note that it's possible to drive the LEDs directly,
  -- however that is not current-limited and results in
  -- overvolting the red LED.
  --
  -- See also:
  -- https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/ICE40LEDDriverUsageGuide.ashx?document_id=50668
  u_sb_rgba_drv : component SB_RGBA_DRV
    generic map (
      CURRENT_MODE => "0b1",            -- half current
      RGB0_CURRENT => "0b000011",       -- 4 mA
      RGB1_CURRENT => "0b000011",       -- 4 mA
      RGB2_CURRENT => "0b000011")       -- 4 mA
    port map (
      CURREN   => '1',
      RGBLEDEN => '1',
      RGB0PWM  => led(1),
      RGB1PWM  => led(0),
      RGB2PWM  => led(2),
      RGB0     => rgb0,
      RGB1     => rgb1,
      RGB2     => rgb2);

  u_app : component app
    port map (
      clk_i       => clk_12mhz,
      rstn_i      => rstn,
      out_data_i  => out_data,
      out_valid_i => out_valid,
      in_ready_i  => in_ready,
      out_ready_o => out_ready,
      in_data_o   => in_data,
      in_valid_o  => in_valid);

  u_usb_cdc : component usb_cdc
    generic map (
      VENDORID               => X"1209",
      PRODUCTID              => X"5BF0",
      IN_BULK_MAXPACKETSIZE  => 8,
      OUT_BULK_MAXPACKETSIZE => 8,
      BIT_SAMPLES            => 4,
      USE_APP_CLK            => 1,
      APP_CLK_RATIO          => 48/12)  -- 48MHz / 12MHz
    port map (
      app_clk_i    => clk_12mhz,
      clk_i        => clk,
      rstn_i       => rstn,
      out_ready_i  => out_ready,
      in_data_i    => in_data,
      in_valid_i   => in_valid,
      dp_rx_i      => dp_rx,
      dn_rx_i      => dn_rx,
      frame_o      => open,
      configured_o => open,
      out_data_o   => out_data,
      out_valid_o  => out_valid,
      in_ready_o   => in_ready,
      dp_pu_o      => dp_pu,
      tx_en_o      => tx_en,
      dp_tx_o      => dp_tx,
      dn_tx_o      => dn_tx);

  u_usb_dp : component SB_IO
    generic map (
      PIN_TYPE => "101001",
      PULLUP   => '0')
    port map (
      PACKAGE_PIN       => usb_dp,
      OUTPUT_ENABLE     => tx_en,
      D_OUT_0           => dp_tx,
      D_IN_0            => dp_rx,
      D_OUT_1           => '0',
      D_IN_1            => open,
      CLOCK_ENABLE      => '0',
      LATCH_INPUT_VALUE => '0',
      INPUT_CLK         => '0',
      OUTPUT_CLK        => '0');

  u_usb_dn : component SB_IO
    generic map (
      PIN_TYPE => "101001",
      PULLUP   => '0')
    port map (
      PACKAGE_PIN       => usb_dn,
      OUTPUT_ENABLE     => tx_en,
      D_OUT_0           => dn_tx,
      D_IN_0            => dn_rx,
      D_OUT_1           => '0',
      D_IN_1            => open,
      CLOCK_ENABLE      => '0',
      LATCH_INPUT_VALUE => '0',
      INPUT_CLK         => '0',
      OUTPUT_CLK        => '0');

  -- drive usb_pu to 3.3V or to high impedance
  usb_dp_pu <= usb_dp_pu_int;

  u_usb_pu : component SB_IO
    generic map (
      PIN_TYPE => "101001",
      PULLUP   => '0')
    port map (
      PACKAGE_PIN       => usb_dp_pu_int,
      OUTPUT_ENABLE     => dp_pu,
      D_OUT_0           => '1',
      D_IN_0            => open,
      D_OUT_1           => '0',
      D_IN_1            => open,
      CLOCK_ENABLE      => '0',
      LATCH_INPUT_VALUE => '0',
      INPUT_CLK         => '0',
      OUTPUT_CLK        => '0');
end architecture fpga;
