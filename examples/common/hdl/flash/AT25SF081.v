// *============================================================================================== 
// *
// *   AT25SF081.v - 8M-BIT CMOS Serial Flash Memory
// *
// *----------------------------------------------------------------------------------------------
// * Environment  : Cadence NC-Verilog
// * Reference Doc: AT25SF081 REV.1.1,aug.20,2014
// * Creation Date: @(#)$Date: 2017/5/05 15:30:00 $
// * Version      : @(#)$Revision: 1.6 $
// * Description  : There is only one module in this file
// *                module AT25SF081->behavior model for the 8M-Bit flash
// *----------------------------------------------------------------------------------------------
// * Note 1:model can load initial flash data from file when parameter CELL_DATA = "xxx" was defined; 
// *        xxx: initial flash data file name;default value xxx = "empty", initial flash data is "FF".
// * Note 2:power setup time is tVSL = 10_000 ns, so after power up, chip can be enable.
// * Note 3:because it is not checked during the Board system simulation the tCLQX timing is not
// *        inserted to the read function flow temporarily.
// * Note 4:more than one values (min. typ. max. value) are defined for some AC parameters in the
// *        datasheet, but only one of them is selected in the behavior model, e.g. program and
// *        erase cycle time is typical value. For the detailed information of the parameters,
// *        please refer to datasheet.
// * Note 5:tabstop=3 in text editor
// *============================================================================================== 
// * timescale define
// *============================================================================================== 
`timescale 1ns / 100ps

// *============================================================================================== 
// * product parameter define
// *============================================================================================== 
    /*----------------------------------------------------------------------*/
    /* all the parameters users may need to change                          */
    /*----------------------------------------------------------------------*/
        `define CELL_DATA         "empty"     // Flash data file name for normal array
        `define CELL_DATA_SEC    "empty"     // Flash data file name for security region
        `define STATUS_REG1    8'h00       // status register 1 are non-volatile bits
        `define STATUS_REG2    8'h00       // status register 2 are non-volatile bits
    /*----------------------------------------------------------------------*/
    /* Define controller STATE						    */
    /*----------------------------------------------------------------------*/
		  `define		IDLE		0
        `define		CMD		1
        `define		BACK_CMD 2

module AT25SF081( SCLK, 
		    CS_N, 
		    SI, 
		    HOLD_N, 
		    WP_N, 
		    SO );

// *============================================================================================== 
// * Declaration of ports (input, output, inout)
// *============================================================================================== 
    input  SCLK;    // Signal of Clock Input
    input  CS_N;	    // Chip select (Low active)
    inout  SI;	    // Serial Input/Output 
    inout  SO;	    // Serial Input/Output 
    inout  WP_N;    // Serial Input/Output  
    inout  HOLD_N;    // Serial Input/Output  

// *============================================================================================== 
// * Declaration of parameter (parameter)
// *============================================================================================== 
    /*----------------------------------------------------------------------*/
    /* Density STATE parameter						    */  		
    /*----------------------------------------------------------------------*/
    parameter	ADDR_MSB		= 19,	    //address max bit	
					TOP_Add		= 20'hfffff,		
					Secur_TOP_Add   = 10'h3ff,
					ADDR_MSB_OTP	= 9,		
					Sector_MSB	= 7,      //sector max  bit
					Buffer_Num      = 256,     
					Block_MSB	= 3,
					Block_NUM	= 16;
  
    /*----------------------------------------------------------------------*/
    /* Define ID Parameter						    */
    /*----------------------------------------------------------------------*/
    parameter	ID_Manufacturer		= 8'h1f,
					ID_Device	= 8'h13,
					Memory_Type	= 8'h85,
					Memory_Capacity	= 8'h01;

    /*----------------------------------------------------------------------*/
    /* Define Initial Memory File Name					    */
    /*----------------------------------------------------------------------*/
    parameter   CELL_DATA	= `CELL_DATA;      // initial flash data
	 parameter   CELL_DATA_SEC	= `CELL_DATA_SEC; // initial flash data for security
    
    /*----------------------------------------------------------------------*/
    /* AC Characters Parameter						    */
    /*----------------------------------------------------------------------*/
    parameter	tSHQZ		= 6,	    // CS_N High to SO Float Time    [max]
					tCLQV		= 7,	    // Clock Low to Output Valid     [max]
               tCLQX    = 0,        // Output hold time [min]
             	tBP  		= 5_000,      //  Byte program time			 [type]
             	tPP  		= 700_000,      //  Page program time      [type]
             	tSE		= 60_000_000,    	// Sector erase time     [type]
					tBE		= 500_000_000,    	// Block erase time   [type]
               tBE32    = 300_000_000,    // Block 32KB erase time [type]
					tCE		= 12_000,     	// unit is ms instead of ns [type]
               tW 		= 10_000_000,     	// Write Status time  [type]
              	tVSL		= 10_000; 	// Time delay to chip select allowed

    parameter	tPGM_CHK	= 2_000,	// 2 us
					tERS_CHK	= 100_000;	// 100 us 

