
module QPU_V(
  input clk,reset,RDY,
  input [15:0]IR,
  input IRQ1,IRQ2,
  input [7:0] A_result,
  input A_vin,A_cin,
  input [7:0] M_Din,
  input I1,I2,I3,I4,

  output [11:0] pc_out,
  output [9:0]  W_AddrO,
  output [7:0]  W_DoutO,
  output [9:0]  M_AddrO,
  output M_WEO,M_IO,
  output A_adc_sbc,A_cout,
  output [7:0] Op1,Op2,
  output [7:0] ST,OPS,RA,RF,RSP

);

parameter [2:0] S0 = 3'b001,  
        S1 = 3'b010,  
        S2 = 3'b100;
parameter [7:0] OP_AND=8'b00000001,
                OP_ORL=8'b00000010,
                OP_XOR=8'b00000100,
                OP_ASC=8'b00001000,
                OP_SRI=8'b00010000,
                OP_LDR=8'b00100000,          
                OP_STR=8'b01000000,
                OP_TMP=8'b10000000,
                OP_NOP=8'b00000000;
                
reg [9:0] W_Addr,M_Addr;
reg [7:0] W_Dout;

reg [2:0]  st;
reg [11:0] pc,pc_next;

reg [9:0]  WAddr;
reg [15:0] SP,RX,RY;

reg [7:0]  OP_TYPE,LAB;
//000=NOP,001=OP_AND,010=OP_ORL,011=OP_XOR;
//100=OP_ADC_SBC,101=SHR_INC,110=POP_PSH,111=OP_LDR_STR;
reg [2:0]  IR_TYPE,LIR_TYPE,COP_TYPE,LOP_TYPE;

reg COut,IOMode,MWE0,MWE1,OP_ADC_SBC,M_WE,C_NEXT,OP_PSH_POP,LOP_PSH_POP;
reg [7:0]  Acc,Flags,LAH;
reg [7:0]  OP1A,OP2A,OPB;
wire[7:0]  OP1,OP2;
reg [3:0]  LWx,LLWx;
reg[7:0]  OP_MUX;

reg F1,F2,LMWE0;
reg[1:0] FS;

wire[2:0]  IR_CMD;
wire[3:0]  IR_REG,PK_REG;
wire[3:0]  IR_REGB,PK_REGB;

assign IR_CMD=IR[14:12];
assign IR_REG=IR[11:8];
assign IR_REGB=IR[3:0];

