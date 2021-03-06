module CacheControl(input Strobe,
                    input DRW,
                    input M,
                    input V,
                    input clk,
                    input reset,
                    input indirty, // set on write hit clear on read mem
                    output DReady,
                    output W,
                    output MStrobe,
                    output MRW,
                    output RSel,
                    output WSel,
                    output [1:0] OutDiry);

   logic [7:0] WSCLoadVal;   
   logic       CtrSig;
   logic       ReadyEn;
   logic       LdCtr;
   logic       Ready;   
   logic       SetDirty = 1'b0;
   logic       ClearDirty = 1'b0;
   logic [7:0]  OutputLogic;

  
   assign DReady = (ReadyEn & M && V && ~DRW) || Ready;
   assign {LdCtr, ReadyEn, Ready, W, MStrobe, MRW, WSel, RSel} = OutputLogic;
   // assign indirty = outdirty;
   assign OutDirty = (Setdirty << 1) + ClearDirty; //10 set; 01 clear; 00 nothing

   logic [3:0] CURRENT_STATE;
   logic [3:0] NEXT_STATE;

   // wait state = 100 cycles
   assign WSCLoadVal = 8'h4;   
   wait_state WaitStateCtr (LdCtr, WSCLoadVal, CtrSig, clk);

   // Insert FSM Here
   //state register
   flopr #(4) curr(.clk(clk),
                   .reset(reset),
                   .d(NEXT_STATE),
                   .q(CURRENT_STATE));
   //next state logic
   NextStateLogic next(.current(CURRENT_STATE),
                       .Strobe(Strobe),
                       .DRW(DRW),
                       .M(M),
                       .V(V),
                       .CtrSig(CtrSig),
                       .SetDirty(SetDirty),
                       .ClearDirty(ClearDirty),
                       .next(NEXT_STATE),
                       .OutputLogic(OutputLogic));
endmodule /* Control */

module NextStateLogic(input  logic [3:0] current,
                      input  logic       Strobe,
                      input  logic       DRW,
                      input  logic       M,
                      input  logic       V,
                      input  logic       CtrSig,
                      output logic       SetDirty,
                      output logic       ClearDirty,
                      output logic [3:0] next,
                      output logic [7:0] OutputLogic);

   parameter [3:0] Idle      = 4'b0000,
                   Read      = 4'b0001,
                   ReadMiss  = 4'b0010,
                   ReadMem   = 4'b0011,
                   ReadData  = 4'b0100,
                   Write     = 4'b0101,
                   WriteHit  = 4'b0110,
                   WriteMiss = 4'b0111,
                   WriteMem  = 4'b1000,
                   WriteData = 4'b1001;

   always_comb begin
      case(current)

         Idle: begin
            if(!Strobe) begin
                  next = Idle;
                  OutputLogic = 8'b10000000;
               end else if (Strobe && DRW) begin
                  next = Write;
                  OutputLogic = 8'b10000000;
               end else if (Strobe && !DRW) begin
                  next = Read;
                  OutputLogic = 8'b10000000;
               end
         end

         Read: begin
            if (!M && !V) begin
                  next = ReadMiss;
                  OutputLogic = 8'b11000000;
               end else if (!M && V) begin
                  next = ReadMiss;
                  OutputLogic = 8'b11000000;
               end else if (M && !V) begin
                  next = ReadMiss;
                  OutputLogic = 8'b11000000;
               end else if (M && V) begin
                  next = Idle;
                  OutputLogic = 8'b11000000;
               end
         end

         ReadMiss: begin
                     next = ReadMem;
                     OutputLogic = 8'b10001000;
         end

         ReadMem: begin
                  if (CtrSig) begin
                     next = ReadData;
                     ClearDirty = 1'b1;
                     OutputLogic = 8'b00000000;
                  end else if (CtrSig) begin
                     next = ReadMem;
                     OutputLogic = 8'b00000000;
                  end
         end

         ReadData: begin
               next = Idle;
               OutputLogic = 8'b00110110;
         end

         Write: begin
            if(M && V) next = WriteMiss;
            else       next = WriteHit;
            OutputLogic = 8'b10000000;
         end

         WriteHit: begin
            next = WriteData;
            dirty = 1;
            OutputLogic = 8'b10001100;
         end

         WriteMiss: begin
            next = WriteMem;
            OutputLogic = 8'b10001100;
         end

         WriteMem: begin
            if(CtrSig) begin
               next = Idle;
               OutputLogic = 8'b00000100;
            end
            else begin
               next = WriteMem;
               OutputLogic = 8'b00000100;
            end
         end

         WriteData: begin
            next = WriteMem;
            OutputLogic = 8'b00110101;
         end

         default: begin
            next = 4'bx;
            OutputLogic = 8'bx;
         end

      endcase
   end

endmodule /*NextStateLogic*/