`ifndef BLACKBOX
   specify
	specparam   tSCLK   = 9.2,    // Clock Cycle Time [ns]
					fSCLK   = 108,    // Clock Frequence except READ instruction[ns] 15pF
					tRSCLK  = 18,   // Clock Cycle Time for READ instruction[ns] 15pF
					fRSCLK  = 55,   // Clock Frequence for READ instruction[ns] 15pF
					tCH	    = 4,	    // Clock High Time (min) [ns]
					tCL	    = 4,	    // Clock Low  Time (min) [ns]
					tSLCH   = 5,    // CS_N Active Setup Time (relative to SCLK) (min) [ns]
					tCHSL   = 5,    // CS_N Not Active Hold Time (relative to SCLK)(min) [ns]
					tSHSL = 20,    // CS_N High Time for write instruction (min) [ns]
					tDVCH   = 2,    // SI Setup Time (min) [ns]
					tCHDX   = 2,    // SI Hold	Time (min) [ns]
					tCHSH   = 5,    // CS_N Active Hold Time (relative to SCLK) (min) [ns]
					tSHCH   = 5,    // CS_N Not Active Setup Time (relative to SCLK) (min) [ns]
					tWHSL   = 20,    // Write Protection Setup Time		  
					tSHWL   = 100,    // Write Protection Hold  Time   
               tDP     = 100,
               tRES1   = 3_000,
               tRES2   = 1_500;

     endspecify

    /*----------------------------------------------------------------------*/
    /* Define Command Parameter						    */
    /*----------------------------------------------------------------------*/
    parameter	WREN	    	= 8'h06, 		// WriteEnable   
					WRDI	    	= 8'h04, 		// WriteDisable  
					RDID	    	= 8'h9F, 		// Read JEDEC ID	  
					RDSR	   	= 8'h05, 		// ReadStatus	  
					RDSR2       = 8'h35, 		// read configuration register SR2
    	         WRSR	    	= 8'h01, 		// WriteStatus   
    	         NORMAL_READ	= 8'h03, 		// ReadData	  
    	         FAST_READ  	= 8'h0b, 		// FastReadData  
    	         SE	    		= 8'h20, 		// SectorErase   
               BE2         = 8'h52, 		// 32k block erase
    	         CE1	    	= 8'h60, 		// ChipErase	  
    	         CE2	    	= 8'hc7, 		// ChipErase	  
    	         PP	    		= 8'h02, 		// PageProgram   
    	         DP	    		= 8'hb9, 		// DeepPowerDown
    	         RDP	    	= 8'hab, 		// ReleaseFromDeepPowerDwon 
    	         RES	    	= 8'hab, 		// ReadElectricID 
    	         REMS	    	= 8'h90, 		// ReadElectricManufacturerDeviceID
               BE	    		= 8'hd8, 		// BlockErase	  
               DUAL_IO_READ 	= 8'hbb, 	// 2X Read 
    	       	RDSCUR	    	= 8'h48, 	// Read  security  register;
    	         WRSCUR	    	= 8'h42, 	// Write security  register;
    	         ERSCUR	    	= 8'h44, 	// Write security  register;
               QUAD_IO_READ 	= 8'heb, 	// 4XI/O Read;
    	       	DUAL_OUT_READ 	= 8'h3b, 	// Fast read dual output;
               QUAD_OUT_READ 	= 8'h6b, 	// Fast read quad output
               RSTEN	    		= 8'h7e, 	// reset enable
               RST	    		= 8'h99, 	// reset memory
               VSR_EN	 		= 8'h50, 	// Write Enable for Volatile Status Register 
               SUS	 			= 8'h75, 	// Program/Erase Suspend    
               RESUME	 		= 8'h7a, 	// Program/Erase resume    
               BURST	 			= 8'h77, 	// Set Burst with Wrap   
               SCRDRST	 		= 8'hff; 	// SContinuous Read Reset      
     

    /*----------------------------------------------------------------------*/
    /* Declaration of internal-signal                                       */
    /*----------------------------------------------------------------------*/
    reg  [7:0]					ARRAY[0:TOP_Add];  				// memory array
	 reg  [7:0]		 			Secur_ARRAY[0:Secur_TOP_Add]; // Secured OTP 
    reg  [7:0]		 			Status_Reg;	    					// Status Register
    reg  [7:0]		 			CMD_BUS;
    reg  [23:0]    			SI_data_Reg;	    				// temp reg to store serial in
    reg  [7:0]    			Dummy_A[0:255];    				// page size
    reg  [ADDR_MSB:0]	 	Address;	    
    reg  [Sector_MSB:0]	 	Sector;	  
    reg  [Block_MSB:0] 		Block;	   
    reg  [Block_MSB+1:0] 	Block2;	   
    reg  [2:0]		 			STATE;
    reg     SO_Reg;
    
    reg     Chip_EN;
    reg     DP_Mode;	    // deep power down mode
    reg     Read_Mode;
    reg     Noumal_Read_Mode;
    reg     Noumal_Read_Chk;

    reg     tDP_Chk;
    reg     tRES1_Chk;
    reg     tRES2_Chk;

    reg     RDID_Mode;
    reg     RDSR_Mode;
    reg     RDSCUR_Mode;
    reg     Fast_Read_Mode;	
    reg     Page_prog_Mode;
    reg     ERSCUR_Mode;
    reg     SE_4K_Mode;
    reg     BE_Mode;
    reg     BE32K_Mode;
    reg     BE64K_Mode;
    reg     CE_Mode;
    reg     WRSR_Mode;
    reg     WRSR2_Mode;
    reg     RES_Mode;
    reg     REMS_Mode;


    reg	   SCLK_EN;
    reg	   SO_OUT_EN;   // for SO
    reg	   SI_IN_EN;    // for SI

     
    reg     RST_CMD_EN;
    reg     W4Read_Mode;
    reg     HOLD_OUT_B;
    wire    HOLD_B_INT;

    wire    CS_N_INT;
    wire    WP_B_INT;
    wire    RESETB_INT;
    wire    SCLK; 
    wire    ISCLK;
    wire    WIP;
    wire    QE;
    wire    WEL;
    wire    SEC;
    wire    TB;
    wire    BP0;
    wire    BP1;
    wire    BP2;
    wire    CMP;
    wire    Dis_CE, Dis_WRSR;  



    event   WRSR_Event; 
    event   BE_Event;
    event   SE_4K_Event;
    event   ERSCUR_Event;
    event   CE_Event;
    event   PP_Event;
    event   BE32K_Event;
    event   RST_Event;
    event   RST_EN_Event;

    integer i;
    integer j;
    integer Bit; 
    integer Bit_Tmp; 
    integer Start_Add;
    integer End_Add;
    integer tWRSR;
    reg 		EN_Burst;
    reg 		flag_scrdrst;
    reg 		flag_scrdrst_dual;
    integer Burst_Length;
    reg 		Read_SHSL;
    wire 	Write_SHSL;


    reg     DUAL_IO_READ_Mode;
    reg     DUAL_IO_READ_Chk;
    reg     Byte_PGM_Mode;	    
    reg	   SI_OUT_EN;   // for SI
    reg	   SO_IN_EN;    // for SO
    reg     SI_Reg;
   
    reg     WP_N_Reg;
    reg     HOLD_N_Reg;
    reg     QUAD_IO_Mode;
    reg     QUAD_Mode;
    reg     QUAD_IO_Chk;
    reg     DUAL_OUT_Mode;
    reg     QUAD_OUT_Mode;
    reg     DUAL_OUT_Chk;
    reg     QUAD_OUT_Chk;

    reg     PP_Mode;
    reg     PP_Load;
    reg     PP_Chk;
    reg     EN4XIO_Read_Mode;
    reg     Set_4XIO_Enhance_Mode;   
    reg	   WP_OUT_EN;   // for WP_N pin
    reg	   HOLD_N_OUT_EN; // for HOLD_N pin
    reg	   WP_IN_EN;    // for WP_N pin
    reg	   HOLD_N_IN_EN;  // for HOLD_N pin
    reg     During_RST_REC;
    wire    HPM_RD;
    wire    HOLD_N;




	 reg[7:0]  	Status_Reg_2;
	 reg 			flag_sr1;
	 reg 			flag_sr2;
	 reg[7:0] 	Status_Reg_2_temp;
	 reg[7:0] 	Status_Reg_temp;
	 reg 			vsr_en;
	 reg 			suspend;
	 reg 			read_scur;
	 reg 			wr_scur;
	 reg[1:0] M54_D;
	 reg[1:0] M54_Q;
	 reg[1:0] M54_D_buff;
	 reg[1:0] M54_Q_buff;

	 reg DUAL_M;
	 reg QUAD_M;
	 
	 reg[15:0] rst_data_Reg;
    /*----------------------------------------------------------------------*/
    /* initial variable value						    */
    /*----------------------------------------------------------------------*/
    initial begin
        Chip_EN         = 1'b0;
		  Status_Reg      = `STATUS_REG1;
        Status_Reg_2    = `STATUS_REG2;
        QUAD_Mode     	= 1'b0;
	     reset_sm;
    end   

// Status Register 1
// 7 SRP0
// 6 SEC
// 5 TB
// 4 BP2
// 3 BP1
// 2 BP0
// 1 WEL
// 0 RDY/BSY

// Status Register 2
// 7 RES
// 6 CMP
// 5 LB3
// 4 LB2
// 3 LB1
// 2 RES
// 1 QE
// 0 SRP1

    task reset_sm; 
		begin
            flag_sr1=0;
            flag_sr2=0;
				vsr_en=0;
				suspend=0;
				read_scur=0;
				wr_scur=0;
				
				DUAL_M=0;
				QUAD_M=0;
				M54_D=0;
				M54_Q=0;
				M54_D_buff=0;
				M54_Q_buff=0;

            During_RST_REC  = 1'b0;
            SI_Reg        = 1'b1;
            SO_Reg        = 1'b1;
            WP_N_Reg        = 1'b1;
            HOLD_N_Reg        = 1'b1;
            RST_CMD_EN      = 1'b0;
				SO_OUT_EN	    = 1'b0; // SO output enable
				SI_IN_EN	    = 1'b0; // SI input enable
				CMD_BUS	    = 8'b0000_0000;
				Address	    = 0;
				i		    = 0;
				j		    = 0;
				Bit		    = 0;
				Bit_Tmp	    = 0;
				Start_Add	    = 0;
				End_Add	    = 0;
				DP_Mode	    = 1'b0;
				SCLK_EN	    = 1'b1;
				Read_Mode	    = 1'b0;
				Noumal_Read_Mode  = 1'b0;
				Noumal_Read_Chk   = 1'b0;
            tDP_Chk         = 1'b0;
            tRES1_Chk       = 1'b0;
            tRES2_Chk       = 1'b0;
            HOLD_OUT_B      = 1'b1;

            RDID_Mode       = 1'b0;
            RDSR_Mode       = 1'b0;

				Page_prog_Mode    = 1'b0;
				ERSCUR_Mode	    = 1'b0;
				SE_4K_Mode	    = 1'b0;
				BE_Mode	    = 1'b0;
            BE32K_Mode      = 1'b0;
            BE64K_Mode      = 1'b0;
				CE_Mode	    = 1'b0;
				WRSR_Mode	    = 1'b0;
            WRSR2_Mode      = 1'b0;
				RES_Mode	    = 1'b0;
				REMS_Mode	    = 1'b0;
            Read_SHSL 	    = 1'b0;
				Fast_Read_Mode  = 1'b0;
				DUAL_OUT_Mode  = 1'b0;
            QUAD_OUT_Mode  = 1'b0;
				SI_OUT_EN	    = 1'b0; // SI output enable
				SO_IN_EN	    = 1'b0; // SO input enable
				DUAL_IO_READ_Mode  = 1'b0;
				DUAL_IO_READ_Chk   = 1'b0;
				Byte_PGM_Mode   = 1'b0;
				WP_OUT_EN	    = 1'b0; // for WP_N pin output enable
				HOLD_N_OUT_EN	    = 1'b0; // for HOLD_N pin output enable
				WP_IN_EN	    = 1'b0; // for WP_N pin input enable
				HOLD_N_IN_EN	    = 1'b0; // for HOLD_N pin input enable
				QUAD_IO_Mode  = 1'b0;
				W4Read_Mode     = 1'b0;
				QUAD_IO_Chk   = 1'b0;
				PP_Mode    = 1'b0;
            PP_Load    = 1'b0;
            PP_Chk     = 1'b0;
            DUAL_OUT_Chk = 1'b0;
            QUAD_OUT_Chk = 1'b0;

				EN4XIO_Read_Mode  = 1'b0;
            Set_4XIO_Enhance_Mode = 1'b0;
            EN_Burst          = 1'b0;
				flag_scrdrst=1'b0;
				flag_scrdrst_dual=1'b0;
            Burst_Length      = 8;
				rst_data_Reg=0;
     
		end
    endtask // reset_sm
    
    /*----------------------------------------------------------------------*/
    /* initial flash data    						    */
    /*----------------------------------------------------------------------*/
    initial 
    begin : memory_initialize
	for ( i = 0; i <=  TOP_Add; i = i + 1 )
	    ARRAY[i] = 8'hff; 
	if ( CELL_DATA != "empty" )
	    $readmemh(CELL_DATA,ARRAY) ;
    
	for( i = 0; i <=  Secur_TOP_Add; i = i + 1 ) begin
	    Secur_ARRAY[i]=8'hff;
	end
        if ( CELL_DATA_SEC != "empty" )
            $readmemh(CELL_DATA_SEC,Secur_ARRAY) ;
	end
// *============================================================================================== 
// * Input/Output bus opearation 
// *============================================================================================== 
    assign ISCLK    = (SCLK_EN == 1'b1) ? SCLK:1'b0;
    assign CS_N_INT = ( During_RST_REC == 1'b0 ) ? CS_N : 1'b1;
    assign WP_B_INT = (Status_Reg_2[1] == 1'b0) ? WP_N : 1'b1;        
    assign HOLD_B_INT = ( Status_Reg_2[1] == 1'b0  && CS_N_INT == 1'b0 ) ? HOLD_N : 1'b1;
   
	//----output
	 assign   SO     = (SO_OUT_EN && HOLD_OUT_B) ? SO_Reg : 1'bz ;
    assign   SI     = (SI_OUT_EN && HOLD_OUT_B) ? SI_Reg : 1'bz ;
    assign   WP_N     = (WP_OUT_EN && HOLD_OUT_B)  ? WP_N_Reg : 1'bz ;
    assign   HOLD_N   = (HOLD_N_OUT_EN && HOLD_OUT_B) ? HOLD_N_Reg : 1'bz ;


// *============================================================================================== 
// * Finite State machine to control Flash operation
// *============================================================================================== 
    /*----------------------------------------------------------------------*/
    /* power on              						    */
    /*----------------------------------------------------------------------*/
    initial begin 
		Chip_EN   = #tVSL 1'b1;// Time delay to chip select allowed 
    end
    
    /*----------------------------------------------------------------------*/
    /* Command Decode        						    */
    /*----------------------------------------------------------------------*/
	 assign QE    = Status_Reg_2[1];
    assign WIP	    = Status_Reg[0] ;
    assign WEL	    = Status_Reg[1] ;

    assign SEC     = Status_Reg[6] ;
    assign TB     = Status_Reg[5] ;
    assign CMP     = Status_Reg_2[6] ;
    assign BP0     = Status_Reg[2] ;
    assign BP1     = Status_Reg[3] ;
    assign BP2     = Status_Reg[4] ;
    assign Dis_CE   = Status_Reg[4] == 1'b1 || Status_Reg[3] == 1'b1 || Status_Reg[2] == 1'b1;
    assign HPM_RD   = EN4XIO_Read_Mode == 1'b1 ;  
    assign Dis_WRSR = !(Status_Reg_2[0]==0 &&(Status_Reg[7] == 1'b0 || WP_B_INT == 1'b1));
 
     
    always @ ( negedge CS_N_INT ) begin
        SI_IN_EN = 1'b1; 
		  if ( EN4XIO_Read_Mode == 1'b1 ) begin
            Read_SHSL = 1'b1;
	         STATE   <= `CMD;
	         QUAD_IO_Mode = 1'b1; 
	     end
	     if ( HPM_RD == 1'b0 ) begin
		   	Read_SHSL <= #1 1'b0;   
	     end
        #1;
        tDP_Chk = 1'b0;
        tRES1_Chk = 1'b0;
        tRES2_Chk = 1'b0;
    end

//--------------------------ADDR INPUT    but no dual
    always @ ( posedge ISCLK or posedge CS_N_INT ) begin
	     if ( CS_N_INT == 1'b0 ) begin
                Bit_Tmp = Bit_Tmp + 1;
                Bit     = Bit_Tmp - 1;
	         if ( SI_IN_EN == 1'b1 && SO_IN_EN == 1'b1 && WP_IN_EN == 1'b1 && HOLD_N_IN_EN == 1'b1 ) begin
		          SI_data_Reg[23:0] = {SI_data_Reg[19:0], HOLD_N, WP_N, SO, SI};
	         end 
	         else  if ( SI_IN_EN == 1'b1 && SO_IN_EN == 1'b1 ) begin
		          SI_data_Reg[23:0] = {SI_data_Reg[21:0], SO, SI};
	         end
	         else begin 
		          SI_data_Reg[23:0] = {SI_data_Reg[22:0], SI};
	         end

	         if ( (EN4XIO_Read_Mode == 1'b1 && ((Bit == 5) || (Bit == 23))) ) begin
                Address = SI_data_Reg[ADDR_MSB:0];
                load_address(Address);
	         end  
				
				rst_data_Reg[15:0] = {rst_data_Reg[14:0], SI};
	     end	
		  
  
		  if( M54_Q==2'b10 && Bit == 7 && CS_N_INT == 1'b0 && (rst_data_Reg[7:0]==8'hff))begin
				STATE = `CMD;
	         CMD_BUS = SCRDRST;
				disable read_4xio;
		  end
		  else if(M54_D==2'b10 && Bit == 15 && CS_N_INT == 1'b0 && (rst_data_Reg[15:0]==16'hffff))begin
				flag_scrdrst_dual=1;
				STATE = `IDLE;
				CMD_BUS = SCRDRST;
				disable read_2xio;
		  end
		  else if(M54_D==2'b10 && CS_N_INT == 1'b0 )begin
				CMD_BUS=DUAL_IO_READ;
				STATE = `CMD;
			end
		  else if(M54_Q==2'b10 && CS_N_INT == 1'b0 )begin
				CMD_BUS=QUAD_IO_READ;
				STATE = `CMD;
			end
		  else if ( Bit == 7 && CS_N_INT == 1'b0 && ~HPM_RD ) begin
	         STATE = `CMD;
	         CMD_BUS = SI_data_Reg[7:0];
            if ( During_RST_REC )
                $display ($time," During reset recovery time, there is command. \n");
			end


        if ( (EN4XIO_Read_Mode && (Bit == 1 || Bit==7)) && CS_N_INT == 1'b0
             && HPM_RD && (SI_data_Reg[7:0]== RSTEN || SI_data_Reg[7:0]== RST)) begin
            CMD_BUS = SI_data_Reg[7:0];
        end

        if ( CS_N_INT == 1'b1 && RST_CMD_EN &&
             ( (Bit+1)%8 == 0 || (EN4XIO_Read_Mode && (Bit+1)%2 == 0) ) ) begin
            RST_CMD_EN <= #1 1'b0;
   	  end
	
	     case ( STATE )
	    `IDLE: 
	        begin
	        end
        
	    `CMD: 
	        begin
	            case ( CMD_BUS ) 
	            WREN: 
						begin
							if ( !DP_Mode && !WIP && Chip_EN && ~HPM_RD ) begin
								if ( CS_N_INT == 1'b1 && Bit == 7 ) begin										
									write_enable;
								end
								else if ( Bit > 7 )
									STATE <= `BACK_CMD; 
							end 
							else if ( Bit == 7 )
								STATE <= `BACK_CMD; 
						end
					WRDI:   
						begin
							if ( !DP_Mode && !WIP && Chip_EN && ~HPM_RD ) begin
	                        if ( CS_N_INT == 1'b1 && Bit == 7 ) begin											
										write_disable;
	                        end
	                        else if ( Bit > 7 )
										STATE <= `BACK_CMD; 
							end 
							else if ( Bit == 7 )
									STATE <= `BACK_CMD; 
						end 

                RDID:
                  begin
							if ( !DP_Mode && !WIP && Chip_EN && ~HPM_RD ) begin
                        Read_SHSL = 1'b1;
                        RDID_Mode = 1'b1;
                     end
                     else if ( Bit == 7 )
                        STATE <= `BACK_CMD;
                  end
                      
	             RDSR:
						begin 
							if ( !DP_Mode && Chip_EN && ~HPM_RD ) begin 
								Read_SHSL = 1'b1;
								RDSR_Mode = 1'b1 ;
								flag_sr1  = 1'b1;
                     end
							else if ( Bit == 7 )
								STATE <= `BACK_CMD; 	
						end
					 RDSR2:                                                              
						begin 
							if ( !DP_Mode && Chip_EN && ~HPM_RD ) begin 
								Read_SHSL = 1'b1;
								RDSR_Mode = 1'b1 ;
								flag_sr2  = 1'b1;
                     end
							else if ( Bit == 7 )
								STATE <= `BACK_CMD; 	
						end

						WRSR:
							begin
								if ( !DP_Mode && !WIP && WEL && Chip_EN && ~HPM_RD ) begin
									if ( CS_N_INT == 1'b1 && Bit == 15 || CS_N_INT == 1'b1 && Bit == 23 ) begin
										if ( Dis_WRSR ) begin 
											Status_Reg[1] = 1'b0; 
										end
										else if (CS_N_INT == 1'b1 && Bit == 15) begin 
											->WRSR_Event;
											WRSR_Mode = 1'b1;
										end	
                              else if (CS_N_INT == 1'b1 && Bit == 23) begin			  
                                 ->WRSR_Event;
                                 WRSR2_Mode = 1'b1;
                              end
		 
									end    
                           else if ( CS_N_INT == 1'b1 && (Bit < 15 || Bit > 15 && Bit < 23) )
										STATE <= `BACK_CMD;
                           else if ( (CS_N_INT == 1'b1 &&  Bit > 23) )
										STATE <= `BACK_CMD;
							end
							else if ( Bit == 7 )
								STATE <= `BACK_CMD;
						end 
                      
	            NORMAL_READ: 
						begin
							if ( !DP_Mode && !WIP && Chip_EN && ~HPM_RD ) begin
								Read_SHSL = 1'b1;
								if ( Bit == 31 ) begin
									Address = SI_data_Reg [ADDR_MSB:0];
                           load_address(Address);
								end
								Noumal_Read_Mode = 1'b1;
							end	
							else if ( Bit == 7 )
	                     STATE <= `BACK_CMD;				
						end

	            FAST_READ:
	    		begin
	    		    if ( !DP_Mode && !WIP && Chip_EN && ~HPM_RD ) begin
                                Read_SHSL = 1'b1;
	    			if ( Bit == 31 ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
                                    load_address(Address);
	    			end
												Fast_Read_Mode = 1'b1;
	    		    end	
	    		    else if ( Bit == 7 )
	                     	STATE <= `BACK_CMD;				
	    		end
				
	            SE: 
	    		begin
	    		    if ( !DP_Mode && !WIP && WEL &&  Chip_EN && ~HPM_RD ) begin
	    			if ( Bit == 31 ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
	    			end
	    			if ( CS_N_INT == 1'b1 && Bit == 31 ) begin
	    			    ->SE_4K_Event;
	    			    SE_4K_Mode = 1'b1;
	    			end
	    			else if ( CS_N_INT == 1'b1 && Bit < 31 || Bit > 31 )
	                     	     STATE <= `BACK_CMD;
	    		    end
	    		    else if ( Bit == 7 )
	    			STATE <= `BACK_CMD;
	    		end

	            BE: 
	    		begin
	    		    if ( !DP_Mode && !WIP && WEL &&  Chip_EN && ~HPM_RD ) begin
	    			if ( Bit == 31 ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
	    			end
	    			if ( CS_N_INT == 1'b1 && Bit == 31 ) begin
	    			    ->BE_Event;
	    			    BE_Mode = 1'b1;
                                    BE64K_Mode = 1'b1;
	    			end 
	    			else if ( CS_N_INT == 1'b1 && Bit < 31 || Bit > 31 )
	    			    STATE <= `BACK_CMD;
	    		    end 
	    		    else if ( Bit == 7 )
	    			STATE <= `BACK_CMD;
	    		end

                    BE2:
                        begin
                            if ( !DP_Mode && !WIP && WEL && Chip_EN && ~HPM_RD ) begin
                                if ( Bit == 31 ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
                                end
                                if ( CS_N_INT == 1'b1 && Bit == 31  ) begin
                                    ->BE32K_Event;
                                    BE_Mode = 1'b1;
                                    BE32K_Mode = 1'b1;
                                end
                                else if ( CS_N_INT == 1'b1 && Bit < 31 || Bit > 31 )
                                    STATE <= `BACK_CMD;
                            end
                            else if ( Bit == 7 )
                                STATE <= `BACK_CMD;
                        end

                      
	            CE1, CE2:
	    		begin
	    		    if ( !DP_Mode && !WIP && WEL && Chip_EN && ~HPM_RD ) begin
	    			if ( CS_N_INT == 1'b1 && Bit == 7 ) begin
	    			    ->CE_Event;
	    			    CE_Mode = 1'b1 ;
	    			end 
	    			else if ( Bit > 7 )
	    			    STATE <= `BACK_CMD;
	    		    end
	    		    else if ( Bit == 7 ) 
	    			STATE <= `BACK_CMD;
	    		end
                      
	            PP: 
	    		begin
	    		    if ( !DP_Mode && !WIP && WEL && Chip_EN && ~HPM_RD ) begin
	    			if ( Bit == 31 ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
                                    load_address(Address);
	    			end

	    			if ( Bit == 31 ) begin
                                    if ( CS_N_INT == 1'b0 ) begin
					->PP_Event;
					Page_prog_Mode = 1'b1;
                                    end  
	    			end
	    			else if ( CS_N_INT == 1 && (Bit < 31 || ((Bit + 1) % 8 !== 0)))
	    			    STATE <= `BACK_CMD;
	    			end
	    		    else if ( Bit == 7 )
	                     	STATE <= `BACK_CMD;
	    		end

                    DP:
                        begin
                            if ( !WIP && Chip_EN && ~HPM_RD ) begin
                                if ( CS_N_INT == 1'b1 && Bit == 7 && DP_Mode == 1'b0 ) begin
                                    tDP_Chk = 1'b1;
                                    DP_Mode = 1'b1;
												if(vsr_en)begin
													Status_Reg =Status_Reg_temp;
													Status_Reg_2 =Status_Reg_2_temp;
												end
												vsr_en=0;
												suspend=0;
                                end
                                else if ( Bit > 7 )
                                    STATE <= `BACK_CMD;
                            end
                            else if ( Bit == 7 )
                                STATE <= `BACK_CMD;
                        end

                    RDP, RES:
                        begin
                            if ( !WIP && Chip_EN && ~HPM_RD ) begin
                                RES_Mode = 1'b1;
                                Read_SHSL = 1'b1;
                                if ( CS_N_INT == 1'b1 && ISCLK == 1'b0 && tRES1_Chk &&(Bit >= 38) ) begin
                                    tRES1_Chk = 1'b0;
                                    tRES2_Chk = 1'b1;
                                    DP_Mode = 1'b0;
                                end
                                else if ( CS_N_INT == 1'b1 && ISCLK == 1'b1 && tRES1_Chk && (Bit >= 39 )) begin
                                    tRES1_Chk = 1'b0;
                                    tRES2_Chk = 1'b1;
                                    DP_Mode = 1'b0;
                                end
                                else if ( CS_N_INT == 1'b1 && Bit > 0 && DP_Mode ) begin
                                    tRES1_Chk = 1'b1;
                                    DP_Mode = 1'b0;
                                end
                            end
                            else if ( Bit == 7 )
                                STATE <= `BACK_CMD;
                        end

	            REMS:
	    		begin
	    		    if ( !DP_Mode && !WIP && Chip_EN && ~HPM_RD ) begin
	    			if ( Bit == 31 ) begin
	    			    Address = SI_data_Reg[ADDR_MSB:0] ;
	    			end
                                Read_SHSL = 1'b1;
	    			REMS_Mode = 1'b1;
	    		    end
	    		    else if ( Bit == 7 )
	                     	STATE <= `BACK_CMD;			    
	    		end

	            DUAL_IO_READ: 
	    		begin 
	    		    if ( !DP_Mode && !WIP && Chip_EN && ~HPM_RD ) begin
                                Read_SHSL = 1'b1;
	    			if ( Bit == 19 && (M54_D!=2'b10)) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
                                    load_address(Address);
	    			end
					else if( Bit == 11 && (M54_D==2'b10))begin
												 Address = SI_data_Reg [ADDR_MSB:0];
                                    load_address(Address);
					end						
					DUAL_IO_READ_Mode = 1'b1;
	    		    end	
	    		    else if ( Bit == 7 )
	                     	STATE <= `BACK_CMD;				
	    		end 	

            RDSCUR: 
	    		begin
	    		    if ( !DP_Mode && !WIP && Chip_EN && ~HPM_RD ) begin
                                Read_SHSL = 1'b1;
	    			if ( Bit == 31 ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
                                    load_address(Address);
	    			end

												Fast_Read_Mode = 1'b1;
						 read_scur=1;

	    		    end	
	    		    else if ( Bit == 7 )
	                     	STATE <= `BACK_CMD;							
	    		end
                      
                      
	            WRSCUR: 
	    		begin
					if ( !DP_Mode && !WIP && WEL && Chip_EN && ~HPM_RD ) begin
	    			if ( Bit == 31 ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
                                    load_address(Address);
	    			end

	    			if ( Bit == 31 ) begin
                                    if ( CS_N_INT == 1'b0 ) begin
					->PP_Event;
					Page_prog_Mode = 1'b1;
					wr_scur=1;
                                    end  
	    			end
	    			else if ( CS_N_INT == 1 && (Bit < 31 || ((Bit + 1) % 8 !== 0)))
	    			    STATE <= `BACK_CMD;
	    			end
	    		    else if ( Bit == 7 )
	                     	STATE <= `BACK_CMD;
	    		end
				
				
				ERSCUR:
				begin
	    		    if ( !DP_Mode && !WIP && WEL &&  Chip_EN && ~HPM_RD ) begin
	    			if ( Bit == 31 ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
	    			end
	    			if ( CS_N_INT == 1'b1 && Bit == 31 ) begin
	    			    ->ERSCUR_Event;
	    			    ERSCUR_Mode = 1'b1;
	    			end
	    			else if ( CS_N_INT == 1'b1 && Bit < 31 || Bit > 31 )
	                     	     STATE <= `BACK_CMD;
	    		    end
	    		    else if ( Bit == 7 )
	    			STATE <= `BACK_CMD;
	    		end

				
                      
	            QUAD_IO_READ:
							begin
	    		    if ( !DP_Mode && !WIP && QE && Chip_EN && ~HPM_RD ) begin
                                Read_SHSL = 1'b1;
                                if ( Bit == 13 && (M54_Q!=2'b10) ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
                                    load_address(Address);
											end
											else if(Bit == 5 && (M54_Q==2'b10) ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
                                    load_address(Address);
											end
											QUAD_IO_Mode = 1'b1;
											QUAD_Mode    = 1'b1;
											end
											else if ( Bit == 7 )begin
												STATE <= `BACK_CMD;
											end

							end

	            DUAL_OUT_READ:
	    		begin
	    		    if ( !DP_Mode && !WIP && Chip_EN && ~HPM_RD ) begin
                                Read_SHSL = 1'b1;
	    			if ( Bit == 31 ) begin
                                    Address = SI_data_Reg [ADDR_MSB:0];
                                    load_address(Address);
	    			end
	    			DUAL_OUT_Mode =1'b1;
	    		    end
	    		    else if ( Bit == 7 )
	                     	STATE <= `BACK_CMD;			    
	    		end
                      
                    QUAD_OUT_READ:
                        begin
                            if ( !DP_Mode && !WIP && QE && Chip_EN  && ~HPM_RD ) begin
                                Read_SHSL = 1'b1;
                                if ( Bit == 31 ) begin
                                    Address = SI_data_Reg[ADDR_MSB:0] ;
                                    load_address(Address);
                                end
                                QUAD_OUT_Mode =1'b1;
                            end
                            else if ( Bit == 7 )
                                STATE <= `BACK_CMD;
                        end


                    RSTEN:
                        begin
                            if ( Chip_EN ) begin
                                if ( CS_N_INT == 1'b1 && (Bit == 7 || (EN4XIO_Read_Mode && Bit == 1)) ) begin
				    ->RST_EN_Event;
                                end
                                else if ( Bit > 7 )
                                    STATE <= `BACK_CMD;
                            end
                            else if ( Bit == 7 )
                                STATE <= `BACK_CMD;
                        end

                    RST:
                        begin
                            if ( Chip_EN && RST_CMD_EN ) begin
                                if ( CS_N_INT == 1'b1 && (Bit == 7 || (EN4XIO_Read_Mode && Bit == 1)) ) begin
                                    ->RST_Event;
                                end
                                else if ( Bit > 7 )
                                    STATE <= `BACK_CMD;
                            end
                            else if ( Bit == 7 )
                                STATE <= `BACK_CMD;
                        end
						VSR_EN:
							begin
								vsr_en=1;
								Status_Reg_temp=Status_Reg;
								Status_Reg_2_temp=Status_Reg_2;
							end
							
						SUS:
							begin
								suspend=1;
							end
						RESUME:
							begin
								suspend=0;
							end
						BURST:
							begin
								if ( !DP_Mode  && QE && Chip_EN && ~HPM_RD ) begin
                                if ((Bit == 15 && QE) ) begin
                                    EN_Burst=!SI_data_Reg[4] ;
												if(!SI_data_Reg[5] && !SI_data_Reg[6])
													Burst_Length=8;
												else if(SI_data_Reg[5] && !SI_data_Reg[6])
													Burst_Length=16;
												else if(!SI_data_Reg[5] && SI_data_Reg[6])
													Burst_Length=32;
												else if(SI_data_Reg[5] && SI_data_Reg[6])
													Burst_Length=64;
										  end
												    SI_IN_EN	= 1'b1;
														SO_IN_EN	= 1'b1;
														WP_IN_EN	= 1'b1;
														HOLD_N_IN_EN   = 1'b1;
							end
							else if ( Bit == 7 )
	                     	STATE <= `BACK_CMD;			    
							end
					SCRDRST:
							begin
								flag_scrdrst=1;
							end
	            default: 
	    		begin
	    		    STATE <= `BACK_CMD;
	    		end
		    endcase
	        end
                 
	    `BACK_CMD: 
	        begin
	        end
            
	    default: 
	        begin
	    	STATE =  `IDLE;
	        end
	endcase


    end


//------------------------------

always@(posedge ISCLK)begin
	if(DUAL_M)begin
			M54_D_buff<={SO, SI};
	end
	else if(flag_scrdrst_dual)
		M54_D_buff<={M54_D[1], 1'b1};
end

always@(posedge CS_N_INT)begin
	M54_D<=M54_D_buff;
	M54_Q<=M54_Q_buff;
end
always@(posedge ISCLK)
	if(QUAD_M)begin
			M54_Q_buff<={SO, SI};
	end
	else if(flag_scrdrst)
		M54_Q_buff<={M54_Q[1], 1'b1};




//------------------------------









    always @ (posedge CS_N_INT) begin
            SI_Reg <= #tSHQZ 1'bx;
            SO_Reg <= #tSHQZ 1'bx;
            WP_N_Reg <= #tSHQZ 1'bx;
            HOLD_N_Reg <= #tSHQZ 1'bx;
           
	    SO_OUT_EN    <= #tSHQZ 1'b0;
	    SI_OUT_EN    <= #tSHQZ 1'b0;
	    WP_OUT_EN    <= #tSHQZ 1'b0;
	    HOLD_N_OUT_EN  <= #tSHQZ 1'b0;

            #1;
            Bit         = 1'b0;
            Bit_Tmp     = 1'b0;
           
            SO_IN_EN    = 1'b0;
            SI_IN_EN    = 1'b0;
            WP_IN_EN    = 1'b0;
            HOLD_N_IN_EN  = 1'b0;

            RDID_Mode   = 1'b0;
            RDSR_Mode   = 1'b0;
            RDSCUR_Mode = 1'b0;
	    Read_Mode	= 1'b0;
	    RES_Mode	= 1'b0;
	    REMS_Mode	= 1'b0;
  
	    Noumal_Read_Mode  = 1'b0;
	    DUAL_IO_READ_Mode  = 1'b0;
	    QUAD_IO_Mode  = 1'b0;
	    Noumal_Read_Chk   = 1'b0;
	    DUAL_IO_READ_Chk   = 1'b0;
	    QUAD_IO_Chk   = 1'b0;
	    Fast_Read_Mode= 1'b0;
            DUAL_OUT_Mode= 1'b0;
            QUAD_OUT_Mode= 1'b0;
            DUAL_OUT_Chk= 1'b0;
            QUAD_OUT_Chk= 1'b0;
	    PP_Load    = 1'b0;
            PP_Chk     = 1'b0;
	    STATE <=  `IDLE;

            disable read_id;
            disable read_status;
            disable read_1xio;
            disable read_2xio;
            disable read_4xio;
            disable fastread_1xio;
            disable fastread_2xio;
            disable fastread_4xio;
            disable read_electronic_id;
            disable read_electronic_manufacturer_device_id;
	    disable read_function;
	    disable dummy_cycle;
				flag_sr1=0;
				flag_sr2=0;
				flag_scrdrst=0;
				flag_scrdrst_dual=0;
				read_scur=0;

	end

    always @ (posedge CS_N_INT) begin 

	if ( Set_4XIO_Enhance_Mode) begin
	    EN4XIO_Read_Mode = 1'b1;
        end
	else begin
	    EN4XIO_Read_Mode = 1'b0;
	    W4Read_Mode      = 1'b0;
            QUAD_Mode      = 1'b0;
        end
    end 

    /*----------------------------------------------------------------------*/
    /*	ALL function trig action            				    */
    /*----------------------------------------------------------------------*/
    always @ ( posedge Noumal_Read_Mode
	    or posedge Fast_Read_Mode
	    or posedge REMS_Mode
	    or posedge RES_Mode
	    or posedge DUAL_IO_READ_Mode
	    or posedge QUAD_IO_Mode 
	    or posedge PP_Load 
	    or posedge DUAL_OUT_Mode
            or posedge QUAD_OUT_Mode
	   ) begin:read_function 
        wait ( SCLK == 1'b0 );
	if ( Noumal_Read_Mode == 1'b1 ) begin
	    Noumal_Read_Chk = 1'b1;
	    read_1xio;
	end
	else if ( Fast_Read_Mode == 1'b1 ) begin
	    fastread_1xio;
	end
	else if ( DUAL_OUT_Mode == 1'b1 ) begin
            DUAL_OUT_Chk = 1'b1;
	    fastread_2xio;
	end   
        else if ( QUAD_OUT_Mode == 1'b1 ) begin
            QUAD_OUT_Chk = 1'b1;
            fastread_4xio;
        end
	else if ( REMS_Mode == 1'b1 ) begin
	    read_electronic_manufacturer_device_id;
	end 
	else if ( RES_Mode == 1'b1 ) begin
	    read_electronic_id;
	end
	else if ( DUAL_IO_READ_Mode == 1'b1 ) begin
	    DUAL_IO_READ_Chk = 1'b1;
	    read_2xio;
	end
	else if ( QUAD_IO_Mode == 1'b1 ) begin
	    QUAD_IO_Chk = 1'b1;
	    read_4xio;
	end   
        else if ( PP_Load == 1'b1 ) begin
            PP_Chk = 1'b1;
        end
    end	
    

    always @ ( RST_EN_Event ) begin
	RST_CMD_EN = #2 1'b1;
    end

    always @ ( RST_Event ) begin
        During_RST_REC = 1;
        #30000;
        disable write_status;
        disable block_erase_32k;
        disable block_erase;
        disable sector_erase_4k;
        disable erase_sec_reg;
        disable chip_erase;
        disable page_program; // can deleted
        disable update_array;
        disable read_id;
        disable read_status;
        disable read_1xio;
        disable read_2xio;
        disable read_4xio;
        disable fastread_1xio;
        disable fastread_2xio;
        disable fastread_4xio;
        disable read_electronic_id;
        disable read_electronic_manufacturer_device_id;
        disable read_function;
        disable dummy_cycle;

        reset_sm;
        QUAD_Mode = 1'b0;
        Status_Reg[1:0] = 2'b0;
		flag_sr1=0;
		flag_sr2=0;
		vsr_en=0;
		suspend=0;
		wr_scur=0;
		read_scur=0;
    end
    


    always @ ( posedge W4Read_Mode ) begin
            QUAD_Mode = 1'b0;
    end
 
    always @ ( posedge QUAD_Mode ) begin
            W4Read_Mode = 1'b0;
    end


    always @ ( WRSR_Event ) begin
	write_status;
    end


    always @ ( BE_Event ) begin
	block_erase;
    end

    always @ ( CE_Event ) begin
	chip_erase;
    end
    
    always @ ( PP_Event ) begin:page_program_mode
        page_program( Address );
    end
   
    always @ ( SE_4K_Event ) begin
	sector_erase_4k;
    end  
	 
	 always @ ( ERSCUR_Event ) begin
	erase_sec_reg;
    end

    always @ ( posedge RDID_Mode ) begin
        read_id;
    end

    always @ ( posedge RDSR_Mode ) begin
        read_status;
    end


    always @ ( BE32K_Event ) begin
        block_erase_32k;
    end



// *========================================================================================== 
// * Module Task Declaration
// *========================================================================================== 
    /*----------------------------------------------------------------------*/
    /*	Description: define a wait dummy cycle task			    */
    /*	INPUT							            */
    /*	    Cnum: cycle number						    */
    /*----------------------------------------------------------------------*/
    task dummy_cycle;
	input [31:0] Cnum;
	begin
	    repeat( Cnum ) begin
		@ ( posedge ISCLK );
	    end
	end
    endtask // dummy_cycle



    /*----------------------------------------------------------------------*/
    /*	Description: define a write enable task				    */
    /*----------------------------------------------------------------------*/
    task write_enable;
	begin
	    Status_Reg[1] = 1'b1; 
	end
    endtask // write_enable
    
    /*----------------------------------------------------------------------*/
    /*	Description: define a write disable task (WRDI)			    */
    /*----------------------------------------------------------------------*/
    task write_disable;
	begin
	    Status_Reg[1]  = 1'b0;             
	end
    endtask // write_disable
    
    /*----------------------------------------------------------------------*/
    /*	Description: define a read id task (RDID)			    */
    /*----------------------------------------------------------------------*/
    task read_id;
	reg  [23:0] Dummy_ID;
	integer Dummy_Count;
	begin
	    Dummy_ID	= {ID_Manufacturer, Memory_Type, Memory_Capacity};
	    Dummy_Count = 0;
	    forever begin
		@ ( negedge ISCLK or posedge CS_N_INT );
		if ( CS_N_INT == 1'b1 ) begin
		    disable read_id;
		end
		else begin
                    SO_OUT_EN = 1'b1;
                    SO_IN_EN  = 1'b0;
                    SI_IN_EN  = 1'b0;
                    WP_IN_EN  = 1'b0;
                    HOLD_N_IN_EN= 1'b0;
                    {SO_Reg, Dummy_ID} <= #tCLQV {Dummy_ID, Dummy_ID[23]};
		end
	    end  // end forever
	end
    endtask // read_id
    
    /*----------------------------------------------------------------------*/
    /*	Description: define a read status task (RDSR)			    */
    /*----------------------------------------------------------------------*/
    task read_status;
	integer Dummy_Count;
	begin
       Dummy_Count = 8;
       forever begin
		@ ( negedge ISCLK or posedge CS_N_INT );
			if ( CS_N_INT == 1'b1 ) begin
				disable read_status;
			end
			else begin
             SO_OUT_EN = 1'b1;
             SO_IN_EN  = 1'b0;
             SI_IN_EN  = 1'b0;
             WP_IN_EN  = 1'b0;
             HOLD_N_IN_EN= 1'b0;
				 if ( Dummy_Count ) begin
						Dummy_Count = Dummy_Count - 1;
                                    
						if(flag_sr1)
							SO_Reg    <= #tCLQV Status_Reg[Dummy_Count];
						else if(flag_sr2)
							SO_Reg    <= #tCLQV Status_Reg_2[Dummy_Count];           
				end
				else begin
               	Dummy_Count = 7;
						if(flag_sr1)
							SO_Reg    <= #tCLQV Status_Reg[Dummy_Count];
						else if(flag_sr2)
							SO_Reg    <= #tCLQV Status_Reg_2[Dummy_Count];      
				end		 
			end
	    end  // end forever
	end
    endtask // read_status

    

    /*----------------------------------------------------------------------*/
    /*	Description: define a write status task				    */
    /*----------------------------------------------------------------------*/
    task write_status;
    reg [7:0] Status_Reg_Up;
    reg [7:0] CR_Up;
	begin
          if (WRSR_Mode == 1'b0 && WRSR2_Mode == 1'b1) begin
	    Status_Reg_Up = SI_data_Reg[15:8] ;
            CR_Up = SI_data_Reg [7:0];
          end
          else if (WRSR_Mode == 1'b1 && WRSR2_Mode == 1'b0) begin
            Status_Reg_Up = SI_data_Reg[7:0] ;
          end

          if (WRSR_Mode == 1'b1 && WRSR2_Mode == 1'b0) begin       
					tWRSR = tW;

                Status_Reg[0]   = 1'b1;
                #tWRSR;
	        Status_Reg[7]   =  Status_Reg_Up[7];
	        Status_Reg[6]   =  Status_Reg_Up[6];                                 
	        Status_Reg[5:2] =  Status_Reg_Up[5:2];
	        Status_Reg[0]   = 1'b0;
	        Status_Reg[1]   = 1'b0;
	        WRSR_Mode       = 1'b0;
          end	 

          else if (WRSR_Mode == 1'b0 && WRSR2_Mode == 1'b1) begin  
		tWRSR = tW;

                Status_Reg[0]   = 1'b1;
                #tWRSR;
					 Status_Reg_2[6:3] = CR_Up[6:3];
					 Status_Reg_2[1:0] = CR_Up[1:0];
					 
					 
	        Status_Reg[7]   =  Status_Reg_Up[7];
			  Status_Reg[6]   =  Status_Reg_Up[6];                                
	        Status_Reg[5:2] =  Status_Reg_Up[5:2];
	        Status_Reg[0]   = 1'b0;
	        Status_Reg[1]   = 1'b0;
	        WRSR2_Mode      = 1'b0;
          end
	end
    endtask // write_status
   
    /*----------------------------------------------------------------------*/
    /*	Description: define a read data task				    */
    /*		     03 AD1 AD2 AD3 X					    */
    /*----------------------------------------------------------------------*/
    task read_1xio;
	integer Dummy_Count, Tmp_Int;
	reg  [7:0]	 OUT_Buf;
	begin
	    Dummy_Count = 8;
            dummy_cycle(24);
            #1; 
            read_array(Address, OUT_Buf);
	    forever begin
		@ ( negedge ISCLK or posedge CS_N_INT );
		if ( CS_N_INT == 1'b1 ) begin
		    disable read_1xio;
		end 
		else  begin 
		    Read_Mode	= 1'b1;
		    SO_OUT_EN	= 1'b1;
                    SI_IN_EN    = 1'b0;
		    if ( Dummy_Count ) begin
		    	{SO_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[7]};
			Dummy_Count = Dummy_Count - 1;
		    end
		    else begin
			Address = Address + 1;
                        load_address(Address);
                        read_array(Address, OUT_Buf);
			{SO_Reg, OUT_Buf} <= #tCLQV  {OUT_Buf, OUT_Buf[7]};
			Dummy_Count = 7 ;
		    end
		end 
	    end  // end forever
	end   
    endtask // read_1xio

    /*----------------------------------------------------------------------*/
    /*	Description: define a fast read data task			    */
    /*		     0B AD1 AD2 AD3 X					    */
    /*----------------------------------------------------------------------*/
    task fastread_1xio;
	integer Dummy_Count, Tmp_Int;
	reg  [7:0]	 OUT_Buf;
	begin
            Dummy_Count = 8;
	    dummy_cycle(32);
            read_array(Address, OUT_Buf);
	    forever begin
		@ ( negedge ISCLK or posedge CS_N_INT );
		if ( CS_N_INT == 1'b1 ) begin
		    disable fastread_1xio;
			 read_scur=0;
		end 
		else begin 
		    Read_Mode = 1'b1;
                    SO_OUT_EN = 1'b1;
                    SI_IN_EN  = 1'b0;
		    if ( Dummy_Count ) begin
		        {SO_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[7]};
			Dummy_Count = Dummy_Count - 1;
		    end
		    else begin
			Address = Address + 1;
                        load_address(Address);
                        read_array(Address, OUT_Buf);
                        {SO_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[7]};
			Dummy_Count = 7 ;
		    end
		end    
	    end  // end forever
	end   
    endtask // fastread_1xio


    /*----------------------------------------------------------------------*/
    /*  Description: define a block erase task                              */
    /*               52 AD1 AD2 AD3                                         */
    /*----------------------------------------------------------------------*/
    task block_erase_32k;
        integer i;
        integer Start_Add;
        integer End_Add;
        begin
            Block       =  Address[ADDR_MSB:15];
            Block2      =  Address[ADDR_MSB:15];
            Start_Add   = (Address[ADDR_MSB:15]<<15) + 16'h0;
            End_Add     = (Address[ADDR_MSB:15]<<15) + 16'h7fff;
            Status_Reg[0] =  1'b1;
            if ( write_protect(Address) == 1'b0 ) begin   
                     for( i = Start_Add; i <= End_Add; i = i + 1 )
                       begin
									 #(tBE32/(End_Add-Start_Add)) ;
                           ARRAY[i] = 8'hff;
									if(suspend)
										i=i-1;
                       end
               Status_Reg[0] =  1'b0;//WIP
               Status_Reg[1] =  1'b0;//WEL
               BE_Mode = 1'b0;
               BE32K_Mode = 1'b0;
            end
            else begin
                $display ($time," Block Erase failed, block at address %24h is write protected.\n", Address);
                #tERS_CHK;
                Status_Reg[0] = 1'b0;//WIP
                Status_Reg[1] = 1'b0;//WEL
                BE_Mode = 1'b0;
                BE32K_Mode = 1'b0;
            end
        end
    endtask // block_erase_32k

    
    /*----------------------------------------------------------------------*/
    /*	Description: define a block erase task				    */
    /*		     D8 AD1 AD2 AD3					    */
    /*----------------------------------------------------------------------*/
    task block_erase;
	integer i;
        integer Start_Add;
        integer End_Add;
	begin
	    Block	=  Address[ADDR_MSB:16];
	    Block2	=  Address[ADDR_MSB:16];
	    Start_Add	= (Address[ADDR_MSB:16]<<16) + 16'h0;
	    End_Add	= (Address[ADDR_MSB:16]<<16) + 16'hffff;
	    Status_Reg[0] =  1'b1;

	    if ( write_protect(Address) == 1'b0 ) begin
                       for( i = Start_Add; i <= End_Add; i = i + 1 )
                       begin
                          if(suspend)
									i=i-1;
									#(tBE/(End_Add-Start_Add)) ;
								  ARRAY[i] = 8'hff;
                       end
	    end
	    else begin
                $display ($time," Block Erase failed, block at address %24h is write protected.\n", Address);
	        #tERS_CHK;
            end   
		Status_Reg[0] =  1'b0;//WIP
		Status_Reg[1] =  1'b0;//WEL
		BE_Mode = 1'b0;
                BE64K_Mode = 1'b0;
	end
    endtask // block_erase

    /*----------------------------------------------------------------------*/
    /*	Description: define a sector 4k erase task			    */
    /*		     20 AD1 AD2 AD3					    */
    /*----------------------------------------------------------------------*/
    task sector_erase_4k;
	integer i;
        integer Start_Add;
        integer End_Add;
	begin
	    Sector	=  Address[ADDR_MSB:12]; 
	    Start_Add	= (Address[ADDR_MSB:12]<<12) + 12'h000;
	    End_Add	= (Address[ADDR_MSB:12]<<12) + 12'hfff;	      
	    Status_Reg[0] =  1'b1;

	    if ( write_protect(Address) == 1'b0) begin  
                       for( i = Start_Add; i <= End_Add; i = i + 1 )
                       begin
                          if(suspend)
									i=i-1;
								  #(tSE/(End_Add-Start_Add));
									ARRAY[i] = 8'hff;
                       end
            end
	    else begin
                $display ($time," Sector Erase failed, block at address %24h is write protected.\n", Address);
	        #tERS_CHK;
	    end
		Status_Reg[0] = 1'b0;//WIP
		Status_Reg[1] = 1'b0;//WEL
		SE_4K_Mode = 1'b0;
	 end
    endtask // sector_erase_4k
    
    /*----------------------------------------------------------------------*/
    /*	Description: define a chip erase task				    */
    /*		     60(C7)						    */
    /*----------------------------------------------------------------------*/
    task chip_erase;
	integer i;
	integer k;
	integer j;
        begin
            Status_Reg[0] =  1'b1;

            if ( Dis_CE == 1'b1  || (WP_B_INT == 1'b0) ) begin
                #tERS_CHK;
                Status_Reg[0] = 1'b1;
            end
            else begin
            	for( i = 0; i <Block_NUM; i = i+1 ) begin
	            Address = (i<<16) + 16'h0;
	            Start_Add = (i<<16) + 16'h0;
	            End_Add   = (i<<16) + 16'hffff;	
	            for( j = Start_Add; j <=End_Add; j = j + 1 )
	            begin
					 for ( k = 0;k<tCE/100;k = k + 1) begin
                   #(100_000_000/((End_Add-Start_Add)*(Block_NUM)));
						  if(suspend)
								k=k-1;
                end
						 ARRAY[j] =  8'hff;
	            end
	        end
	    end
            Status_Reg[0] = 1'b0;//WIP
            Status_Reg[1] = 1'b0;//WEL
	    CE_Mode = 1'b0;
        end
    endtask // chip_erase	


    /*----------------------------------------------------------------------*/
    /*	Description: define a erase_sec_reg task			    */
    /*		     20 AD1 AD2 AD3					    */
    /*----------------------------------------------------------------------*/
    task erase_sec_reg;
	integer i;
        integer Start_Add;
        integer End_Add;
	begin 
	    Start_Add	= { Address[9:8],8'h00};
	    End_Add	= { Address[9:8],8'hff};	      
	    Status_Reg[0] =  1'b1;
                       for( i = Start_Add; i <= End_Add; i = i + 1 )
                       begin
								  #(tSE/12'hfff);
									Secur_ARRAY[i] = 8'hff;
                       end
		Status_Reg[0] = 1'b0;//WIP
		Status_Reg[1] = 1'b0;//WEL
		ERSCUR_Mode = 1'b0;
	 end
    endtask // erase_sec_reg



    /*----------------------------------------------------------------------*/
    /*	Description: define a page program task				    */
    /*		     02 AD1 AD2 AD3					    */
    /*----------------------------------------------------------------------*/
    task page_program;
	input  [ADDR_MSB:0]  Address;
	reg    [7:0]	  Offset;
	integer Dummy_Count, Tmp_Int, i;
	begin
	    Dummy_Count = Buffer_Num;    // page size
	    Tmp_Int = 0;
            Offset  = Address[7:0];
	    /*------------------------------------------------*/
	    /*	Store 256 bytes into a temp buffer - Dummy_A  */
	    /*------------------------------------------------*/
            for (i = 0; i < Dummy_Count ; i = i + 1 ) begin
		Dummy_A[i]  = 8'hff;
            end
	    forever begin
				@ ( posedge ISCLK or posedge CS_N_INT );
				if ( CS_N_INT == 1'b1 ) begin
					if ( (Tmp_Int % 8 !== 0) || (Tmp_Int == 1'b0) ) begin
						PP_Mode = 0;
						Page_prog_Mode = 0;
						disable page_program;
					end
					else begin
						if ( Tmp_Int > 8 )
							Byte_PGM_Mode = 1'b0;
                  else 
							Byte_PGM_Mode = 1'b1;
						update_array ( Address );
					end
					disable page_program;
				end
				else begin  // count how many Bits been shifted
					Tmp_Int = ( PP_Mode ) ? Tmp_Int + 4 : Tmp_Int + 1;
					if ( Tmp_Int % 8 == 0) begin
                        #1;
						Dummy_A[Offset] = SI_data_Reg [7:0];
						Offset = Offset + 1;   
                  Offset = Offset[7:0];   
               end  
				end
	    end  // end forever
		end
    endtask // page_program

    
    /*----------------------------------------------------------------------*/
    /*	Description: define a read electronic ID (RES)			    */
    /*		     AB X X X						    */
    /*----------------------------------------------------------------------*/
    task read_electronic_id;
	reg  [7:0] Dummy_ID;
	begin
        dummy_cycle(23);
	    Dummy_ID = ID_Device;
	    dummy_cycle(1);

	    forever begin
		@ ( negedge ISCLK or posedge CS_N_INT );
		if ( CS_N_INT == 1'b1 ) begin
		    disable read_electronic_id;
		end 
		else begin  
		    SO_OUT_EN = 1'b1;
                    SO_IN_EN  = 1'b0;
                    SI_IN_EN  = 1'b0;
                    WP_IN_EN  = 1'b0;
                    HOLD_N_IN_EN= 1'b0;
                   {SO_Reg, Dummy_ID} <= #tCLQV  {Dummy_ID, Dummy_ID[7]};
		end
	    end // end forever	 
	end
    endtask // read_electronic_id
	    
    /*----------------------------------------------------------------------*/
    /*	Description: define a read electronic manufacturer & device ID	    */
    /*----------------------------------------------------------------------*/
    task read_electronic_manufacturer_device_id;
	reg  [15:0] Dummy_ID;
	integer Dummy_Count;
	begin
	    dummy_cycle(24);
	    #1;
	    if ( Address[0] == 1'b0 ) begin
		Dummy_ID = {ID_Manufacturer,ID_Device};
	    end
	    else begin
		Dummy_ID = {ID_Device,ID_Manufacturer};
	    end
	    Dummy_Count = 0;
	    forever begin
		@ ( negedge ISCLK or posedge CS_N_INT );
		if ( CS_N_INT == 1'b1 ) begin
		    disable read_electronic_manufacturer_device_id;
		end
		else begin
		    SO_OUT_EN =  1'b1;
                    SI_IN_EN  =  1'b0;
		    {SO_Reg, Dummy_ID} <= #tCLQV  {Dummy_ID, Dummy_ID[15]};
		end
	    end	// end forever
	end
    endtask // read_electronic_manufacturer_device_id

    /*----------------------------------------------------------------------*/
    /*	Description: define a program chip task				    */
    /*	INPUT:address                            			    */
    /*----------------------------------------------------------------------*/
    task update_array;
	 input [ADDR_MSB:0] Address;
	 integer Dummy_Count, i;
    integer program_time;
	 begin
	    Dummy_Count = Buffer_Num;
       Address = { Address [ADDR_MSB:8], 8'h0 };
       program_time = (Byte_PGM_Mode) ? tBP : tPP;
	    Status_Reg[0]= 1'b1;
            if ( write_protect(Address) == 1'b0 ) begin
                        #program_time ;
                        for ( i = 0; i < Dummy_Count; i = i + 1 ) begin
                           if(wr_scur)begin
										Secur_ARRAY[Address+ i] = Secur_ARRAY[Address + i] & Dummy_A[i];
									end
									else
										ARRAY[Address+ i] = ARRAY[Address + i] & Dummy_A[i];
                        end
								 Status_Reg[0] = 1'b0;
				end
				else begin
					#tPGM_CHK ;
					Status_Reg[0] = 1'b0;
					$display ($time," Page Program failed, block at address %24h is write protected.\n", Address);
				end
	    Status_Reg[1] = 1'b0;
	    PP_Mode = 1'b0;
	    Page_prog_Mode = 1'b0;
       Byte_PGM_Mode = 1'b0;
		 wr_scur=0;
	end
    endtask // update_array



    /*----------------------------------------------------------------------*/
    /*	Description: Execute 2X IO Read Mode				    */
    /*----------------------------------------------------------------------*/
    task read_2xio;
	reg  [7:0]  OUT_Buf;
	integer     Dummy_Count;
	begin
	    Dummy_Count=4;
	    SI_IN_EN = 1'b1;
	    SO_IN_EN = 1'b1;
	    SI_OUT_EN = 1'b0;
	    SO_OUT_EN = 1'b0;
	    if(M54_D==2)
			dummy_cycle(12);
		else
			dummy_cycle(13);
		  @ ( negedge ISCLK)
		 DUAL_M= 1'b1;
	    dummy_cycle(1);
		 @ ( negedge ISCLK)
		DUAL_M= 1'b0;
	    #1;
	    if(M54_D==2)
			dummy_cycle(2);
		else
			dummy_cycle(2);
            read_array(Address, OUT_Buf);
          
	    forever @ ( negedge ISCLK or  posedge CS_N_INT ) begin
	        if ( CS_N_INT == 1'b1 ) begin
		    disable read_2xio;
	        end
	        else begin
		    Read_Mode	= 1'b1;
		    SO_OUT_EN	= 1'b1;
		    SI_OUT_EN	= 1'b1;
		    SI_IN_EN	= 1'b0;
		    SO_IN_EN	= 1'b0;
		    if ( Dummy_Count ) begin
			{SO_Reg, SI_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[1:0]};
			Dummy_Count = Dummy_Count - 1;
		    end
		    else begin
//			if ( EN_Burst && Burst_Length==8 && Address[2:0]==3'b111 )
//                            Address = {Address[ADDR_MSB:3], 3'b000};
//			else if ( EN_Burst && Burst_Length==16 && Address[3:0]==4'b1111 )
//                            Address = {Address[ADDR_MSB:4], 4'b0000};
//                        else if ( EN_Burst && Burst_Length==32 && Address[4:0]==5'b1_1111 )
//                            Address = {Address[ADDR_MSB:5], 5'b0_0000};
//                        else if ( EN_Burst && Burst_Length==64 && Address[5:0]==6'b11_1111 )
//                            Address = {Address[ADDR_MSB:6], 6'b00_0000};
//			else
                            Address = Address + 1;
                        load_address(Address);
                        read_array(Address, OUT_Buf);
	    		{SO_Reg, SI_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[1:0]};
	    		Dummy_Count = 3 ;
		    end
	        end
	    end//forever  
	end
    endtask // read_2xio

    /*----------------------------------------------------------------------*/
    /*	Description: Execute 4X IO Read Mode				    */
    /*----------------------------------------------------------------------*/
    task read_4xio;
	reg [7:0]   OUT_Buf ;
	reg [23:0]   burst_addr ;
	reg [5:0]   Address_num ;
	integer	    Dummy_Count;
	begin
	    Address_num = 0;
		 Dummy_Count = 2;
	    SI_OUT_EN    = 1'b0;
	    SO_OUT_EN    = 1'b0;
	    WP_OUT_EN    = 1'b0;
	    HOLD_N_OUT_EN  = 1'b0;
	    SI_IN_EN	= 1'b1;
	    SO_IN_EN	= 1'b1;
	    WP_IN_EN	= 1'b1;
	    HOLD_N_IN_EN   = 1'b1;
 
		  if(M54_Q==2)
			dummy_cycle(5);
		else
			dummy_cycle(6);
		  @ ( negedge ISCLK)
		 QUAD_M= 1'b1;
	    dummy_cycle(1);
		 @ ( negedge ISCLK)
		QUAD_M= 1'b0;
	    #1;
//	    if(M54_Q!=2)
			//dummy_cycle(2);
//		else
			dummy_cycle(1);
	    #1;
	    if ( (SI_data_Reg[0]!= SI_data_Reg[4]) &&
	         (SI_data_Reg[1]!= SI_data_Reg[5]) &&
	         (SI_data_Reg[2]!= SI_data_Reg[6]) &&
	         (SI_data_Reg[3]!= SI_data_Reg[7]) ) begin
	        Set_4XIO_Enhance_Mode = 1'b1;
	    end
	    else  begin 
	        Set_4XIO_Enhance_Mode = 1'b0;
	    end
//            if (!QUAD_Mode && (CMD_BUS == RSTEN || CMD_BUS == RST) && EN4XIO_Read_Mode == 1'b1) 
//
//                dummy_cycle(2);
//            else if ( QUAD_Mode==1'b1)
//                dummy_cycle(6);
//	    else
                dummy_cycle(4);
					 burst_addr=Address;
            read_array(Address, OUT_Buf);
				


	    forever @ ( negedge ISCLK or  posedge CS_N_INT ) begin
	        if ( CS_N_INT == 1'b1 ) begin
		    disable read_4xio;
	        end
	          
	        else begin
                    SO_OUT_EN   = 1'b1;
                    SI_OUT_EN   = 1'b1;
                    WP_OUT_EN   = 1'b1;
                    HOLD_N_OUT_EN = 1'b1;
                    SO_IN_EN    = 1'b0;
                    SI_IN_EN    = 1'b0;
                    WP_IN_EN    = 1'b0;
                    HOLD_N_IN_EN  = 1'b0;
                    Read_Mode  = 1'b1;
                    if ( Dummy_Count ) begin
                        {HOLD_N_Reg, WP_N_Reg, SO_Reg, SI_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[3:0]};
                        Dummy_Count = Dummy_Count - 1;
                    end
                    else begin
                        if ( EN_Burst && Burst_Length==8 && Address_num==3'b111 )begin
                           Address_num = 0;
                            Address = burst_addr;
								end
                        else if ( EN_Burst && Burst_Length==16 && Address_num==4'b1111 )begin
                            Address_num = 0;
									 Address = burst_addr;
								end
                        else if ( EN_Burst && Burst_Length==32 && Address_num==5'b1_1111)begin
                            Address_num = 0;
									 Address = burst_addr;
								end
                        else if ( EN_Burst && Burst_Length==64 && Address_num==6'b11_1111)begin
                            Address_num = 0;
									 Address = burst_addr;
								end
                        else begin
                            Address = Address + 1;
									 Address_num=Address_num+1;
								end
                        load_address(Address);
                        read_array(Address, OUT_Buf);
                        {HOLD_N_Reg, WP_N_Reg, SO_Reg, SI_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[3:0]};
                        Dummy_Count = 1 ;
                    end
	        end
	    end//forever  
	end
    endtask // read_4xio

    /*----------------------------------------------------------------------*/
    /*	Description: define a fast read dual output data task		    */
    /*		     3B AD1 AD2 AD3 X					    */
    /*----------------------------------------------------------------------*/
    task fastread_2xio;
	integer Dummy_Count;
	reg  [7:0] OUT_Buf;
	begin
	    Dummy_Count = 4 ;
	    dummy_cycle(32);
            read_array(Address, OUT_Buf);
	    forever @ ( negedge ISCLK or  posedge CS_N_INT ) begin
	        if ( CS_N_INT == 1'b1 ) begin
		    disable fastread_2xio;
	        end
	        else begin
		    Read_Mode= 1'b1;
		    SO_OUT_EN = 1'b1;
		    SI_OUT_EN = 1'b1;
		    SI_IN_EN  = 1'b0;
		    SO_IN_EN  = 1'b0;
		    if ( Dummy_Count ) begin
			{SO_Reg, SI_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[1:0]};
	    	 	Dummy_Count = Dummy_Count - 1;
		    end
		    else begin
			Address = Address + 1;
                        load_address(Address);
                        read_array(Address, OUT_Buf);
			{SO_Reg, SI_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[1:0]};
			Dummy_Count = 3 ;
		    end
	        end
	    end//forever  
	end
    endtask // fastread_2xio

    /*----------------------------------------------------------------------*/
    /*  Description: define a fast read quad output data task               */
    /*               6B AD1 AD2 AD3 X                                       */
    /*----------------------------------------------------------------------*/
    task fastread_4xio;
        integer Dummy_Count;
        reg  [7:0]  OUT_Buf;
        begin
            Dummy_Count = 2 ;
            dummy_cycle(32);
            read_array(Address, OUT_Buf);
            forever @ ( negedge ISCLK or  posedge CS_N_INT ) begin
                if ( CS_N_INT ==      1'b1 ) begin
                    disable fastread_4xio;
                end
                else begin
                    SI_IN_EN    = 1'b0;
                    SI_OUT_EN   = 1'b1;
                    SO_OUT_EN   = 1'b1;
                    WP_OUT_EN   = 1'b1;
                    HOLD_N_OUT_EN = 1'b1;
                    if ( Dummy_Count ) begin
                        {HOLD_N_Reg, WP_N_Reg, SO_Reg, SI_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[3:0]};
                        Dummy_Count = Dummy_Count - 1;
                    end
                    else begin
                        Address = Address + 1;
                        load_address(Address);
                        read_array(Address, OUT_Buf);
                        {HOLD_N_Reg, WP_N_Reg, SO_Reg, SI_Reg, OUT_Buf} <= #tCLQV {OUT_Buf, OUT_Buf[3:0]};
                        Dummy_Count = 1 ;
                    end
                end
            end//forever
        end
    endtask // fastread_4xio

    /*----------------------------------------------------------------------*/
    /*  Description: define read array output task                          */
    /*----------------------------------------------------------------------*/
    task read_array;
        input [ADDR_MSB:0] Address;
        output [7:0]    OUT_Buf;
        begin
                if(read_scur)begin
						OUT_Buf = Secur_ARRAY[Address] ;
					end
					else
						OUT_Buf = ARRAY[Address] ;
        end
    endtask //  read_array

    /*----------------------------------------------------------------------*/
    /*  Description: define read array output task                          */
    /*----------------------------------------------------------------------*/
    task load_address;
        inout [ADDR_MSB:0] Address;
        begin
				if ( read_scur == 1 ) begin
                Address = Address[ADDR_MSB_OTP:0] ;
            end
        end
    endtask //  load_address

    /*----------------------------------------------------------------------*/
    /*	Description: define a write_protect area function		    */
    /*	INPUT: address							    */
    /*----------------------------------------------------------------------*/ 
    function write_protect;
        input [ADDR_MSB:0] Address;
        begin
	casex({CMP,SEC,TB,BP2,BP1,BP0})
		  6'b0??000:	 write_protect = 1'b0;	// None
		  6'b000001:	 write_protect = (20'hF0000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 1/16
		  6'b000010:	 write_protect = (20'hE0000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 1/8
		  6'b000011:	 write_protect = (20'hC0000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 1/4
		  6'b000100:	 write_protect = (20'h80000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 1/2
		  6'b001001:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'h0FFFF) ? 1'b1 : 1'b0;	// Lower 1/16
		  6'b001010:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'h1FFFF) ? 1'b1 : 1'b0;	// Lower 1/8
		  6'b001011:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'h3FFFF) ? 1'b1 : 1'b0;	// Lower 1/4
		  6'b001100:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Lower 1/2
		  6'b00?101:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// All
		  6'b0??11?:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// All
		  6'b010001:	 write_protect = (20'hFF000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 1/256
		  6'b010010:	 write_protect = (20'hFE000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 1/128
		  6'b010011:	 write_protect = (20'hFC000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 1/64
		  6'b01010?:	 write_protect = (20'hF8000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 1/32
		  6'b011001:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'h00FFF) ? 1'b1 : 1'b0;	// Lower 1/256
		  6'b011010:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'h01FFF) ? 1'b1 : 1'b0;	// Lower 1/128
		  6'b011011:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'h03FFF) ? 1'b1 : 1'b0;	// Lower 1/64
		  6'b01110?:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'h07FFF) ? 1'b1 : 1'b0;	// Lower 1/32
		  6'b1??000:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// All
		  6'b100001:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hEFFFF) ? 1'b1 : 1'b0;	// Lower 15/16
		  6'b100010:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hDFFFF) ? 1'b1 : 1'b0;	// Lower 7/8
		  6'b100011:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hBFFFF) ? 1'b1 : 1'b0;	// Lower 3/4
		  6'b100100:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'h7FFFF) ? 1'b1 : 1'b0;	// Lower 1/2
		  6'b101001:	 write_protect = (20'h10000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 15/16
		  6'b101010:	 write_protect = (20'h20000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 7/8
		  6'b101011:	 write_protect = (20'h40000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 3/4
		  6'b101100:	 write_protect = (20'h80000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 1/2
		  6'b10?101:	 write_protect = 1'b0;	// None
		  6'b1??11?:	 write_protect = 1'b0;	// None
		  6'b110001:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hFEFFF) ? 1'b1 : 1'b0;	// Lower 255/256
		  6'b110010:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hFDFFF) ? 1'b1 : 1'b0;	// Lower 127/128
		  6'b110011:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hFBFFF) ? 1'b1 : 1'b0;	// Lower 63/64
		  6'b11010?:	 write_protect = (20'h00000 <= Address  &&  Address <= 20'hF7FFF) ? 1'b1 : 1'b0;	// Lower 31/32
		  6'b111001:	 write_protect = (20'h01000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 255/256
		  6'b111010:	 write_protect = (20'h02000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 127/128
		  6'b111011:	 write_protect = (20'h04000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 63/64
		  6'b11110?:	 write_protect = (20'h08000 <= Address  &&  Address <= 20'hFFFFF) ? 1'b1 : 1'b0;	// Upper 31/32
	default:   write_protect = 1'b0;
	endcase
        end
    endfunction // write_protect


// *============================================================================================== 
// * AC Timing Check Section
// *==============================================================================================
    wire HOLD_N_EN;
    wire WP_EN;
    assign HOLD_N_EN = !Status_Reg_2[1];
    assign WP_EN = (!Status_Reg_2[1]);

    assign  Write_SHSL = !Read_SHSL;

    wire Noumal_Read_Chk_W;
    assign Noumal_Read_Chk_W = Noumal_Read_Chk;
    wire DUAL_IO_READ_Chk_W;
    assign DUAL_IO_READ_Chk_W = DUAL_IO_READ_Chk;
    wire DUAL_OUT_Chk_W;
    assign DUAL_OUT_Chk_W = DUAL_OUT_Chk;
    wire QUAD_OUT_Chk_W;
    assign QUAD_OUT_Chk_W = QUAD_OUT_Chk;
    wire QUAD_IO_Chk_W;
    assign QUAD_IO_Chk_W = QUAD_IO_Chk ;
    wire QUAD_IO_Chk_W0;
    assign QUAD_IO_Chk_W0 = QUAD_IO_Chk;
    wire tDP_Chk_W;
    assign tDP_Chk_W = tDP_Chk;
    wire tRES1_Chk_W;
    assign tRES1_Chk_W = tRES1_Chk;
    wire tRES2_Chk_W;
    assign tRES2_Chk_W = tRES2_Chk;
    wire PP_Chk_W;
    assign PP_Chk_W = PP_Chk;
    wire Read_SHSL_W;
    assign Read_SHSL_W = Read_SHSL;
    wire SI_IN_EN_W;
    assign SI_IN_EN_W = SI_IN_EN;
    wire SO_IN_EN_W;
    assign SO_IN_EN_W = SO_IN_EN;
    wire WP_IN_EN_W;
    assign WP_IN_EN_W = WP_IN_EN;
    wire HOLD_N_IN_EN_W;
    assign HOLD_N_IN_EN_W = HOLD_N_IN_EN;

    specify
    	/*----------------------------------------------------------------------*/
    	/*  Timing Check                                                        */
    	/*----------------------------------------------------------------------*/
			$period( posedge  ISCLK &&& ~CS_N, tSCLK  );	// SCLK _/~ ->_/~
			$period( negedge  ISCLK &&& ~CS_N, tSCLK  );	// SCLK ~\_ ->~\_
			$period( posedge  ISCLK &&& Noumal_Read_Chk_W , tRSCLK ); // SCLK _/~ ->_/~
			$period( posedge  ISCLK &&& DUAL_IO_READ_Chk_W , tSCLK ); // SCLK _/~ ->_/~
			$period( posedge  ISCLK &&& DUAL_OUT_Chk_W , tSCLK ); // SCLK _/~ ->_/~
			$period( posedge  ISCLK &&& QUAD_IO_Chk_W , tSCLK ); // SCLK _/~ ->_/~ 
			$period( posedge  ISCLK &&& QUAD_OUT_Chk_W , tSCLK ); // SCLK _/~ ->_/~
			$period( posedge  ISCLK &&& QUAD_IO_Chk_W0 , tSCLK ); // SCLK _/~ ->_/~
			$period( posedge  ISCLK &&& PP_Chk_W, tSCLK ); // SCLK _/~ ->_/~

			$width ( posedge  CS_N  &&& tDP_Chk_W, tDP );       // CS_N _/~\_
			$width ( posedge  CS_N  &&& tRES1_Chk_W, tRES1 );   // CS_N _/~\_
			$width ( posedge  CS_N  &&& tRES2_Chk_W, tRES2 );   // CS_N _/~\_

			$width ( posedge  ISCLK &&& ~CS_N, tCH   );       // SCLK _/~~\_
			$width ( negedge  ISCLK &&& ~CS_N, tCL   );       // SCLK ~\__/~
			$width ( posedge  ISCLK &&& Noumal_Read_Chk_W, tCH   );       // SCLK _/~~\_
			$width ( negedge  ISCLK &&& Noumal_Read_Chk_W, tCL   );       // SCLK ~\__/~

			$width ( posedge  CS_N  &&& Read_SHSL_W, tSHSL );	// CS_N _/~\_
			$width ( posedge  CS_N  &&& Write_SHSL, tSHSL );// CS_N _/~\_
			$setup ( SI &&& ~CS_N, posedge ISCLK &&& SI_IN_EN_W,  tDVCH );
			$hold  ( posedge ISCLK &&& SI_IN_EN_W, SI &&& ~CS_N,  tCHDX );

			$setup ( SO &&& ~CS_N, posedge ISCLK &&& SO_IN_EN_W,  tDVCH );
			$hold  ( posedge ISCLK &&& SO_IN_EN_W, SO &&& ~CS_N,  tCHDX );
			$setup ( WP_N &&& ~CS_N, posedge ISCLK &&& WP_IN_EN_W,  tDVCH );
			$hold  ( posedge ISCLK &&& WP_IN_EN_W, WP_N &&& ~CS_N,  tCHDX );

			$setup ( HOLD_N &&& ~CS_N, posedge ISCLK &&& HOLD_N_IN_EN_W,  tDVCH );
			$hold  ( posedge ISCLK &&& HOLD_N_IN_EN_W, HOLD_N &&& ~CS_N,  tCHDX );

			$setup    ( negedge CS_N, posedge ISCLK &&& ~CS_N, tSLCH );
			$hold     ( posedge ISCLK &&& ~CS_N, posedge CS_N, tCHSH );
     
			$setup    ( posedge CS_N, posedge ISCLK &&& CS_N, tSHCH );
			$hold     ( posedge ISCLK &&& CS_N, negedge CS_N, tCHSL );

			$setup ( posedge WP_N &&& WP_EN, negedge CS_N,  tWHSL );
			$hold  ( posedge CS_N, negedge WP_N &&& WP_EN,  tSHWL );

     endspecify

    integer AC_Check_File;
    // timing check module 
    initial 
    begin 
    	AC_Check_File= $fopen ("ac_check.err" );    
    end

    time  T_CS_P , T_CS_N;
    time  T_WP_P , T_WP_N;
    time  T_SCLK_P , T_SCLK_N;
    time  T_HOLD_N_P , T_HOLD_N_N;
    time  T_SI;
    time  T_SO;
    time  T_WP;
    time  T_HOLD;    
    time  T_HOLD_P , T_HOLD_N;                

    initial 
    begin
		T_CS_P = 0; 
		T_CS_N = 0;
		T_WP_P = 0;  
		T_WP_N = 0;
		T_SCLK_P = 0;  
		T_SCLK_N = 0;
		T_HOLD_N_P = 0;  
		T_HOLD_N_N = 0;
		T_SI = 0;
		T_SO = 0;
		T_WP = 0;
		T_HOLD = 0;           
      T_HOLD_P = 0;
      T_HOLD_N = 0;
         
    end
 
    always @ ( posedge ISCLK ) begin

	//tSCLK
        if ( $time - T_SCLK_P < tSCLK && $time > 0 && ~CS_N ) 
	    $fwrite (AC_Check_File, "Clock Frequence for except READ struction fSCLK =%d Mhz, fSCLK timing violation at %d \n", fSCLK, $time );
	//fRSCLK
        if ( $time - T_SCLK_P < tRSCLK && Noumal_Read_Chk && $time > 0 && ~CS_N )
	    $fwrite (AC_Check_File, "Clock Frequence for READ instruction fRSCLK =%d Mhz, fRSCLK timing violation at %d \n", fRSCLK, $time );
	//fSCLK
        if ( $time - T_SCLK_P < tSCLK && DUAL_IO_READ_Chk && $time > 0 && ~CS_N )
	    $fwrite (AC_Check_File, "Clock Frequence for 2XI/O instruction fSCLK =%d Mhz, fSCLK timing violation at %d \n", fSCLK, $time );
   //fSCLK
        if ( $time - T_SCLK_P < tSCLK &&  DUAL_OUT_Chk && $time > 0 && ~CS_N )
            $fwrite (AC_Check_File, "Clock Frequence for DUAL_OUT_READ instruction fSCLK =%d Mhz, fSCLK timing violation at %d \n", fSCLK, $time );

	//fSCLK
        if ( $time - T_SCLK_P < tSCLK && QUAD_IO_Chk_W && $time > 0 && ~CS_N )
	    $fwrite (AC_Check_File, "Clock Frequence for 4XI/O instruction fSCLK =%d Mhz, fSCLK timing violation at %d \n", fSCLK, $time );
        //fSCLK
        if ( $time - T_SCLK_P < tSCLK && QUAD_OUT_Chk && $time > 0 && ~CS_N )
            $fwrite (AC_Check_File, "Clock Frequence for QUAD_OUT_READ instruction fSCLK =%d Mhz, fSCLK timing violation at %d \n", fSCLK, $time );
        //fSCLK
        if ( $time - T_SCLK_P < tSCLK && QUAD_IO_Chk_W0  && $time > 0 && ~CS_N )
            $fwrite (AC_Check_File, "Clock Frequence for 4XI/O instruction fSCLK =%d Mhz, fSCLK timing violation at %d \n", fSCLK, $time );
        //fSCLK
        if ( $time - T_SCLK_P < tSCLK && PP_Chk && $time > 0 && ~CS_N )
            $fwrite (AC_Check_File, "Clock Frequence for 4PP program instruction fSCLK =%d Mhz, fSCLK timing violation at %d \n", fSCLK, $time );

        T_SCLK_P = $time; 
        #0;  
	//tDVCH
        if ( T_SCLK_P - T_SI < tDVCH && SI_IN_EN && T_SCLK_P > 0 )
	    $fwrite (AC_Check_File, "minimun Data SI setup time tDVCH=%d ns, tDVCH timing violation at %d \n", tDVCH, $time );
        if ( T_SCLK_P - T_SO < tDVCH && SO_IN_EN && T_SCLK_P > 0 )
	    $fwrite (AC_Check_File, "minimun Data SO setup time tDVCH=%d ns, tDVCH timing violation at %d \n", tDVCH, $time );
        if ( T_SCLK_P - T_WP < tDVCH && WP_IN_EN && T_SCLK_P > 0 )
	    $fwrite (AC_Check_File, "minimun Data WP_N setup time tDVCH=%d ns, tDVCH timing violation at %d \n", tDVCH, $time );

        if ( T_SCLK_P - T_HOLD < tDVCH && HOLD_N_IN_EN && T_SCLK_P > 0 )
	    $fwrite (AC_Check_File, "minimun Data HOLD_N setup time tDVCH=%d ns, tDVCH timing violation at %d \n", tDVCH, $time );
	//tCL
        if ( T_SCLK_P - T_SCLK_N < tCL && ~CS_N && T_SCLK_P > 0 )
	    $fwrite (AC_Check_File, "minimun SCLK Low time tCL=%f ns, tCL timing violation at %d \n", tCL, $time );
        //tCL
        if ( T_SCLK_P - T_SCLK_N < tCL && Noumal_Read_Chk && T_SCLK_P > 0 )
            $fwrite (AC_Check_File, "minimun SCLK Low time tCL=%f ns, tCL timing violation at %d \n", tCL, $time );
        #0;
        // tSLCH
        if ( T_SCLK_P - T_CS_N < tSLCH  && T_SCLK_P > 0 )
            $fwrite (AC_Check_File, "minimun CS_N active setup time tSLCH=%d ns, tSLCH timing violation at %d \n", tSLCH, $time );

        // tSHCH
        if ( T_SCLK_P - T_CS_P < tSHCH  && T_SCLK_P > 0 )
            $fwrite (AC_Check_File, "minimun CS_N not active setup time tSHCH=%d ns, tSHCH timing violation at %d \n", tSHCH, $time );
    end

    always @ ( negedge ISCLK ) begin
        T_SCLK_N = $time;
        #0; 
	//tCH
        if ( T_SCLK_N - T_SCLK_P < tCH && ~CS_N && T_SCLK_N > 0 )
	    $fwrite (AC_Check_File, "minimun SCLK High time tCH=%f ns, tCH timing violation at %d \n", tCH, $time );
        //tCH
        if ( T_SCLK_N - T_SCLK_P < tCH && Noumal_Read_Chk && T_SCLK_N > 0 )
            $fwrite (AC_Check_File, "minimun SCLK High time tCH=%f ns, tCH timing violation at %d \n", tCH, $time );
    end


    always @ ( SI ) begin
        T_SI = $time; 
        #0;  
	//tCHDX
	if ( T_SI - T_SCLK_P < tCHDX && SI_IN_EN && T_SI > 0 )
	    $fwrite (AC_Check_File, "minimun Data SI hold time tCHDX=%d ns, tCHDX timing violation at %d \n", tCHDX, $time );
    end

    always @ ( SO ) begin
        T_SO = $time; 
        #0;  
	//tCHDX
	if ( T_SO - T_SCLK_P < tCHDX && SO_IN_EN && T_SO > 0 )
	    $fwrite (AC_Check_File, "minimun Data SO hold time tCHDX=%d ns, tCHDX timing violation at %d \n", tCHDX, $time );
    end

    always @ ( WP_N ) begin
        T_WP = $time; 
        #0;  
	//tCHDX
	if ( T_WP - T_SCLK_P < tCHDX && WP_IN_EN && T_WP > 0 )
	    $fwrite (AC_Check_File, "minimun Data WP_N hold time tCHDX=%d ns, tCHDX timing violation at %d \n", tCHDX, $time );
    end

    always @ ( HOLD_N ) begin
        T_HOLD = $time;   
	//tCHDX
       if ( T_HOLD - T_SCLK_P < tCHDX && HOLD_N_IN_EN && T_HOLD_N > 0 )
	    $fwrite (AC_Check_File, "minimun Data HOLD_N hold time tCHDX=%d ns, tCHDX timing violation at %d \n", tCHDX, $time );
    end

    always @ ( posedge CS_N ) begin
        T_CS_P = $time;  
	// tCHSH 
        if ( T_CS_P - T_SCLK_P < tCHSH  && T_CS_P > 0 )
	    $fwrite (AC_Check_File, "minimun CS_N active hold time tCHSH=%d ns, tCHSH timing violation at %d \n", tCHSH, $time );
    end

    always @ ( negedge CS_N ) begin
        T_CS_N = $time;
        #0;
	//tCHSL
        if ( T_CS_N - T_SCLK_P < tCHSL  && T_CS_N > 0 )
	    $fwrite (AC_Check_File, "minimun CS_N not active hold time tCHSL=%d ns, tCHSL timing violation at %d \n", tCHSL, $time );
	//tSHSL
        if ( T_CS_N - T_CS_P < tSHSL && T_CS_N > 0 && Read_SHSL)
            $fwrite (AC_Check_File, "minimun CS_N deslect  time tSHSL=%d ns, tSHSL timing violation at %d \n", tSHSL, $time );
        if ( T_CS_N - T_CS_P < tSHSL && T_CS_N > 0 && Write_SHSL)
            $fwrite (AC_Check_File, "minimun CS_N deslect  time tSHSL=%d ns, tSHSL timing violation at %d \n", tSHSL, $time );

	//tWHSL
        if ( T_CS_N - T_WP_P < tWHSL && WP_EN  && T_CS_N > 0 )
	    $fwrite (AC_Check_File, "minimun WP setup  time tWHSL=%d ns, tWHSL timing violation at %d \n", tWHSL, $time );


        //tDP
        if ( T_CS_N - T_CS_P < tDP && T_CS_N > 0 && tDP_Chk)
            $fwrite (AC_Check_File, "when transite from Standby Mode to Deep-Power Mode to Deep-Power Mode, CS_N must remain high for at least tDP =%d ns, tDP timing violation at %d \n", tDP, $time );


        //tRES1/2
        if ( T_CS_N - T_CS_P < tRES1 && T_CS_N > 0 && tRES1_Chk)
            $fwrite (AC_Check_File, "when transite from Deep-Power Mode to Standby Mode, CS_N must remain high for at least tRES1 =%d ns, tRES1 timing violation at %d \n", tRES1, $time );

        if ( T_CS_N - T_CS_P < tRES2 && T_CS_N > 0 && tRES2_Chk)
            $fwrite (AC_Check_File, "when transite from Deep-Power Mode to Standby Mode, CS_N must remain high for at least tRES2 =%d ns, tRES2 timing violation at %d \n", tRES2, $time );
    end

    always @ ( posedge HOLD_B_INT ) begin
        T_HOLD_P = $time;
        #0;
    end

    always @ ( negedge HOLD_B_INT ) begin
        T_HOLD_N = $time;
        #0;
    end

    always @ ( posedge WP_N ) begin
        T_WP_P = $time;
        #0;  
    end

    always @ ( negedge WP_N ) begin
        T_WP_N = $time;
        #0;
	//tSHWL
        if ( ((T_WP_N - T_CS_P < tSHWL) || ~CS_N) && WP_EN && T_WP_N > 0 )
	    $fwrite (AC_Check_File, "minimun WP hold time tSHWL=%d ns, tSHWL timing violation at %d \n", tSHWL, $time );
    end
`endif
endmodule







