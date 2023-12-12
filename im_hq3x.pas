unit im_hq3x;
INTERFACE

IMPLEMENTATION
USES imageManipulation,imageContexts,myParams,mypics,myColors,math,pixMaps;

PROCEDURE hq3x_impl(CONST parameters:T_parameterValue; CONST context:P_abstractWorkflow);
  var dim,newDim: T_imageDimensions;
      temp: T_rawImage;
      tempDat: ^T_rgbFloatColor;

      inputCol,
      outputCol:array[-1..1] of ^T_rgbFloatColor;
      stencil:array[-1..1,-1..1] of T_rgbFloatColor;
      x,y,j,k,dx,dy:longint;
      threshold: Single;
      switch: byte;
  FUNCTION colSqr(CONST col:T_rgbFloatColor):single; inline;
    begin
      result:=sqr(col[cc_red])+
              sqr(col[cc_green])+
              sqr(col[cc_blue]);
    end;

  begin
    dim:=context^.image.dimensions;
    newDim.width:=dim.width*3;
    newDim.height:=dim.height*3;
    if (newDim.width>MAX_HEIGHT_OR_WIDTH) or (newDim.height>MAX_HEIGHT_OR_WIDTH) then begin
      context^.cancelWithError('Operation would exceed max. image dimensions');
      halt;
    end;
    temp.create(context^.image);
    context^.image.resize(newDim,res_dataResize);

    for y:=0 to dim.height-1 do begin
      inputCol [-1]:=temp.linePtr(Max(0,y-1));
      inputCol [ 0]:=temp.linePtr(      y   );
      inputCol [ 1]:=temp.linePtr(min(dim.height-1,y+1));
      outputCol[-1]:=context^.image.linePtr(3*y  );
      outputCol[ 0]:=context^.image.linePtr(3*y+1);
      outputCol[ 1]:=context^.image.linePtr(3*y+2);

      for x:=0 to dim.width-1 do begin
        j:=max(0,x-1);
        k:=min(dim.width-1,x+1);
        stencil[-1,-1]:=inputCol[-1][j]; stencil[0,-1]:=inputCol[-1][x]; stencil[1,-1]:=inputCol[-1][k];
        stencil[-1, 0]:=inputCol[ 0][j]; stencil[0, 0]:=inputCol[ 0][x]; stencil[1, 0]:=inputCol[ 0][k];
        stencil[-1, 1]:=inputCol[ 1][j]; stencil[0, 1]:=inputCol[ 1][x]; stencil[1, 1]:=inputCol[ 1][k];

        threshold:=((colSqr(stencil[-1,-1])+colSqr(stencil[-1,0])+colSqr(stencil[-1,1])
                    +colSqr(stencil[ 0,-1])+colSqr(stencil[ 0,0])+colSqr(stencil[ 0,1])
                    +colSqr(stencil[ 1,-1])+colSqr(stencil[ 1,0])+colSqr(stencil[ 1,1]))*0.1111111111111111
                  - colSqr((stencil[-1,-1] +       stencil[-1,0] +       stencil[-1,1]
                           +stencil[ 0,-1] +       stencil[ 0,0] +       stencil[ 0,1]
                           +stencil[ 1,-1] +       stencil[ 1,0] +       stencil[ 1,1] )*0.1111111111111111))*2;
        j:=1; switch:=0;
        for dx:=-1 to 1 do for dy:=-1 to 1 do if (dx<>0) or (dy<>0) then begin
          if colSqr(stencil[0,0]-stencil[dx,dy])<=threshold then switch+=j;
          j+=j;
        end;
        case switch of
        {$i hq3x_cases.inc}
        end;
      end;
    end;
    temp.destroy;




  end;


INITIALIZATION
  registerSimpleOperation(imc_filter,newParameterDescription('hq3x',pt_none),@hq3x_impl);

end.