assign PK_REG= (IR_REG >4'b1001)? 4'b1000:IR_REG;
assign PK_REGB=(IR_REGB>4'b1001)? 4'b1000:IR_REGB;

assign W_AddrO=W_Addr;
assign M_AddrO=M_Addr;
assign W_DoutO=W_Dout;
assign M_IO=IOMode;

assign pc_out=pc;

assign Op1=OP1;
assign Op2=OP2;

assign A_cout=Flags[0];
assign A_adc_sbc=OP_ADC_SBC;

assign ST= {LLWx,F2,LOP_TYPE}; 
assign OPS=OP_TYPE;
assign RA=Acc;
assign RF=Flags;
assign RSP=SP[7:0];



always @(posedge clk)
begin
    OPB=M_Din;

    LAB=IR[7:0];
    IR_TYPE=IR[10:8];

    OP_ADC_SBC=~IR[14];              //3r=ADC,5r=SBC
    COut=Flags[0];
    
    COP_TYPE=IR[14:12];
    
    if (reset)
    begin
        st=S0;
        OP_TYPE=OP_NOP;
        IOMode=1'b0;
        MWE0=1'b0;
        MWE1=1'b0;
        LWx=4'b1111;
        
        pc=12'd0;
        SP=16'h0100;
        RX=10'd0;
        RY=10'd0;
        Flags=8'd0;
        Acc=8'hA5;    //Cold Reset Flag 
        pc_next=10'd0;      
    end
    else
    begin
    case(st) 
      S0:
      begin
              
        if (~IR[15])
        begin
//            LOP_TYPE=IR[14:12];
            
            //Decoding OP_TYPE from IR
            if (IR_CMD==3'b000)
                OP_TYPE=OP_AND;
            else if (IR_CMD==3'b001)
                OP_TYPE=OP_ORL;
            else if (IR_CMD==3'b010)
                OP_TYPE=OP_XOR;
            else if (IR_CMD==3'b011)
                OP_TYPE=OP_ASC;
            else if (IR_CMD==3'b100)
                OP_TYPE=OP_SRI;
            else if (IR_CMD==3'b101)
                OP_TYPE=OP_ASC;
            else if (IR_CMD==3'b110)
                OP_TYPE=OP_LDR;
            else // if (IR_CMD=3'b111)
                OP_TYPE=OP_STR;
          
                        
            //OP1 Assignment
            if (LWx==PK_REG)
            begin
                OP1A=OP_MUX;
                F1=1'b0;
            end                         
            else if(IR_REG==4'b1001)
            begin
                OP1A=Flags;
                F1=1'b0;
            end    
            else if((IR_REG[3])|(IR_CMD>=3'b110))
            begin
                OP1A=Acc;
                F1=1'b0;
            end        
            else
            begin        
                OP1A=8'd0;//M_Din;            
                F1=1'b1;
            end 
            
            //OP2 Assignment     
            if(IR_REG==4'b101x)
            begin
                if(LWx==PK_REGB)
                begin
                    OP2A=OP_MUX;
                    F2=1'b0;
                end                          
                else if(IR_REGB==4'b1001)
                begin
                    OP2A=Flags;
                    F2=1'b0;
                end
                else if(IR_REGB[3])
                begin
                    OP2A=Acc;
                    F2=1'b0;
                end
                else
                begin
                    OP2A=8'd0;//M_Din;
                    F2=1'b1;
                end    
            end
            else
            begin
                OP2A=IR[7:0];
                F2=1'b0;
            end 
            
            if (IR_REG>=4'b1100)
            begin
                if (IR[9:8]==2'b00)     //6F:LDR Acc,(Ex-RAM)   7F:STR Acc,(Ex-RAM)
                        WAddr={2'd0,IR[7:0]};
                else if (IR[9:8]==2'b01)
                begin
                        WAddr=SP-{IR[7],IR[7],IR[7],IR[7],IR[7],IR[7],IR[7:0]};
                end
                else if (IR[9:8]==2'b10)
                        WAddr=RX;
                else
                        WAddr=RY;
                        
                OP_PSH_POP=(IR[9:7]==3'b010) & (IR_CMD>=3'b110);         
                IOMode=(IR[7:6]==2'b00);

                MWE1=(IR_CMD==3'b111);    //STM
                MWE0=1'b0;
                LWx=4'b1000;
                st=S1;                
            end
            else
            begin
                WAddr=6'd0+PK_REG;
                
                OP_PSH_POP=1'b0;    
                IOMode=1'b0;
                MWE1=1'b0;
                if ((IR_CMD==3'b100)&(IR_REG>4'b1000))  //4 101x£¬À©Õ¹Ö¸Áî
                begin
                    st=S1;
                    MWE0=1'b0;
                end
                else
                begin
                    MWE0=1'b1;
                    pc=pc+1;    
                end
                
                LWx=PK_REG; 
            end
                                                   
            //RUN Last Decoded OPs
              
            if (LMWE0)
            begin
                if (LLWx==4'b1001)
                    Flags=OP_MUX;
                else
                begin    
                    if (LLWx>=4'b1000)
                        Acc=OP_MUX;
                    Flags[0]=C_NEXT;
                    Flags[1]=(OP_MUX==8'd0);
                    if (OP_TYPE[3])           //OP_ASC:ADC/SBC
                        Flags[2]=A_vin;
                    Flags[3]=OP_MUX[7];   
                end                    
            end

        end //(~IR[15])
        else
        begin
            LWx=4'b1110;
            MWE0=1'b0;
            MWE1=1'b0;
            OP_TYPE=3'b000;
           
            pc=pc+1;
        end  
      end
      
      S1:
      begin   //A->X,A<-XH,A<-XL,X->Y,Y->X,X->SP,SP->X
          if(LOP_TYPE==4'b100)
          begin
          	
              begin
              	  if (LIR_TYPE==3'b01x)
              	      SP={M_Din,Acc};
                  else if (LIR_TYPE==3'b101)
                      SP=SP-{IR[7],IR[7],IR[7],IR[7],IR[7],IR[7],IR[7:0]};
                  else if (LIR_TYPE==3'b110)
                      RX=RX-{IR[7],IR[7],IR[7],IR[7],IR[7],IR[7],IR[7:0]};
                  else if (LIR_TYPE==3'b111)
                      RY=RY-{IR[7],IR[7],IR[7],IR[7],IR[7],IR[7],IR[7:0]};
/*
                  else if (LIR_TYPE==3'b00x)
                  begin
                  		RX={RX[7:0],Acc};
                  		Acc=RX[15:8];
                	end	
                	else
                  begin
                  		RY={RY[7:0],Acc};
                  		Acc=RY[15:8];
                	end	
*/                	
              end
//              else
//              begin
//                  case (LIR_TYPE)
//                    3'b010:
//                        Acc=RX[7:0];
//                    3'b011:
//                        Acc=RX[15:8];
//                    3'b100:
//                        RX=RY;
//                    3'b101:
//                        RY=RX;
//                    3'b110:
//                        RX=SP;
//                    3'b111:
//                        SP=RX;
//                    default:
//                        RX={RX[7:0],Acc};   
//                  endcase
//              end 
                  
              LWx=4'b1110;
              MWE0=1'b0;
              MWE1=1'b0;          
          end
          else if(LOP_TYPE<4'b110)
          begin
              WAddr=6'd0+4'b1000;
              LWx=4'b1000;
              MWE0=1'b1;
              MWE1=1'b0;              
          end   
          else 
          begin
              if(LOP_TYPE==4'b110)   //OP_LDR
                  Acc=M_Din;
                  
              LWx=4'b1110;
              MWE0=1'b0;
              MWE1=1'b0;                                
          end
                    
          if((LOP_PSH_POP)) //SP adjusted after POP,PSH (LOP_TYPE>=3'b110) & 
          begin
              if (LOP_TYPE[0])  //PSH
                  SP=WAddr;
              else              //POP
                  SP=SP+1;
          end 
          
          OP_PSH_POP=1'b0;
          IOMode=1'b0;
          
          pc=pc+1;              
          st=S0;    
      end
      
      default:
      begin
          st=S0;
          IOMode=1'b0;
          LWx=4'b1110;
          MWE0=1'b0;
          MWE1=1'b0;
          pc=12'd0;
      end
    endcase
    
    end
    
end

always @(negedge clk)
begin
    if (reset)
    begin
        LLWx=4'b1110;
        LOP_TYPE=3'b000;
        LIR_TYPE=3'b000;
        LMWE0=1'b0;
        LOP_PSH_POP=1'b0;
    end
    else 
    begin
        LLWx=LWx;
        LOP_TYPE=COP_TYPE;
        LIR_TYPE=IR_TYPE;
        LMWE0=MWE0;
        LOP_PSH_POP=OP_PSH_POP;
    end
end

assign M_WEO=MWE0 | MWE1; //(st==S0) & MWE0 | (st==S1) & MWE1;
assign OP1=(F1)? OPB:OP1A;
assign OP2=(F2)? OPB:OP2A;
        
always @*
begin
    if(st==S0)
    begin
        if (IR_REG[3]) //==4'b101x)
            M_Addr={6'd0,PK_REGB};
        else
            M_Addr={6'd0,PK_REG};
            
//        if (MWE0)
        W_Addr=WAddr;
            
            
//        M_WE=MWE0;

        case(OP_TYPE) 
        OP_AND:
        begin
            OP_MUX=OP1 & OP2;
            C_NEXT=Flags[0];
        end
            
        OP_ORL:
        begin
            OP_MUX=OP1 | OP2;
            C_NEXT=Flags[0];
        end
            
        OP_XOR:
        begin
            OP_MUX=OP1 ^ OP2;
            C_NEXT=Flags[0];
        end
                    
        OP_ASC:
        begin
            OP_MUX=A_result;
            C_NEXT=A_cin;
        end
            
        OP_SRI:
        begin
            if (~LAB[7])
            begin
                OP_MUX={Flags[0],OP1[7:1]};
                C_NEXT=OP1[0];
            end
            else
            begin
                OP_MUX=OP1+1;
                C_NEXT=Flags[0];
            end
        end        
                
        OP_LDR:
        begin
            OP_MUX=OP2;
            C_NEXT=Flags[0];
        end    
        
        default:
        begin 
            OP_MUX=Acc;
            C_NEXT=Flags[0];
        end
        endcase
        
        W_Dout=OP_MUX;    
            
    end
    else
    begin
//        M_WE=MWE1;
        W_Addr=WAddr;
        M_Addr=WAddr;
        W_Dout=Acc;
    end   
end


endmodule