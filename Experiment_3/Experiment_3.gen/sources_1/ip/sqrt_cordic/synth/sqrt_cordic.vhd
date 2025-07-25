-- (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- (c) Copyright 2022-2025 Advanced Micro Devices, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of AMD and is protected under U.S. and international copyright
-- and other intellectual property laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- AMD, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) AMD shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or AMD had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- AMD products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of AMD products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.

-- IP VLNV: xilinx.com:ip:cordic:6.0
-- IP Revision: 23

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY cordic_v6_0_23;
USE cordic_v6_0_23.cordic_v6_0_23;

ENTITY sqrt_cordic IS
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_cartesian_tvalid : IN STD_LOGIC;
    s_axis_cartesian_tready : OUT STD_LOGIC;
    s_axis_cartesian_tlast : IN STD_LOGIC;
    s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(39 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tready : IN STD_LOGIC;
    m_axis_dout_tlast : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END sqrt_cordic;

ARCHITECTURE sqrt_cordic_arch OF sqrt_cordic IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF sqrt_cordic_arch: ARCHITECTURE IS "yes";
  COMPONENT cordic_v6_0_23 IS
    GENERIC (
      C_ARCHITECTURE : INTEGER;
      C_CORDIC_FUNCTION : INTEGER;
      C_COARSE_ROTATE : INTEGER;
      C_DATA_FORMAT : INTEGER;
      C_XDEVICEFAMILY : STRING;
      C_HAS_ACLKEN : INTEGER;
      C_HAS_ACLK : INTEGER;
      C_HAS_S_AXIS_CARTESIAN : INTEGER;
      C_HAS_S_AXIS_PHASE : INTEGER;
      C_HAS_ARESETN : INTEGER;
      C_INPUT_WIDTH : INTEGER;
      C_ITERATIONS : INTEGER;
      C_OUTPUT_WIDTH : INTEGER;
      C_PHASE_FORMAT : INTEGER;
      C_PIPELINE_MODE : INTEGER;
      C_PRECISION : INTEGER;
      C_ROUND_MODE : INTEGER;
      C_SCALE_COMP : INTEGER;
      C_THROTTLE_SCHEME : INTEGER;
      C_TLAST_RESOLUTION : INTEGER;
      C_HAS_S_AXIS_PHASE_TUSER : INTEGER;
      C_HAS_S_AXIS_PHASE_TLAST : INTEGER;
      C_S_AXIS_PHASE_TDATA_WIDTH : INTEGER;
      C_S_AXIS_PHASE_TUSER_WIDTH : INTEGER;
      C_HAS_S_AXIS_CARTESIAN_TUSER : INTEGER;
      C_HAS_S_AXIS_CARTESIAN_TLAST : INTEGER;
      C_S_AXIS_CARTESIAN_TDATA_WIDTH : INTEGER;
      C_S_AXIS_CARTESIAN_TUSER_WIDTH : INTEGER;
      C_M_AXIS_DOUT_TDATA_WIDTH : INTEGER;
      C_M_AXIS_DOUT_TUSER_WIDTH : INTEGER
    );
    PORT (
      aclk : IN STD_LOGIC;
      aclken : IN STD_LOGIC;
      aresetn : IN STD_LOGIC;
      s_axis_phase_tvalid : IN STD_LOGIC;
      s_axis_phase_tready : OUT STD_LOGIC;
      s_axis_phase_tuser : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      s_axis_phase_tlast : IN STD_LOGIC;
      s_axis_phase_tdata : IN STD_LOGIC_VECTOR(39 DOWNTO 0);
      s_axis_cartesian_tvalid : IN STD_LOGIC;
      s_axis_cartesian_tready : OUT STD_LOGIC;
      s_axis_cartesian_tuser : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      s_axis_cartesian_tlast : IN STD_LOGIC;
      s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(39 DOWNTO 0);
      m_axis_dout_tvalid : OUT STD_LOGIC;
      m_axis_dout_tready : IN STD_LOGIC;
      m_axis_dout_tuser : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      m_axis_dout_tlast : OUT STD_LOGIC;
      m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
  END COMPONENT cordic_v6_0_23;
  ATTRIBUTE X_CORE_INFO : STRING;
  ATTRIBUTE X_CORE_INFO OF sqrt_cordic_arch: ARCHITECTURE IS "cordic_v6_0_23,Vivado 2024.2";
  ATTRIBUTE CHECK_LICENSE_TYPE : STRING;
  ATTRIBUTE CHECK_LICENSE_TYPE OF sqrt_cordic_arch : ARCHITECTURE IS "sqrt_cordic,cordic_v6_0_23,{}";
  ATTRIBUTE CORE_GENERATION_INFO : STRING;
  ATTRIBUTE CORE_GENERATION_INFO OF sqrt_cordic_arch: ARCHITECTURE IS "sqrt_cordic,cordic_v6_0_23,{x_ipProduct=Vivado 2024.2,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=cordic,x_ipVersion=6.0,x_ipCoreRevision=23,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,C_ARCHITECTURE=2,C_CORDIC_FUNCTION=6,C_COARSE_ROTATE=0,C_DATA_FORMAT=1,C_XDEVICEFAMILY=artix7,C_HAS_ACLKEN=0,C_HAS_ACLK=1,C_HAS_S_AXIS_CARTESIAN=1,C_HAS_S_AXIS_PHASE=0,C_HAS_ARESETN=0,C_INPUT_WIDTH=33,C_ITERATIONS=0,C_OUTPUT_WIDTH=16,C_PHASE_FORMAT=0,C_PIPELINE_MODE=-1,C_PRECISION=0,C_ROUND_MODE=0,C_SCALE_COMP=0," & 
"C_THROTTLE_SCHEME=2,C_TLAST_RESOLUTION=1,C_HAS_S_AXIS_PHASE_TUSER=0,C_HAS_S_AXIS_PHASE_TLAST=0,C_S_AXIS_PHASE_TDATA_WIDTH=40,C_S_AXIS_PHASE_TUSER_WIDTH=1,C_HAS_S_AXIS_CARTESIAN_TUSER=0,C_HAS_S_AXIS_CARTESIAN_TLAST=1,C_S_AXIS_CARTESIAN_TDATA_WIDTH=40,C_S_AXIS_CARTESIAN_TUSER_WIDTH=1,C_M_AXIS_DOUT_TDATA_WIDTH=16,C_M_AXIS_DOUT_TUSER_WIDTH=1}";
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_MODE : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_INFO OF aclk: SIGNAL IS "xilinx.com:signal:clock:1.0 aclk_intf CLK";
  ATTRIBUTE X_INTERFACE_MODE OF aclk: SIGNAL IS "slave aclk_intf";
  ATTRIBUTE X_INTERFACE_PARAMETER OF aclk: SIGNAL IS "XIL_INTERFACENAME aclk_intf, ASSOCIATED_BUSIF M_AXIS_DOUT:S_AXIS_PHASE:S_AXIS_CARTESIAN, ASSOCIATED_RESET aresetn, ASSOCIATED_CLKEN aclken, FREQ_HZ 1000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_dout_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TDATA";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_dout_tlast: SIGNAL IS "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TLAST";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_dout_tready: SIGNAL IS "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TREADY";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_dout_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TVALID";
  ATTRIBUTE X_INTERFACE_MODE OF m_axis_dout_tvalid: SIGNAL IS "master M_AXIS_DOUT";
  ATTRIBUTE X_INTERFACE_PARAMETER OF m_axis_dout_tvalid: SIGNAL IS "XIL_INTERFACENAME M_AXIS_DOUT, TDATA_NUM_BYTES 2, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_cartesian_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_CARTESIAN TDATA";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_cartesian_tlast: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_CARTESIAN TLAST";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_cartesian_tready: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_CARTESIAN TREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_cartesian_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_CARTESIAN TVALID";
  ATTRIBUTE X_INTERFACE_MODE OF s_axis_cartesian_tvalid: SIGNAL IS "slave S_AXIS_CARTESIAN";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axis_cartesian_tvalid: SIGNAL IS "XIL_INTERFACENAME S_AXIS_CARTESIAN, TDATA_NUM_BYTES 5, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 1, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
BEGIN
  U0 : cordic_v6_0_23
    GENERIC MAP (
      C_ARCHITECTURE => 2,
      C_CORDIC_FUNCTION => 6,
      C_COARSE_ROTATE => 0,
      C_DATA_FORMAT => 1,
      C_XDEVICEFAMILY => "artix7",
      C_HAS_ACLKEN => 0,
      C_HAS_ACLK => 1,
      C_HAS_S_AXIS_CARTESIAN => 1,
      C_HAS_S_AXIS_PHASE => 0,
      C_HAS_ARESETN => 0,
      C_INPUT_WIDTH => 33,
      C_ITERATIONS => 0,
      C_OUTPUT_WIDTH => 16,
      C_PHASE_FORMAT => 0,
      C_PIPELINE_MODE => -1,
      C_PRECISION => 0,
      C_ROUND_MODE => 0,
      C_SCALE_COMP => 0,
      C_THROTTLE_SCHEME => 2,
      C_TLAST_RESOLUTION => 1,
      C_HAS_S_AXIS_PHASE_TUSER => 0,
      C_HAS_S_AXIS_PHASE_TLAST => 0,
      C_S_AXIS_PHASE_TDATA_WIDTH => 40,
      C_S_AXIS_PHASE_TUSER_WIDTH => 1,
      C_HAS_S_AXIS_CARTESIAN_TUSER => 0,
      C_HAS_S_AXIS_CARTESIAN_TLAST => 1,
      C_S_AXIS_CARTESIAN_TDATA_WIDTH => 40,
      C_S_AXIS_CARTESIAN_TUSER_WIDTH => 1,
      C_M_AXIS_DOUT_TDATA_WIDTH => 16,
      C_M_AXIS_DOUT_TUSER_WIDTH => 1
    )
    PORT MAP (
      aclk => aclk,
      aclken => '1',
      aresetn => '1',
      s_axis_phase_tvalid => '0',
      s_axis_phase_tuser => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      s_axis_phase_tlast => '0',
      s_axis_phase_tdata => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 40)),
      s_axis_cartesian_tvalid => s_axis_cartesian_tvalid,
      s_axis_cartesian_tready => s_axis_cartesian_tready,
      s_axis_cartesian_tuser => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      s_axis_cartesian_tlast => s_axis_cartesian_tlast,
      s_axis_cartesian_tdata => s_axis_cartesian_tdata,
      m_axis_dout_tvalid => m_axis_dout_tvalid,
      m_axis_dout_tready => m_axis_dout_tready,
      m_axis_dout_tlast => m_axis_dout_tlast,
      m_axis_dout_tdata => m_axis_dout_tdata
    );
END sqrt_cordic_arch;
