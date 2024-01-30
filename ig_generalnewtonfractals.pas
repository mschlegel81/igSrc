UNIT ig_generalNewtonFractals;

INTERFACE
USES complex,imageGeneration,myColors,myParams,myGenerics;
TYPE
  P_generalNewtonFractal=^T_generalNewtonFractal;

  { T_generalNewtonFractal }

  T_generalNewtonFractal=object(T_functionPerPixelAlgorithm)
    numberOfRoots:longint;
    rootColor:array[0..9] of T_rgbFloatColor;
    root     :array[0..9] of T_Complex;
    CONSTRUCTOR create;
    FUNCTION parameterResetStyles:T_arrayOfString; virtual;
    PROCEDURE resetParameters(CONST style:longint); virtual;
    FUNCTION numberOfParameters:longint; virtual;
    PROCEDURE setParameter(CONST index:byte; CONST value:T_parameterValue); virtual;
    FUNCTION getParameter(CONST index:byte):T_parameterValue; virtual;
    FUNCTION getColorAt(CONST ix,iy:longint; CONST xy:T_Complex):T_rgbFloatColor; virtual;
  end;

IMPLEMENTATION

{ T_generalNewtonFractal }

CONSTRUCTOR T_generalNewtonFractal.create;
  begin
    inherited create;
    addParameter('Roots',pt_integer,3,10);
    addParameter('r0',pt_2floats);
    addParameter('r1',pt_2floats);
    addParameter('r2',pt_2floats);
    addParameter('r3',pt_2floats);
    addParameter('r4',pt_2floats);
    addParameter('r5',pt_2floats);
    addParameter('r6',pt_2floats);
    addParameter('r7',pt_2floats);
    addParameter('r8',pt_2floats);
    addParameter('r9',pt_2floats);
    addParameter('Col0',pt_color);
    addParameter('Col1',pt_color);
    addParameter('Col2',pt_color);
    addParameter('Col3',pt_color);
    addParameter('Col4',pt_color);
    addParameter('Col5',pt_color);
    addParameter('Col6',pt_color);
    addParameter('Col7',pt_color);
    addParameter('Col8',pt_color);
    addParameter('Col9',pt_color);
    resetParameters(0);
  end;

FUNCTION T_generalNewtonFractal.parameterResetStyles: T_arrayOfString;
  begin
    setLength(result,4);
    result[0]:='Reset (default)';
    result[1]:='3rd roots of unity';
    result[2]:='5th roots of unity';
    result[3]:='L-Shape';
  end;

PROCEDURE T_generalNewtonFractal.resetParameters(CONST style: longint);
  VAR i:longint;
  begin
    inherited resetParameters(style);
    rootColor[0]:=BLACK;
    rootColor[1]:=RED;
    rootColor[2]:=GREEN;
    rootColor[3]:=BLUE;
    rootColor[4]:=YELLOW;
    rootColor[5]:=CYAN;
    rootColor[6]:=MAGENTA;
    rootColor[7]:=WHITE;
    rootColor[8]:=rgbColor(1,0.5,0);
    rootColor[9]:=rgbColor(0,0.5,1);
    root[0]:= 1;
    root[1]:=-1;
    for i:=2 to 9 do root[i]:=0;
    numberOfRoots:=3;
    if (style>0) and (style<=255) then case byte(style) of
      1: begin
        for i:=0 to 2 do begin
          root[i].re:=system.cos(i*2*pi/3);
          root[i].im:=system.sin(i*2*pi/3);
        end;
      end;
      2: begin
        for i:=0 to 4 do begin
          root[i].re:=system.cos(i*2*pi/5);
          root[i].im:=system.sin(i*2*pi/5);
        end;
        numberOfRoots:=5;
      end;
      3: begin
        root[0]:=-1-II;
        root[1]:=0-II;
        root[2]:=1;
        root[3]:=1+II;
        root[4]:=1-II;
        numberOfRoots:=5;
      end;
    end;
  end;

FUNCTION T_generalNewtonFractal.numberOfParameters: longint;
  begin
    result:=inherited numberOfParameters+21;
  end;

PROCEDURE T_generalNewtonFractal.setParameter(CONST index: byte; CONST value: T_parameterValue);
  begin
    if index<inherited numberOfParameters then inherited setParameter(index,value)
    else case byte(index-inherited numberOfParameters) of
      0: numberOfRoots:=value.i0;
      1..10:  with root[index-inherited numberOfParameters-1] do begin re:=value.f0; im:=value.f1; end;
      11..20: rootColor[index-inherited numberOfParameters-11]:=value.color;
    end;
  end;

FUNCTION T_generalNewtonFractal.getParameter(CONST index: byte): T_parameterValue;
  begin
    if index<inherited numberOfParameters then exit(inherited getParameter(index));
    case byte(index-inherited numberOfParameters) of
      0:      result.createFromValue(parameterDescription(index),numberOfRoots);
      1..10:  with root[index-inherited numberOfParameters-1] do result.createFromValue(parameterDescription(index),re,im);
      11..20: result.createFromValue(parameterDescription(index),rootColor[index-inherited numberOfParameters-11]);
    end;
  end;

FUNCTION T_generalNewtonFractal.getColorAt(CONST ix, iy: longint; CONST xy: T_Complex): T_rgbFloatColor;
  // F(x)  = (x-r0)*(x-r1)*(x-r2)*...
  // F'(x) = (x-r0)*(d/dx (x-r1)*(x-r2)*...) + (x-r1)*(x-r2)*...
  //       =        (x-r1)*(x-r2)*... +
  //         (x-r0)*       (x-r2)*... +
  //         (x-r0)*(x-r1)*       ... + ...
  // Newton: x[i+1] = x[i]-F(x[i])/F'(x[i])
  FUNCTION step(CONST x:T_Complex):T_Complex;
    VAR tmp:array[0..9] of T_Complex;
        i,j:longint;
        F,DF:T_Complex;
    begin
      for i:=0 to numberOfRoots-1 do tmp[i]:=x-root[i];
      DF:=0;
      F:=1;
      for i:=0 to numberOfRoots-1 do begin
        F*=tmp[i];
        result:=1;
        for j:=0 to numberOfRoots-1 do if j<>i then result*=tmp[j];
        DF+=result;
      end;
      result:=x-F/DF;
    end;

  FUNCTION closeToRoot(CONST x:T_Complex):longint;
    VAR i:longint;
    begin
      for i:=0 to numberOfRoots-1 do if sqrabs(x-root[i])<1E-12 then exit(i);
      result:=-1;
    end;

  FUNCTION closestRoot(CONST x:T_Complex):longint;
    VAR i:longint;
    begin
      result:=0;
      for i:=1 to numberOfRoots-1 do if sqrabs(x-root[i])<sqrabs(x-root[result]) then result:=i;
    end;

  VAR x:T_Complex;
      n,i0,i1,i2:longint;
  begin
    x:=xy;
    for n:=0 to 2046 do begin
      x:=step(x);
      if (n and 7)=7 then begin
        i0:=closeToRoot(x);
        if i0>=0 then begin
          x:=step(x);
          i1:=closestRoot(x);
          x:=step(x);
          i2:=closestRoot(x);
          if (i0=i1) and (i0=i2) then exit(rootColor[i0]);
        end;
      end;
    end;
    result:=rootColor[closestRoot(x)];
  end;

FUNCTION newGeneralNewton:P_generalImageGenrationAlgorithm;
  begin
    new(P_generalNewtonFractal(result),create);
  end;

INITIALIZATION
  registerAlgorithm('Generalized Newton Fractal',@newGeneralNewton,true,false,false);
end.

