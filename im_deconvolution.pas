UNIT im_deconvolution;

{$mode objfpc}{$H+}

INTERFACE
USES pixMaps,imageManipulation,imageContexts,myParams,sysutils,mypics;

IMPLEMENTATION
USES myColors;
TYPE
 T_kernel=object
       dat:PDouble;
       radius:longint;
       _width:longint;
       CONSTRUCTOR create(CONST radius_:longint);
       DESTRUCTOR destroy;
       FUNCTION getValue(CONST x,y:longint):double;
       PROCEDURE setValue(CONST x,y:longint; CONST val:double);
       PROPERTY value[x,y:longint]:double read getValue write setValue; default;
       PROCEDURE makePointSymmetric;
       PROCEDURE normalize;
       PROCEDURE multiplyWith(CONST other:T_kernel);
     end;

CONSTRUCTOR T_kernel.create(CONST radius_: longint);
  begin
    radius:=radius_;
    _width:=radius*2+1;
    getMem(dat,sqr(_width)*sizeOf(double));
  end;

DESTRUCTOR T_kernel.destroy;
  begin
    freeMem(dat,sqr(_width)*sizeOf(double));
  end;

FUNCTION T_kernel.getValue(CONST x, y: longint): double;
  begin
    result:=dat[x+radius+(y+radius)*_width];
  end;

PROCEDURE T_kernel.setValue(CONST x, y: longint; CONST val: double);
  begin
    dat[x+radius+(y+radius)*_width]:=val;
  end;

PROCEDURE T_kernel.makePointSymmetric;
  VAR x,y:longint;
      v:double;
  begin
    for y:=-radius to 0 do for x:=-radius to radius do begin
      v:=(value[x,y]+value[-x,-y])*0.5;
      value[ x, y]:=v;
      value[-x,-y]:=v;
    end;
  end;

PROCEDURE T_kernel.normalize;
  VAR i:longint;
      tmp:double=0;
  begin
    for i:=0 to _width*_width-1 do tmp+=dat[i];
    tmp:=1/tmp;
    for i:=0 to _width*_width-1 do dat[i]*=tmp;
  end;

PROCEDURE T_kernel.multiplyWith(CONST other: T_kernel);
  VAR i:longint;
  begin
    //TODO: Allow for multiplication with smaller or larger kernels
    if other.radius<>radius then raise Exception.create('Incompatible size');
    for i:=0 to sqr(_width)-1 do dat[i]*=other.dat[i];
  end;

PROCEDURE blind_deconvolution(VAR inputImage:T_rawImage; CONST kernel_radius,numberOfIterations:longint);
  VAR kernelGuess:T_kernel;
      imageGuess:T_rawImage;
      x,y:longint;
  PROCEDURE makeNonnegative(VAR c:T_rgbFloatColor);
    begin
      if c[cc_red  ]<0 then c[cc_red  ]:=0;
      if c[cc_green]<0 then c[cc_green]:=0;
      if c[cc_blue ]<0 then c[cc_blue ]:=0;
    end;

  begin
    kernelGuess.create(kernel_radius);
    for y:=-kernel_radius to kernel_radius do
    for x:=-kernel_radius to kernel_radius do
      kernelGuess[x,y]:=exp((-sqr(x)-sqr(y))/sqr(kernel_radius)*6);
    kernelGuess.normalize;

    imageGuess.create(inputImage);
    imageGuess.sharpen(0.1,0.5);
    for y:=0 to imageGuess.pixelCount-1 do makeNonnegative(imageGuess.rawData[y]);

  end;

end.

